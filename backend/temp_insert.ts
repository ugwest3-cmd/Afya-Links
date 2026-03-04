import * as dotenv from 'dotenv';
dotenv.config();
import { supabase } from './src/config/supabase';

async function run() {
    const { data, error } = await supabase.from('drugs').insert([{
        name: 'dicloday tube 1mg',
        default_price: 1000,
        description: 'Test drug for payment flow',
        is_active: true
    }]).select();

    if (error) {
        console.error('Error adding drug:', error);
    } else {
        console.log('Successfully added drug:', data);
    }
}

run();
