import cron from 'node-cron';
import { supabase } from '../config/supabase';

// Scheduled for every Monday at 00:00
export const initCronJobs = () => {
    cron.schedule('0 0 * * 1', async () => {
        console.log('[CRON] Running weekly invoice generation...');

        try {
            // 1. Get all DELIVERED orders from the past week that haven't been invoiced
            // For MVP, we'll simplify and just generate an invoice for any pharmacy that had
            // delivered orders in the last 7 days.

            const oneWeekAgo = new Date();
            oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

            const { data: orders, error } = await supabase
                .from('orders')
                .select('pharmacy_id, platform_commission, delivery_commission, updated_at')
                .eq('status', 'DELIVERED')
                .gte('updated_at', oneWeekAgo.toISOString());

            if (error) throw error;

            if (!orders || orders.length === 0) {
                console.log('[CRON] No orders to invoice this week.');
                return;
            }

            // Group by pharmacy
            const totalsByPharmacy: Record<string, number> = {};
            orders.forEach(order => {
                const pharmacyId = order.pharmacy_id;
                if (!totalsByPharmacy[pharmacyId]) totalsByPharmacy[pharmacyId] = 0;
                totalsByPharmacy[pharmacyId] += (order.platform_commission + order.delivery_commission);
            });

            // Insert invoices
            const invoicesToInsert = Object.keys(totalsByPharmacy).map(pharmacyId => ({
                pharmacy_id: pharmacyId,
                total_amount: totalsByPharmacy[pharmacyId],
                period_start: oneWeekAgo.toISOString(),
                period_end: new Date().toISOString(),
                status: 'UNPAID'
            }));

            const { error: insertError } = await supabase
                .from('invoices')
                .insert(invoicesToInsert);

            if (insertError) throw insertError;

            console.log(`[CRON] Successfully generated ${invoicesToInsert.length} invoices.`);

        } catch (e) {
            console.error('[CRON Error] generating invoices:', e);
        }
    });

    // Scheduled to run every 2 minutes to check for Driver Timeouts (10 mins)
    cron.schedule('*/2 * * * *', async () => {
        try {
            const tenMinsAgo = new Date();
            tenMinsAgo.setMinutes(tenMinsAgo.getMinutes() - 10);

            // Fetch assigned orders older than 10 mins
            const { data: timedOutOrders, error } = await supabase
                .from('orders')
                .select('id, driver_id, order_code')
                .eq('status', 'ASSIGNED')
                .lt('driver_assigned_at', tenMinsAgo.toISOString());

            if (error) throw error;
            if (!timedOutOrders || timedOutOrders.length === 0) return;

            console.log(`[CRON] Found ${timedOutOrders.length} timed out orders. Reverting...`);

            for (const order of timedOutOrders) {
                // Delete delivery record
                await supabase.from('deliveries').delete().eq('order_id', order.id);

                // Reset order status back to pool
                await supabase.from('orders')
                    .update({
                        status: 'READY_FOR_PICKUP',
                        driver_id: null,
                        driver_assigned_at: null,
                        pickup_qr: null,
                        delivery_qr: null
                    })
                    .eq('id', order.id);

                // Notify driver that they lost the job
                if (order.driver_id) {
                    await supabase.from('notifications').insert({
                        user_id: order.driver_id,
                        title: '⏳ Delivery Timeout',
                        body: `Order #${order.order_code} was removed from you due to 10 mins inactivity.`
                    });
                }
            }
        } catch (e) {
            console.error('[CRON Error] Driver timeout check failed:', e);
        }
    });

    console.log('Cron jobs initialized.');
};
