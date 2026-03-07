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
    deleteDriverRoute,
    getSystemSettings,
    updateSystemSettings,
    getAllDriverLocations
} from '../controllers/admin.controller';
import { adminGetPayoutRequests, adminGetPayoutAlerts, adminMarkPayoutPaid, adminGetDriverPayoutRequests, adminMarkDriverPayoutPaid } from '../controllers/payout.controller';
import { adminConfirmPayment, adminCheckPesapalStatus } from '../controllers/payment.controller';

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

// Payout Management
router.get('/payouts', adminGetPayoutRequests);
router.get('/payouts/drivers', adminGetDriverPayoutRequests);
router.get('/payout-alerts', adminGetPayoutAlerts);
router.post('/payouts/:id/pay', adminMarkPayoutPaid);
router.post('/payouts/drivers/:id/pay', adminMarkDriverPayoutPaid);

// Clinic-Driver Route Assignments
router.get('/driver-routes', getDriverRoutes);
router.post('/driver-routes', upsertDriverRoute);
router.delete('/driver-routes/:clinic_id', deleteDriverRoute);

// Payment Diagnostics & Manual Override
router.post('/payments/confirm', adminConfirmPayment);
router.get('/payments/status/:tracking_id', adminCheckPesapalStatus);

// System Settings
router.get('/settings', getSystemSettings);
router.post('/settings', updateSystemSettings);

// Live Monitoring
router.get('/locations', getAllDriverLocations);

export default router;
