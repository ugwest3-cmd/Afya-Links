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
          // Filter to only delivered or cancelled
          _deliveries = allDeliveries.where((d) {
             final status = d['order']?['status'] ?? d['status'];
             return status == 'DELIVERED' || status == 'CANCELLED';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Delivery History'),
        backgroundColor: const Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: _deliveries.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _deliveries.length,
                      itemBuilder: (context, index) {
                        return _buildHistoryCard(_deliveries[index]);
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
          Icon(Icons.receipt_long_rounded, size: 60, color: const Color(0xFF9CA3AF).withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No completed deliveries yet', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(dynamic delivery) {
    final order = delivery['order'];
    if (order == null) return const SizedBox.shrink();

    final status = order['status'] ?? 'UNKNOWN';
    final isDelivered = status == 'DELIVERED';
    
    final pharmacyName = order['pharmacy']?['name'] ?? order['pharmacy']?['business_name'] ?? 'Pharmacy';
    final clinicName = order['clinic']?['name'] ?? order['clinic']?['business_name'] ?? 'Clinic';
    final fee = delivery['driver_fee_collected'] ?? 0;
    
    // Format Date
    String dateStr = '';
    if (delivery['dropoff_time'] != null) {
       try {
         final d = DateTime.parse(delivery['dropoff_time']).toLocal();
         dateStr = '${d.day}/${d.month}/${d.year}';
       } catch (e) {}
    }

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
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'])));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w600)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDelivered ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isDelivered ? 'COMPLETED' : status,
                        style: TextStyle(
                          color: isDelivered ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(pharmacyName, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF111827)), maxLines: 1)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(clinicName, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF111827)), maxLines: 1)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Earned', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                    Text('UGX ${fee.toInt()}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
