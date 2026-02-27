import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;

  final String apiUrl = 'http://localhost:5000/api/auth';

  Future<void> sendOtp() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/request-otp'),
        body: {'phone': _phoneController.text},
      );
      if (res.statusCode == 200) {
        setState(() => _otpSent = true);
      } else {
        _showError('Failed to send OTP');
      }
    } catch (e) {
      _showError('Network error');
    }
    setState(() => _isLoading = false);
  }

  Future<void> verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': _phoneController.text,
          'otp': _otpController.text,
          'role': 'PHARMACY'
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError('Invalid OTP');
      }
    } catch (e) {
      _showError('Network error');
    }
    setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacy Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number (Pharmacy)'),
              keyboardType: TextInputType.phone,
            ),
            if (_otpSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(labelText: 'OTP'),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _otpSent ? verifyOtp : sendOtp,
                    child: Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
                  ),
          ],
        ),
      ),
    );
  }
}
