import { Router, Request, Response } from 'express';
import { requireAuth, requireRole, requireVerified } from '../middlewares/authMiddleware';
import { upload } from '../middlewares/uploadMiddleware';
import { uploadPriceList, respondToOrder, uploadPaymentProof, markOrderReady, getDashboardStatsPharmacy, getInboxOrders, getInvoices } from '../controllers/pharmacy.controller';
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

        // Fetch pharmacy profiles for address info and ensure they are wholesale
        const ids = (data || []).map((u: any) => u.id);
        let profiles: any[] = [];
        if (ids.length > 0) {
            const { data: profileData } = await supabase
                .from('pharmacy_profiles')
                .select('user_id, business_name, address, contact_phone')
                .eq('is_wholesale', true)
                .in('user_id', ids);
            profiles = profileData || [];
        }

        const pharmacies = profiles.map((profile: any) => {
            const u: any = (data || []).find((user: any) => user.id === profile.user_id) || {};
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
    requireVerified,
    upload.single('file'),
    uploadPriceList
);

router.post(
    '/orders/:id/response',
    requireRole(['PHARMACY']),
    requireVerified,
    respondToOrder
);

router.post(
    '/orders/:id/mark-ready',
    requireRole(['PHARMACY']),
    requireVerified,
    markOrderReady
);

router.post(
    '/invoices/:id/payment-proof',
    requireRole(['PHARMACY']),
    upload.single('proof'),
    uploadPaymentProof
);

router.get(
    '/stats',
    requireRole(['PHARMACY']),
    getDashboardStatsPharmacy
);

router.get(
    '/orders-inbox',
    requireRole(['PHARMACY']),
    getInboxOrders
);

router.get(
    '/invoices',
    requireRole(['PHARMACY']),
    getInvoices
);


export default router;
