import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'screen_tracking.dart';

class DashboardScreen extends StatefulWidget {
  final String clinicName;
  final VoidCallback onNewOrder;

  const DashboardScreen({super.key, required this.clinicName, required this.onNewOrder});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int> _stats = {'pending': 0, 'in_transit': 0, 'delivered': 0, 'rejected': 0};
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
      final ordersRes = await ApiService.getMyOrders();

      if (statsRes.statusCode == 200) {
        _stats = Map<String, int>.from(jsonDecode(statsRes.body)['stats']);
      }
      if (ordersRes.statusCode == 200) {
        _recentOrders = jsonDecode(ordersRes.body)['orders'];
        if (_recentOrders.length > 3) _recentOrders = _recentOrders.sublist(0, 3);
      }
    } catch (e) {
      debugPrint('Error fetching dashboard: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0D47A1);
    const green = Color(0xFF2E7D32);
    const orange = Color(0xFFE65100);
    const red = Color(0xFFC62828);

    if (_loading && _recentOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0D47A1).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome back 👋', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(widget.clinicName,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: widget.onNewOrder,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_circle_rounded, color: Color(0xFF0D47A1), size: 16),
                                SizedBox(width: 6),
                                Text('Place New Order',
                                    style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            const Text('Today\'s Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _StatCard('Pending', _stats['pending'].toString(), Icons.hourglass_top_rounded, orange, () {
                  // Navigate to orders with Pending filter
                  Navigator.pushNamed(context, '/orders', arguments: 'AWAITING_PAYMENT');
                }),
                _StatCard('Active', _stats['in_transit'].toString(), Icons.local_shipping_rounded, primary, () {
                  Navigator.pushNamed(context, '/orders', arguments: 'InTransit');
                }),
                _StatCard('Delivered', _stats['delivered'].toString(), Icons.check_circle_rounded, green, () {
                  Navigator.pushNamed(context, '/orders', arguments: 'Completed');
                }),
                _StatCard('Rejected', _stats['rejected'].toString(), Icons.cancel_rounded, red, () {
                  Navigator.pushNamed(context, '/orders', arguments: 'CANCELLED');
                }),
              ],
            ),
            const SizedBox(height: 24),

            // Tracking Widget (If active orders exist)
            if (_recentOrders.any((o) => ['ASSIGNED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY'].contains(o['status']))) ...[
              const Text('Active Tracking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              ..._recentOrders.where((o) => ['ASSIGNED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY'].contains(o['status'])).map((o) {
                final oIdStr = o['id']?.toString() ?? '';
                final shortId = oIdStr.length > 8 ? oIdStr.substring(0, 8).toUpperCase() : oIdStr;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: primary.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                    border: Border.all(color: primary.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: primary.withOpacity(0.1),
                        child: const Icon(Icons.delivery_dining_rounded, color: primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #$shortId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(o['status']?.toString().replaceAll('_', ' ') ?? '', style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(orderId: oIdStr, orderCode: '#$shortId')));
                        },
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Track'),
                        style: TextButton.styleFrom(foregroundColor: primary),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],

            // Quick Actions Row
            const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionButton(
                  icon: Icons.add_shopping_cart_rounded,
                  label: 'New Order',
                  color: primary,
                  onTap: widget.onNewOrder,
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Confirm Delivery',
                  color: green,
                  onTap: () => _showConfirmDeliveryDialog(context),
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.history_rounded,
                  label: 'Order History',
                  color: orange,
                  onTap: () => Navigator.pushNamed(context, '/orders'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Orders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Orders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/orders'),
                  child: const Text('See all', style: TextStyle(color: Color(0xFF0D47A1), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_recentOrders.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No orders yet', style: TextStyle(color: Colors.grey)))),
            ..._recentOrders.map((o) {
              Color sColor = primary;
              if (o['status'] == 'DELIVERED') sColor = green;
              if (o['status'] == 'PENDING') sColor = orange;
              if (o['status'] == 'REJECTED') sColor = red;

              return _OrderTile(
                id: '#${o['id'].toString().substring(0, 4)}',
                items: (o['items'] as List?)?.map((i) => i['drug_name']).join(', ') ?? 'Medicines',
                status: o['status'].toString(),
                statusColor: sColor,
                time: 'Recently', // Could use a timeago lib here
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showConfirmDeliveryDialog(BuildContext context) {
    final activeOrders = _recentOrders.where((o) => ['ASSIGNED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY'].contains(o['status'])).toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirm Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (activeOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No active orders awaiting delivery', style: TextStyle(color: Colors.grey))),
              )
            else
              ...activeOrders.map((o) {
                final oIdStr = o['id']?.toString() ?? '';
                final shortId = oIdStr.length > 8 ? oIdStr.substring(0, 8).toUpperCase() : oIdStr;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                  title: Text('Order #$shortId'),
                  subtitle: Text(o['items_summary'] ?? 'Medicines'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Open the confirm delivery dialog from screen_orders.dart logic
                    // Actually, we can just navigate to orders and filter for InTransit
                    Navigator.pushNamed(context, '/orders', arguments: 'InTransit');
                  },
                );
              }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
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
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
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
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final String id, items, status, time;
  final Color statusColor;
  const _OrderTile({required this.id, required this.items, required this.status, required this.statusColor, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: statusColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.medication_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(items, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 3),
              Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
