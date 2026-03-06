import { Router } from 'express';
import { requireAuth } from '../middlewares/authMiddleware';
import { updateDriverLocation, getOrderTracking } from '../controllers/tracking.controller';

const router = Router();

router.use(requireAuth);

// Delivery App: Update location
router.post('/update', updateDriverLocation);

// Clinic App: Get order tracking
router.get('/order/:orderId', getOrderTracking);

export default router;
