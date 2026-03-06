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

  // ── Deliveries ───────────────────────────────────────────────────────────

  static Future<http.Response> getMyDeliveries() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/users/me/deliveries'), headers: headers);
  }

  static Future<http.Response> getOrderById(String id) async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/orders/$id'), headers: headers);
  }

  static Future<http.Response> confirmPickup(String id) async {
    final headers = await _authHeaders();
    return http.post(Uri.parse('$baseUrl/orders/$id/pickup'), headers: headers);
  }

  static Future<http.Response> confirmDelivery(String id) async {
    final headers = await _authHeaders();
    return http.post(Uri.parse('$baseUrl/orders/$id/deliver'), headers: headers);
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
