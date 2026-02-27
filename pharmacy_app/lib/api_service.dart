import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Use HTTPS for production Railway domain
  static const String baseUrl = 'https://afya-links.railway.internal/api';

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

  // ── Auth ───────────────────────────────────────────────────────────────────

  static Future<http.Response> requestOtp(String phone) => http.post(
        Uri.parse('$baseUrl/auth/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );

  static Future<http.Response> verifyOtp(String phone, String otp) => http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'otp': otp, 'role': 'PHARMACY'}),
      );

  // ── Pharmacy ───────────────────────────────────────────────────────────────

  /// GET /api/pharmacies/orders-inbox — orders sent to this pharmacy
  static Future<http.Response> getInboxOrders() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/pharmacies/orders-inbox'), headers: headers);
  }

  /// POST /api/pharmacies/orders/:id/response — accept/partial/reject
  static Future<http.Response> respondToOrder(
      String orderId, String status, {String? rejectedReason}) async {
    final headers = await _authHeaders();
    return http.post(
      Uri.parse('$baseUrl/pharmacies/orders/$orderId/response'),
      headers: headers,
      body: jsonEncode({
        'status': status,
        if (rejectedReason != null) 'rejected_reason': rejectedReason,
      }),
    );
  }

  /// Upload CSV price list (multipart)
  static Future<http.Response> uploadPriceList(String filePath, List<int> fileBytes, String fileName) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/pharmacies/price-list'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  /// GET /api/users/status
  static Future<http.Response> getProfileStatus() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/users/status'), headers: headers);
  }
}
