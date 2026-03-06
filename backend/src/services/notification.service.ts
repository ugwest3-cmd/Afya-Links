import { supabase } from '../config/supabase';
import { getMessaging } from '../config/firebase';
import { sendSMS } from '../utils/sms';

interface NotificationPayload {
    userId: string;
    title: string;
    body: string;
    type?: string;
}

export const sendNotification = async (payload: NotificationPayload) => {
    const { userId, title, body, type = 'GENERAL' } = payload;

    try {
        // 1. Insert into Database
        const { error: dbError } = await supabase.from('notifications').insert([{
            user_id: userId,
            title,
            message: body, // schema uses 'message' not 'body'
            type,
            is_read: false
        }]);

        if (dbError) {
            console.error('[NotificationService] Failed to insert DB notification:', dbError);
        }

        // 2. Fetch User's FCM Token
        const { data: user, error: userError } = await supabase
            .from('users')
            .select('fcm_token')
            .eq('id', userId)
            .single();

        if (userError || !user?.fcm_token) {
            console.log(`[NotificationService] No FCM token found for user ${userId}. DB notification saved.`);
            return;
        }

        // 3. Send Push Notification via Firebase
        const messaging = getMessaging();
        const message = {
            notification: {
                title,
                body,
            },
            data: {
                type,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            token: user.fcm_token,
            android: {
                priority: 'high' as const,
                notification: {
                    sound: 'default',
                    channelId: 'high_importance_channel'
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default'
                    }
                }
            }
        };

        const response = await messaging.send(message);
        console.log(`[NotificationService] Successfully sent FCM push to ${userId}:`, response);

    } catch (error) {
        console.error('[NotificationService] Error sending notification:', error);
    }
};

/**
 * Notify all users with the ADMIN role
 */
export const notifyAdmins = async (payload: { title: string, body: string, type?: string }) => {
    try {
        const { data: admins } = await supabase
            .from('users')
            .select('id')
            .eq('role', 'ADMIN');

        if (!admins || admins.length === 0) {
            console.log('[NotificationService] No admin users found to notify.');
            return;
        }

        console.log(`[NotificationService] Broadcasting to ${admins.length} admins: ${payload.title}`);

        await Promise.all(admins.map(admin =>
            sendNotification({
                ...payload,
                userId: admin.id
            }).catch(e => console.error(`[NotificationService] Failed to notify admin ${admin.id}:`, e))
        ));

    } catch (error) {
        console.error('[NotificationService] Error in notifyAdmins:', error);
    }
};
