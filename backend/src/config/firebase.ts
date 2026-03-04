import * as admin from 'firebase-admin';

// Initialize Firebase Admin with the JSON file
export const initFirebase = () => {
    try {
        const serviceAccountJsonStr = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
        const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

        let serviceAccount: any;

        if (serviceAccountJsonStr) {
            // Priority 1: Read raw JSON from environment variable (Best for Railway production)
            serviceAccount = JSON.parse(serviceAccountJsonStr);
        } else if (serviceAccountPath) {
            // Priority 2: Read from local file path (Best for local development)
            serviceAccount = require(serviceAccountPath);
        } else {
            console.warn('[Firebase] Warning: Neither FIREBASE_SERVICE_ACCOUNT_JSON nor FIREBASE_SERVICE_ACCOUNT_PATH is set. Push notifications will be disabled.');
            return;
        }

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
