import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { supabase } from '../config/supabase';

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
            .in('price_list_id', priceListIds)
            .in('drug_name', drug_names);

        if (itemsError) throw itemsError;

        const offersByPharmacy: Record<string, any[]> = {};

        activeLists.forEach(list => {
            offersByPharmacy[list.pharmacy_id] = priceItems
                .filter(item => item.price_list_id === list.id)
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
        const platform_commission = subtotal * 0.05;
        const delivery_fee = 5000;
        const delivery_commission = delivery_fee * 0.1;

        const { data: order, error: orderError } = await supabase
            .from('orders')
            .insert([{
                clinic_id: clinicId,
                pharmacy_id,
                status: 'PENDING',
                subtotal,
                platform_commission,
                delivery_fee,
                delivery_commission,
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

        res.status(201).json({ success: true, message: 'Order created successfully', order_id: order.id });

    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};


export const confirmDelivery = async (req: AuthRequest, res: Response): Promise<void> => {
    try {
        const clinicId = req.user?.id;
        const { id: orderId } = req.params;
        const { order_code } = req.body;

        if (!order_code) {
            res.status(400).json({ success: false, message: 'Order code is required for confirmation' });
            return;
        }

        // Fetch order to verify
        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select('id, status, order_code, clinic_id')
            .eq('id', orderId)
            .eq('clinic_id', clinicId)
            .single();

        if (orderError || !order) {
            res.status(404).json({ success: false, message: 'Order not found or access denied' });
            return;
        }

        if (order.order_code !== order_code.toUpperCase()) {
            res.status(400).json({ success: false, message: 'Invalid order code' });
            return;
        }

        if (order.status === 'DELIVERED') {
            res.status(400).json({ success: false, message: 'Order is already delivered' });
            return;
        }

        // Update order status to DELIVERED
        const { error: updateError } = await supabase
            .from('orders')
            .update({ status: 'DELIVERED' })
            .eq('id', orderId);

        if (updateError) throw updateError;

        // Update deliveries table and send airtime rewards
        try {
            const { data: delivery } = await supabase
                .from('deliveries')
                .select('driver_id, driver:users(phone)')
                .eq('order_id', orderId)
                .single();

            if (delivery && delivery.driver_id) {
                await supabase
                    .from('deliveries')
                    .update({ dropoff_time: new Date() })
                    .eq('order_id', orderId);

                // Send Airtime reward (e.g. 1000 UGX for now)
                const { sendAirtime } = await import('../utils/airtime');
                const driverPhone = (delivery.driver as any)?.phone;
                if (driverPhone) {
                    await sendAirtime(driverPhone, 1000);
                }
            }
        } catch (e) {
            console.error('Failed to process post-delivery rewards:', e);
        }

        res.status(200).json({
            success: true,
            message: 'Delivery confirmed successfully'
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

        const { data: orders, error } = await supabase
            .from('orders')
            .select(`
                *,
                pharmacy:users!orders_pharmacy_id_fkey(name),
                items:order_items(*)
            `)
            .eq('clinic_id', clinicId)
            .order('created_at', { ascending: false })
            .limit(Number(limit));

        if (error) throw error;

        res.status(200).json({ success: true, orders });
    } catch (error: any) {
        res.status(500).json({ success: false, message: error.message });
    }
};

