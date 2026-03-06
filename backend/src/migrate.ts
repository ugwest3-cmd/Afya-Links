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

    const { error: settingsError } = await supabase.rpc('exec_sql', {
        query: `
            CREATE TABLE IF NOT EXISTS system_settings (
                key VARCHAR(100) PRIMARY KEY,
                value JSONB NOT NULL,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            INSERT INTO system_settings (key, value)
            VALUES ('commissions', '{"pharmacy_percent": 8, "driver_percent": 15, "min_payout": 500000}')
            ON CONFLICT (key) DO NOTHING;
        `
    });
    if (settingsError) console.error('Settings error:', settingsError);
    else console.log('system_settings check complete');

    const { error: locationError } = await supabase.rpc('exec_sql', {
        query: `
            CREATE TABLE IF NOT EXISTS driver_locations (
                driver_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                latitude DOUBLE PRECISION NOT NULL,
                longitude DOUBLE PRECISION NOT NULL,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
            ALTER TABLE driver_locations ENABLE ROW LEVEL SECURITY;
        `
    });
    if (locationError) console.error('Location error:', locationError);
    else console.log('driver_locations check complete');
}

runSQL();
