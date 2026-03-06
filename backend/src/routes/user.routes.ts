import { Router } from 'express';
import { requireAuth, requireRole } from '../middlewares/authMiddleware';
import { upload } from '../middlewares/uploadMiddleware';
import { setupClinicProfile, setupPharmacyProfile, getProfileStatus, uploadVerificationDoc, updateAddress, getNotifications, markNotificationsRead, saveFcmToken, updateProfilePreferences, getMyDeliveries } from '../controllers/user.controller';

const router = Router();

// Apply authentication middleware to all routes in this file
router.use(requireAuth);

router.get('/status', getProfileStatus);
router.get('/notifications', getNotifications);
router.post('/notifications/mark-read', markNotificationsRead);
router.post('/fcm-token', saveFcmToken);
router.get('/me/deliveries', getMyDeliveries);

router.post(
    '/profile/clinic',
    requireRole(['CLINIC']),
    upload.fields([{ name: 'business_reg', maxCount: 1 }]),
    setupClinicProfile
);

router.post(
    '/profile/pharmacy',
    requireRole(['PHARMACY']),
    upload.fields([{ name: 'business_reg', maxCount: 1 }, { name: 'pharmacy_license', maxCount: 1 }]),
    setupPharmacyProfile
);

router.post(
    '/upload-doc',
    upload.single('document'),
    uploadVerificationDoc
);

// We can add the driver and health worker profile routes here similarly.

router.put(
    '/profile/address',
    updateAddress
);

router.put(
    '/profile/preferences',
    updateProfilePreferences
);

export default router;
