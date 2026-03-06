import { Router, Request, Response } from 'express';
import { requireAuth, requireRole, requireVerified } from '../middlewares/authMiddleware';
import { upload } from '../middlewares/uploadMiddleware';
import { uploadPriceList, respondToOrder, uploadPaymentProof, markOrderReady, getDashboardStatsPharmacy, getInboxOrders, getInvoices } from '../controllers/pharmacy.controller';
import { requestPayout, getPayoutHistory } from '../controllers/payout.controller';
import { supabase } from '../config/supabase';

const router = Router();

router.use(requireAuth);

// List all verified pharmacies (accessible by clinics when placing orders)
router.get('/', requireRole(['CLINIC', 'ADMIN']), async (req: any, res: Response): Promise<void> => {
    try {
        const userId = req.user?.id;
        const userRole = req.user?.role;

        // 1. Fetch clinic preferences
        let preferredTowns: string[] = [];
        if (userRole === 'CLINIC') {
            const { data: clinicProfile } = await supabase
                .from('clinic_profiles')
                .select('preferred_supply_towns')
                .eq('user_id', userId)
                .single();
            if (clinicProfile?.preferred_supply_towns) {
                preferredTowns = clinicProfile.preferred_supply_towns;
            }
        }

        const { data: users, error } = await supabase
            .from('users')
            .select('id, name, phone')
            .eq('role', 'PHARMACY')
            .eq('is_verified', true);
        if (error) throw error;

        const ids = (users || []).map((u: any) => u.id);
        let profiles: any[] = [];
        if (ids.length > 0) {
            const { data: profileData } = await supabase
                .from('pharmacy_profiles')
                .select('user_id, business_name, address, contact_phone, supply_areas')
                .in('user_id', ids);
            profiles = profileData || [];
        }

        let pharmacies = (users || []).map((u: any) => {
            const profile = profiles.find((p: any) => p.user_id === u.id);
            return {
                id: u.id,
                name: profile?.business_name || u.name || 'Pharmacy',
                address: profile?.address || '',
                phone: profile?.contact_phone || u.phone,
                supply_areas: profile?.supply_areas || []
            };
        });

        // Note: We only filter for CLINIC users. Admins see all.
        // If a clinic hasn't set preferences, they see all.
        // If a pharmacy hasn't set supply areas, they are shown to everyone for backward compatibility.
        if (userRole === 'CLINIC' && preferredTowns.length > 0) {
            pharmacies = pharmacies.filter((p: any) => {
                if (!p.supply_areas || p.supply_areas.length === 0) return true;
                return preferredTowns.some(town => p.supply_areas.includes(town));
            });
        }

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

// Payouts
router.post(
    '/payouts',
    requireRole(['PHARMACY']),
    requestPayout
);

router.get(
    '/payouts',
    requireRole(['PHARMACY']),
    getPayoutHistory
);


export default router;
