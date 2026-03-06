import { Router } from 'express';
import { requireAuth, requireRole } from '../middlewares/authMiddleware';
import { getOrderById, confirmPickup, confirmDelivery, getAvailableDeliveries, acceptDelivery } from '../controllers/order.controller';

const router = Router();

router.use(requireAuth);

router.get('/available', requireRole(['DRIVER']), getAvailableDeliveries);
router.post('/:id/accept', requireRole(['DRIVER']), acceptDelivery);
router.get('/:id', getOrderById);
router.post('/:id/pickup', confirmPickup);
router.post('/:id/deliver', confirmDelivery);

export default router;
