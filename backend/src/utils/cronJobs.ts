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

    console.log('Cron jobs initialized.');
};
