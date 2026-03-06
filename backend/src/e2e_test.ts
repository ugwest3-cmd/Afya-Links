import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';
const supabase = createClient(supabaseUrl, supabaseKey);

async function runE2E() {
    console.log('--- Starting E2E Flow ---');

    console.log('1. Fetching Clinic and Pharmacy...');
    const { data: clinic } = await supabase.from('users').select('id, name').eq('role', 'CLINIC').limit(1).single();
    const { data: pharmacy } = await supabase.from('users').select('id, name').eq('role', 'PHARMACY').limit(1).single();

    if (!clinic || !pharmacy) {
        console.error('Could not find a clinic or pharmacy in DB. Aborting test.');
        return;
    }
    console.log(`Found Clinic: ${clinic.name} (${clinic.id})`);
    console.log(`Found Pharmacy: ${pharmacy.name} (${pharmacy.id})`);

    console.log('\n2. Creating an Order...');
    const subtotal = 600000; // Keep it high so the pharmacy gets > 500k to test payouts
    const commission = subtotal * 0.08;
    const pharmacy_net = subtotal - commission;

    const { data: order, error: orderError } = await supabase
        .from('orders')
        .insert([{
            clinic_id: clinic.id,
            pharmacy_id: pharmacy.id,
            status: 'AWAITING_PAYMENT',
            payment_status: 'AWAITING_PAYMENT',
            subtotal,
            delivery_fee: 10000,
            platform_commission: commission,
            pharmacy_commission: commission,
            pharmacy_net,
            delivery_commission: 1500,
            driver_commission: 1500,
            driver_net: 8500,
            total_platform_revenue: commission + 1500,
            total_payable: subtotal + 10000,
            delivery_address: 'E2E Test Address'
        }])
        .select()
        .single();

    if (orderError) throw orderError;
    console.log(`Order created: ${order.id}`);

    const { error: itemError } = await supabase.from('order_items').insert([{
        order_id: order.id,
        drug_name: 'Test Amoxicillin',
        quantity: 10,
        price_agreed: 60000
    }]);
    if (itemError) throw itemError;

    console.log('\n3. Simulating Payment Confirmation (Pesapal IPN)...');
    // Using simple DB update to simulate `payment.controller.ts` confirmation logic
    await supabase.from('orders').update({ status: 'PAID', payment_status: 'VERIFIED' }).eq('id', order.id);

    // Credit Pharmacy Wallet
    const { data: wallet } = await supabase.from('pharmacy_wallet').select('available_balance').eq('pharmacy_id', pharmacy.id).single();
    const currentBalance = wallet ? Number(wallet.available_balance) : 0;
    const newBalance = currentBalance + pharmacy_net;

    await supabase.from('pharmacy_wallet').upsert({
        pharmacy_id: pharmacy.id,
        available_balance: newBalance
    }, { onConflict: 'pharmacy_id' });
    console.log(`Pharmacy wallet updated. Old Balance: ${currentBalance}, New Balance: ${newBalance} (Added: ${pharmacy_net})`);


    console.log('\n4. Pharmacy requests payout...');
    if (newBalance >= 500000) {
        // Set up payout method if needed
        await supabase.from('pharmacy_profiles').upsert({
            user_id: pharmacy.id,
            preferred_payout_method: 'Mobile Money',
            payout_details: { accountName: 'Test Phone', accountNumber: '0700000000' }
        }, { onConflict: 'user_id' });

        // Update wallet (deduct)
        await supabase.from('pharmacy_wallet').update({ available_balance: newBalance - newBalance, pending_balance: newBalance }).eq('pharmacy_id', pharmacy.id);

        // Create request
        const { data: payoutReq, error: payoutErr } = await supabase.from('payout_requests').insert([{
            pharmacy_id: pharmacy.id,
            amount: newBalance,
            payment_method: 'Mobile Money',
            payment_details: { accountName: 'Test Phone', accountNumber: '0700000000' },
            status: 'PENDING'
        }]).select().single();

        if (payoutErr) throw payoutErr;
        console.log(`Payout Request created: ID = ${payoutReq.id}, Amount: ${payoutReq.amount}`);

        console.log('\n5. Admin marks payout as PAID...');
        await supabase.from('payout_requests').update({ status: 'PAID' }).eq('id', payoutReq.id);

        const { data: finalWallet } = await supabase.from('pharmacy_wallet').select('pending_balance, total_paid_out, lifetime_payouts').eq('pharmacy_id', pharmacy.id).single();
        if (finalWallet) {
            await supabase.from('pharmacy_wallet').update({
                pending_balance: finalWallet.pending_balance - payoutReq.amount,
                total_paid_out: finalWallet.total_paid_out + payoutReq.amount,
                lifetime_payouts: finalWallet.lifetime_payouts + 1
            }).eq('pharmacy_id', pharmacy.id);
        }
        console.log(`Admin marked payout as PAID and updated wallet stats.`);

    } else {
        console.log('Balance < 500k, cannot request payout in this test.');
    }

    console.log('\n--- E2E Flow Completed Successfully ---');
}

runE2E().catch(console.error);
