import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL as string;
// Use service_role key on the server — bypasses RLS for admin-level DB operations
const supabaseKey = (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY) as string;

if (!supabaseUrl || !supabaseKey) {
    console.warn('⚠️  Supabase URL or Key is missing. Check your .env file.');
}

export const supabase = createClient(supabaseUrl || 'http://localhost:8000', supabaseKey || 'dummy_key', {
    auth: {
        autoRefreshToken: false,
        persistSession: false,
    }
});
