import { supabase } from '../config/supabase';
import { sendSMS } from './sms';
import { sendNotification } from '../services/notification.service';

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
                driver_id,
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

        // 2. Find the correct driver
        // Priority 1: Use the driver already embedded in the order (from clinic_driver_routes lookup at order creation)
        // Priority 2: Fall back to picking any available verified driver
        let driver: { id: string; phone: string; name: string } | null = null;

        if (order.driver_id) {
            const { data: preAssigned } = await supabase
                .from('users')
                .select('id, phone, name')
                .eq('id', order.driver_id)
                .eq('is_verified', true)
                .single();
            if (preAssigned) {
                driver = preAssigned;
                console.log(`[Driver Assignment] Using pre-assigned driver ${driver.name} (${driver.id}) for order ${orderId}`);
            }
        }

        if (!driver) {
            // Fallback: look for any available verified driver
            console.log(`[Driver Assignment] No pre-assigned driver for order ${orderId}. Selecting from pool.`);
            const currentHour = new Date().getHours();

            const { data: drivers, error: driverError } = await supabase
                .from('users')
                .select(`
                    id, 
                    phone, 
                    name,
                    driver_profiles!inner(region, available_hours, is_online)
                `)
                .eq('role', 'DRIVER')
                .eq('is_verified', true)
                .eq('driver_profiles.is_online', true);

            if (driverError || !drivers || drivers.length === 0) {
                console.error('No verified drivers available for assignment', driverError);
                return;
            }

            const availableDrivers = drivers.filter(d => {
                const profiles = d.driver_profiles as any;
                const profile = Array.isArray(profiles) ? profiles[0] : profiles;
                if (!profile) return false;

                // Simple check: does the driver's region overlap with the delivery address or pharmacy address?
                const isRegionMatch = profile.region ? (
                    (order.delivery_address || '').toLowerCase().includes(profile.region.toLowerCase()) ||
                    (pharmacyProfile?.address || '').toLowerCase().includes(profile.region.toLowerCase())
                ) : true;

                if (!isRegionMatch) return false;

                if (!profile.available_hours) return true;
                try {
                    const [startStr, endStr] = profile.available_hours.split('-');
                    const startHour = parseInt(startStr.split(':')[0]);
                    const endHour = parseInt(endStr.split(':')[0]);
                    return currentHour >= startHour && currentHour < endHour;
                } catch (e) {
                    return true;
                }
            });

            if (availableDrivers.length === 0) {
                console.error('No online drivers available in the region at this hour');
                // You could choose to drop the region check here if absolutely needed as a fallback, 
                // but the MVP says "Drivers only see deliveries in their region."
                return;
            }

            // We do NOT auto-assign anymore. We just keep it as READY_FOR_PICKUP
            // and notify all of these valid drivers.
            const pharmacyName = pharmacyProfile?.business_name || 'Pharmacy';
            const pharmacyAddress = pharmacyProfile?.address || 'Unknown Address';
            const broadcastSms = `AfyaLinks: New Pickup @ ${pharmacyName}, ${pharmacyAddress}. Open app to Accept.`;

            // Notify all matched drivers
            for (const d of availableDrivers) {
                sendNotification({
                    userId: d.id,
                    title: '🛵 New Pickup Available',
                    body: broadcastSms,
                    type: 'NEW_DELIVERY_AVAILABLE'
                });
            }
            return; // Driver assignment will be done manually by the driver
        }

        // If we reach here, a driver was pre-assigned manually (rare, but supported)
        const pickupQr = `QR-PICKUP-${orderCode}`;
        const deliveryQr = `QR-DELIVER-${orderCode}`;

        const { error: updateError } = await supabase.from('orders').update({
            status: 'ASSIGNED',
            pickup_qr: pickupQr,
            delivery_qr: deliveryQr,
            driver_assigned_at: new Date().toISOString()
        }).eq('id', order.id);

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

        // Notify Driver (Push only - replacing SMS)
        sendNotification({
            userId: driver.id,
            title: '🛵 New Delivery Assigned',
            body: driverSms,
            type: 'NEW_DELIVERY_ASSIGNED'
        });

        // Notify Pharmacy (Push only)
        sendNotification({
            userId: order.pharmacy_id,
            title: '🛵 Driver Assigned',
            body: pharmacySms,
            type: 'DRIVER_ASSIGNED'
        });

        // Send push to Clinic
        sendNotification({
            userId: order.clinic_id,
            title: '🛵 Driver Assigned',
            body: `Driver ${driverName} (${driverPhone}) is out for pickup.`,
            type: 'DRIVER_ASSIGNED'
        });

    } catch (error) {
        console.error('Error in assignDriverAndNotify logic:', error);
    }
};
