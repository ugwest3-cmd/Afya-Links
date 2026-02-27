import { Router } from 'express';
import { requireAuth, requireRole } from '../middlewares/authMiddleware';
import {
    getPendingVerifications,
    approveUser,
    getInvoices,
    verifyPayment
} from '../controllers/admin.controller';

const router = Router();

router.use(requireAuth);
router.use(requireRole(['ADMIN'])); // Ensure only ADMINs can access these routes

router.get('/verifications/pending', getPendingVerifications);
router.post('/users/:id/approve', approveUser);
router.get('/invoices', getInvoices);
router.post('/invoices/:id/verify', verifyPayment);

export default router;
