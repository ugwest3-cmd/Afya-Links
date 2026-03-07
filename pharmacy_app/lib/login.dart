import 'dart:convert';
import 'package:flutter/material.dart';
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
  final _locationCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  
  bool _otpSent = false;
  bool _loading = false;
  bool _isSignUp = false;

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
        final body = jsonDecode(res.body);
        _showSnack(body['message'] ?? 'Failed to send OTP', isError: true);
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
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1B5E20),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo Section
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.local_pharmacy_rounded, color: primary, size: 56),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'AfyaLinks Pharmacy',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Partner Portal • Secure Access',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Title & Description
                    Text(
                      _otpSent ? 'Enter Verification Code' : (_isSignUp ? 'Apply as Partner' : 'Sign In'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _otpSent
                          ? 'We\'ve sent a 6-digit code to ${_phoneCtrl.text}'
                          : (_isSignUp ? 'Register to start receiving clinic orders.' : 'Enter your registered phone number to continue.'),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 32),

                    // Form Fields
                    if (!_otpSent) ...[
                      if (_isSignUp) ...[
                        _buildInputField(_nameCtrl, 'Pharmacy Name', Icons.business_rounded),
                        const SizedBox(height: 16),
                        _buildInputField(_locationCtrl, 'City/Location', Icons.location_on_rounded),
                        const SizedBox(height: 16),
                        _buildInputField(_licenseCtrl, 'License Number', Icons.badge_rounded),
                        const SizedBox(height: 16),
                      ],
                      _buildInputField(_phoneCtrl, 'Phone Number', Icons.phone_android_rounded, type: TextInputType.phone),
                    ] else ...[
                      _buildInputField(_otpCtrl, '6-Digit OTP', Icons.lock_open_rounded, type: TextInputType.number),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => setState(() => _otpSent = false),
                        icon: const Icon(Icons.arrow_back_rounded, size: 14),
                        label: const Text('Change Phone Number', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      ),
                    ],

                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _otpSent ? _verifyOtp : _sendOtp,
                      child: Text(
                        _otpSent ? 'Verify & Login' : (_isSignUp ? 'Submit Application' : 'Get Access Code →'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Toggle Sign In / Sign Up
                    if (!_otpSent)
                      Center(
                        child: TextButton(
                          onPressed: () => setState(() => _isSignUp = !_isSignUp),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                              children: [
                                TextSpan(text: _isSignUp ? 'Already have an account? ' : 'New Pharmacy Partner? '),
                                TextSpan(
                                  text: _isSignUp ? 'Login Here' : 'Register Now',
                                  style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }
}
