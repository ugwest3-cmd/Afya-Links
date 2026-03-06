import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'order_detail_screen.dart';

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
    // Filter deliveries
    final pending = _deliveries.where((d) => d['status'] == 'ASSIGNED' || d['status'] == 'READY_FOR_PICKUP').toList();
    final active = _deliveries.where((d) => d['status'] == 'IN_TRANSIT').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliveries,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDeliveries,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                   _buildSectionHeader('Active Deliveries', Icons.local_shipping),
                  if (active.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No active deliveries', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...active.map((d) => _buildDeliveryCard(d, Colors.blue)),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Pending Pickups', Icons.inventory),
                  if (pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No pending pickups', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...pending.map((d) => _buildDeliveryCard(d, Colors.orange)),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0D47A1), size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(dynamic delivery, Color color) {
    final order = delivery['order'];
    final pharmacyName = order != null ? (order['pharmacy']?['name'] ?? 'Unknown Pharmacy') : 'Unknown';
    final clinicName = order != null ? (order['clinic']?['name'] ?? 'Unknown Clinic') : 'Unknown';
    final orderCode = order != null ? (order['id']?.toString().substring(0, 8) ?? '---') : '---';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Order #$orderCode', style: const TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                delivery['status'],
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.store, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(pharmacyName),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.local_hospital, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(clinicName),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: order['id']),
            ),
          ).then((_) => _loadDeliveries());
        },
      ),
    );
  }
}
