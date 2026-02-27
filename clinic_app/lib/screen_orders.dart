import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String _filter = 'All';

  static const _primary = Color(0xFF0D47A1);
  static const _green = Color(0xFF2E7D32);
  static const _orange = Color(0xFFE65100);
  static const _red = Color(0xFFC62828);

  final _filters = ['All', 'PENDING', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'];
  final _filterLabels = {'PENDING': 'Pending', 'IN_TRANSIT': 'In Transit', 'DELIVERED': 'Delivered', 'CANCELLED': 'Cancelled'};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMyOrders();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _orders = data['data'] ?? data['orders'] ?? [];
          _loading = false;
        });
      } else {
        setState(() { _orders = _mockOrders; _loading = false; });
      }
    } catch (_) {
      setState(() { _orders = _mockOrders; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _mockOrders => [
    {'id': 'ord-1045', 'display_id': '#1045', 'items': 'Amoxicillin 500mg × 20', 'status': 'IN_TRANSIT', 'date': 'Feb 27, 2026', 'urgent': true},
    {'id': 'ord-1044', 'display_id': '#1044', 'items': 'Paracetamol 1g × 50', 'status': 'DELIVERED', 'date': 'Feb 27, 2026', 'urgent': false},
    {'id': 'ord-1043', 'display_id': '#1043', 'items': 'Metformin 500mg × 30', 'status': 'DELIVERED', 'date': 'Feb 26, 2026', 'urgent': false},
    {'id': 'ord-1042', 'display_id': '#1042', 'items': 'ORS Sachets × 100', 'status': 'PENDING', 'date': 'Feb 26, 2026', 'urgent': true},
    {'id': 'ord-1041', 'display_id': '#1041', 'items': 'IV Drip × 5', 'status': 'CANCELLED', 'date': 'Feb 25, 2026', 'urgent': false},
  ];

  List<dynamic> get _filteredOrders => _filter == 'All'
      ? _orders
      : _orders.where((o) => (o['status'] ?? '') == _filter).toList();

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING': return _orange;
      case 'IN_TRANSIT': return _primary;
      case 'DELIVERED': return _green;
      case 'CANCELLED': return _red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    return _filterLabels[status] ?? status;
  }

  void _showConfirmDelivery(BuildContext context, String orderId) {
    final codeCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20, left: 120),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                const Text('Confirm Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Order $orderId', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Enter Order Code',
                    hintText: 'e.g. ABC123',
                    prefixIcon: const Icon(Icons.qr_code_rounded, color: _green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _green, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: submitting ? null : () async {
                      if (codeCtrl.text.isEmpty) return;
                      setSheetState(() => submitting = true);
                      try {
                        final res = await ApiService.confirmDelivery(orderId, codeCtrl.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadOrders();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(res.statusCode == 200 ? '✓ Delivery confirmed!' : 'Failed: ${jsonDecode(res.body)['message']}'),
                            backgroundColor: res.statusCode == 200 ? _green : _red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ));
                        }
                      } catch (_) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Network error. Check connection.'),
                            backgroundColor: _red,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    },
                    child: submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final label = f == 'All' ? 'All' : (_filterLabels[f] ?? f);
                final isActive = _filter == f;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive ? _primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadOrders,
                  child: _filteredOrders.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          Center(child: Column(children: [
                            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No orders found', style: TextStyle(color: Colors.grey, fontSize: 15)),
                          ])),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, i) {
                            final o = _filteredOrders[i];
                            final status = o['status'] ?? 'PENDING';
                            final color = _statusColor(status);
                            final id = o['display_id'] ?? o['id'] ?? '#${i + 1}';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(children: [
                                          Text(id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          if (o['urgent'] == true) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                              child: const Text('URGENT', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                          ]
                                        ]),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                          child: Text(_statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(o['items'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(o['date'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    if (status == 'IN_TRANSIT') ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                                          label: const Text('Confirm Delivery', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _green,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          onPressed: () => _showConfirmDelivery(context, o['id'] ?? ''),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
