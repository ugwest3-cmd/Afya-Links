import { Response, Request } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';
import { submitOrder, getTransactionStatus } from '../utils/pesapal';

const APP_FRONTEND_URL = process.env.APP_FRONTEND_URL || 'https://afya-links-frontend.vercel.app';
const BACKEND_URL = process.env.APP_BASE_URL || 'https://afya-links-production.up.railway.app';

/**
 * Shared helper: confirm a payment by tracking ID and update the order status.
 * Used by both the IPN webhook and the callback (as a fallback).
 */
const confirmPaymentByTrackingId = async (trackingId: string, merchantReference: string): Promise<void> => {
    const txStatus = await getTransactionStatus(trackingId);

    const isCompleted = txStatus.payment_status_code === 1;
    const isFailed = txStatus.payment_status_code === 2 || txStatus.payment_status_code === 3;

    // Update transaction log
    await supabase
        .from('pesapal_transactions')
        .upsert({
            tracking_id: trackingId,
            order_id: merchantReference,
            merchant_reference: merchantReference,
            amount: txStatus.amount,
            currency: txStatus.currency,
            payment_method: txStatus.payment_method,
            payment_status_code: txStatus.payment_status_code,
            payment_status_description: txStatus.payment_status_description,
            ipn_notified: true
        }, { onConflict: 'tracking_id' });

    if (isCompleted) {
        const { data: order } = await supabase
            .from('orders')
            .select('status, total_payable, clinic_id, pharmacy_id')
            .eq('id', merchantReference)
            .single();

        if (order && order.status === 'AWAITING_PAYMENT') {
            // Allow a small tolerance (±2 UGX) for rounding and sandbox discrepancies
            const expectedAmount = Number(order.total_payable);
            const receivedAmount = Number(txStatus.amount);
            const amountOk = Math.abs(expectedAmount - receivedAmount) <= 2;

            if (amountOk) {
                await supabase.from('orders')
                    .update({ status: 'PAID', payment_status: 'VERIFIED' })
                    .eq('id', merchantReference);

                const shortId = merchantReference.slice(0, 8).toUpperCase();
                Promise.resolve(supabase.from('notifications').insert([
                    {
                        user_id: order.clinic_id,
                        title: '✅ Payment Confirmed',
                        body: `Your payment for order #${shortId} was successful. The pharmacy is now processing your order.`,
                        type: 'PAYMENT_SUCCESS',
                        is_read: false
                    },
                    {
                        user_id: order.pharmacy_id,
                        title: '💰 Payment Received – Action Required',
                        body: `Payment for order #${shortId} has been confirmed. Please check your Orders Inbox and action this order.`,
                        type: 'PAYMENT_SUCCESS',
                        is_read: false
                    }
                ])).catch(console.error);

                // Auto-assign driver if one is linked to this clinic's route
                const { assignDriverAndNotify } = await import('../utils/driverAssignment');
                Promise.resolve(assignDriverAndNotify(merchantReference, shortId)).catch(console.error);
            } else {
                console.error(`[Payment] Amount mismatch on order ${merchantReference}. Expected ${expectedAmount}, got ${receivedAmount}`);
            }
        }
    } else if (isFailed) {
        await supabase.from('orders')
            .update({ payment_status: 'PAYMENT_FAILED' })
            .eq('id', merchantReference);
    }
};

export const initiatePayment = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;
        const { order_id } = req.body;

        if (!order_id) {
            res.status(400).json({ success: false, message: 'order_id is required' });
            return;
        }

        // Check order details
        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('*, clinic:users!orders_clinic_id_fkey(name, phone, email)')
            .eq('id', order_id)
            .eq('clinic_id', clinicId)
            .single();

        if (orderError || !order) {
            res.status(404).json({ success: false, message: 'Order not found' });
            return;
        }

        if (order.status !== 'AWAITING_PAYMENT') {
            res.status(400).json({ success: false, message: 'Order is not awaiting payment' });
            return;
        }

        // Prepare Pesapal order
        const clinicUser = Array.isArray(order.clinic) ? order.clinic[0] : order.clinic;

        const pesapalResponse = await submitOrder({
            id: order.id,
            amount: order.total_payable,
            description: `Afya Links Order ${order.id}`,
            callback_url: `${BACKEND_URL}/api/payments/callback?order_id=${order.id}`,
            billing_address: {
                email_address: clinicUser?.email || 'test@pesapal.com',
                phone_number: clinicUser?.phone || '0700000000',
                country_code: 'UG',
                first_name: clinicUser?.name?.split(' ')[0] || 'Clinic',
                last_name: clinicUser?.name?.split(' ')[1] || 'Owner'
            }
        });

        // The pesapal tracking ID could be saved here, but it's normally generated by Pesapal and passed back in IPN. 
        // We'll log it if needed, or simply let the IPN handle it. We can insert a pending transaction log:
        await supabase.from('pesapal_transactions').insert([{
            order_id: order.id,
            tracking_id: pesapalResponse.order_tracking_id,
            merchant_reference: order.id,
            amount: order.total_payable,
            payment_status_description: 'PENDING'
        }]);

        res.status(200).json({
            success: true,
            redirect_url: pesapalResponse.redirect_url,
            order_tracking_id: pesapalResponse.order_tracking_id
        });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Pesapal Webhook (IPN)
 * This is called by Pesapal when a payment succeeds or fails.
 */
export const pesapalWebhook = async (req: Request, res: Response): Promise<void> => {
    try {
        const { OrderTrackingId, OrderNotificationType, OrderMerchantReference } = req.query;

        if (!OrderTrackingId || !OrderMerchantReference) {
            res.status(400).json({ success: false, message: 'Missing OrderTrackingId or OrderMerchantReference' });
            return;
        }

        await confirmPaymentByTrackingId(
            OrderTrackingId as string,
            OrderMerchantReference as string
        );

        // Respond to Pesapal with 200 OK (required)
        res.status(200).json({
            OrderTrackingId,
            OrderNotificationType,
            OrderMerchantReference,
            status: 200
        });

    } catch (error: any) {
        console.error('Pesapal Webhook Error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * Pesapal Callback (browser redirect after payment)
 * This is loaded in the WebView after the user finishes payment on Pesapal.
 * As a safety net, it also confirms the payment status in case the IPN webhook was delayed.
 */
export const pesapalCallback = async (req: Request, res: Response): Promise<void> => {
    const { order_id, OrderTrackingId, OrderMerchantReference } = req.query;

    const trackingId = OrderTrackingId as string | undefined;
    const merchantRef = (OrderMerchantReference as string) || (order_id as string);

    // Best-effort: try to confirm payment if we have enough info
    if (trackingId && merchantRef) {
        try {
            await confirmPaymentByTrackingId(trackingId, merchantRef);
        } catch (err) {
            console.error('[Callback] Could not confirm payment status:', err);
        }
    }

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
};
