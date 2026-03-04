import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';
import { uploadFileToSupabase } from '../utils/storage';
import csvParser from 'csv-parser';
import { Readable } from 'stream';
import { assignDriverAndNotify } from '../utils/driverAssignment';

export const uploadPriceList = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = req.user?.id;
        const file = req.file;

        if (!file) {
            res.status(400).json({ success: false, message: 'CSV file is required' });
            return;
        }

        const isCsv = file.mimetype === 'text/csv' ||
            file.mimetype === 'application/vnd.ms-excel' ||
            file.mimetype === 'text/plain' ||
            (file.mimetype === 'application/octet-stream' && file.originalname.endsWith('.csv'));

        if (!isCsv) {
            res.status(400).json({ success: false, message: 'Only CSV files are allowed' });
            return;
        }

        let csvUrl = '';
        try {
            csvUrl = await uploadFileToSupabase('price-lists', file, `pharmacies/${pharmacyId}`);
        } catch (e: any) {
            res.status(500).json({ success: false, message: 'Storage upload failed', error: e.message });
            return;
        }

        const validUntil = new Date();
        validUntil.setHours(validUntil.getHours() + 48);

        const { data: priceList, error: plError } = await supabase
            .from('price_lists')
            .insert([{ pharmacy_id: pharmacyId, csv_url: csvUrl, valid_until: validUntil }])
            .select()
            .single();

        if (plError || !priceList) throw plError || new Error('Failed to create price_list record');

        const results: any[] = [];
        const stream = Readable.from(file.buffer);

        stream
            .pipe(csvParser({
                mapHeaders: ({ header }) => header.trim().toLowerCase().replace(/\s+/g, '_')
            }))
            .on('data', (data) => {
                if (data.drug_name && data.price) {
                    results.push({
                        price_list_id: priceList.id,
                        sku: data.sku || null,
                        drug_name: data.drug_name.trim(),
                        brand: data.brand || null,
                        strength: data.strength || null,
                        pack_size: data.pack_size || null,
                        unit: data.unit || null,
                        price: parseFloat(data.price),
                        stock_qty: data.stock_qty ? parseInt(data.stock_qty) : null,
                    });
                }
            })
            .on('end', async () => {
                if (results.length > 0) {
                    const { error: piError } = await supabase.from('price_items').insert(results);
                    if (piError) console.error('Failed to insert price items', piError);
                }

                res.status(200).json({
                    success: true,
                    message: 'Price list uploaded and parsed successfully',
                    items_count: results.length,
                    valid_until: validUntil,
                    csv_url: csvUrl
                });
            })
            .on('error', (error) => {
                res.status(500).json({ success: false, message: 'Error parsing CSV', error: error.message });
            });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

const generateOrderCode = () => {
    return Math.random().toString(36).substring(2, 8).toUpperCase();
};

export const respondToOrder = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = req.user?.id;
        const orderId = String(req.params.id);
        const { status, rejected_reason } = req.body;

        if (!['ACCEPTED', 'PARTIAL', 'REJECTED'].includes(status)) {
            res.status(400).json({ success: false, message: 'Invalid status' });
            return;
        }

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, status, clinic_id')
            .eq('id', orderId)
            .eq('pharmacy_id', String(pharmacyId))
            .single();

        if (orderError || !order) {
            res.status(404).json({ success: false, message: 'Order not found or not assigned to you' });
            return;
        }

        if (order.status !== 'PAID') {
            res.status(400).json({ success: false, message: `Order is already ${order.status}` });
            return;
        }

        let updateData: any = { status };
        if (status === 'REJECTED') {
            updateData.rejected_reason = rejected_reason || 'No reason provided';
        } else {
            updateData.order_code = generateOrderCode();
        }

        const { error: updateError } = await supabase
            .from('orders')
            .update(updateData)
            .eq('id', orderId);

        if (updateError) throw updateError;

        // Notify the clinic about the order status change
        const shortId = orderId.slice(0, 8).toUpperCase();
        const notifMap: Record<string, { title: string; body: string }> = {
            ACCEPTED: {
                title: '✅ Order Accepted',
                body: `Your order #${shortId} has been accepted by the pharmacy and is being prepared.`
            },
            PARTIAL: {
                title: '⚠️ Order Partially Accepted',
                body: `Your order #${shortId} was partially accepted. Some items may be missing. Check your Orders tab.`
            },
            REJECTED: {
                title: '❌ Order Rejected',
                body: `Your order #${shortId} was rejected by the pharmacy. Reason: ${rejected_reason || 'No reason provided'}.`
            }
        };
        const notif = notifMap[status];
        if (notif && order.clinic_id) {
            Promise.resolve(supabase.from('notifications').insert([{
                user_id: order.clinic_id,
                title: notif.title,
                body: notif.body,
                type: 'ORDER_STATUS',
                is_read: false
            }])).catch(console.error);
        }

        if (status === 'ACCEPTED' || status === 'PARTIAL') {
            console.log(`[Order Processing] Order ${orderId} Accepted. Order Code: ${updateData.order_code}. Waiting for Pharmacy to mark ready.`);
        }

        res.status(200).json({
            success: true,
            message: `Order marked as ${status}`,
            order_code: updateData.order_code
        });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// Mark Order Ready for driver auto-assignment
export const markOrderReady = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = String(req.user?.id);
        const orderId = String(req.params.id);

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, status, order_code')
            .eq('id', orderId)
            .eq('pharmacy_id', pharmacyId)
            .single();

        if (orderError || !order) {
            res.status(404).json({ success: false, message: 'Order not found or not assigned to you' });
            return;
        }

        if (order.status !== 'ACCEPTED' && order.status !== 'PARTIAL') {
            res.status(400).json({ success: false, message: `Cannot mark ready. Order is currently ${order.status}` });
            return;
        }

        // Trigger Auto-assignment
        console.log(`[Driver Assignment] Pharmacy marked Order ${orderId} Ready. Attempting assignment...`);
        assignDriverAndNotify(orderId, order.order_code || '').catch(console.error);

        res.status(200).json({
            success: true,
            message: 'Order marked ready. Driver assignment in progress.'
        });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

// Handle Payment proof uploads by pharmacy
export const uploadPaymentProof = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = String(req.user?.id);
        const invoiceId = String(req.params.id);
        const file = req.file;

        if (!file) {
            res.status(400).json({ success: false, message: 'Payment proof screenshot is required' });
            return;
        }

        let proofUrl = '';
        try {
            proofUrl = await uploadFileToSupabase('verification-docs', file, `invoices/${invoiceId}`);
        } catch (e: any) {
            res.status(500).json({ success: false, message: 'Storage upload failed', error: e.message });
            return;
        }

        const { error } = await supabase
            .from('invoices')
            .update({ payment_proof_url: proofUrl, status: 'PENDING_VERIFICATION' })
            .eq('id', invoiceId)
            .eq('pharmacy_id', pharmacyId);

        if (error) throw error;

        res.status(200).json({ success: true, message: 'Payment proof uploaded successfully. Pending admin review.' });

    } catch (e: any) {
        res.status(500).json({ success: false, message: e.message });
    }
};

export const getDashboardStatsPharmacy = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = req.user?.id;

        const { data: orders, error } = await supabase
            .from('orders')
            .select('status, pharmacy_net, payout_status')
            .eq('pharmacy_id', pharmacyId);

        if (error) throw error;

        const completedStatuses = ['DELIVERED', 'COMPLETED'];
        const earningStatuses = ['PAID', 'ACCEPTED', 'PARTIAL', 'READY_FOR_PICKUP', 'ASSIGNED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', ...completedStatuses];

        const stats = {
            new: orders.filter(o => o.status === 'PAID').length,
            accepted: orders.filter(o => ['ACCEPTED', 'PARTIAL'].includes(o.status)).length,
            ready_transit: orders.filter(o => ['READY_FOR_PICKUP', 'ASSIGNED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY'].includes(o.status)).length,
            completed: orders.filter(o => completedStatuses.includes(o.status)).length,
            total_earnings: orders
                .filter(o => completedStatuses.includes(o.status) && o.payout_status === 'PAID')
                .reduce((sum, o) => sum + (Number(o.pharmacy_net) || 0), 0),
            pending_balance: orders
                .filter(o => {
                    const isCompleted = completedStatuses.includes(o.status);
                    const isEarning = earningStatuses.includes(o.status);
                    // Pending if: Not completed yet OR completed but not formally paid out
                    if (isCompleted && o.payout_status !== 'PAID') return true;
                    if (isEarning && !isCompleted) return true;
                    return false;
                })
                .reduce((sum, o) => sum + (Number(o.pharmacy_net) || 0), 0),
        };

        res.status(200).json({ success: true, stats });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getInboxOrders = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = req.user?.id;
        const { limit = 20 } = req.query;

        // Step 1: Fetch orders (no joins — avoids FK/RLS issues)
        const { data: orders, error } = await supabase
            .from('orders')
            .select('*')
            .eq('pharmacy_id', pharmacyId)
            .neq('status', 'AWAITING_PAYMENT')
            .order('created_at', { ascending: false })
            .limit(Number(limit));

        if (error) {
            console.error('[getInboxOrders] Orders query error:', error);
            throw error;
        }

        if (!orders || orders.length === 0) {
            res.status(200).json({ success: true, orders: [] });
            return;
        }

        // Step 2: Fetch items for all returned orders
        const orderIds = orders.map((o: any) => o.id);
        const { data: allItems } = await supabase
            .from('order_items')
            .select('id, order_id, drug_name, quantity, price_agreed')
            .in('order_id', orderIds);

        // Attach items to each order
        const ordersWithItems = orders.map((o: any) => ({
            ...o,
            items: (allItems || []).filter((i: any) => i.order_id === o.id),
            clinic: null // populated separately if needed
        }));


        console.log(`[getInboxOrders] Returning ${ordersWithItems.length} orders for pharmacy ${pharmacyId}`);
        res.status(200).json({ success: true, orders: ordersWithItems });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};


export const getInvoices = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const pharmacyId = req.user?.id;

        const { data: invoices, error } = await supabase
            .from('invoices')
            .select(`
                *,
                order:orders(order_code)
            `)
            .eq('pharmacy_id', pharmacyId)
            .order('created_at', { ascending: false });

        if (error) throw error;

        res.status(200).json({ success: true, invoices });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};
