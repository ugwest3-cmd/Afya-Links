import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class PharmDashboardScreen extends StatefulWidget {
  final String pharmacyName;
  final Function(String?) onViewOrders;

  const PharmDashboardScreen({super.key, required this.pharmacyName, required this.onViewOrders});

  @override
  State<PharmDashboardScreen> createState() => _PharmDashboardScreenState();
}

class _PharmDashboardScreenState extends State<PharmDashboardScreen> {
  Map<String, dynamic> _stats = {'new': 0, 'accepted': 0, 'ready_transit': 0, 'completed': 0, 'total_earnings': 0, 'pending_balance': 0};
  List<dynamic> _recentOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final statsRes = await ApiService.getDashboardStats();
      final ordersRes = await ApiService.getInboxOrders();

      if (statsRes.statusCode == 200) {
        _stats = Map<String, dynamic>.from(jsonDecode(statsRes.body)['stats'] ?? {});
      }
      if (ordersRes.statusCode == 200) {
        _recentOrders = jsonDecode(ordersRes.body)['orders'] ?? [];
        if (_recentOrders.length > 5) _recentOrders = _recentOrders.sublist(0, 5);
      }
    } catch (e) {
      debugPrint('Error fetching dashboard: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_loading && _recentOrders.isEmpty) {
      return Center(child: CircularProgressIndicator(color: primary));
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Welcome Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, const Color(0xFF388E3C)],
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome back,', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          widget.pharmacyName,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => widget.onViewOrders(null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mark_email_unread_rounded, color: primary, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Orders Inbox',
                                  style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 40),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Interactive Stats Section
            _buildSectionHeader('Operations Overview'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _StatCard('Incoming', _stats['new'].toString(), Icons.notifications_active_rounded, Colors.orange, 
                    () => widget.onViewOrders('PAID')),
                _StatCard('Processing', _stats['accepted'].toString(), Icons.pending_actions_rounded, Colors.blue, 
                    () => widget.onViewOrders('ACCEPTED')),
                _StatCard('In Transit', _stats['ready_transit'].toString(), Icons.local_shipping_rounded, primary, 
                    () => widget.onViewOrders('READY_FOR_PICKUP')),
                _StatCard('Completed', _stats['completed'].toString(), Icons.check_circle_rounded, const Color(0xFF2E7D32), 
                    () => widget.onViewOrders('COMPLETED')),
              ],
            ),
            const SizedBox(height: 28),

            // Quick Access
            _buildSectionHeader('Quick Access'),
            const SizedBox(height: 12),
            Row(children: [
              _ActionButton(
                icon: Icons.upload_file_rounded,
                label: 'Stock CSV',
                color: primary,
                onTap: () => Navigator.pushNamed(context, '/pricelist'),
              ),
              const SizedBox(width: 12),
              _ActionButton(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Wallet',
                color: Colors.blueGrey,
                onTap: () => widget.onViewOrders('WALLET'),
              ),
              const SizedBox(width: 12),
              _ActionButton(
                icon: Icons.history_rounded,
                label: 'Logs',
                color: Colors.grey,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmInvoicesScreen())),
              ),
            ]),
            const SizedBox(height: 28),

            // Recent Orders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Recent Orders'),
                TextButton(
                  onPressed: () => widget.onViewOrders(null),
                  child: Text('View All', style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_recentOrders.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, color: Colors.grey, size: 48),
                      SizedBox(height: 12),
                      Text('No recent orders found', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ..._recentOrders.map((o) {
              return _OrderTile(
                id: '#${(o['display_id'] ?? o['id']).toString().toUpperCase()}',
                items: (o['items'] as List?)?.map((i) => i['drug_name']).join(', ') ?? 'Medicines',
                status: o['status'].toString(),
                time: o['created_at'] != null ? 'Recently' : '',
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.2),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StatCard(this.label, this.value, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final String id, items, status, time;
  const _OrderTile({required this.id, required this.items, required this.status, required this.time});
  Color get _color {
    switch (status) {
      case 'PAID': return Colors.orange;
      case 'ACCEPTED': return Colors.blue;
      case 'READY_FOR_PICKUP': return const Color(0xFF1B5E20);
      case 'COMPLETED': return const Color(0xFF2E7D32);
      default: return Colors.grey;
    }
  }
  String get _label {
    switch (status) {
      case 'READY_FOR_PICKUP': return 'Ready for Pickup';
      default: return status[0] + status.substring(1).toLowerCase();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.receipt_long_rounded, color: _color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(items, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(_label, style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ]),
      ]),
    );
  }
}
