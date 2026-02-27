import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatelessWidget {
  final String clinicName;
  const ProfileScreen({super.key, required this.clinicName});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('clinicName');
    if (context.mounted) Navigator.pushReplacementNamed(context, '/login');

  }

  @override
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
          Text(clinicName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

          // Info tiles
          _InfoTile(icon: Icons.phone, label: 'Phone', value: '+256 700 000 000'),
          _InfoTile(icon: Icons.location_on, label: 'Location', value: 'Kampala, Uganda'),
          _InfoTile(icon: Icons.badge, label: 'Clinic ID', value: 'CLN-0042'),

          const SizedBox(height: 24),

          // Settings
          _SettingsTile(icon: Icons.lock_outline, label: 'Change PIN', onTap: () {}),
          _SettingsTile(icon: Icons.notifications_outlined, label: 'Notification Preferences', onTap: () {}),
          _SettingsTile(icon: Icons.help_outline, label: 'Help & Support', onTap: () {}),

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
