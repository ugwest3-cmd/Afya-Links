import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        _driverName = user['name']?.split(' ')[0] ?? 'Driver';
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final statusRes = await ApiService.checkProfileStatus();
      if (statusRes.statusCode == 200) {
        final profile = jsonDecode(statusRes.body)['data'];
        if (profile != null) _isOnline = profile['is_online'] ?? false;
      }

      final walletRes = await ApiService.getDriverWallet();
      if (walletRes.statusCode == 200) {
        final walletData = jsonDecode(walletRes.body);
        _walletBalance = (walletData['wallet_balance'] ?? 0).toDouble();
        _totalEarned = (walletData['total_earned'] ?? 0).toDouble();
      }

      if (_isOnline) {
        final availableRes = await ApiService.getAvailableDeliveries();
        if (availableRes.statusCode == 200) {
          _availableDeliveries = jsonDecode(availableRes.body)['available_deliveries'] ?? [];
        }
      } else {
        _availableDeliveries = [];
      }

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
        _loadData();
      } else {
        setState(() => _isOnline = !val);
        _showError('Status update failed');
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _isOnline = !val);
      setState(() => _loading = false);
      _showError('Connection error');
    }
  }

  Future<void> _acceptPickup(String orderId) async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.acceptDelivery(orderId);
      if (res.statusCode == 200) {
        _showSuccess('Job Accepted! Proceed to Pharmacy.');
        _loadData();
      } else {
        final msg = jsonDecode(res.body)['message'] ?? 'Failed to accept job';
        _showError(msg);
        _loadData();
      }
    } catch (e) {
      _showError('Network error');
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF312E81),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF312E81);
    const accentCyan = Color(0xFF0891B2);

    final myActiveDeliveries = _myDeliveries.where((d) {
       final s = d['order']?['status'] ?? d['status']; 
       return s == 'ASSIGNED' || s == 'IN_TRANSIT';
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(primaryIndigo),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Premium Header
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: primaryIndigo,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryIndigo, Color(0xFF4338CA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('OPERATIONAL MODE', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(_isOnline ? 'Active & Ready' : 'Currently Offline', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                  const SizedBox(height: 8),
                                  Text('Welcome back, $_driverName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                            _buildOnlineToggle(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Stats Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildMiniStat('Available', 'UGX ${_walletBalance.toInt()}', Icons.wallet_rounded, accentCyan),
                          Container(width: 1, height: 40, color: const Color(0xFFF1F5F9)),
                          _buildMiniStat('Lifetime', 'UGX ${_totalEarned.toInt()}', Icons.auto_graph_rounded, primaryIndigo),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_loading) 
                      const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator(strokeWidth: 3)))
                    else ...[
                      // Active Work
                      _buildHeader('Ongoing Deliveries', myActiveDeliveries.length),
                      if (myActiveDeliveries.isEmpty)
                        _buildEmptyState('No active tasks', Icons.inventory_2_outlined)
                      else
                        ...myActiveDeliveries.map((d) => _buildJobTicket(d, true, primaryIndigo)),

                      const SizedBox(height: 32),

                      // Market Pool
                      _buildHeader('Available Near You', _availableDeliveries.length),
                      if (!_isOnline)
                        _buildEmptyState('Go online to view opportunities', Icons.power_settings_new_rounded)
                      else if (_availableDeliveries.isEmpty)
                        _buildEmptyState('Checking for new jobs...', Icons.location_searching_rounded)
                      else
                        ..._availableDeliveries.map((o) => _buildJobTicket(o, false, accentCyan)),
                      
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: _loading ? null : () => _toggleOnlineStatus(!_isOnline),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        height: 40,
        decoration: BoxDecoration(
          color: _isOnline ? const Color(0xFF0891B2) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: _isOnline ? 42 : 4,
              top: 4,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(
                  _isOnline ? Icons.flash_on_rounded : Icons.power_settings_new_rounded,
                  color: _isOnline ? const Color(0xFF0891B2) : primaryIndigo,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF312E81).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(count.toString(), style: const TextStyle(color: Color(0xFF312E81), fontWeight: FontWeight.w900, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _buildJobTicket(dynamic data, bool isActive, Color themeColor) {
    final order = isActive ? data['order'] : data;
    final pharmacy = order?['pharmacy']?['name'] ?? 'Pharmacy Pool';
    final clinic = order?['clinic']?['name'] ?? 'Clinic Delivery';
    final fee = order?['delivery_fee']?.toString() ?? '0';
    final id = order?['order_code'] ?? 'ORD-#';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: InkWell(
        onTap: isActive ? () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id']))).then((_) => _loadData());
        } : null,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.token_rounded, color: themeColor.withOpacity(0.5), size: 16),
                          const SizedBox(width: 6),
                          Text(id, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B))),
                        ],
                      ),
                      Text('UGX $fee', style: TextStyle(fontWeight: FontWeight.w900, color: themeColor, fontSize: 14)),
                    ],
                  ),
                  const Divider(height: 32, thickness: 0.5, color: Color(0xFFF1F5F9)),
                  Row(
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF94A3B8), size: 14),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          Icon(Icons.location_on_rounded, color: themeColor, size: 14),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pharmacy, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 1),
                            const SizedBox(height: 18),
                            Text(clinic, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), maxLines: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isActive)
              GestureDetector(
                onTap: () => _acceptPickup(order['id']),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: const Center(child: Text('ACCEPT PICKUP REQUEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFE2E8F0), size: 48),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDrawer(Color primaryIndigo) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            color: primaryIndigo,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                Text('$_driverName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const Text('AFYA LINKS COURIER', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _drawerItem(Icons.speed_rounded, 'Operational Hub', () => Navigator.pop(context), true),
          _drawerItem(Icons.account_balance_wallet_rounded, 'My Earnings', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
          }, false),
          _drawerItem(Icons.history_rounded, 'Job History', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
          }, false),
          _drawerItem(Icons.notifications_active_rounded, 'Notifications', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          }, false),
          const Spacer(),
          const Divider(indent: 20, endIndent: 20, color: Color(0xFFF1F5F9)),
          _drawerItem(Icons.logout_rounded, 'Sign Out', () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
          }, false, isDestructive: true),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, bool active, {bool isDestructive = false}) {
    final color = isDestructive ? Colors.red.shade700 : (active ? const Color(0xFF312E81) : const Color(0xFF64748B));
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontWeight: active ? FontWeight.w900 : FontWeight.w600, fontSize: 14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}

const primaryIndigo = Color(0xFF312E81);
