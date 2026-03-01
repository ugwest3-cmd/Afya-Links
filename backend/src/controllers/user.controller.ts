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

        const { error } = await supabase
            .from(table)
            .update({ address })
            .eq('user_id', userId);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Address updated successfully' });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getNotifications = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;

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
