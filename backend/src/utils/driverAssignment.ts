import { supabase } from '../config/supabase';
import { sendSMS } from './sms';

export const assignDriverAndNotify = async (orderId: string, orderCode: string): Promise<void> => {
    try {
        // 1. Fetch order details with clinic and pharmacy info
        const { data: order, error: orderError } = await supabase
            .from('orders')
            .select(`
                id,
                order_code,
                delivery_address,
                subtotal,
                delivery_fee,
                clinic_id,
                pharmacy_id,
                clinic:users!orders_clinic_id_fkey(phone),
                pharmacy:users!orders_pharmacy_id_fkey(phone)
            `)
            .eq('id', orderId)
            .single();

        if (orderError || !order) {
            console.error('Failed to fetch order for assignment', orderError);
            return;
        }

        // Fetch profiles for names and addresses
        const { data: pharmacyProfile } = await supabase
            .from('pharmacy_profiles')
            .select('business_name, address, contact_phone')
            .eq('user_id', order.pharmacy_id)
            .single();

        const { data: clinicProfile } = await supabase
            .from('clinic_profiles')
            .select('contact_phone')
            .eq('user_id', order.clinic_id)
            .single();

        // 2. Find a verified driver (MVP: Pick random verified driver)
        const { data: drivers, error: driverError } = await supabase
            .from('users')
            .select('id, phone, name')
            .eq('role', 'DRIVER')
            .eq('is_verified', true)
            .limit(1);

        if (driverError || !drivers || drivers.length === 0) {
            console.error('No verified drivers available for assignment');
            return;
        }

        const driver = drivers[0];

        // 3. Create delivery record
        const { error: deliveryError } = await supabase
            .from('deliveries')
            .insert([{
                order_id: order.id,
                driver_id: driver.id
            }]);

        if (deliveryError && deliveryError.code !== '23505') { // ignore duplicate key if already assigned
            console.error('Failed to create delivery record', deliveryError);
        }

        // 4. Compose and Send SMS
        const pharmacyName = pharmacyProfile?.business_name || 'Pharmacy';
        const pharmacyAddress = pharmacyProfile?.address || 'Unknown Address';
        const clinicPhone = clinicProfile?.contact_phone || (order.clinic as any)?.phone;
        const driverName = driver.name || 'AfyaLinks Driver';
        const driverPhone = driver.phone;
        const deliveryAddress = order.delivery_address || 'Clinic Address';

        const driverSms = `AfyaLinks: Pickup @ ${pharmacyName}, ${pharmacyAddress}. Drop-off: ${clinicPhone} / ${deliveryAddress}. OrderCode: ${orderCode}.`;
        const pharmacySms = `Driver ${driverName} (${driverPhone}) assigned. Attach order code to parcel.`;

        // Send to Driver
        await sendSMS([driver.phone], driverSms);

        // Send to Pharmacy
        const pharmacyPhone = pharmacyProfile?.contact_phone || (order.pharmacy as any)?.phone;
        if (pharmacyPhone) {
            await sendSMS([pharmacyPhone], pharmacySms);
        }

    } catch (error) {
        console.error('Error in assignDriverAndNotify logic:', error);
    }
};
