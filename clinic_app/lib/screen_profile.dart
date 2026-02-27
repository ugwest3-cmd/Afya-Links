import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class ProfileScreen extends StatefulWidget {
  final String clinicName;
  const ProfileScreen({super.key, required this.clinicName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('clinicName');
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
          'business_reg_url',
        );

        setState(() => _isLoading = false);
        
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Document uploaded successfully!'),
            backgroundColor: Color(0xFF26C87C),
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
        'subject': 'Support Request - AfyaLinks Clinic Partner'
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
                  activeColor: const Color(0xFF0D6EFD),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF0D6EFD), Color(0xFF6B9FFF)]),
            ),
            child: const CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white,
              child: Icon(Icons.local_hospital, size: 46, color: Color(0xFF0D6EFD)),
            ),
          ),
          const SizedBox(height: 12),
          Text(widget.clinicName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Verified Clinic Partner', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF26C87C).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Color(0xFF26C87C), size: 14),
                SizedBox(width: 4),
                Text('Active', style: TextStyle(color: Color(0xFF26C87C), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const SizedBox(height: 28),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Info tiles
            _InfoTile(icon: Icons.phone, label: 'Phone', value: _profileData?['phone'] ?? 'N/A'),
            _InfoTile(icon: Icons.location_on, label: 'Location', value: _profileData?['address'] ?? 'N/A'),
            _InfoTile(icon: Icons.badge, label: 'License / ID', value: _profileData?['license_number'] ?? 'N/A'),
          ],

          const SizedBox(height: 24),

          // Settings
          _SettingsTile(icon: Icons.upload_file, label: 'Upload Verification Docs', onTap: _uploadDoc),
          _SettingsTile(icon: Icons.notifications_outlined, label: 'Notification Preferences', onTap: _showNotificationSettings),
          _SettingsTile(icon: Icons.help_outline, label: 'Help & Support', onTap: _launchSupportEmail),

          const SizedBox(height: 16),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0D6EFD), size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0D6EFD), size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
