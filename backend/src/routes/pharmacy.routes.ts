import { Router, Request, Response } from 'express';
import { requireAuth, requireRole } from '../middlewares/authMiddleware';
import { upload } from '../middlewares/uploadMiddleware';
import { uploadPriceList, respondToOrder, uploadPaymentProof } from '../controllers/pharmacy.controller';
import { supabase } from '../config/supabase';

const router = Router();

router.use(requireAuth);

// List all verified pharmacies (accessible by clinics when placing orders)
router.get('/', requireRole(['CLINIC', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
    try {
        const { data, error } = await supabase
            .from('users')
            .select('id, name, phone')
            .eq('role', 'PHARMACY')
            .eq('is_verified', true);
        if (error) throw error;

        // Fetch pharmacy profiles for address info
        const ids = (data || []).map((u: any) => u.id);
        let profiles: any[] = [];
        if (ids.length > 0) {
            const { data: profileData } = await supabase
                .from('pharmacy_profiles')
                .select('user_id, business_name, address, contact_phone')
                .in('user_id', ids);
            profiles = profileData || [];
        }

        const pharmacies = (data || []).map((u: any) => {
            const profile = profiles.find((p: any) => p.user_id === u.id) || {};
            return { id: u.id, name: profile.business_name || u.name || 'Pharmacy', address: profile.address || '', phone: profile.contact_phone || u.phone };
        });

        res.status(200).json({ success: true, data: pharmacies });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
});

router.post(
    '/price-list',
    requireRole(['PHARMACY']),
    upload.single('file'),
    uploadPriceList
);

router.post(
    '/orders/:id/response',
    requireRole(['PHARMACY']),
    respondToOrder
);

router.post(
    '/invoices/:id/payment-proof',
    requireRole(['PHARMACY']),
    upload.single('proof'),
    uploadPaymentProof
);

export default router;
