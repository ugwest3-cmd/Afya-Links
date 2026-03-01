import { Router } from 'express';
import { requireAuth, requireRole, requireVerified } from '../middlewares/authMiddleware';
import { getPriceOffers, createOrder, confirmDelivery, getDashboardStatsClinic, getMyOrders } from '../controllers/clinic.controller';

const router = Router();

router.use(requireAuth);

router.post(
    '/price-offers',
    requireRole(['CLINIC']),
    requireVerified,
    getPriceOffers
);

router.post(
    '/orders',
    requireRole(['CLINIC', 'ADMIN']),
    requireVerified,
    createOrder
);

router.post(
    '/orders/:id/confirm-delivery',
    requireRole(['CLINIC', 'ADMIN']),
    requireVerified,
    confirmDelivery
);

router.get(
    '/stats',
    requireRole(['CLINIC']),
    getDashboardStatsClinic
);

router.get(
    '/my-orders',
    requireRole(['CLINIC']),
    getMyOrders
);


export default router;
