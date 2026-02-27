// @ts-ignore
import Africastalking from 'africastalking';
import dotenv from 'dotenv';

dotenv.config();

const options = {
    apiKey: process.env.AFRICAS_TALKING_API_KEY as string,
    username: process.env.AFRICAS_TALKING_USERNAME as string || 'sandbox'
};

const africastalking = Africastalking(options);

export const sendSMS = async (to: string[], message: string) => {
    try {
        if (!options.apiKey || options.apiKey === 'YOUR_AT_API_KEY') {
            console.warn(`[SMS Mock] To: ${to.join(', ')} -> ${message}`);
            return { success: true, mocked: true };
        }

        const result = await africastalking.SMS.send({
            to,
            message,
            enque: true
        });

        console.log('[SMS Sent]', result);
        return { success: true, result };
    } catch (error: any) {
        console.error('[SMS Error]', error.message);
        return { success: false, error: error.message };
    }
};
