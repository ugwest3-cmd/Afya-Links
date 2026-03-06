import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'payment_webview_sheet.dart';
import 'api_service.dart';
import 'screen_tracking.dart';

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

  // All statuses that belong to each filter tab
  static const _processingStatuses  = ['PAID', 'ACCEPTED', 'PARTIAL', 'READY_FOR_PICKUP'];
  static const _inTransitStatuses   = ['ASSIGNED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY'];
  static const _completedStatuses   = ['DELIVERED', 'COMPLETED', 'DELIVERY_CONFIRMED'];

  final _filters = ['All', 'AWAITING_PAYMENT', 'Processing', 'InTransit', 'Completed', 'CANCELLED'];
  final _filterLabels = {
    'AWAITING_PAYMENT': 'To Pay',
    'Processing':       'Processing',
    'InTransit':        'In Transit',
    'Completed':        'Completed',
    'CANCELLED':        'Cancelled',
  };


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
        debugPrint('[Orders] API error ${res.statusCode}: ${res.body}');
        setState(() { _orders = []; _loading = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders (${res.statusCode})'), backgroundColor: _red));
      }
    } catch (e) {
      debugPrint('[Orders] Exception: $e');
      setState(() { _orders = []; _loading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error loading orders'), backgroundColor: Colors.grey));
    }
  }


  List<dynamic> get _filteredOrders {
    if (_filter == 'All') return _orders;
    if (_filter == 'Processing') return _orders.where((o) => _processingStatuses.contains(o['status'] ?? '')).toList();
    if (_filter == 'InTransit')  return _orders.where((o) => _inTransitStatuses.contains(o['status'] ?? '')).toList();
    if (_filter == 'Completed')  return _orders.where((o) => _completedStatuses.contains(o['status'] ?? '')).toList();
    return _orders.where((o) => (o['status'] ?? '') == _filter).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
      case 'AWAITING_PAYMENT': return _orange;
      case 'PAID':
      case 'READY_FOR_PICKUP':
      case 'IN_TRANSIT': 
      case 'OUT_FOR_DELIVERY': return _primary;
      case 'DELIVERED': 
      case 'COMPLETED': return _green;
      case 'CANCELLED': return _red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    return _filterLabels[status] ?? status;
  }

  void _handleConfirmDeliveryRequest(String orderId) {
    _showConfirmDeliveryDialog(context, orderId);
  }

  Future<void> _handlePayNow(String orderId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final res = await ApiService.initiatePayment(orderId);
      if (mounted) Navigator.pop(context);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final url = data['redirect_url'];
        if (mounted) {
          // WebView now auto-closes when callback URL is detected and returns tracking ID
          await PaymentWebViewSheet.show(context, url, orderId, title: 'Order Payment');
        }
        // Poll for order status update (up to 30 seconds / 10 tries every 3s)
        await _pollForPaymentConfirmation(orderId);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: ${jsonDecode(res.body)['message']}'), backgroundColor: _red));
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error. Check connection.'), backgroundColor: _red));
    }
  }

  Future<void> _pollForPaymentConfirmation(String orderId) async {
    if (!mounted) return;
    // Show polling indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Verifying payment...'),
        ]),
      ),
    );

    bool confirmed = false;
    for (int attempt = 0; attempt < 10; attempt++) {
      await Future.delayed(const Duration(seconds: 3));
      try {
        final statusRes = await ApiService.getOrderStatus(orderId);
        if (statusRes.statusCode == 200) {
          final body = jsonDecode(statusRes.body);
          final status = body['status'] ?? body['data']?['status'] ?? '';
          if (status != 'AWAITING_PAYMENT') {
            confirmed = true;
            break;
          }
        }
      } catch (_) {}
    }

    if (mounted) Navigator.pop(context); // close dialog
    _loadOrders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(confirmed ? '✅ Payment confirmed! Order is now processing.' : 'Payment submitted. Your order list has been refreshed.'),
        backgroundColor: confirmed ? _green : _orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _showConfirmDeliveryDialog(BuildContext context, String orderId) {
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
                  decoration: InputDecoration(
                    labelText: 'Enter Order Code from Pharmacy',
                    hintText: 'Code written on receipt/parcel',
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
                            // Build short display ID from UUID (backend doesn't send display_id)
                            final rawId = o['id']?.toString() ?? '';
                            final id = o['display_id'] ?? (rawId.length >= 8 ? '#${rawId.substring(0, 8).toUpperCase()}' : '#${i + 1}');
                            // Build items summary string from the list returned by backend
                            final itemsList = o['items'] as List?;
                            final itemsSummary = itemsList != null && itemsList.isNotEmpty
                                ? itemsList.map((it) => '${it['drug_name'] ?? ''} × ${it['quantity'] ?? ''}').join(', ')
                                : (o['items_summary'] ?? '');
                            // Date: backend sends 'created_at', not 'date'
                            final rawDate = o['created_at']?.toString() ?? o['date']?.toString() ?? '';
                            String displayDate = rawDate;
                            if (rawDate.length >= 10) displayDate = rawDate.substring(0, 10);
                            // Pharmacy name from joined object
                            final pharmObj = o['pharmacy'];
                            final pharmName = pharmObj is Map ? pharmObj['name'] ?? '' : '';
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
                                    if (pharmName.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(children: [
                                          const Icon(Icons.local_pharmacy_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(pharmName, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        ]),
                                      ),
                                    Text(itemsSummary, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(displayDate, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    if (status == 'AWAITING_PAYMENT') ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.payments_outlined, size: 16, color: Colors.white),
                                          label: const Text('Pay via Pesapal', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _orange,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          onPressed: () => _handlePayNow(o['id'] ?? ''),
                                        ),
                                      ),
                                    ],
                                    if (status == 'OUT_FOR_DELIVERY' || status == 'IN_TRANSIT' || status == 'READY_FOR_PICKUP' || status == 'ASSIGNED') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.location_on_outlined, size: 16, color: Colors.white),
                                              label: const Text('Track', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _primary,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                elevation: 0,
                                              ),
                                              onPressed: () {
                                                Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(orderId: o['id'] ?? '', orderCode: id)));
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 2,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                                              label: const Text('Confirm & Release', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _green,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                elevation: 0,
                                              ),
                                              onPressed: () => _handleConfirmDeliveryRequest(o['id'] ?? ''),
                                            ),
                                          ),
                                        ],
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
