import { Router } from 'express';
import { requireAuth } from '../middlewares/authMiddleware';
import { initiatePayment, pesapalWebhook, pesapalCallback } from '../controllers/payment.controller';

const router = Router();

// Endpoint for clinics to initiate pesapal checkout
router.post('/initiate', requireAuth, initiatePayment);

// HTML Callback for the App WebView after payment finishes
// Also acts as a safety net to confirm payment status if IPN webhook was delayed/missed
router.get('/callback', pesapalCallback);

// Public endpoint for Pesapal IPN URL
// Important: This MUST NOT require auth — Pesapal servers call it directly
router.post('/webhook', pesapalWebhook);
router.get('/webhook', pesapalWebhook); // Support both GET and POST IPN notifications

export default router;
