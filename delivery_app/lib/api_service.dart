import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://afya-links-production.up.railway.app/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  static Future<http.Response> requestOtp(String phone) {
    return http.post(
      Uri.parse('$baseUrl/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
  }

  static Future<http.Response> verifyOtp(String phone, String otp) {
    return http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
        'role': 'DRIVER',
      }),
    );
  }

  // ── Driver Profile & Wallet ──────────────────────────────────────────────

  static Future<http.Response> checkProfileStatus() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/users/status'), headers: headers);
  }

  static Future<http.Response> setupDriverProfile(Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    return http.post(
      Uri.parse('$baseUrl/users/profile/driver'),
      headers: headers,
      body: jsonEncode(data),
    );
  }

  static Future<http.Response> toggleDriverStatus(bool isOnline) async {
    final headers = await _authHeaders();
    return http.put(
      Uri.parse('$baseUrl/users/driver/status'),
      headers: headers,
      body: jsonEncode({'is_online': isOnline}),
    );
  }

  static Future<http.Response> getDriverWallet() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/users/driver/wallet'), headers: headers);
  }

  static Future<http.Response> requestPayout() async {
    final headers = await _authHeaders();
    return http.post(Uri.parse('$baseUrl/users/driver/payout'), headers: headers);
  }

  // ── Deliveries ───────────────────────────────────────────────────────────

  static Future<http.Response> getAvailableDeliveries() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/orders/available'), headers: headers);
  }

  static Future<http.Response> getMyDeliveries() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/users/me/deliveries'), headers: headers);
  }

  static Future<http.Response> getOrderById(String id) async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/orders/$id'), headers: headers);
  }

  static Future<http.Response> acceptDelivery(String id) async {
    final headers = await _authHeaders();
    return http.post(Uri.parse('$baseUrl/orders/$id/accept'), headers: headers);
  }

  static Future<http.Response> confirmPickup(String id, String orderCode) async {
    final headers = await _authHeaders();
    return http.post(
      Uri.parse('$baseUrl/orders/$id/pickup'), 
      headers: headers,
      body: jsonEncode({'order_code': orderCode}),
    );
  }

  static Future<http.Response> confirmDelivery(String id, String otp) async {
    final headers = await _authHeaders();
    return http.post(
      Uri.parse('$baseUrl/orders/$id/deliver'), 
      headers: headers,
      body: jsonEncode({'otp': otp}),
    );
  }

  // ── Notifications ────────────────────────────────────────────────────────

  static Future<http.Response> getNotifications() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/users/notifications'), headers: headers);
  }

  static Future<http.Response> markNotificationsRead() async {
    final headers = await _authHeaders();
    return http.post(Uri.parse('$baseUrl/users/notifications/read'), headers: headers);
  }

  // ── Tracking ─────────────────────────────────────────────────────────────

  static Future<http.Response> updateLocation(double lat, double lng) async {
    final headers = await _authHeaders();
    return http.post(
      Uri.parse('$baseUrl/tracking/update'),
      headers: headers,
      body: jsonEncode({
        'latitude': lat,
        'longitude': lng,
      }),
    );
  }
}
