import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'dashboard_screen.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;

  void _requestOtp() async {
    if (_phoneController.text.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService.requestOtp(_phoneController.text);
      if (res.statusCode == 200) {
        setState(() => _otpSent = true);
        _showSuccess('Verification code sent');
      } else {
        _showError('Error: ${res.body}');
      }
    } catch (e) {
      _showError('Network error. Check your connection.');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _verifyOtp() async {
    if (_otpController.text.length < 4) {
      _showError('Please enter a valid code');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService.verifyOtp(_phoneController.text, _otpController.text);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user', jsonEncode(data['user']));
        
        // Check profile status
        final statusRes = await ApiService.checkProfileStatus();
        bool isComplete = false;
        
        if (statusRes.statusCode == 200) {
           final statusData = jsonDecode(statusRes.body)['data'];
           if (statusData != null && statusData['national_id_number'] != null && statusData['national_id_number'].toString().isNotEmpty) {
             isComplete = true;
           }
        }

        if (mounted) {
          if (isComplete) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RegistrationScreen(phone: _phoneController.text)));
          }
        }
      } else {
        _showError('Invalid code. Please try again.');
      }
    } catch (e) {
      _showError('Verification failed. Try again later.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF312E81),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF312E81);
    const accentCyan = Color(0xFF0891B2);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Design
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: primaryIndigo.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Moving Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: primaryIndigo.withOpacity(0.12),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          )
                        ],
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, size: 54, color: primaryIndigo),
                    ),
                    const SizedBox(height: 40),
                    
                    const Text(
                      'Afya Links',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: primaryIndigo,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text(
                      'FAST DELIVERY PORTAL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentCyan,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Input Form
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _otpSent ? 'ENTER VERIFICATION CODE' : 'GET STARTED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade400,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_otpSent && !_loading,
                          decoration: InputDecoration(
                            hintText: 'Phone (e.g., 0722...)',
                            prefixIcon: const Icon(Icons.phone_android_rounded),
                            suffixIcon: _otpSent 
                              ? IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 18), 
                                  onPressed: () => setState(() => _otpSent = false)
                                ) 
                              : null,
                          ),
                        ),
                        
                        if (_otpSent) ...[
                          const SizedBox(height: 20),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            enabled: !_loading,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.black, fontSize: 24, letterSpacing: 12),
                            decoration: const InputDecoration(
                              hintText: '••••••',
                              hintStyle: TextStyle(letterSpacing: 12, color: Color(0xFFE2E8F0)),
                              prefixIcon: Icon(Icons.lock_rounded),
                              contentPadding: EdgeInsets.symmetric(vertical: 20),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                        
                        ElevatedButton(
                          onPressed: _loading ? null : (_otpSent ? _verifyOtp : _requestOtp),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(_otpSent ? 'Verify and Login' : 'Send Access Code'),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    Text(
                      'By continuing, you agree to our Terms of Service',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
