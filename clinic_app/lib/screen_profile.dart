import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
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

  Future<void> _showUpdateLocationDialog() async {
    final TextEditingController locCtrl = TextEditingController(text: _profileData?['address'] ?? '');
    bool isSaving = false;
    bool isFetchingLocation = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {

        Future<void> fetchGpsLocation() async {
          setDialogState(() => isFetchingLocation = true);
          try {
            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Location services are disabled. Please enable GPS.'), backgroundColor: Colors.orange),
              );
              setDialogState(() => isFetchingLocation = false);
              return;
            }

            LocationPermission permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }
            if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Location permission denied. Please allow it in app settings.'), backgroundColor: Colors.red),
              );
              setDialogState(() => isFetchingLocation = false);
              return;
            }

            final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
            final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              final parts = [p.street, p.subLocality, p.locality, p.country]
                  .where((s) => s != null && s.isNotEmpty)
                  .toList();
              locCtrl.text = parts.join(', ');
            }
          } catch (e) {
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(content: Text('Could not get location: $e'), backgroundColor: Colors.red),
            );
          } finally {
            setDialogState(() => isFetchingLocation = false);
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Update Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // GPS auto-fill button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isFetchingLocation ? null : fetchGpsLocation,
                  icon: isFetchingLocation
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(isFetchingLocation ? 'Detecting location...' : 'Use My Location 📍'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D6EFD),
                    side: const BorderSide(color: Color(0xFF0D6EFD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('or type manually', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Kampala Road, Plaza XYZ',
                  filled: true,
                  fillColor: const Color(0xFFF0F4FF),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF0D6EFD)),
                ),
              ),
              const SizedBox(height: 8),
              if (isSaving) const Padding(padding: EdgeInsets.only(top: 8), child: CircularProgressIndicator()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (locCtrl.text.trim().isEmpty) return;
                      setDialogState(() => isSaving = true);
                      
                      try {
                        final token = await SharedPreferences.getInstance().then((p) => p.getString('token'));
                        final res = await http.put(
                          Uri.parse('${ApiService.baseUrl}/users/profile/address'),
                          headers: {
                            'Content-Type': 'application/json',
                            if (token != null) 'Authorization': 'Bearer $token',
                          },
                          body: jsonEncode({'address': locCtrl.text.trim()}),
                        );

                        if (res.statusCode == 200) {
                          if (mounted) Navigator.pop(ctx);
                          _fetchProfile();
                          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Location updated successfully')));
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: ${jsonDecode(res.body)['message']}')));
                        }
                      } catch (e) {
                         ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Network error')));
                      } finally {
                        setDialogState(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showUpdateSupplyTownsDialog() async {
    final List<String> availableTowns = [
      'Kampala', 'Entebbe', 'Wakiso', 'Mukono', 'Jinja',
      'Mbarara', 'Gulu', 'Mbale', 'Arua', 'Masaka',
      'Lira', 'Hoima', 'Fort Portal', 'Soroti', 'Kabale',
      'Ntungamo', 'Bushenyi', 'Isingiro'
    ];
    
    List<String> selectedTowns = [];
    if (_profileData?['preferred_supply_towns'] != null) {
      selectedTowns = List<String>.from(_profileData!['preferred_supply_towns']);
    }

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Preferred Supply Hubs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select the regions you prefer to buy supplies from:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableTowns.length,
                    itemBuilder: (context, index) {
                      final town = availableTowns[index];
                      final isSelected = selectedTowns.contains(town);
                      return CheckboxListTile(
                        title: Text(town),
                        value: isSelected,
                        activeColor: const Color(0xFF0D6EFD),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedTowns.add(town);
                            } else {
                              selectedTowns.remove(town);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                if (isSaving) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        final res = await ApiService.updateProfilePreferences({
                          'preferred_supply_towns': selectedTowns,
                        });
                        if (res.statusCode == 200) {
                          if (mounted) Navigator.pop(ctx);
                          _fetchProfile();
                          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Supply hubs updated successfully')));
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: ${jsonDecode(res.body)['message']}')));
                        }
                      } catch (e) {
                         ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Network error')));
                      } finally {
                        setDialogState(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0D47A1);
    const secondary = Color(0xFF1976D2);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar Header
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [primary, secondary]),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withOpacity(0.05),
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(Icons.local_hospital_rounded, size: 50, color: primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.clinicName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary)),
          const SizedBox(height: 4),
          const Text('Verified Clinic Partner', style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF26C87C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF26C87C).withOpacity(0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF26C87C), size: 16),
                SizedBox(width: 6),
                Text('ACTIVE ACCOUNT', style: TextStyle(color: Color(0xFF26C87C), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else ...[
            // Info Group
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('CLINIC INFORMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 12),
            _InfoTile(icon: Icons.phone_android_rounded, label: 'Phone', value: _profileData?['phone'] ?? 'N/A'),
            _InfoTile(icon: Icons.location_on_rounded, label: 'Location', value: _profileData?['address'] ?? 'N/A'),
            _InfoTile(icon: Icons.badge_rounded, label: 'License / ID', value: _profileData?['license_number'] ?? 'N/A'),
            
            if (_profileData?['preferred_supply_towns'] != null && (_profileData!['preferred_supply_towns'] as List).isNotEmpty)
              _InfoTile(
                icon: Icons.local_shipping_rounded, 
                label: 'Supply Hubs', 
                value: (_profileData!['preferred_supply_towns'] as List).join(', ')
              )
            else
              const _InfoTile(icon: Icons.local_shipping_rounded, label: 'Supply Hubs', value: 'None Selected (Show All)'),
          ],

          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('SETTINGS & SUPPORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 12),

          // Settings
          _SettingsTile(icon: Icons.cloud_upload_rounded, label: 'Verification Documents', onTap: _uploadDoc),
          _SettingsTile(icon: Icons.edit_location_alt_rounded, label: 'Update Clinic Location', onTap: _showUpdateLocationDialog),
          _SettingsTile(icon: Icons.map_rounded, label: 'Manage Supply Hubs', onTap: _showUpdateSupplyTownsDialog),
          _SettingsTile(icon: Icons.notifications_active_rounded, label: 'Notification Preferences', onTap: _showNotificationSettings),
          _SettingsTile(icon: Icons.headset_mic_rounded, label: 'Help & Support', onTap: _launchSupportEmail),

          const SizedBox(height: 32),

          // Logout
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('AfyaLinks v2.1.0', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 24),
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
