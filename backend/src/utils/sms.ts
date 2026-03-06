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
 * Send SMS via Africa's Talking
 * @param to Array of E.164 formatted phone numbers (+256...)
 * @param message SMS body text
 * @param from Optional ShortCode or SenderID
 */
export const sendSMS = async (to: string[], message: string, from?: string) => {
    try {
        const at = getAT();

        if (!at) {
            console.warn(`[SMS Mock] No AT API key configured. Would have sent to: ${to.join(', ')} → "${message}"`);
            return { success: true, mocked: true };
        }

        const options: any = { to, message };
        if (from) {
            options.from = from;
        }

        const result = await at.SMS.send(options);
        console.log('[SMS Sent]', JSON.stringify(result, null, 2));
        return { success: true, result };
    } catch (error: any) {
        console.error('[SMS Error]', error.message);
        return { success: false, error: error.message };
    }
};
