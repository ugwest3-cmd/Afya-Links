import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
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
  final _hwidCtrl = TextEditingController();

  static const _primary = Color(0xFF0D6EFD);

  Future<void> _sendOtp() async {
    if (_phoneCtrl.text.trim().isEmpty) {
      _showSnack('Enter a phone number', isError: true);
      return;
    }
    if (_isSignUp) {
      if (_nameCtrl.text.trim().isEmpty) {
        _showSnack('Enter your clinic name', isError: true);
        return;
      }
      if (_locationCtrl.text.trim().isEmpty) {
        _showSnack('Enter your clinic location', isError: true);
        return;
      }
      if (_hwidCtrl.text.trim().isEmpty) {
        _showSnack('Enter your Health Worker ID or License', isError: true);
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
      // If signing up, we pass the name to verifyOtp (which handles registration)
      final res = await ApiService.verifyOtp(
        _phoneCtrl.text.trim(),
        _otpCtrl.text.trim(),
        name: _isSignUp ? _nameCtrl.text.trim() : null,
        location: _isSignUp ? _locationCtrl.text.trim() : null,
        licenseNumber: _isSignUp ? _hwidCtrl.text.trim() : null,
      );

      // Wait, ApiService.verifyOtp needs to support name. Let me update that too.
      // For now, I'll update the body manually or update ApiService first.
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        // Prevent PHARMACY or DRIVER from logging into CLINIC app
        final role = data['user']['role'];
        if (role == 'PHARMACY' || role == 'DRIVER') {
          _showSnack('This number is registered as a $role. Please use a different number for your Clinic.', isError: true);
          setState(() => _loading = false);
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('clinicName', data['business_name'] ?? '');
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
      backgroundColor: const Color(0xFFF0F4FF),
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
                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              const Text('AfyaLinks', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
              const Text('Clinic Portal', style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                    Text(_otpSent ? 'Enter OTP' : (_isSignUp ? 'Create Account' : 'Sign In'), 
                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _otpSent
                          ? 'Enter the code sent to ${_phoneCtrl.text}'
                          : (_isSignUp ? 'Register your clinic to start ordering' : 'Enter your registered clinic phone number'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    if (!_otpSent) ...[
                      if (_isSignUp) ...[
                        _InputField(controller: _nameCtrl, hint: 'Clinic Name', icon: Icons.local_hospital, type: TextInputType.text),
                        const SizedBox(height: 12),
                        const Text('Clinic Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                        const SizedBox(height: 4),
                        _LocationInputField(controller: _locationCtrl),
                        const SizedBox(height: 12),
                        _InputField(controller: _hwidCtrl, hint: 'Health Worker ID / License No.', icon: Icons.badge, type: TextInputType.text),
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
                          child: Text(_isSignUp ? 'Already have an account? Sign In' : 'New Clinic? Create Account',
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
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF0D47A1), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _LocationInputField extends StatefulWidget {
  final TextEditingController controller;
  const _LocationInputField({required this.controller});

  @override
  State<_LocationInputField> createState() => _LocationInputFieldState();
}

class _LocationInputFieldState extends State<_LocationInputField> {
  bool _isLoadingGps = false;

  static const _ugandaLocations = [
    'Kampala - Central', 'Kampala - Nakawa', 'Kampala - Makindye', 'Kampala - Rubaga', 'Kampala - Kawempe',
    'Wakiso - Entebbe', 'Wakiso - Kira', 'Wakiso - Nansana', 'Wakiso - Makindye Ssabagabo',
    'Mukono', 'Jinja', 'Mbarara', 'Gulu', 'Mbale', 'Masaka', 'Lira', 'Hoima', 'Fort Portal', 'Arua', 'Soroti'
  ];

  Future<void> _fetchGpsLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      // Inline simplified GPS fetch since it's just for MVP
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Location permissions are denied';
      }
      if (permission == LocationPermission.deniedForever) throw 'Location permissions are permanently denied';

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final address = '${p.street}, ${p.subLocality}, ${p.locality}';
        widget.controller.text = address.replaceAll(RegExp(r'^, |, $'), ''); // clean up empty parts
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
            return _ugandaLocations.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (s) => widget.controller.text = s,
          fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
            // Keep controller in sync
            if (widget.controller.text != ctrl.text && !focusNode.hasFocus) {
               ctrl.text = widget.controller.text;
            }
            ctrl.addListener(() {
              if (widget.controller.text != ctrl.text) widget.controller.text = ctrl.text;
            });
            widget.controller.addListener(() {
               if (widget.controller.text != ctrl.text) ctrl.text = widget.controller.text;
            });

            return Container(
              decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: ctrl,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Search district/city or enter address manually',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: const Icon(Icons.location_city, color: Color(0xFF0D47A1), size: 20),
                  suffixIcon: _isLoadingGps
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(
                          icon: const Icon(Icons.my_location, color: Color(0xFF0D6EFD), size: 20),
                          onPressed: _fetchGpsLocation,
                          tooltip: 'Use my current location',
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            );
          },
          optionsViewBuilder: (ctx, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: options.map((String option) => ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
