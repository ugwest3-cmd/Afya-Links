import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';
import { uploadFileToSupabase } from '../utils/storage';

export const setupClinicProfile = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const { business_name, address, contact_phone } = req.body;

        // Explicit type to handle Multer fields
        const files = req.files as { [fieldname: string]: Express.Multer.File[] };
        const businessRegFile = files?.business_reg?.[0];

        if (!businessRegFile) {
            res.status(400).json({ success: false, message: 'Business registration document is required' });
            return;
        }

        let business_reg_url = '';
        try {
            business_reg_url = await uploadFileToSupabase('verification-docs', businessRegFile, `clinics/${userId}`);
        } catch (e: any) {
            res.status(500).json({ success: false, message: 'Upload failed', error: e.message });
            return;
        }

        const { error } = await supabase
            .from('clinic_profiles')
            .upsert({
                user_id: userId,
                business_name,
                address,
                business_reg_url,
                contact_phone
            });

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Clinic profile setup successfully' });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const setupPharmacyProfile = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const { business_name, address, contact_phone } = req.body;

        const files = req.files as { [fieldname: string]: Express.Multer.File[] };
        const businessRegFile = files?.business_reg?.[0];
        const pharmacyLicenseFile = files?.pharmacy_license?.[0];

        if (!businessRegFile || !pharmacyLicenseFile) {
            res.status(400).json({ success: false, message: 'Business registration and pharmacy license are required' });
            return;
        }

        const business_reg_url = await uploadFileToSupabase('verification-docs', businessRegFile, `pharmacies/${userId}`);
        const pharmacy_license_url = await uploadFileToSupabase('verification-docs', pharmacyLicenseFile, `pharmacies/${userId}`);

        const { error } = await supabase
            .from('pharmacy_profiles')
            .upsert({
                user_id: userId,
                business_name,
                address,
                business_reg_url,
                pharmacy_license_url,
                contact_phone
            });

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Pharmacy profile setup successfully' });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getProfileStatus = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const { data: user, error } = await supabase
            .from('users')
            .select('is_verified, role, phone')
            .eq('id', userId)
            .single();

        if (error || !user) {
            res.status(404).json({ success: false, message: 'User not found' });
            return;
        }

        let profileData = {};
        if (user.role === 'CLINIC') {
            const { data } = await supabase.from('clinic_profiles').select('*').eq('user_id', userId).single();
            if (data) profileData = data;
        } else if (user.role === 'PHARMACY') {
            const { data } = await supabase.from('pharmacy_profiles').select('*').eq('user_id', userId).single();
            if (data) profileData = data;
        } else if (user.role === 'DRIVER') {
            const { data } = await supabase.from('driver_profiles').select('*').eq('user_id', userId).single();
            if (data) profileData = data;
        }

        res.status(200).json({
            success: true,
            data: {
                ...profileData,
                is_verified: user.is_verified,
                role: user.role,
                phone: user.phone
            }
        });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
}

export const uploadVerificationDoc = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const role = req.user?.role;
        const { doc_type } = req.body; // 'business_reg_url' or 'pharmacy_license_url'

        const file = req.file;

        if (!file) {
            res.status(400).json({ success: false, message: 'Document file is required' });
            return;
        }

        if (!doc_type || !['business_reg_url', 'pharmacy_license_url'].includes(doc_type)) {
            res.status(400).json({ success: false, message: 'Invalid doc_type. Must be business_reg_url or pharmacy_license_url' });
            return;
        }

        const folder = role === 'PHARMACY' ? `pharmacies/${userId}` : `clinics/${userId}`;
        const fileUrl = await uploadFileToSupabase('verification-docs', file, folder);

        const table = role === 'PHARMACY' ? 'pharmacy_profiles' : 'clinic_profiles';

        const { error } = await supabase
            .from(table)
            .update({ [doc_type]: fileUrl })
            .eq('user_id', userId);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Document uploaded successfully', url: fileUrl });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const updateAddress = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const role = req.user?.role;
        const { address } = req.body;

        if (!address) {
            res.status(400).json({ success: false, message: 'Address is required' });
            return;
        }

        const table = role === 'PHARMACY' ? 'pharmacy_profiles' : 'clinic_profiles';

        // Use upsert so it creates a row if none exists yet
        const { error } = await supabase
            .from(table)
            .upsert({ user_id: userId, address }, { onConflict: 'user_id' });

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Address updated successfully' });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getNotifications = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;

        // Auto-delete read notifications that were marked as read more than 1 day ago
        const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
        await supabase
            .from('notifications')
            .delete()
            .eq('user_id', userId)
            .eq('is_read', true)
            .lt('read_at', oneDayAgo);

        // Fetch remaining notifications
        const { data: notifications, error } = await supabase
            .from('notifications')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', { ascending: false });

        if (error) throw error;

        res.status(200).json({ success: true, notifications });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const markNotificationsRead = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;

        const { error } = await supabase
            .from('notifications')
            .update({ is_read: true, read_at: new Date().toISOString() })
            .eq('user_id', userId)
            .eq('is_read', false);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'All notifications marked as read' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const saveFcmToken = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const { fcm_token } = req.body;

        if (!fcm_token) {
            res.status(400).json({ success: false, message: 'FCM token is required' });
            return;
        }

        const { error } = await supabase
            .from('users')
            .update({ fcm_token })
            .eq('id', userId);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'FCM token saved successfully' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const updateProfilePreferences = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const role = req.user?.role;

        if (role === 'CLINIC') {
            const { preferred_supply_towns } = req.body;
            if (preferred_supply_towns !== undefined) {
                const { error } = await supabase
                    .from('clinic_profiles')
                    .update({ preferred_supply_towns })
                    .eq('user_id', userId);
                if (error) throw error;
            }
        } else if (role === 'PHARMACY') {
            const { supply_areas, preferred_payout_method, payout_details } = req.body;

            const updates: any = {};
            if (supply_areas !== undefined) updates.supply_areas = supply_areas;
            if (preferred_payout_method !== undefined) updates.preferred_payout_method = preferred_payout_method;
            if (payout_details !== undefined) updates.payout_details = payout_details;

            if (Object.keys(updates).length > 0) {
                const { error } = await supabase
                    .from('pharmacy_profiles')
                    .update(updates)
                    .eq('user_id', userId);
                if (error) throw error;
            }
        }

        res.status(200).json({ success: true, message: 'Profile preferences updated successfully' });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getMyDeliveries = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;

        const { data: deliveries, error } = await supabase
            .from('deliveries')
            .select(`
                id,
                order_id,
                pickup_time,
                dropoff_time,
                orders (
                    id,
                    order_code,
                    delivery_address,
                    status,
                    total_amount,
                    pharmacy_id,
                    clinic_id,
                    pharmacy:pharmacy_profiles!orders_pharmacy_id_fkey(business_name, address),
                    clinic:clinic_profiles!orders_clinic_id_fkey(business_name, address)
                )
            `)
            .eq('driver_id', userId)
            .order('created_at', { ascending: false });

        if (error) throw error;

        // Flatten the relation so the Flutter app can easily read it
        const formattedDeliveries = deliveries?.map((d: any) => ({
            ...d,
            order: {
                ...d.orders,
                pharmacy: Array.isArray(d.orders?.pharmacy) ? d.orders?.pharmacy[0] : d.orders?.pharmacy,
                clinic: Array.isArray(d.orders?.clinic) ? d.orders?.clinic[0] : d.orders?.clinic,
            }
        }));

        res.status(200).json({ success: true, deliveries: formattedDeliveries });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const setupDriverProfile = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const { national_id_number, vehicle_type, license_plate_number, region, preferred_payout_method, payout_details, name } = req.body;

        if (name) {
            await supabase.from('users').update({ name }).eq('id', userId);
        }

        const { error } = await supabase
            .from('driver_profiles')
            .upsert({
                user_id: userId,
                national_id_number,
                vehicle_type,
                license_plate_number,
                region,
                preferred_payout_method,
                payout_details: typeof payout_details === 'string' ? JSON.parse(payout_details) : payout_details
            });

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Driver profile setup successfully' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const toggleDriverStatus = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const { is_online } = req.body;

        console.log(`[DriverStatus] Attempting to set driver ${userId} to ${is_online ? 'ONLINE' : 'OFFLINE'}`);

        // We use upsert to ensure that even if the profile row is missing, it gets created
        // though normally it should already exist from registration.
        const { data, error } = await supabase
            .from('driver_profiles')
            .upsert({ user_id: userId, is_online }, { onConflict: 'user_id' })
            .select();

        if (error) {
            console.error(`[DriverStatus] Supabase error for ${userId}:`, error);
            throw error;
        }

        console.log(`[DriverStatus] Success for ${userId}. Data:`, data);

        res.status(200).json({ success: true, message: `Driver went ${is_online ? 'ONLINE' : 'OFFLINE'}` });
    } catch (e: any) {
        console.error(`[DriverStatus] Fatal error for driver toggle:`, e.message);
        res.status(500).json({ success: false, message: e.message });
    }
};

export const getDriverWallet = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const { data: profile, error } = await supabase
            .from('driver_profiles')
            .select('wallet_balance')
            .eq('user_id', userId)
            .single();

        if (error || !profile) {
            res.status(404).json({ success: false, message: 'Profile not found' });
            return;
        }

        const { data: payouts } = await supabase
            .from('driver_payouts')
            .select('*')
            .eq('driver_id', userId)
            .order('created_at', { ascending: false });

        const { data: deliveries } = await supabase
            .from('deliveries')
            .select('driver_fee_collected')
            .eq('driver_id', userId);

        const totalEarned = deliveries?.reduce((sum, d) => sum + (d.driver_fee_collected || 0), 0) || 0;

        res.status(200).json({
            success: true,
            wallet_balance: profile.wallet_balance,
            total_earned: totalEarned,
            payout_history: payouts || []
        });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const requestDriverPayout = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const MIN_PAYOUT = 10000;

        // Fetch driver's wallet and details
        const { data: profile, error } = await supabase
            .from('driver_profiles')
            .select('wallet_balance, preferred_payout_method, payout_details')
            .eq('user_id', userId)
            .single();

        if (error || !profile) {
            res.status(404).json({ success: false, message: 'Driver profile not found' });
            return;
        }

        if (profile.wallet_balance < MIN_PAYOUT) {
            res.status(400).json({ success: false, message: `Minimum payout is UGX ${MIN_PAYOUT}` });
            return;
        }

        // Create payout request
        const { error: insertError } = await supabase
            .from('driver_payouts')
            .insert({
                driver_id: userId,
                amount: profile.wallet_balance,
                payment_method: profile.preferred_payout_method,
                payment_details: profile.payout_details,
                status: 'PENDING'
            });

        if (insertError) throw insertError;

        // Deduct from wallet
        const { error: updateError } = await supabase
            .from('driver_profiles')
            .update({ wallet_balance: 0 })
            .eq('user_id', userId);

        if (updateError) throw updateError;

        // Create an admin notification instead of sending an email for now
        await supabase.from('notifications').insert({
            user_id: userId, // Keep user_id here just as reference, maybe we need an admin role ID, but MVP simply assumes admins read all payout reqs.
            title: 'New Driver Payout Request',
            body: `Driver requested UGX ${profile.wallet_balance} via ${profile.preferred_payout_method}.`
        });

        res.status(200).json({ success: true, message: 'Payout requested successfully' });
    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};
