import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background Handler must be a top-level function.
  debugPrint("Handling a background message: ${message.messageId}");
}

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  // TODO: Point this to the correct hosted backend URL in production
  static const String _baseUrl = 'https://afya-links-production.up.railway.app';

  static Future<void> initialize() async {
    // Request permission (mostly for iOS, but good practice for Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      
      // Get the token and send to backend
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen(_sendTokenToBackend);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          // Flutter automatically shows notifications when in background.
          // In foreground, we might want to show a local snackbar or dialog here.
        }
      });
      
      // Setup background handling
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userToken = prefs.getString('token'); // The JWT

      if (userToken == null) return; // Not logged in

      final response = await http.post(
        Uri.parse('$_baseUrl/api/users/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userToken',
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM Token successfully synced to backend.');
      } else {
        debugPrint('Failed to sync FCM Token: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error syncing FCM token to backend: $e');
    }
  }
}
