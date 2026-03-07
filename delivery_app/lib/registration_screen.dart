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
  int _currentStep = 0;

  void _nextStep() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty || _nationalIdController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill operator details')));
        return;
      }
    } else if (_currentStep == 1) {
      if (_vehicleTypeController.text.trim().isEmpty || _licensePlateController.text.trim().isEmpty || _regionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill vehicle details')));
        return;
      }
    }
    setState(() => _currentStep++);
  }

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
          SnackBar(content: Text('Submission failed: ${res.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF312E81);
    const accentCyan = Color(0xFF0891B2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('DRIVER ONBOARDING', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: primaryIndigo,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: Colors.grey.shade200,
              color: accentCyan,
              minHeight: 6,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        _currentStep == 0 ? 'Operator\nIdentity' : (_currentStep == 1 ? 'Vehicle\nLogistics' : 'Payment\nSettlement'),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryIndigo, height: 1.1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentStep == 0 
                          ? 'Provide your official identification details.' 
                          : (_currentStep == 1 ? 'Configure your vehicle specs for deliveries.' : 'Tell us where to send your earnings.'),
                        style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13),
                      ),
                      const SizedBox(height: 48),

                      if (_currentStep == 0) ...[
                        _buildSectionTitle('OPERATOR DETAILS'),
                        _buildField(_nameController, "Legal Full Name", Icons.person_rounded),
                        _buildField(_nationalIdController, "National ID Number", Icons.badge_rounded),
                      ] else if (_currentStep == 1) ...[
                        _buildSectionTitle('VEHICLE CONFIGURATION'),
                        _buildField(_vehicleTypeController, "Vehicle Class (e.g., Bajaj Boxer)", Icons.two_wheeler_rounded),
                        _buildField(_licensePlateController, "License Plate", Icons.onetwothree_rounded),
                        _buildField(_regionController, "Primary Service Region", Icons.location_on_rounded),
                      ] else ...[
                        _buildSectionTitle('SETTLEMENT PREFERENCES'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _payoutMethod,
                          decoration: InputDecoration(
                            labelText: 'Payment Gateway',
                            prefixIcon: const Icon(Icons.account_balance_rounded),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: accentCyan, width: 2)),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          items: ['Mobile Money', 'Bank Account', 'Cash'].map((m) {
                            return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)));
                          }).toList(),
                          onChanged: (val) => setState(() => _payoutMethod = val!),
                        ),
                        if (_payoutMethod != 'Cash') ...[
                          const SizedBox(height: 24),
                          _buildField(
                            _payoutDetailsController, 
                            _payoutMethod == 'Mobile Money' ? "Number & Network Provider" : "Bank Name & Account Number", 
                            Icons.wallet_rounded
                          ),
                        ],
                      ],

                      const SizedBox(height: 48),
                      Row(
                        children: [
                          if (_currentStep > 0)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _currentStep--),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: primaryIndigo),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Text('Back', style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : (_currentStep < 2 ? _nextStep : _submitProfile),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryIndigo,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: _isLoading 
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(_currentStep < 2 ? 'Continue' : 'Complete Setup', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: (val) => val == null || val.isEmpty ? 'This field is required' : null,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
