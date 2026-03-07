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
  int _currentRegStep = 0;

  static const _primary = Color(0xFF1B5E20);

  void _nextStep() {
    if (_currentRegStep == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        _showSnack('Enter your pharmacy name', isError: true);
        return;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        _showSnack('Enter a phone number', isError: true);
        return;
      }
    } else if (_currentRegStep == 1) {
      if (_licenseCtrl.text.trim().isEmpty) {
        _showSnack('Enter your license number', isError: true);
        return;
      }
    }
    setState(() => _currentRegStep++);
  }

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
      backgroundColor: const Color(0xFFF1F8E9), // Light green background
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Logo Section
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, primary.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: primary.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))
                        ],
                      ),
                      child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 50),
                    ),
                    const SizedBox(height: 24),
                    Text('AfyaLinks', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primary, letterSpacing: -0.5)),
                    const Text('Pharmacy Partner Portal', style: TextStyle(fontSize: 15, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 48),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 40, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_otpSent ? 'Verification' : (_isSignUp ? 'Apply as Partner' : 'Sign In'), 
                               style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary)),
                          const SizedBox(height: 8),
                          Text(
                            _otpSent
                                ? 'We\'ve sent a 6-digit code to ${_phoneCtrl.text}'
                                : (_isSignUp ? 'Step ${_currentRegStep + 1} of 3: Enter details' : 'Secure access to your pharmacy dashboard'),
                            style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 32),

                          if (!_otpSent) ...[
                            if (_isSignUp) ...[
                              if (_currentRegStep == 0) ...[
                                _buildInputField(_nameCtrl, 'Pharmacy Business Name', Icons.storefront_rounded),
                                const SizedBox(height: 16),
                                _buildInputField(_phoneCtrl, 'Business Phone Number', Icons.phone_android_rounded, type: TextInputType.phone),
                              ] else if (_currentRegStep == 1) ...[
                                _buildInputField(_licenseCtrl, 'Pharmacy License Number', Icons.badge_rounded),
                                const SizedBox(height: 12),
                                Text('We will verify this with the National Drug Authority', style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 11)),
                              ] else ...[
                                _buildInputField(_locationCtrl, 'District / Physical Address', Icons.location_on_rounded),
                              ],
                            ] else ...[
                              _buildInputField(_phoneCtrl, 'Phone (e.g., 0722...)', Icons.phone_android_rounded, type: TextInputType.phone),
                            ],
                          ] else ...[
                            _buildInputField(_otpCtrl, 'Enter 6-digit code', Icons.lock_open_rounded, type: TextInputType.number),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () => setState(() { _otpSent = false; _otpCtrl.clear(); }),
                                child: Text('Change phone number', style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),

                          Row(
                            children: [
                              if (_isSignUp && _currentRegStep > 0 && !_otpSent)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: SizedBox(
                                      height: 56,
                                      child: OutlinedButton(
                                        onPressed: () => setState(() => _currentRegStep--),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: primary),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        child: Text('Back', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                                ),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : (_otpSent ? _verifyOtp : (_isSignUp && _currentRegStep < 2 ? _nextStep : _sendOtp)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    child: _loading
                                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                        : Text(_otpSent ? 'Verify OTP' : (_isSignUp ? (_currentRegStep < 2 ? 'Continue' : 'Submit Application') : 'Get Access'),
                                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          if (!_otpSent) ...[
                            const SizedBox(height: 20),
                            Center(
                              child: TextButton(
                                onPressed: () => setState(() {
                                  _isSignUp = !_isSignUp;
                                  if (!_isSignUp) _currentRegStep = 0;
                                }),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    children: [
                                      TextSpan(text: _isSignUp ? 'Already a partner? ' : 'New Pharmacy Partner? '),
                                      TextSpan(
                                        text: _isSignUp ? 'Sign In' : 'Register Now',
                                        style: TextStyle(color: primary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
                    Text('Secure Health Ecosystem by AfyaLinks', style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 12)),
                    const SizedBox(height: 12),
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
