import { supabase } from '../config/supabase';
import { getMessaging } from '../config/firebase';

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
