import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  bool _isSignUp = false;
  final _locationCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  static const _primary = Color(0xFF1B5E20);

  Future<void> _sendOtp() async {
    if (_phoneCtrl.text.trim().isEmpty) {
      _showSnack('Enter a phone number', isError: true);
      return;
    }
    if (_isSignUp) {
      if (_nameCtrl.text.trim().isEmpty) {
        _showSnack('Enter your pharmacy name', isError: true);
        return;
      }
      if (_locationCtrl.text.trim().isEmpty) {
        _showSnack('Enter your pharmacy location', isError: true);
        return;
      }
      if (_licenseCtrl.text.trim().isEmpty) {
        _showSnack('Enter your pharmacy license number', isError: true);
        return;
      }
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService.requestOtp(_phoneCtrl.text.trim());
      if (res.statusCode == 200) {
        setState(() => _otpSent = true);
        _showSnack('OTP sent!');
      } else {
        _showSnack(jsonDecode(res.body)['message'] ?? 'Failed to send OTP', isError: true);
      }
    } catch (_) {
      _showSnack('Network error', isError: true);
    }
    setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().isEmpty) {
      _showSnack('Enter the OTP', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService.verifyOtp(
        _phoneCtrl.text.trim(),
        _otpCtrl.text.trim(),
        name: _isSignUp ? _nameCtrl.text.trim() : null,
        location: _isSignUp ? _locationCtrl.text.trim() : null,
        licenseNumber: _isSignUp ? _licenseCtrl.text.trim() : null,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('pharmacyName', data['business_name'] ?? '');
        if (mounted) Navigator.pushReplacementNamed(context, '/home');

      } else {
        _showSnack(jsonDecode(res.body)['message'] ?? 'Invalid OTP', isError: true);
      }
    } catch (_) {
      _showSnack('Network error', isError: true);
    }
    setState(() => _loading = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              const Text('AfyaLinks', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primary)),
              const Text('Pharmacy Portal', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 40),

              // Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_otpSent ? 'Enter OTP' : (_isSignUp ? 'Apply as Provider' : 'Sign In'), 
                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _otpSent
                          ? 'Enter the code sent to ${_phoneCtrl.text}'
                          : (_isSignUp ? 'Register your pharmacy to receive orders' : 'Enter your registered pharmacy phone number'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    if (!_otpSent) ...[
                      if (_isSignUp) ...[
                        _InputField(controller: _nameCtrl, hint: 'Pharmacy Name', icon: Icons.business, type: TextInputType.text),
                        const SizedBox(height: 12),
                        _InputField(controller: _locationCtrl, hint: 'Pharmacy Location (e.g. Jinja Road)', icon: Icons.location_on, type: TextInputType.text),
                        const SizedBox(height: 12),
                        _InputField(controller: _licenseCtrl, hint: 'License Number (e.g. PHAR-1234)', icon: Icons.badge, type: TextInputType.text),
                        const SizedBox(height: 12),
                      ],
                      _InputField(controller: _phoneCtrl, hint: '+256 700 000 000', icon: Icons.phone, type: TextInputType.phone),
                    ] else ...[
                      _InputField(controller: _otpCtrl, hint: '6-digit code', icon: Icons.lock_outline, type: TextInputType.number),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() { _otpSent = false; _otpCtrl.clear(); }),
                        child: const Text('← Change number', style: TextStyle(color: _primary, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          disabledBackgroundColor: _primary.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_otpSent ? 'Verify & Continue' : (_isSignUp ? 'Sign Up' : 'Get OTP'),
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    if (!_otpSent) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _isSignUp = !_isSignUp),
                          child: Text(_isSignUp ? 'Already have an account? Sign In' : 'New Pharmacy? Register Here',
                               style: const TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text('AfyaLinks © 2026', style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType type;
  const _InputField({required this.controller, required this.hint, required this.icon, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF1B5E20), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
