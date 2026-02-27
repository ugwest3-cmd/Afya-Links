import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Use HTTPS for production Railway domain
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

  static Future<http.Response> verifyOtp(String phone, String otp, {String? name, String? location, String? licenseNumber}) {
    return http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
        'role': 'CLINIC',
        if (name != null) 'name': name,
        if (location != null) 'location': location,
        if (licenseNumber != null) 'license_number': licenseNumber,
      }),
    );
  }

  // ── Pharmacies ────────────────────────────────────────────────────────────

  /// GET /api/pharmacies — list all verified pharmacies
  static Future<http.Response> getPharmacies() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/pharmacies'), headers: headers);
  }

  // ── Clinic ────────────────────────────────────────────────────────────────

  /// GET /api/users/status - get profile & verification status
  static Future<http.Response> getProfileStatus() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/users/status'), headers: headers);
  }

  /// POST /api/users/upload-doc
  static Future<http.Response> uploadVerificationDoc(List<int> fileBytes, String fileName, String docType) async {
    final token = await _getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/users/upload-doc'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['doc_type'] = docType;
    request.files.add(http.MultipartFile.fromBytes('document', fileBytes, filename: fileName));
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  /// GET clinic's own orders
  static Future<http.Response> getMyOrders() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/users/my-orders'), headers: headers);
  }

  /// POST /api/clinics/orders — create a new order
  static Future<http.Response> createOrder({
    required String pharmacyId,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
  }) async {
    final headers = await _authHeaders();
    return http.post(
      Uri.parse('$baseUrl/clinics/orders'),
      headers: headers,
      body: jsonEncode({
        'pharmacy_id': pharmacyId,
        'items': items,
        'delivery_address': deliveryAddress,
      }),
    );
  }

  /// POST /api/clinics/orders/:id/confirm-delivery
  static Future<http.Response> confirmDelivery(String orderId, String orderCode) async {
    final headers = await _authHeaders();
    return http.post(
      Uri.parse('$baseUrl/clinics/orders/$orderId/confirm-delivery'),
      headers: headers,
      body: jsonEncode({'order_code': orderCode}),
    );
  }

  /// POST /api/clinics/price-offers
  static Future<http.Response> getPriceOffers({
    required List<String> drugNames,
    required List<String> pharmacyIds,
  }) async {
    final headers = await _authHeaders();
    return http.post(
      Uri.parse('$baseUrl/clinics/price-offers'),
      headers: headers,
      body: jsonEncode({'drug_names': drugNames, 'pharmacy_ids': pharmacyIds}),
    );
  }

  /// GET /api/clinics/stats
  static Future<http.Response> getDashboardStats() async {
    final headers = await _authHeaders();
    return http.get(Uri.parse('$baseUrl/clinics/stats'), headers: headers);
  }
}

