import { Request, Response } from 'express';
import { supabase } from '../config/supabase';

/**
 * USSD Handler for Africa's Talking
 * AT sends: sessionId, serviceCode, phoneNumber, text
 */
export const handleUSSD = async (req: Request, res: Response): Promise<void> => {
    const { sessionId, serviceCode, phoneNumber, text } = req.body;

    let response = '';
    const input = text.split('*');
    const level = text === '' ? 0 : input.length;

    // Normalize phone number (AT usually sends +256...)
    const phone = phoneNumber;

    try {
        // Find driver by phone
        const { data: driver } = await supabase
            .from('users')
            .select('id, name, is_verified')
            .eq('phone', phone)
            .eq('role', 'DRIVER')
            .single();

        if (!driver || !driver.is_verified) {
            response = `END Welcome to Afya Links. 
Your phone number ${phone} is not registered as a verified driver.`;
        } else {
            if (level === 0) {
                // Main Menu
                response = `CON Afya Links Driver Menu
1. View Pending Deliveries
2. Confirm Pickup
3. Confirm Delivery
4. My Balance`;
            } else if (input[0] === '1') {
                // View Pending Deliveries
                const { data: deliveries } = await supabase
                    .from('deliveries')
                    .select('order_id, orders(order_code, delivery_address)')
                    .eq('driver_id', driver.id)
                    .is('dropoff_time', null);

                if (!deliveries || deliveries.length === 0) {
                    response = `END You have no pending deliveries.`;
                } else {
                    let list = deliveries.map((d: any, i) => `${i + 1}. ${d.orders.order_code} - ${d.orders.delivery_address}`).join('\n');
                    response = `END Your Pending Deliveries:\n${list}`;
                }
            } else if (input[0] === '2') {
                // Confirm Pickup
                if (level === 1) {
                    response = `CON Enter Order Code to confirm pickup:`;
                } else {
                    const orderCode = input[1];
                    const { data: order } = await supabase.from('orders').select('id').eq('order_code', orderCode).single();

                    if (order) {
                        await supabase.from('deliveries').update({ pickup_time: new Date() }).eq('order_id', order.id).eq('driver_id', driver.id);
                        await supabase.from('orders').update({ status: 'IN_TRANSIT' }).eq('id', order.id);
                        response = `END Pickup confirmed for ${orderCode}. Stay safe!`;
                    } else {
                        response = `END Invalid Order Code.`;
                    }
                }
            } else if (input[0] === '3') {
                // Confirm Delivery
                if (level === 1) {
                    response = `CON Enter Order Code to confirm delivery:`;
                } else {
                    const orderCode = input[1];
                    const { data: order } = await supabase.from('orders').select('id').eq('order_code', orderCode).single();

                    if (order) {
                        await supabase.from('deliveries').update({ dropoff_time: new Date() }).eq('order_id', order.id).eq('driver_id', driver.id);
                        await supabase.from('orders').update({ status: 'DELIVERED' }).eq('id', order.id);

                        // Send Airtime reward
                        try {
                            const { sendAirtime } = await import('../utils/airtime');
                            await sendAirtime(phone, 1000);
                        } catch (e) {
                            console.error('Airtime reward failed via USSD:', e);
                        }

                        response = `END Delivery confirmed for ${orderCode}. Good job! Airtime reward coming soon.`;
                    } else {
                        response = `END Invalid Order Code.`;
                    }
                }
            } else if (input[0] === '4') {
                // Balance
                response = `END Your current balance is UGX 0. Payouts are processed weekly.`;
            } else {
                response = `END Invalid option.`;
            }
        }
    } catch (e) {
        console.error('USSD Error:', e);
        response = `END A system error occurred. Please try again later.`;
    }

    res.set('Content-Type', 'text/plain');
    res.send(response);
};
