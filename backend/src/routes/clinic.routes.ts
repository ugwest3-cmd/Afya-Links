import { Router } from 'express';
import { requireAuth, requireRole } from '../middlewares/authMiddleware';
import { getPriceOffers, createOrder, confirmDelivery } from '../controllers/clinic.controller';

const router = Router();

router.use(requireAuth);

router.post(
    '/price-offers',
    requireRole(['CLINIC']),
    getPriceOffers
);

router.post(
    '/orders',
    requireRole(['CLINIC']),
    createOrder
);

router.post(
    '/orders/:id/confirm-delivery',
    requireRole(['CLINIC']),
    confirmDelivery
);

export default router;
