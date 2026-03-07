import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
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
  Map<String, dynamic> _stats = {'total_orders': 0, 'completed_orders': 0, 'pending_orders': 0, 'total_revenue': 0};

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await ApiService.getProfileStatus();
      final statsRes = await ApiService.getDashboardStats();

      if (res.statusCode == 200) {
        setState(() {
          _profileData = jsonDecode(res.body)['data'];
          if (statsRes.statusCode == 200) {
             _stats = Map<String, dynamic>.from(jsonDecode(statsRes.body)['stats']);
          }
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isFetchingLocation ? null : fetchGpsLocation,
                  icon: isFetchingLocation
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(isFetchingLocation ? 'Detecting location...' : 'Use My Location 📍'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1B5E20),
                    side: const BorderSide(color: Color(0xFF1B5E20)),
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
                  hintText: 'e.g. Kampala Road, Kampala',
                  filled: true,
                  fillColor: const Color(0xFFF0FAF0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.location_on, color: Color(0xFF1B5E20)),
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
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Location updated successfully')),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Failed: ${jsonDecode(res.body)['message']}')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Network error')),
                        );
                      } finally {
                        setDialogState(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
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

  Future<void> _showUpdateSupplyAreasDialog() async {
    final List<String> availableTowns = [
      'Kampala', 'Entebbe', 'Wakiso', 'Mukono', 'Jinja',
      'Mbarara', 'Gulu', 'Mbale', 'Arua', 'Masaka',
      'Lira', 'Hoima', 'Fort Portal', 'Soroti', 'Kabale',
      'Ntungamo', 'Bushenyi', 'Isingiro'
    ];
    
    List<String> selectedTowns = [];
    if (_profileData?['supply_areas'] != null) {
      selectedTowns = List<String>.from(_profileData!['supply_areas']);
    }

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Supply Areas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select the regions you can deliver supplies to:', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                        activeColor: _primary,
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
                          'supply_areas': selectedTowns,
                        });
                        if (res.statusCode == 200) {
                          if (mounted) Navigator.pop(ctx);
                          _fetchProfile();
                          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Supply areas updated successfully')));
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: ${jsonDecode(res.body)['message']}')));
                        }
                      } catch (e) {
                         ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Network error')));
                      } finally {
                        setDialogState(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: _primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }



  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        children: [
          // Premium Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                      ),
                      child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 48),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.verified_rounded, color: primary, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.pharmacyName,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Authenticated Partner',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Business Information Card
          _buildSectionHeader('Business Profile'),
          _InfoCard(children: [
            _InfoRow(Icons.business_rounded, 'Legal Name', widget.pharmacyName),
            const _Divider(),
            _InfoRow(Icons.location_on_rounded, 'Operational Address', _profileData?['address'] ?? 'Address not set'),
            const _Divider(),
            _InfoRow(Icons.phone_iphone_rounded, 'Primary Contact', _profileData?['phone'] ?? 'Phone not set'),
            const _Divider(),
            _InfoRow(Icons.badge_rounded, 'Pharmacy License', _profileData?['license_number'] ?? 'Verification Pending'),
            const _Divider(),
            _InfoRow(Icons.local_shipping_rounded, 'Authorized Regions', 
                (_profileData?['supply_areas'] as List?)?.isEmpty ?? true 
                    ? 'Nationwide / Not Set'
                    : (_profileData!['supply_areas'] as List).join(', ')),
          ]),
          const SizedBox(height: 16),

          // Platform Settings Card
          _buildSectionHeader('Operations & Compliance'),
          _InfoCard(children: [
            _SettingsRow(Icons.draw_rounded, 'Verification Documents', primary, _uploadDoc),
            const _Divider(),
            _SettingsRow(Icons.playlist_add_check_rounded, 'Price List Management', primary, _uploadPriceList),
            const _Divider(),
            _SettingsRow(Icons.receipt_long_rounded, 'Platform Invoices', Colors.blue, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmInvoicesScreen()));
            }),
            const _Divider(),
            _SettingsRow(Icons.share_location_rounded, 'Set Delivery Areas', primary, _showUpdateSupplyAreasDialog),
            const _Divider(),
            _SettingsRow(Icons.gps_fixed_rounded, 'Calibrate GPS Location', primary, _showUpdateLocationDialog),
            const _Divider(),
            _SettingsRow(Icons.notifications_active_outlined, 'Alert Preferences', Colors.blueGrey, _showNotificationSettings),
            const _Divider(),
            _SettingsRow(Icons.help_center_outlined, 'Partner Support', Colors.orange, _launchSupportEmail),
          ]),
          const SizedBox(height: 32),

          // Logout Action
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showSignOutDialog(context),
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text('Sign Out of Portal', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.withOpacity(0.2))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2),
        ),
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

