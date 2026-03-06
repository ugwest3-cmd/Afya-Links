import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'order_detail_screen.dart';
import 'notifications_screen.dart';
import 'wallet_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _availableDeliveries = [];
  List<dynamic> _myDeliveries = [];
  bool _loading = true;
  
  String _driverName = 'Driver';
  bool _isOnline = false;
  double _walletBalance = 0.0;
  double _totalEarned = 0.0;

  @override
  void initState() {
    super.initState();
    _initUser();
    _loadData();
  }

  Future<void> _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final user = jsonDecode(userStr);
      setState(() {
        _driverName = user['name'] ?? 'Driver';
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Fetch profile to get isOnline
      final statusRes = await ApiService.checkProfileStatus();
      if (statusRes.statusCode == 200) {
        final profile = jsonDecode(statusRes.body)['data'];
        if (profile != null) {
          _isOnline = profile['is_online'] ?? false;
        }
      }

      // Fetch wallet info
      final walletRes = await ApiService.getDriverWallet();
      if (walletRes.statusCode == 200) {
        final walletData = jsonDecode(walletRes.body);
        _walletBalance = (walletData['wallet_balance'] ?? 0).toDouble();
        _totalEarned = (walletData['total_earned'] ?? 0).toDouble();
      }

      // Fetch available unassigned orders
      if (_isOnline) {
        final availableRes = await ApiService.getAvailableDeliveries();
        if (availableRes.statusCode == 200) {
          _availableDeliveries = jsonDecode(availableRes.body)['available_deliveries'] ?? [];
        }
      } else {
        _availableDeliveries = [];
      }

      // Fetch active deliveries already assigned to this driver
      final myRes = await ApiService.getMyDeliveries();
      if (myRes.statusCode == 200) {
        _myDeliveries = jsonDecode(myRes.body)['deliveries'] ?? [];
      }

    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleOnlineStatus(bool val) async {
    setState(() {
      _isOnline = val;
      _loading = true;
    });
    try {
      final res = await ApiService.toggleDriverStatus(val);
      if (res.statusCode == 200) {
        _loadData(); // reload available pools
      } else {
        setState(() => _isOnline = !val);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status')));
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _isOnline = !val);
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _acceptPickup(String orderId) async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.acceptDelivery(orderId);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pickup Accepted!')));
        _loadData();
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to accept pickup';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        _loadData(); // clear it from pool if it was taken by someone else
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _myDeliveries.where((d) => ['ASSIGNED', 'IN_TRANSIT', 'READY_FOR_PICKUP'].contains(d['status']) || d['status'] == null || d['status']?.toString().isEmpty == false).toList();
    // we only want things not delivered in myDeliveries, but backend should return all not delivered, or actually backend returns all including delivered.
    final myActiveDeliveries = _myDeliveries.where((d) {
       final s = d['order']?['status'] ?? d['status']; 
       return s == 'ASSIGNED' || s == 'IN_TRANSIT';
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('Welcome, $_driverName', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: Theme.of(context).colorScheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // Status Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                     children: [
                       Container(
                         width: 12, height: 12,
                         decoration: BoxDecoration(shape: BoxShape.circle, color: _isOnline ? Colors.green : Colors.grey),
                       ),
                       const SizedBox(width: 8),
                       Text(_isOnline ? 'ONLINE' : 'OFFLINE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isOnline ? Colors.green : Colors.grey)),
                     ],
                   ),
                   Switch(
                     value: _isOnline,
                     onChanged: _loading ? null : (val) => _toggleOnlineStatus(val),
                     activeColor: Colors.green,
                   ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Earnings Overview
            Row(
              children: [
                Expanded(child: _buildStatCard('Wallet Balance', 'UGX ${_walletBalance.toInt()}', Icons.account_balance_wallet_rounded, const Color(0xFF3B82F6))),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Total Earned', 'UGX ${_totalEarned.toInt()}', Icons.trending_up_rounded, const Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 32),
            
            if (_loading) 
              const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
            else ...[
              // Active Deliveries Sector
              _buildSectionHeader('Active Deliveries', Icons.local_shipping_rounded, myActiveDeliveries.length),
              if (myActiveDeliveries.isEmpty)
                _buildEmptyState('No active deliveries right now', Icons.check_circle_outline)
              else
                ...myActiveDeliveries.map((d) => _buildDeliveryTicket(d, const Color(0xFF2563EB), true)),

              const SizedBox(height: 32),

              // Pending Pickups Sector
              _buildSectionHeader('Pending Pickups', Icons.inbox_rounded, _availableDeliveries.length),
              if (!_isOnline)
                _buildEmptyState('Go online to receive pickups', Icons.power_settings_new_rounded)
              else if (_availableDeliveries.isEmpty)
                _buildEmptyState('No pickups available in your region', Icons.hourglass_empty_rounded)
              else
                ..._availableDeliveries.map((o) => _buildDeliveryTicket(o, const Color(0xFFF59E0B), false)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(_driverName, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text('Afya Links Delivery'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.two_wheeler_rounded, color: Color(0xFF1E40AF), size: 36),
            ),
            decoration: const BoxDecoration(color: Color(0xFF1E40AF)),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_rounded, color: Color(0xFF4B5563)),
            title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF4B5563)),
            title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded, color: Color(0xFF4B5563)),
            title: const Text('Delivery History', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
            onTap: () async {
               final prefs = await SharedPreferences.getInstance();
               await prefs.clear();
               if (mounted) {
                 Navigator.pushAndRemoveUntil(
                   context, 
                   MaterialPageRoute(builder: (_) => const LoginScreen()), 
                   (route) => false,
                 );
               }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFF9CA3AF).withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: const Color(0xFF1E40AF), size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const Spacer(),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(12)),
              child: Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563), fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTicket(dynamic data, Color statusColor, bool isActive) {
    // Determine data structure
    final order = isActive ? data['order'] : data;
    final pharmacyName = order != null ? (order['pharmacy']?['name'] ?? order['pharmacy']?['business_name'] ?? 'Unknown Pharmacy') : 'Unknown';
    final clinicName = order != null ? (order['clinic']?['name'] ?? order['clinic']?['business_name'] ?? 'Unknown Clinic') : 'Unknown';
    final orderCode = order?['order_code'] ?? (order?['id']?.toString().substring(0, 8).toUpperCase() ?? 'NONE');
    final fee = order?['delivery_fee']?.toString() ?? '0';
    final statusText = isActive ? order['status']?.toString().replaceAll('_', ' ') ?? 'UNKNOWN' : 'AVAILABLE';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isActive ? () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'])),
            ).then((_) => _loadData());
          } : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Ticket Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tag, size: 16, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(orderCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827))),
                      ],
                    ),
                    Text('Fee: UGX $fee', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                ),
                
                // Route Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 2),
                        const Icon(Icons.storefront_rounded, size: 20, color: Color(0xFF6B7280)),
                        Container(width: 2, height: 24, margin: const EdgeInsets.symmetric(vertical: 4), color: const Color(0xFFE5E7EB)),
                        const Icon(Icons.medical_services_outlined, size: 20, color: Color(0xFF2563EB)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pickup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF).withOpacity(0.8))),
                          Text(pharmacyName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 16),
                          Text('Dropoff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF).withOpacity(0.8))),
                          Text(clinicName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),

                if (!isActive) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _acceptPickup(order['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E40AF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Accept Pickup'),
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
