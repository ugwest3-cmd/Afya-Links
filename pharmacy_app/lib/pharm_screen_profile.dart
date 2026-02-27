import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'pharm_screen_invoices.dart';

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

  Future<void> _uploadDoc() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isLoading = true);
        final file = result.files.single;
        
        final res = await ApiService.uploadVerificationDoc(
          file.bytes!.toList(),
          file.name,
          'pharmacy_license_url',
        );

        setState(() => _isLoading = false);
        
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Document uploaded successfully!'),
            backgroundColor: _green,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: ${jsonDecode(res.body)['message']}'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error selecting file: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _uploadPriceList() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isLoading = true);
        final file = result.files.single;
        
        // Pass dummy filePath or name if needed, important part is file.bytes
        final res = await ApiService.uploadPriceList(
          file.name,
          file.bytes!.toList(),
          file.name,
        );

        setState(() => _isLoading = false);
        
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Price list uploaded! ${data['items_count']} items added.'),
            backgroundColor: _primary,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: ${jsonDecode(res.body)['message']}'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error selecting file: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _launchSupportEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'bdplinksapps@gmail.com',
      queryParameters: {
        'subject': 'Support Request - AfyaLinks Pharmacy Partner'
      }
    );
    if (!await launchUrl(emailLaunchUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open email client.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _showNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notification Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Enable push notifications'),
                  subtitle: const Text('Receive alerts for new orders and updates.'),
                  value: isEnabled,
                  activeColor: _primary,
                  onChanged: (val) async {
                    setModalState(() => isEnabled = val);
                    await prefs.setBool('notifications_enabled', val);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
      ),
    );
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
            _SettingsRow(Icons.upload_file_rounded, 'Upload Verification Docs', _green, _uploadDoc),
            const _Divider(),
            _SettingsRow(Icons.list_alt_rounded, 'Manage Price Lists', _primary, _uploadPriceList),
            const _Divider(),
            _SettingsRow(Icons.receipt_long_rounded, 'View Invoices', Colors.blueGrey, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmInvoicesScreen()));
            }),
            const _Divider(),
            _SettingsRow(Icons.notifications_outlined, 'Notification Settings', Colors.blueGrey, _showNotificationSettings),
            const _Divider(),
            _SettingsRow(Icons.help_outline, 'Help & Support', Colors.blue, _launchSupportEmail),
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
