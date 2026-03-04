import * as admin from 'firebase-admin';

// Initialize Firebase Admin with the JSON file
export const initFirebase = () => {
    try {
        const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

        if (!serviceAccountPath) {
            console.warn('[Firebase] Warning: FIREBASE_SERVICE_ACCOUNT_PATH environment variable not set. Push notifications will be disabled.');
            return;
        }

        // We use require to load the JSON file synchronously
        const serviceAccount = require(serviceAccountPath);

        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });

        console.log('[Firebase] Successfully initialized Firebase Admin SDK');
    } catch (error) {
        console.error('[Firebase] Failed to initialize Firebase Admin SDK:', error);
    }
};

export const getMessaging = () => {
    if (!admin.apps.length) {
        throw new Error('Firebase Admin SDK is not initialized');
    }
    return admin.messaging();
};
