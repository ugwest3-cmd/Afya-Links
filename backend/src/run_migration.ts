import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL as string,
    process.env.SUPABASE_SERVICE_ROLE_KEY as string
);

async function runMigration() {
    console.log('Running 06_pharmacy_payouts_and_supply.sql...');
    const sqlPath = path.join(__dirname, '../supabase/06_pharmacy_payouts_and_supply.sql');
    const query = fs.readFileSync(sqlPath, 'utf8');

    const { error } = await supabase.rpc('exec_sql', { query });
    if (error) {
        console.error('Migration error:', error);
    } else {
        console.log('Migration completed successfully');
    }
}

runMigration();
