import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL as string,
    process.env.SUPABASE_SERVICE_ROLE_KEY as string
);

async function runSQL() {
    console.log('Running schema updates...');
    const { error: clinicError } = await supabase.rpc('exec_sql', {
        query: 'ALTER TABLE clinic_profiles ADD COLUMN IF NOT EXISTS license_number VARCHAR(100);'
    });
    if (clinicError) console.error('Clinic error:', clinicError);
    else console.log('clinic_profiles check complete');

    const { error: pharmError } = await supabase.rpc('exec_sql', {
        query: 'ALTER TABLE pharmacy_profiles ADD COLUMN IF NOT EXISTS license_number VARCHAR(100);'
    });
    if (pharmError) console.error('Pharm error:', pharmError);
    else console.log('pharmacy_profiles check complete');
}

runSQL();
