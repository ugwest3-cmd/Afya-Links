import { Router } from 'express';
import { requireAuth } from '../middlewares/authMiddleware';
import { getOrderById, confirmPickup, confirmDelivery } from '../controllers/order.controller';

const router = Router();

router.use(requireAuth);

router.get('/:id', getOrderById);
router.post('/:id/pickup', confirmPickup);
router.post('/:id/deliver', confirmDelivery);

export default router;
