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
    sendNotificationAdmin,
    deleteUser,
    getEscrowLedger,
    resolveDispute,
    getDriverRoutes,
    upsertDriverRoute,
    deleteDriverRoute
} from '../controllers/admin.controller';

const router = Router();

router.use(requireAuth);
router.use(requireRole(['ADMIN'])); // Ensure only ADMINs can access these routes

router.get('/orders', getAllOrders);
router.get('/verifications/pending', getPendingVerifications);
router.get('/users', getAllUsers);
router.post('/users', addUser);
router.delete('/users/:id', deleteUser);
router.post('/users/:id/approve', approveUser);
router.post('/drivers/:id/profile', updateDriverProfile);
router.post('/notifications/send', sendNotificationAdmin);
router.get('/invoices', getInvoices);
router.post('/invoices/:id/verify', verifyPayment);

// Escrow Management
router.get('/escrow', getEscrowLedger);
router.post('/escrow/resolve', resolveDispute);

// Clinic-Driver Route Assignments
router.get('/driver-routes', getDriverRoutes);
router.post('/driver-routes', upsertDriverRoute);
router.delete('/driver-routes/:clinic_id', deleteDriverRoute);

export default router;
