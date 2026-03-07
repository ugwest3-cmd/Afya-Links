// @ts-ignore
import Africastalking from 'africastalking';
import dotenv from 'dotenv';

dotenv.config();

/**
 * Normalizes phone numbers to E.164 format for Africa's Talking (+256...)
 */
export const normalizePhone = (phone: string): string => {
    let cleaned = phone.trim().replace(/\s+/g, '');
    if (cleaned.startsWith('0')) {
        return '+256' + cleaned.substring(1);
    }
    if (cleaned.startsWith('7') || cleaned.startsWith('3')) {
        return '+256' + cleaned;
    }
    if (cleaned.startsWith('256')) {
        return '+' + cleaned;
    }
    return cleaned;
};

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
 * @param to Array of phone numbers
 * @param message SMS body text
 * @param from Optional ShortCode or SenderID
 */
export const sendSMS = async (to: string[], message: string, from?: string) => {
    try {
        const at = getAT();
        const normalizedTo = to.map(normalizePhone);
        const senderId = process.env.AFRICAS_TALKING_SENDER_ID;

        if (!at) {
            console.warn(`[SMS Mock] No AT API key configured. Would have sent to: ${normalizedTo.join(', ')} → "${message}"`);
            return { success: true, mocked: true };
        }

        const options: any = { to: normalizedTo, message };
        if (senderId) {
            options.from = senderId;
        } else if (from) {
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
