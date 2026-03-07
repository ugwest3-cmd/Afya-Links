import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';
import { sendNotification } from '../services/notification.service';

// ... (keep the existing getPriceOffers and createOrder)

export const getPriceOffers = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const { drug_names, pharmacy_ids } = req.body;

        if (!Array.isArray(drug_names) || !Array.isArray(pharmacy_ids)) {
            res.status(400).json({ success: false, message: 'drug_names and pharmacy_ids must be arrays' });
            return;
        }

        const { data: activeLists, error: listError } = await supabase
            .from('price_lists')
            .select('id, pharmacy_id, valid_until')
            .in('pharmacy_id', pharmacy_ids)
            .gt('valid_until', new Date().toISOString());

        if (listError) throw listError;

        if (!activeLists || activeLists.length === 0) {
            res.status(404).json({ success: false, message: 'No active price lists found for selected pharmacies' });
            return;
        }

        const priceListIds = activeLists.map(list => list.id);

        const { data: priceItems, error: itemsError } = await supabase
            .from('price_items')
            .select('id, price_list_id, sku, drug_name, price, stock_qty, brand, strength, pack_size')
            .in('price_list_id', priceListIds);

        if (itemsError) throw itemsError;

        const normalizedRequestedNames = drug_names.map((n: string) => n.trim().toLowerCase());

        const offersByPharmacy: Record<string, any[]> = {};

        activeLists.forEach(list => {
            offersByPharmacy[list.pharmacy_id] = (priceItems || [])
                .filter(item => {
                    const isFromThisList = item.price_list_id === list.id;
                    const matchesName = normalizedRequestedNames.includes(item.drug_name.trim().toLowerCase());
                    return isFromThisList && matchesName;
                })
                .map(item => ({
                    ...item,
                    valid_until: list.valid_until
                }));
        });

        res.status(200).json({ success: true, data: offersByPharmacy });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const createOrder = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;
        const { pharmacy_id, items, delivery_address } = req.body;

        if (!pharmacy_id || !items || !Array.isArray(items) || items.length === 0) {
            res.status(400).json({ success: false, message: 'pharmacy_id and items array are required' });
            return;
        }

        const subtotal = items.reduce((sum, item) => sum + (item.price_agreed * item.quantity), 0);

        // Look up the admin-configured delivery fee and driver for this clinic's route
        const { data: routeAssignment } = await supabase
            .from('clinic_driver_routes')
            .select('driver_id, delivery_fee')
            .eq('clinic_id', clinicId)
            .eq('is_active', true)
            .single();

        const delivery_fee = routeAssignment?.delivery_fee ? Number(routeAssignment.delivery_fee) : 0;
        const assigned_driver_id = routeAssignment?.driver_id || null;

        // Escrow Ledger calculations
        const pharmacy_commission = subtotal * 0.08; // 8% Pharmacy Commission
        const pharmacy_net = subtotal - pharmacy_commission;

        const driver_commission = delivery_fee > 0 ? delivery_fee * 0.15 : 0; // 15% Driver Commission
        const driver_net = delivery_fee - driver_commission;

        const total_platform_revenue = pharmacy_commission + driver_commission;
        const total_payable = subtotal + delivery_fee;

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .insert([{
                clinic_id: clinicId,
                pharmacy_id,
                driver_id: assigned_driver_id,
                status: 'AWAITING_PAYMENT',
                payment_status: 'AWAITING_PAYMENT',
                subtotal,
                delivery_fee,
                platform_commission: pharmacy_commission, // legacy mapping
                delivery_commission: driver_commission,   // legacy mapping
                pharmacy_commission,
                driver_commission,
                pharmacy_net,
                driver_net,
                total_platform_revenue,
                total_payable,
                delivery_address
            }])
            .select()
            .single();

        if (orderError || !order) throw orderError || new Error('Failed to create order');

        const orderItemsToInsert = items.map(item => ({
            order_id: order.id,
            drug_name: item.drug_name,
            quantity: item.quantity,
            price_agreed: item.price_agreed
        }));

        const { error: itemsError } = await supabase
            .from('order_items')
            .insert(orderItemsToInsert);

        if (itemsError) throw itemsError;

        // Notify pharmacy of new incoming order (non-blocking)
        const shortId = order.id.slice(0, 8).toUpperCase();
        Promise.resolve(supabase.from('notifications').insert([{
            user_id: pharmacy_id,
            title: '🛒 New Order Received',
            body: `A new order (#${shortId}) has been placed and is awaiting payment. It will appear in your inbox once payment clears.`,
            type: 'NEW_ORDER',
            is_read: false
        }])).catch(console.error);

        // Send a push notification to the clinic
        sendNotification({
            userId: clinicId as string,
            title: 'Order Created',
            body: `Order #${shortId} created successfully. Please wait to be redirected to payment.`,
            type: 'ORDER_CREATED'
        });

        res.status(201).json({ success: true, message: 'Order created successfully', order_id: order.id });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};


export const requestDeliveryOtp = async (req: AuthRequest, res: Response): Promise<void> => {
    // Delivery codes (order_code) are now generated by the pharmacy when marking ready.
    // They are available on the receipt/parcel. No need to request via SMS.
    res.status(200).json({ success: true, message: 'Delivery code is on your receipt' });
};

export const confirmDelivery = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;
        const orderId = req.params.id as string;
        const { otp: deliveryCode } = req.body; // Keeping 'otp' key for client compatibility but renaming internally

        if (!deliveryCode) {
            res.status(400).json({ success: false, message: 'Delivery code is required' });
            return;
        }

        // Fetch order to verify code
        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, status, order_code, delivery_otp')
            .eq('id', orderId)
            .eq('clinic_id', clinicId)
            .single();

        if (orderError || !order) {
            res.status(404).json({ success: false, message: 'Order not found' });
            return;
        }

        // Verify code (can be delivery_otp or order_code for fallback)
        const validCode = order.delivery_otp || order.order_code;
        if (deliveryCode !== validCode) {
            res.status(400).json({ success: false, message: 'Invalid delivery code. Check your app or receipt.' });
            return;
        }

        if (order.status === 'COMPLETED' || order.status === 'DELIVERED') {
            res.status(400).json({ success: false, message: 'Order is already completed' });
            return;
        }

        // Atomic Status Update
        const { error: updateError } = await supabase
            .from('orders')
            .update({
                status: 'COMPLETED',
                payout_status: 'INITIATED'
            })
            .eq('id', orderId);

        if (updateError) throw updateError;

        // Update deliveries dropoff_time and notify pharmacy
        try {
            await supabase
                .from('deliveries')
                .update({ dropoff_time: new Date() })
                .eq('order_id', orderId);

            // Fetch pharmacy_id for notification
            const { data: orderData } = await supabase.from('orders').select('pharmacy_id, order_code').eq('id', orderId).single();
            if (orderData) {
                sendNotification({
                    userId: orderData.pharmacy_id,
                    title: '📦 Delivery Confirmed',
                    body: `The clinic has confirmed receipt of order #${orderData.order_code}. Funds are being released to your wallet.`,
                    type: 'DELIVERY_CONFIRMED'
                });
            }
        } catch (e) {
            console.error('Failed to update dropoff time or notify:', e);
        }

        res.status(200).json({
            success: true,
            message: 'Delivery confirmed and escrow funds released successfully'
        });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getDashboardStatsClinic = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;

        const { data: orders, error } = await supabase
            .from('orders')
            .select('status')
            .eq('clinic_id', clinicId);

        if (error) throw error;

        const stats = {
            pending: orders.filter(o => o.status === 'PENDING').length,
            in_transit: orders.filter(o => ['ACCEPTED', 'PARTIAL', 'READY_FOR_PICKUP', 'ASSIGNED', 'IN_TRANSIT'].includes(o.status)).length,
            delivered: orders.filter(o => o.status === 'DELIVERED').length,
            rejected: orders.filter(o => o.status === 'REJECTED').length,
        };

        res.status(200).json({ success: true, stats });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getMyOrders = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;
        const { limit = 20 } = req.query;

        // Step 1: Fetch orders with no joins
        const { data: orders, error } = await supabase
            .from('orders')
            .select('*')
            .eq('clinic_id', clinicId)
            .order('created_at', { ascending: false })
            .limit(Number(limit));

        if (error) {
            console.error('[getMyOrders] Orders query error:', error);
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

        const ordersWithItems = orders.map((o: any) => ({
            ...o,
            items: (allItems || []).filter((i: any) => i.order_id === o.id),
        }));

        console.log(`[getMyOrders] Returning ${ordersWithItems.length} orders for clinic ${clinicId}`);
        res.status(200).json({ success: true, orders: ordersWithItems });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

