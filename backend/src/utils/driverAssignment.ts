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
            .select('contact_phone, address')
            .eq('user_id', order.clinic_id)
            .single();

        // 2. Find a verified driver
        // Requirement: pick verified driver in the clinic's region who is currently available
        const currentHour = new Date().getHours();

        let targetRegion = 'Default';
        if (clinicProfile?.address) {
            // Very basic region extraction placeholder; assuming address contains region or region is passed
            // For MVP, we'll try to match a driver who has *any* assigned region for now, 
            // or modify the query to check if the driver's 'region' text matches part of the clinic address.
        }

        const { data: drivers, error: driverError } = await supabase
            .from('users')
            .select(`
                id, 
                phone, 
                name,
                driver_profiles(region, available_hours)
            `)
            .eq('role', 'DRIVER')
            .eq('is_verified', true);

        if (driverError || !drivers || drivers.length === 0) {
            console.error('No verified drivers available for assignment', driverError);
            return;
        }

        // Extremely basic time filtering: available_hours might be "08:00-17:00"
        let availableDrivers = drivers.filter(d => {
            const profiles = d.driver_profiles as any;
            const profile = Array.isArray(profiles) ? profiles[0] : profiles;

            if (!profile || !profile.available_hours) return true; // Default to available

            try {
                const [startStr, endStr] = profile.available_hours.split('-');
                const startHour = parseInt(startStr.split(':')[0]);
                const endHour = parseInt(endStr.split(':')[0]);
                return currentHour >= startHour && currentHour < endHour;
            } catch (e) {
                return true; // IF parsing fails, assume available
            }
        });

        if (availableDrivers.length === 0) {
            console.error('No drivers available at this hour');
            return;
        }

        // Just pick the first available one for MVP
        const driver = availableDrivers[0];

        // 3. Create delivery record and update order to ASSIGNED
        const { error: deliveryError } = await supabase
            .from('deliveries')
            .insert([{
                order_id: order.id,
                driver_id: driver.id
            }]);

        if (deliveryError && deliveryError.code !== '23505') { // ignore duplicate key if already assigned
            console.error('Failed to create delivery record', deliveryError);
        }

        const { error: updateError } = await supabase.from('orders').update({ status: 'ASSIGNED' }).eq('id', order.id);
        if (updateError) {
            console.error('Failed to update order status to ASSIGNED', updateError);
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
