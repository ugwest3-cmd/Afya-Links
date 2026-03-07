import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

class PharmOrdersScreen extends StatefulWidget {
  final String? initialFilter;
  const PharmOrdersScreen({super.key, this.initialFilter});

  @override
  State<PharmOrdersScreen> createState() => _PharmOrdersScreenState();
}

class _PharmOrdersScreenState extends State<PharmOrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  bool _actionLoading = false;
  late String _filter;

  final _filters = ['All', 'PAID', 'ACCEPTED', 'PARTIAL', 'READY_FOR_PICKUP', 'REJECTED'];
  final _filterLabels = {
    'PAID': 'New Orders',
    'ACCEPTED': 'Accepted',
    'PARTIAL': 'Partial',
    'READY_FOR_PICKUP': 'Ready',
    'REJECTED': 'Rejected',
  };

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? 'All';
    _loadOrders();
  }
  
  @override
  void didUpdateWidget(covariant PharmOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter && widget.initialFilter != null) {
      setState(() => _filter = widget.initialFilter!);
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getInboxOrders();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() { 
          _orders = data['orders'] ?? data['data'] ?? []; 
          _loading = false; 
        });
      } else {
        setState(() { _orders = []; _loading = false; });
      }
    } catch (e) {
      setState(() { _orders = []; _loading = false; });
    }
  }

  String _formatCurrency(dynamic val) {
    if (val == null) return 'UGX 0';
    try {
      double d = double.parse(val.toString());
      String s = d.toStringAsFixed(0);
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      s = s.replaceAllMapped(reg, (Match m) => '${m[1]},');
      return 'UGX $s';
    } catch (_) {
      return 'UGX $val';
    }
  }

  List<dynamic> get _filtered => _filter == 'All' ? _orders : _orders.where((o) => o['status'] == _filter).toList();

  Color _statusColor(String s) {
    switch (s) {
      case 'PAID': return Colors.orange;
      case 'ACCEPTED': return Colors.blue;
      case 'READY_FOR_PICKUP': return const Color(0xFF1B5E20);
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // Filter Strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final isActive = f == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      f == 'All' ? 'All Orders' : (_filterLabels[f] ?? f),
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Orders List
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: primary))
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  color: primary,
                  child: _filtered.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No orders found for this category',
                                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final o = _filtered[i];
                            return _OrderCard(
                              order: o,
                              statusColor: _statusColor(o['status']),
                              statusLabel: _filterLabels[o['status']] ?? o['status'],
                              onRespond: () => _showRespondSheet(context, o),
                              onMarkReady: () => _markReady(context, o['id']),
                              actionLoading: _actionLoading,
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  void _showRespondSheet(BuildContext context, Map<String, dynamic> order) {
    if (order['status'] != 'PAID') return;
    final rejectCtrl = TextEditingController();
    String? action;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, 
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                Text('Order Response', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Managing ${(order['display_id'] ?? order['id']).toString().toUpperCase()}', 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 24),

                Row(
                  children: [
                    _ActionBtn(label: 'Accept', color: const Color(0xFF2E7D32), icon: Icons.check_circle_rounded, 
                      selected: action == 'ACCEPTED', onTap: () => setSheetState(() => action = 'ACCEPTED')),
                    const SizedBox(width: 12),
                    _ActionBtn(label: 'Partial', color: Colors.blue, icon: Icons.remove_circle_rounded, 
                      selected: action == 'PARTIAL', onTap: () => setSheetState(() => action = 'PARTIAL')),
                    const SizedBox(width: 12),
                    _ActionBtn(label: 'Reject', color: Colors.red, icon: Icons.cancel_rounded, 
                      selected: action == 'REJECTED', onTap: () => setSheetState(() => action = 'REJECTED')),
                  ],
                ),

                if (action == 'REJECTED') ...[
                  const SizedBox(height: 24),
                  TextField(
                    controller: rejectCtrl,
                    decoration: InputDecoration(
                      labelText: 'Rejection Reason',
                      prefixIcon: const Icon(Icons.info_outline),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: action == null ? null : () async {
                      Navigator.pop(ctx);
                      final res = await ApiService.respondToOrder(
                        order['id'],
                        action!,
                        rejectedReason: action == 'REJECTED' ? rejectCtrl.text : null,
                      );
                      _loadOrders();
                    },
                    child: Text('Confirm Application', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markReady(BuildContext context, String orderId) async {
    setState(() => _actionLoading = true);
    try {
      final res = await ApiService.markOrderReady(orderId);
      if (res.statusCode == 200) _loadOrders();
    } finally {
      setState(() => _actionLoading = false);
    }
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onRespond, onMarkReady;
  final bool actionLoading;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.statusLabel,
    required this.onRespond,
    required this.onMarkReady,
    required this.actionLoading,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Color(0xFF1B5E20);
    final status = order['status'] as String;
    final items = order['items'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${(order['display_id'] ?? order['id']).toString().toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(order['clinic'] ?? 'Partner Clinic', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                ...items.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.medication_rounded, size: 14, color: primary),
                      const SizedBox(width: 8),
                      Text('${i['drug_name']} × ${i['quantity']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net Earnings', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(order['pharmacy_net'] ?? 0),
                          style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    if (order['order_code'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          order['order_code'],
                          style: TextStyle(color: primary, fontWeight: FontWeight.black, fontSize: 16, letterSpacing: 2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (status == 'PAID' || (status == 'ACCEPTED' && order['order_code'] != null))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton(
                onPressed: status == 'PAID' ? onRespond : (actionLoading ? null : onMarkReady),
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'PAID' ? Colors.orange : primary,
                ),
                child: Text(
                  status == 'PAID' ? 'Review & Respond' : (actionLoading ? 'Updating...' : 'Ready for Dispatch'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic val) {
    if (val == null) return 'UGX 0';
    try {
      double d = double.parse(val.toString());
      String s = d.toStringAsFixed(0);
      RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      s = s.replaceAllMapped(reg, (Match m) => '${m[1]},');
      return 'UGX $s';
    } catch (_) {
      return 'UGX $val';
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.icon, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: selected ? 0 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
