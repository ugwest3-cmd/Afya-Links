import { Router } from 'express';
import { requireAuth } from '../middlewares/authMiddleware';
import { initiatePayment, pesapalWebhook } from '../controllers/payment.controller';

const router = Router();

// Endpoint for clinics to initiate pesapal checkout
router.post('/initiate', requireAuth, initiatePayment);

// Public endpoint for Pesapal IPN URL 
// Important: This MUST NOT require auth, Pesapal servers call it
router.post('/webhook', pesapalWebhook);
router.get('/webhook', pesapalWebhook); // Sometimes IPNs do GET depending on setup. Best to support both

export default router;
