import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';
import { sendNotification } from '../services/notification.service';

// 1. Get Pending Verifications
export const getPendingVerifications = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: users, error } = await supabase
            .from('users')
            .select(`
                id, name, email, phone, role, is_verified, created_at,
                pharmacy: pharmacy_profiles(registration_doc_url),
                clinic: clinic_profiles(business_reg_url)
            `)
            .eq('is_verified', false);

        if (error) throw error;

        // Process data to extract the correct URL into a flat `document_url` field
        const processedUsers = users.map((u: any) => {
            let docPath = null;
            if (u.role === 'PHARMACY' && u.pharmacy?.registration_doc_url) {
                docPath = u.pharmacy.registration_doc_url;
            } else if (u.role === 'CLINIC' && u.clinic?.business_reg_url) {
                docPath = u.clinic.business_reg_url;
            }

            let document_url = null;
            if (docPath) {
                const { data: urlData } = supabase.storage
                    .from('verification-docs')
                    .getPublicUrl(docPath);
                document_url = urlData.publicUrl;
            }

            return {
                id: u.id,
                name: u.name,
                email: u.email,
                phone: u.phone,
                role: u.role,
                is_verified: u.is_verified,
                created_at: u.created_at,
                document_url
            };
        });

        res.status(200).json({ success: true, pending_users: processedUsers });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 1.2 Get All Orders
export const getAllOrders = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: orders, error } = await supabase
            .from('orders')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw error;

        res.status(200).json({ success: true, orders });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 1.5 Get All Users
export const getAllUsers = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: users, error } = await supabase
            .from('users')
            .select('id, name, email, phone, role, is_verified, created_at')
            .order('created_at', { ascending: false });

        if (error) throw error;

        res.status(200).json({ success: true, users });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 2. Approve User
export const approveUser = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id: targetUserId } = req.params;
        const { error } = await supabase
            .from('users')
            .update({ is_verified: true })
            .eq('id', targetUserId);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'User approved successfully' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 2.5 Add User Manually
export const addUser = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { phone, role, name, email } = req.body;
        if (!phone || !role) {
            res.status(400).json({ success: false, message: 'Phone and role are required' });
            return;
        }

        const { data: existingUser } = await supabase
            .from('users')
            .select('id')
            .eq('phone', phone)
            .single();

        if (existingUser) {
            res.status(400).json({ success: false, message: 'User with this phone number already exists' });
            return;
        }

        const { data: newUser, error } = await supabase
            .from('users')
            .insert([{ phone, role, name, email, is_verified: true }])
            .select()
            .single();

        if (error) throw error;

        res.status(201).json({ success: true, message: 'User created successfully', user: newUser });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 2.5.1 Delete User
export const deleteUser = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id: targetUserId } = req.params;
        const { error } = await supabase
            .from('users')
            .delete()
            .eq('id', targetUserId);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'User deleted successfully' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 2.6 Update Driver Profile
export const updateDriverProfile = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id: driverId } = req.params;
        const { region, available_hours } = req.body;

        const { data: driverInfo } = await supabase
            .from('users')
            .select('role')
            .eq('id', driverId)
            .single();

        if (driverInfo?.role !== 'DRIVER') {
            res.status(400).json({ success: false, message: 'User is not a driver' });
            return;
        }

        const { error } = await supabase
            .from('driver_profiles')
            .upsert({ user_id: driverId, region, available_hours }, { onConflict: 'user_id' });

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Driver profile updated' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 2.7 Send Notification Broadcast
export const sendNotificationAdmin = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { targetUserId, role, message } = req.body;
        if (!message) {
            res.status(400).json({ success: false, message: 'Message content is required' });
            return;
        }

        let recipients: any[] = [];
        if (targetUserId) {
            const { data } = await supabase.from('users').select('id, phone').eq('id', targetUserId).single();
            if (data) recipients.push(data);
        } else if (role) {
            const { data } = await supabase.from('users').select('id, phone').eq('role', role).eq('is_verified', true);
            if (data) recipients = data;
        } else {
            const { data } = await supabase.from('users').select('id, phone').eq('is_verified', true);
            if (data) recipients = data;
        }

        if (recipients.length === 0) {
            res.status(404).json({ success: false, message: 'No recipients found' });
            return;
        }

        // Send real-time push notifications using NotificationService
        await Promise.all(recipients.map(r =>
            sendNotification({
                userId: r.id,
                title: 'Admin Alert',
                body: message,
                type: 'ADMIN_BROADCAST'
            }).catch((err: any) => console.error(`[Admin Broadcast] Failed for user ${r.id}:`, err))
        ));

        res.status(200).json({ success: true, message: `Notification broadcasted to ${recipients.length} users` });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 2.8 Get System Settings
export const getSystemSettings = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data, error } = await supabase
            .from('system_settings')
            .select('*');

        if (error) throw error;

        const settings: Record<string, any> = {};
        data?.forEach(row => {
            settings[row.key] = row.value;
        });

        res.status(200).json({ success: true, settings });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 2.9 Update System Settings
export const updateSystemSettings = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { key, value } = req.body;
        if (!key || value === undefined) {
            res.status(400).json({ success: false, message: 'Key and value are required' });
            return;
        }

        const { error } = await supabase
            .from('system_settings')
            .upsert({ key, value, updated_at: new Date().toISOString() });

        if (error) throw error;

        res.status(200).json({ success: true, message: `Settings for ${key} updated successfully` });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 3. Get Invoices
export const getInvoices = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: invoices, error } = await supabase
            .from('invoices')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw error;
        res.status(200).json({ success: true, invoices });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 4. Verify Payment (Invoice)
export const verifyPayment = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { id: invoiceId } = req.params;
        const { error } = await supabase
            .from('invoices')
            .update({ status: 'PAID' })
            .eq('id', invoiceId);

        if (error) throw error;
        res.status(200).json({ success: true, message: 'Payment verified successfully' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 5. Escrow Ledger
export const getEscrowLedger = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: orders, error } = await supabase
            .from('orders')
            .select(`
                id, order_code, status, payment_status, payout_status, total_payable, 
                pharmacy_net, driver_net, total_platform_revenue, created_at,
                pharmacy: users!orders_pharmacy_id_fkey(name),
                clinic: users!orders_clinic_id_fkey(name)
            `)
            .order('created_at', { ascending: false });

        if (error) throw error;

        const totalLocked = orders.filter(o => o.status === 'PAID').reduce((sum, o) => sum + (Number(o.total_payable) || 0), 0);
        const totalReleased = orders.filter(o => o.status === 'COMPLETED').reduce((sum, o) => sum + (Number(o.total_payable) || 0), 0);
        const platformRevenue = orders.filter(o => o.status === 'COMPLETED').reduce((sum, o) => sum + (Number(o.total_platform_revenue) || 0), 0);

        res.status(200).json({
            success: true,
            metrics: {
                totalLocked,
                totalReleased,
                platformRevenue,
                activeDisputes: orders.filter(o => o.status === 'DISPUTE').length
            },
            ledger: orders
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 6. Resolve Dispute
export const resolveDispute = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { order_id, resolution_action } = req.body;
        if (!order_id || !['RELEASE_TO_PHARMACY', 'REFUND_TO_CLINIC'].includes(resolution_action)) {
            res.status(400).json({ success: false, message: 'Invalid parameters' });
            return;
        }

        const { data: order, error } = await supabase
            .from('orders')
            .select('id, status')
            .eq('id', order_id)
            .single();

        if (error || !order) {
            res.status(404).json({ success: false, message: 'Order not found' });
            return;
        }

        if (order.status === 'COMPLETED' || order.status === 'REFUNDED') {
            res.status(400).json({ success: false, message: 'Order is already resolved.' });
            return;
        }

        if (resolution_action === 'RELEASE_TO_PHARMACY') {
            await supabase.from('orders').update({
                status: 'COMPLETED',
                payout_status: 'INITIATED'
            }).eq('id', order_id);
        } else {
            await supabase.from('orders').update({ status: 'REFUNDED' }).eq('id', order_id);
        }

        res.status(200).json({ success: true, message: `Dispute resolved: ${resolution_action}` });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 7. Route Management
export const getDriverRoutes = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: routes, error } = await supabase
            .from('clinic_driver_routes')
            .select(`
                id, clinic_id, driver_id, delivery_fee, notes, is_active, created_at, updated_at,
                clinic: users!clinic_driver_routes_clinic_id_fkey(id, name, phone),
                driver: users!clinic_driver_routes_driver_id_fkey(id, name, phone)
            `)
            .order('created_at', { ascending: false });

        if (error) throw error;
        res.status(200).json({ success: true, routes });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

export const upsertDriverRoute = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { clinic_id, driver_id, delivery_fee, notes } = req.body;
        if (!clinic_id || !driver_id || delivery_fee === undefined) {
            res.status(400).json({ success: false, message: 'clinic_id, driver_id, and delivery_fee are required' });
            return;
        }

        const { data: route, error } = await supabase
            .from('clinic_driver_routes')
            .upsert({
                clinic_id,
                driver_id,
                delivery_fee: Number(delivery_fee),
                notes: notes || null,
                is_active: true
            }, { onConflict: 'clinic_id' })
            .select()
            .single();

        if (error) throw error;
        res.status(200).json({ success: true, message: 'Route assignment saved', route });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

export const deleteDriverRoute = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { clinic_id } = req.params;
        const { error } = await supabase
            .from('clinic_driver_routes')
            .delete()
            .eq('clinic_id', clinic_id);

        if (error) throw error;
        res.status(200).json({ success: true, message: 'Route assignment removed' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 8. Get All Driver Locations (Live Map)
export const getAllDriverLocations = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: locations, error } = await supabase
            .from('driver_locations')
            .select(`
                latitude, longitude, updated_at,
                driver: users(id, name, phone)
            `);

        if (error) throw error;

        res.status(200).json({ success: true, locations });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}
