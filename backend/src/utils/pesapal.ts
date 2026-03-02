import axios from 'axios';

// Ensure these are in your .env
const PESAPAL_CONSUMER_KEY = process.env.PESAPAL_CONSUMER_KEY || '';
const PESAPAL_CONSUMER_SECRET = process.env.PESAPAL_CONSUMER_SECRET || '';
const APP_BASE_URL = process.env.APP_BASE_URL || 'https://afya-links-production.up.railway.app';

// Validate & sanitise PESAPAL_BASE_URL — fall back to sandbox if the env var is missing/invalid
const SANDBOX_URL = 'https://cybqa.pesapal.com/pesapalv3';
const LIVE_URL = 'https://pay.pesapal.com/v3';
const rawPesapalUrl = (process.env.PESAPAL_BASE_URL || '').trim();
let PESAPAL_BASE_URL: string;
try {
    if (!rawPesapalUrl) throw new Error('not set');
    new URL(rawPesapalUrl); // throws if invalid
    PESAPAL_BASE_URL = rawPesapalUrl;
} catch {
    console.warn(`[Pesapal Config] PESAPAL_BASE_URL is "${rawPesapalUrl}" — INVALID or not set. Falling back to sandbox: ${SANDBOX_URL}`);
    PESAPAL_BASE_URL = SANDBOX_URL;
}

console.log(`[Pesapal Config] URL: ${PESAPAL_BASE_URL} | Key set: ${!!PESAPAL_CONSUMER_KEY} | Secret set: ${!!PESAPAL_CONSUMER_SECRET}`);

let pesapalToken: string | null = null;
let tokenExpiry: number = 0;

/**
 * Get Pesapal OAuth Token
 */
export const getPesapalToken = async (): Promise<string> => {
    try {
        // If we already have a valid token (padding by 10 seconds to be safe)
        if (pesapalToken && Date.now() < (tokenExpiry - 10000)) {
            return pesapalToken;
        }

        const response = await axios.post(`${PESAPAL_BASE_URL}/api/Auth/RequestToken`, {
            consumer_key: PESAPAL_CONSUMER_KEY,
            consumer_secret: PESAPAL_CONSUMER_SECRET
        }, {
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
        });

        if (response.data?.token) {
            pesapalToken = response.data.token;
            // Token usually valid for 5 mins (300 seconds), we set expiry
            const expiresIn = (response.data.expiryDate) ? new Date(response.data.expiryDate).getTime() : Date.now() + (5 * 60 * 1000);
            tokenExpiry = expiresIn;
            return pesapalToken as string;
        }

        throw new Error('Could not get Pesapal token');
    } catch (error: any) {
        const detail = error?.response?.data ? JSON.stringify(error.response.data) : error.message;
        console.error('Pesapal Auth Error:', detail);
        throw new Error(`Pesapal Authentication Failed: ${detail}`);
    }
};

/**
 * Register IPN URL (Must be registered once, usually returns an IPN ID)
 * In production, you might store this IPN ID in env. For simplicity, we can fetch it dynamically.
 */
export const getOrRegisterIPN = async (): Promise<string> => {
    try {
        const token = await getPesapalToken();
        const ipnUrl = `${APP_BASE_URL}/api/payments/webhook`; // Your public webhook URL

        // 1. Get List of existing IPNs
        const listResponse = await axios.get(`${PESAPAL_BASE_URL}/api/URLSetup/GetIpnList`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });

        const existingIPN = listResponse.data?.find((ipn: any) => ipn.url === ipnUrl);
        if (existingIPN) {
            return existingIPN.ipn_id;
        }

        // 2. Register if not found
        const response = await axios.post(`${PESAPAL_BASE_URL}/api/URLSetup/RegisterIPN`, {
            url: ipnUrl,
            ipn_notification_type: 'POST'
        }, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });

        return response.data.ipn_id;
    } catch (error: any) {
        const detail = error?.response?.data ? JSON.stringify(error.response.data) : error.message;
        console.error('IPN Registration Error:', detail);
        throw new Error(`Failed to register IPN: ${detail}`);
    }
};

/**
 * Submit an order request to Pesapal
 * Returns the redirect URL (iframe URL)
 */
export interface SubmitOrderParams {
    id: string; // Order Reference / ID
    amount: number;
    description: string;
    callback_url: string;
    billing_address: {
        email_address: string;
        phone_number: string;
        country_code: string;
        first_name: string;
        last_name: string;
    };
}

export const submitOrder = async (params: SubmitOrderParams) => {
    try {
        const token = await getPesapalToken();
        const ipn_id = await getOrRegisterIPN();

        const payload = {
            id: params.id,
            currency: 'UGX',
            amount: params.amount,
            description: params.description,
            callback_url: params.callback_url,
            notification_id: ipn_id,
            billing_address: params.billing_address
        };

        const response = await axios.post(`${PESAPAL_BASE_URL}/api/Transactions/SubmitOrderRequest`, payload, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });

        if (response.data && response.data.redirect_url) {
            return {
                redirect_url: response.data.redirect_url,
                order_tracking_id: response.data.order_tracking_id
            };
        }

        throw new Error('Invalid response from Pesapal SubmitOrder');
    } catch (error: any) {
        const detail = error?.response?.data ? JSON.stringify(error.response.data) : error.message;
        console.error('Pesapal Submit Order Error:', detail);
        throw new Error(`Failed to submit order to Pesapal: ${detail}`);
    }
};

/**
 * Get Transaction Status By Tracking ID
 */
export const getTransactionStatus = async (tracking_id: string) => {
    try {
        const token = await getPesapalToken();

        const response = await axios.get(`${PESAPAL_BASE_URL}/api/Transactions/GetTransactionStatus?orderTrackingId=${tracking_id}`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        return response.data;
        // Example: { payment_method: "Visa", amount: 100, payment_status_code: 1, payment_status_description: "Completed", ... }
    } catch (error: any) {
        console.error('Pesapal Get Status Error:', error?.response?.data || error.message);
        throw new Error('Failed to get transaction status');
    }
};
