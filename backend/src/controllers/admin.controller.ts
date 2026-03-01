import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';

// 1. Get Pending Verifications
export const getPendingVerifications = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { data: users, error } = await supabase
            .from('users')
            .select(`
                id, name, email, phone, role, is_verified, created_at,
                pharmacy:pharmacy_profiles(registration_doc_url),
                clinic:clinic_profiles(business_reg_url)
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
        // Fetch all orders
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

// 1.5 Get All Users (for management)
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

// 2.5 Add User Manually (Admin override)
export const addUser = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { phone, role, name, email } = req.body;

        if (!phone || !role) {
            res.status(400).json({ success: false, message: 'Phone and role are required' });
            return;
        }

        // Check if user already exists
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

// 2.5.1 Delete User (Admin override)
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

        // Ensure user is actually a driver
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
            .upsert({
                user_id: driverId,
                region,
                available_hours
            }, { onConflict: 'user_id' });

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Driver profile updated' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
}

// 2.7 Send Notification (Admin)
export const sendNotificationAdmin = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { targetUserId, role, message } = req.body;

        if (!message) {
            res.status(400).json({ success: false, message: 'Message content is required' });
            return;
        }

        // Logic to resolve recipients
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

        // Insert notifications into the database
        const notifications = recipients.map(r => ({
            user_id: r.id,
            title: 'Admin Alert',
            message: message,
            is_read: false
        }));

        if (notifications.length > 0) {
            const { error: insertError } = await supabase
                .from('notifications')
                .insert(notifications);

            if (insertError) {
                console.error('[Notification Insert Error]', insertError);
                throw insertError;
            }
        }

        res.status(200).json({ success: true, message: `Notification broadcasted to ${recipients.length} users` });
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

// 4. Verify Payment
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
