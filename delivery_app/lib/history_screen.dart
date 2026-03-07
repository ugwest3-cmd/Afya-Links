import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'order_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;
  List<dynamic> _deliveries = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMyDeliveries();
      if (res.statusCode == 200) {
        final allDeliveries = jsonDecode(res.body)['deliveries'] as List;
        setState(() {
          _deliveries = allDeliveries.where((d) {
             final s = d['order']?['status'] ?? d['status'];
             return s == 'DELIVERED' || s == 'CANCELLED';
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF312E81);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('JOB ARCHIVE')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: primaryIndigo,
              child: _deliveries.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _deliveries.length,
                      itemBuilder: (context, index) {
                        return _buildHistoryTicket(_deliveries[index], primaryIndigo);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_rounded, size: 60, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          const Text('No completed jobs in your history', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildHistoryTicket(dynamic delivery, Color indigo) {
    final order = delivery['order'];
    if (order == null) return const SizedBox.shrink();

    final status = order['status'] ?? 'UNKNOWN';
    final isDelivered = status == 'DELIVERED';
    final pharmacy = order['pharmacy']?['name'] ?? 'Pharmacy Pool';
    final clinic = order['clinic']?['name'] ?? 'Clinic Delivery';
    final fee = delivery['driver_fee_collected'] ?? 0;
    final id = order['order_code'] ?? 'ORD-#';
    
    DateTime date = delivery['dropoff_time'] != null ? DateTime.parse(delivery['dropoff_time']).toLocal() : DateTime.now();
    String formattedDate = '${date.day}/${date.month}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id']))),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formattedDate, style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDelivered ? const Color(0xFF059669) : Colors.red.shade700).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isDelivered ? 'SUCCESS' : status,
                      style: TextStyle(color: isDelivered ? const Color(0xFF059669) : Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  )
                ],
              ),
              const Divider(height: 28, thickness: 0.5, color: Color(0xFFF1F5F9)),
              Row(
                children: [
                  Column(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF94A3B8)),
                      Container(width: 1, height: 12, margin: const EdgeInsets.symmetric(vertical: 4), color: const Color(0xFFE2E8F0)),
                      const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF312E81)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pharmacy, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)), maxLines: 1),
                        const SizedBox(height: 14),
                        Text(clinic, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)), maxLines: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('EARNED', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      Text('UGX $fee', style: const TextStyle(color: Color(0xFF059669), fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
