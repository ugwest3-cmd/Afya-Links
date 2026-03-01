// @ts-ignore
import Africastalking from 'africastalking';
import dotenv from 'dotenv';

dotenv.config();

const getAT = () => {
    const apiKey = process.env.AFRICAS_TALKING_API_KEY as string;
    const username = (process.env.AFRICAS_TALKING_USERNAME as string) || 'sandbox';
    if (!apiKey) {
        return null;
    }
    return Africastalking({ apiKey, username });
};

/**
 * Send airtime to a phone number
 * @param phone E.164 formatted phone number (+256...)
 * @param amount Amount in UGX
 */
export const sendAirtime = async (phone: string, amount: number) => {
    try {
        const at = getAT();
        if (!at) {
            console.log(`[Airtime Mock] No AT API key configured. Would have sent UGX ${amount} to: ${phone}`);
            return { success: true, mocked: true };
        }

        const result = await at.AIRTIME.send({
            recipients: [{
                phoneNumber: phone,
                currencyCode: 'UGX',
                amount: amount
            }]
        });

        console.log('[Airtime Sent]', result);
        return { success: true, result };
    } catch (error: any) {
        console.error('[Airtime Error]', error.message);
        return { success: false, error: error.message };
    }
};
