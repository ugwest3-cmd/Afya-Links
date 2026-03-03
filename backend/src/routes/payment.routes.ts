import { Router } from 'express';
import { requireAuth } from '../middlewares/authMiddleware';
import { initiatePayment, pesapalWebhook } from '../controllers/payment.controller';

const router = Router();

// Endpoint for clinics to initiate pesapal checkout
router.post('/initiate', requireAuth, initiatePayment);

// HTML Callback for the App WebView after payment finishes
router.get('/callback', (req, res) => {
    res.send(`
        <html>
            <head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
            <body style="font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; background: #f8f9fa;">
                <div style="background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); text-align: center;">
                    <h2 style="color: #2E7D32; margin-bottom: 10px;">Payment Processing ✓</h2>
                    <p style="color: #666; font-size: 15px;">Your transaction has been submitted.</p>
                    <p style="color: #666; font-size: 14px; margin-top: 20px;">You can now close this window and return to the Afya Links app.</p>
                </div>
            </body>
        </html>
    `);
});

// Public endpoint for Pesapal IPN URL 
// Important: This MUST NOT require auth, Pesapal servers call it
router.post('/webhook', pesapalWebhook);
router.get('/webhook', pesapalWebhook); // Sometimes IPNs do GET depending on setup. Best to support both

export default router;
