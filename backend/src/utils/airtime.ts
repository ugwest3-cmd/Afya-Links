// @ts-ignore
import Africastalking from 'africastalking';
import dotenv from 'dotenv';

dotenv.config();

const options = {
    apiKey: process.env.AFRICAS_TALKING_API_KEY as string,
    username: process.env.AFRICAS_TALKING_USERNAME as string || 'sandbox'
};

const africastalking = Africastalking(options);
const airtime = africastalking.AIRTIME;

/**
 * Send airtime to a phone number
 * @param phone E.164 formatted phone number (+256...)
 * @param amount Amount in UGX
 */
export const sendAirtime = async (phone: string, amount: number) => {
    try {
        if (options.username === 'sandbox') {
            console.log(`[Airtime Mock] To: ${phone} -> UGX ${amount}`);
            return { success: true, mocked: true };
        }

        const result = await airtime.send({
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
