import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class PharmProfileScreen extends StatefulWidget {
  final String pharmacyName;
  const PharmProfileScreen({super.key, required this.pharmacyName});

  @override
  State<PharmProfileScreen> createState() => _PharmProfileScreenState();
}

class _PharmProfileScreenState extends State<PharmProfileScreen> {
  static const _primary = Color(0xFF1B5E20);
  static const _green = Color(0xFF2E7D32);

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await ApiService.getProfileStatus();
      if (res.statusCode == 200) {
        setState(() {
          _profileData = jsonDecode(res.body)['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('pharmacyName');
    if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Feature coming soon!'),
      behavior: SnackBarBehavior.floating,
    ));
  }
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          // Avatar + name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _primary.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 12),
              Text(widget.pharmacyName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Text('Verified Pharmacy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Info section
            _InfoCard(children: [
              _InfoRow(Icons.business_rounded, 'Business Name', widget.pharmacyName),
              const _Divider(),
              _InfoRow(Icons.location_on_rounded, 'Address', _profileData?['address'] ?? 'N/A'),
              const _Divider(),
              _InfoRow(Icons.phone_rounded, 'Contact', _profileData?['phone'] ?? 'N/A'),
              const _Divider(),
              _InfoRow(Icons.badge_rounded, 'License No.', _profileData?['license_number'] ?? 'N/A'),
            ]),
          ],
          const SizedBox(height: 14),

          // Settings
          _InfoCard(children: [
            _SettingsRow(Icons.upload_file_rounded, 'Upload Verification Docs', _green, _showComingSoon),
            const _Divider(),
            _SettingsRow(Icons.list_alt_rounded, 'Manage Price Lists', _primary, _showComingSoon),
            const _Divider(),
            _SettingsRow(Icons.receipt_long_rounded, 'View Invoices', Colors.blueGrey, _showComingSoon),
            const _Divider(),
            _SettingsRow(Icons.notifications_outlined, 'Notification Settings', Colors.blueGrey, _showComingSoon),
          ]),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              label: const Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              onPressed: () => _showSignOutDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?'),
        content: const Text('You will be taken back to the login screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () { Navigator.pop(context); _signOut(context); },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
    ),
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF1B5E20), size: 20),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SettingsRow(this.icon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
      ]),
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(height: 0, thickness: 0.5, indent: 16, endIndent: 16, color: Colors.grey.shade200);
}
