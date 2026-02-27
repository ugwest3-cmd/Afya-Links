import { Router } from 'express';
import { requireAuth, requireRole } from '../middlewares/authMiddleware';
import {
    getPendingVerifications,
    approveUser,
    getInvoices,
    verifyPayment,
    getAllUsers,
    addUser,
    getAllOrders,
    updateDriverProfile,
    sendNotificationAdmin
} from '../controllers/admin.controller';

const router = Router();

router.use(requireAuth);
router.use(requireRole(['ADMIN'])); // Ensure only ADMINs can access these routes

router.get('/orders', getAllOrders);
router.get('/verifications/pending', getPendingVerifications);
router.get('/users', getAllUsers);
router.post('/users', addUser);
router.post('/users/:id/approve', approveUser);
router.post('/drivers/:id/profile', updateDriverProfile);
router.post('/notifications/send', sendNotificationAdmin);
router.get('/invoices', getInvoices);
router.post('/invoices/:id/verify', verifyPayment);

export default router;
