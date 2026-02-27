import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class PharmOrdersScreen extends StatefulWidget {
  const PharmOrdersScreen({super.key});

  @override
  State<PharmOrdersScreen> createState() => _PharmOrdersScreenState();
}

class _PharmOrdersScreenState extends State<PharmOrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String _filter = 'All';

  static const _primary = Color(0xFF1B5E20);
  static const _green = Color(0xFF2E7D32);
  static const _orange = Color(0xFFE65100);
  static const _blue = Color(0xFF0D47A1);
  static const _red = Color(0xFFC62828);

  final _filters = ['All', 'PENDING', 'ACCEPTED', 'PARTIAL', 'READY_FOR_PICKUP', 'REJECTED'];
  final _filterLabels = {
    'PENDING': 'Pending',
    'ACCEPTED': 'Accepted',
    'PARTIAL': 'Partial',
    'READY_FOR_PICKUP': 'Ready',
    'REJECTED': 'Rejected',
  };

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getInboxOrders();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() { _orders = data['data'] ?? data['orders'] ?? []; _loading = false; });
      } else {
        setState(() { _orders = _mockOrders; _loading = false; });
      }
    } catch (_) {
      setState(() { _orders = _mockOrders; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _mockOrders => [
    {'id': 'ord-1045', 'display_id': '#1045', 'clinic': 'St. Luke\'s Clinic', 'items': [
      {'drug_name': 'Amoxicillin 500mg', 'quantity': 20},
      {'drug_name': 'Paracetamol 1g', 'quantity': 10},
    ], 'status': 'PENDING', 'created_at': '5 min ago', 'urgent': true, 'delivery_address': 'Kampala Road, KLA'},
    {'id': 'ord-1044', 'display_id': '#1044', 'clinic': 'Hope Health Centre', 'items': [
      {'drug_name': 'Paracetamol 1g', 'quantity': 50},
    ], 'status': 'ACCEPTED', 'created_at': '1 hr ago', 'urgent': false, 'order_code': 'HX7K2P'},
    {'id': 'ord-1043', 'display_id': '#1043', 'clinic': 'Grace Clinic', 'items': [
      {'drug_name': 'Metformin 500mg', 'quantity': 30},
    ], 'status': 'READY_FOR_PICKUP', 'created_at': '2 hrs ago', 'urgent': false, 'order_code': 'AB3MN9'},
    {'id': 'ord-1042', 'display_id': '#1042', 'clinic': 'Sunrise Dispensary', 'items': [
      {'drug_name': 'ORS Sachets', 'quantity': 100},
    ], 'status': 'REJECTED', 'created_at': '3 hrs ago', 'urgent': false},
  ];

  List<dynamic> get _filtered => _filter == 'All' ? _orders : _orders.where((o) => o['status'] == _filter).toList();

  Color _statusColor(String s) {
    switch (s) {
      case 'PENDING': return _orange;
      case 'ACCEPTED': return _green;
      case 'PARTIAL': return _blue;
      case 'READY_FOR_PICKUP': return _primary;
      case 'REJECTED': return _red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String s) => _filterLabels[s] ?? s;

  void _showRespondSheet(BuildContext context, Map<String, dynamic> order) {
    if (order['status'] != 'PENDING') return;
    final rejectCtrl = TextEditingController();
    String? _action;

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
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16, left: 130),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                Text('Respond to ${order['display_id'] ?? order['id']}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text('From: ${order['clinic'] ?? "Clinic"}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                // Items summary
                ...((order['items'] as List? ?? []).map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        const Icon(Icons.medication_rounded, size: 14, color: _primary),
                        const SizedBox(width: 6),
                        Text('${item['drug_name']} × ${item['quantity']}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ]),
                    ))),
                const SizedBox(height: 20),
                Row(children: [
                  _ResponseBtn('Accept', _green, Icons.check_circle_rounded, _action == 'ACCEPTED',
                      () => setSheetState(() => _action = 'ACCEPTED')),
                  const SizedBox(width: 8),
                  _ResponseBtn('Partial', _blue, Icons.remove_circle_rounded, _action == 'PARTIAL',
                      () => setSheetState(() => _action = 'PARTIAL')),
                  const SizedBox(width: 8),
                  _ResponseBtn('Reject', _red, Icons.cancel_rounded, _action == 'REJECTED',
                      () => setSheetState(() => _action = 'REJECTED')),
                ]),
                if (_action == 'REJECTED') ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: rejectCtrl,
                    decoration: InputDecoration(
                      labelText: 'Reason for rejection',
                      prefixIcon: const Icon(Icons.info_outline, color: _red),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _action == null ? Colors.grey.shade300 : (_action == 'REJECTED' ? _red : _green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _action == null ? null : () async {
                      Navigator.pop(ctx);
                      final res = await ApiService.respondToOrder(
                        order['id'],
                        _action!,
                        rejectedReason: _action == 'REJECTED' ? rejectCtrl.text : null,
                      );
                      _loadOrders();
                      if (context.mounted) {
                        final body = jsonDecode(res.body);
                        final ok = res.statusCode == 200;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok
                              ? '${_statusLabel(_action!)} · Order Code: ${body['order_code'] ?? '-'}'
                              : body['message'] ?? 'Error'),
                          backgroundColor: ok ? _green : _red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    },
                    child: Text(
                      _action == null ? 'Select an action above' : 'Confirm — $_action',
                      style: TextStyle(color: _action == null ? Colors.grey : Colors.white, fontWeight: FontWeight.bold),
                    ),
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
        // Filter strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _filters.map((f) {
              final isActive = f == _filter;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? _primary : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(f == 'All' ? 'All' : (_filterLabels[f] ?? f),
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.w600, fontSize: 12,
                      )),
                ),
              );
            }).toList()),
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : RefreshIndicator(
                  color: _primary,
                  onRefresh: _loadOrders,
                  child: _filtered.isEmpty
                      ? ListView(children: const [SizedBox(height: 80),
                          Center(child: Column(children: [
                            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No orders here', style: TextStyle(color: Colors.grey, fontSize: 15)),
                          ]))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final o = _filtered[i] as Map<String, dynamic>;
                            final status = o['status'] as String? ?? 'PENDING';
                            final color = _statusColor(status);
                            final id = o['display_id'] ?? o['id'] ?? '#${i + 1}';
                            final items = o['items'] as List? ?? [];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: status == 'PENDING' ? Border.all(color: _orange.withOpacity(0.4), width: 1.5) : null,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Row(children: [
                                      Text(id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      if (o['urgent'] == true) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                          child: const Text('URGENT', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ]),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                      child: Text(_statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  // From
                                  Row(children: [
                                    const Icon(Icons.local_hospital_outlined, size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(o['clinic'] ?? 'Clinic', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ]),
                                  const SizedBox(height: 8),
                                  // Drug items
                                  ...items.map((item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Row(children: [
                                          const Icon(Icons.medication_rounded, size: 14, color: _primary),
                                          const SizedBox(width: 6),
                                          Text('${item['drug_name']} × ${item['quantity']}',
                                              style: const TextStyle(fontSize: 13)),
                                        ]),
                                      )),
                                  const SizedBox(height: 6),
                                  Text(o['created_at'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),

                                  // Order code if available
                                  if (o['order_code'] != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                      child: Row(children: [
                                        const Icon(Icons.qr_code_rounded, color: _primary, size: 16),
                                        const SizedBox(width: 8),
                                        Text('Order Code: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        Text(o['order_code'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary, letterSpacing: 2)),
                                      ]),
                                    ),
                                  ],

                                  // Action button for PENDING
                                  if (status == 'PENDING') ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.touch_app_rounded, size: 16, color: Colors.white),
                                        label: const Text('Respond to Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _orange,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        onPressed: () => _showRespondSheet(context, o),
                                      ),
                                    ),
                                  ],
                                ]),
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

class _ResponseBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ResponseBtn(this.label, this.color, this.icon, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: selected ? 0 : 1),
          ),
          child: Column(children: [
            Icon(icon, color: selected ? Colors.white : color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
