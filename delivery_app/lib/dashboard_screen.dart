import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'order_detail_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _deliveries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMyDeliveries();
      if (res.statusCode == 200) {
        setState(() {
          _deliveries = jsonDecode(res.body)['deliveries'];
        });
      }
    } catch (e) {
      debugPrint('Error loading deliveries: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _deliveries.where((d) => d['status'] == 'ASSIGNED' || d['status'] == 'READY_FOR_PICKUP').toList();
    final active = _deliveries.where((d) => d['status'] == 'IN_TRANSIT').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshing...'), duration: Duration(seconds: 1)));
              _loadDeliveries();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDeliveries,
              color: Theme.of(context).colorScheme.primary,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildSectionHeader('Active Deliveries', Icons.local_shipping_rounded, active.length),
                  if (active.isEmpty)
                    _buildEmptyState('No active deliveries right now', Icons.check_circle_outline)
                  else
                    ...active.map((d) => _buildDeliveryTicket(d, const Color(0xFF2563EB))),
                  
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('Pending Pickups', Icons.inventory_2_rounded, pending.length),
                  if (pending.isEmpty)
                    _buildEmptyState('You have no new pickups assigned', Icons.inbox_rounded)
                  else
                    ...pending.map((d) => _buildDeliveryTicket(d, const Color(0xFFF59E0B))),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(icon, size: 32, color: const Color(0xFF9CA3AF)),
          ),
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
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1E40AF), size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827), letterSpacing: -0.3)),
          const Spacer(),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563), fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTicket(dynamic delivery, Color statusColor) {
    final order = delivery['order'];
    final pharmacyName = order != null ? (order['pharmacy']?['name'] ?? 'Unknown Pharmacy') : 'Unknown';
    final clinicName = order != null ? (order['clinic']?['name'] ?? 'Unknown Clinic') : 'Unknown';
    final orderCode = order != null ? (order['id']?.toString().substring(0, 8).toUpperCase() ?? 'NONE') : 'NONE';
    final statusText = delivery['status'].toString().replaceAll('_', ' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(orderId: order['id']),
              ),
            ).then((_) => _loadDeliveries());
          },
          child: Column(
            children: [
              // Ticket Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tag, size: 16, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          orderCode,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827), letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
              
              // Ticket Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route Timeline Indicators
                    Column(
                      children: [
                        const SizedBox(height: 2),
                        const Icon(Icons.storefront_rounded, size: 20, color: Color(0xFF6B7280)),
                        Container(
                          width: 2,
                          height: 24,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: const Color(0xFFE5E7EB),
                        ),
                        const Icon(Icons.medical_services_outlined, size: 20, color: Color(0xFF2563EB)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Route Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF).withOpacity(0.8)),
                          ),
                          Text(
                            pharmacyName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Dropoff',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF).withOpacity(0.8)),
                          ),
                          Text(
                            clinicName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Align(
                      alignment: Alignment.center,
                      child: Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
