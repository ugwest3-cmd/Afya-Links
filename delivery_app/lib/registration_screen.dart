import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'dashboard_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String phone;
  const RegistrationScreen({super.key, required this.phone});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _regionController = TextEditingController();
  final _payoutDetailsController = TextEditingController();
  
  String _payoutMethod = 'Mobile Money';
  bool _isLoading = false;

  void _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final payload = {
        'name': _nameController.text,
        'national_id_number': _nationalIdController.text,
        'vehicle_type': _vehicleTypeController.text,
        'license_plate_number': _licensePlateController.text,
        'region': _regionController.text,
        'preferred_payout_method': _payoutMethod,
        'payout_details': _payoutDetailsController.text,
      };

      final res = await ApiService.setupDriverProfile(payload);
      
      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${res.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profile Setup'),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0E7FF), Color(0xFFF3F4F6)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 8),
                  const Text('We need some details before you can start delivering.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  
                  _buildField(_nameController, "Full Name", Icons.person_rounded),
                  const SizedBox(height: 16),
                  _buildField(_nationalIdController, "National ID Number", Icons.badge_rounded),
                  const SizedBox(height: 16),
                  _buildField(_vehicleTypeController, "Vehicle Type (e.g. Motorcycle)", Icons.two_wheeler_rounded),
                  const SizedBox(height: 16),
                  _buildField(_licensePlateController, "License Plate Number", Icons.pin_rounded),
                  const SizedBox(height: 16),
                  _buildField(_regionController, "Operating Region", Icons.map_rounded),
                  
                  const SizedBox(height: 24),
                  const Text('Payout Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<String>(
                    value: _payoutMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      prefixIcon: Icon(Icons.payment_rounded),
                      border: OutlineInputBorder(),
                    ),
                    items: ['Mobile Money', 'Bank Account', 'Cash'].map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _payoutMethod = val!;
                      });
                    },
                  ),
                  
                  if (_payoutMethod != 'Cash') ...[
                    const SizedBox(height: 16),
                    _buildField(
                      _payoutDetailsController, 
                      _payoutMethod == 'Mobile Money' ? "Mobile Number & Network" : "Bank Name & Account No.", 
                      Icons.account_balance_wallet_rounded
                    ),
                  ],

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Complete Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
