require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
    process.env.SUPABASE_URL || 'https://iovoktoweqtexglrhtxo.supabase.co',
    process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlvdm9rdG93ZXF0ZXhnbHJodHhvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjE4OTY5MywiZXhwIjoyMDg3NzY1NjkzfQ.-uX-EfMNAta0bjtATEsxVwj_nv0HXIVwlJWp9gC49jg'
);

async function run() {
    // Try to get a pharmacy or create one
    let pharmacyId;
    const { data: pharmacies } = await supabase.from('users').select('id').eq('role', 'PHARMACY').limit(1);

    if (pharmacies && pharmacies.length > 0) {
        pharmacyId = pharmacies[0].id;
    } else {
        const { data: newUser } = await supabase.auth.admin.createUser({
            email: 'testpharmacy@example.com',
            password: 'password123',
            email_confirm: true
        });
        pharmacyId = newUser.user.id;
        await supabase.from('users').insert([{ id: pharmacyId, email: 'testpharmacy@example.com', role: 'PHARMACY', name: 'Test Pharmacy' }]);
    }

    // Insert price list
    const { data: priceList } = await supabase.from('price_lists').insert([{
        pharmacy_id: pharmacyId,
        valid_until: new Date(Date.now() + 86400000 * 365).toISOString(),
        status: 'ACTIVE'
    }]).select().single();

    // Insert the test drug
    const { data: item, error: itemErr } = await supabase.from('price_items').insert([{
        price_list_id: priceList.id,
        sku: 'TEST-' + Date.now(),
        drug_name: 'Dicloday Tube 1mg',
        price: 1000,
        stock_qty: 100,
        brand: 'Test Pharma',
        strength: '1mg',
        pack_size: '1 tube'
    }]).select();

    if (itemErr) {
        console.error('Error inserting drug:', itemErr);
    } else {
        console.log('Successfully inserted test drug for pharmacy ' + pharmacyId, item);
    }

    if (itemErr) {
        console.error('Error inserting drug:', itemErr);
    } else {
        console.log('Successfully inserted test drug:', item);
    }
}

run();
