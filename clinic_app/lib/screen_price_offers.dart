import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';

// ─── Step 3: Price Offers + Confirm Order ─────────────────────────────────────

class PriceOffersScreen extends StatefulWidget {
  final List<Map<String, dynamic>> drugs;
  final List<String> pharmacyIds;
  final List<Map<String, dynamic>> pharmacies;
  final String deliveryAddress;

  const PriceOffersScreen({
    super.key,
    required this.drugs,
    required this.pharmacyIds,
    required this.pharmacies,
    required this.deliveryAddress,
  });

  @override
  State<PriceOffersScreen> createState() => _PriceOffersScreenState();
}

class _PriceOffersScreenState extends State<PriceOffersScreen> {
  bool _loading = true;
  Map<String, List<Map<String, dynamic>>> _offersByPharmacy = {};
  String? _selectedPharmacyId;
  bool _submitting = false;
  late Timer _ttlTimer;
  int _ttlSecondsLeft = 900; // 15 minutes like system rules

  static const _primary = Color(0xFF0D47A1);
  static const _green = Color(0xFF2E7D32);
  static const _orange = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _fetchOffers();
    _ttlTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_ttlSecondsLeft > 0) {
        setState(() => _ttlSecondsLeft--);
      } else {
        _ttlTimer.cancel();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _ttlTimer.cancel();
    super.dispose();
  }

  Future<void> _fetchOffers() async {
    final drugNames = widget.drugs.map((d) => d['drug_name'] as String).toList();
    try {
      final res = await ApiService.getPriceOffers(drugNames: drugNames, pharmacyIds: widget.pharmacyIds);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _offersByPharmacy = Map<String, List<Map<String, dynamic>>>.from(
            (data['data'] as Map).map((k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v))),
          );
          _loading = false;
        });
      } else {
        // Mock offers for demo
        setState(() { _offersByPharmacy = _mockOffers; _loading = false; });
      }
    } catch (_) {
      setState(() { _offersByPharmacy = _mockOffers; _loading = false; });
    }
  }

  Map<String, List<Map<String, dynamic>>> get _mockOffers {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final id in widget.pharmacyIds) {
      final pharmacy = widget.pharmacies.firstWhere((p) => p['id'] == id, orElse: () => {'name': 'Pharmacy'});
      result[id] = widget.drugs.map((d) => {
        'drug_name': d['drug_name'],
        'price': (id.contains('002') ? 4800.0 : 5500.0),
        'stock_qty': id.contains('002') ? 120 : 45,
        'brand': 'Generic',
        'strength': '',
        'pharmacy_name': pharmacy['name'],
      }).toList();
    }
    return result;
  }

  double _totalForPharmacy(String pharmacyId) {
    final items = _offersByPharmacy[pharmacyId] ?? [];
    double total = 0;
    for (int i = 0; i < items.length; i++) {
      final qty = i < widget.drugs.length ? (widget.drugs[i]['quantity'] as int? ?? 1) : 1;
      total += (items[i]['price'] as num).toDouble() * qty;
    }
    return total;
  }

  Future<void> _placeOrder() async {
    if (_selectedPharmacyId == null) return;
    setState(() => _submitting = true);

    final items = _offersByPharmacy[_selectedPharmacyId!] ?? [];
    final orderItems = widget.drugs.asMap().entries.map((e) {
      final offer = e.key < items.length ? items[e.key] : {};
      return {
        'drug_name': e.value['drug_name'],
        'quantity': e.value['quantity'],
        'price_agreed': (offer['price'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();

    try {
      final res = await ApiService.createOrder(
        pharmacyId: _selectedPharmacyId!,
        items: orderItems,
        deliveryAddress: widget.deliveryAddress,
      );
      final body = jsonDecode(res.body);
      final success = res.statusCode == 201;

      if (mounted) {
        _ttlTimer.cancel();
        if (success) {
          Navigator.pop(context); // go back to New Order
          Navigator.pop(context); // stay on main shell
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Order placed! ID: ${body['order_id'] ?? ''}')),
            ]),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${body['message'] ?? 'Could not place order'}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Network error. Is the server running?'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  String get _ttlDisplay {
    final m = _ttlSecondsLeft ~/ 60;
    final s = _ttlSecondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: _primary,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price Offers', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            Text('Step 3 of 3 — Select best offer', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // TTL countdown
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _ttlSecondsLeft < 120 ? Colors.red.shade800 : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(_ttlDisplay, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _primary),
                SizedBox(height: 12),
                Text('Fetching pharmacy prices...', style: TextStyle(color: Colors.grey)),
              ],
            ))
          : Column(
              children: [
                // Order summary strip
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Order:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: widget.drugs.map((d) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(8)),
                          child: Text('${d['drug_name']} ×${d['quantity']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _primary)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      ...widget.pharmacies.map((pharmacy) {
                        final pid = pharmacy['id'] as String;
                        final offers = _offersByPharmacy[pid] ?? [];
                        final isSelected = _selectedPharmacyId == pid;
                        final total = _totalForPharmacy(pid);

                        if (offers.isEmpty) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                            child: Row(children: [
                              const Icon(Icons.local_pharmacy_outlined, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(pharmacy['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Text('No price list available', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ])),
                            ]),
                          );
                        }

                        return GestureDetector(
                          onTap: () => setState(() => _selectedPharmacyId = isSelected ? null : pid),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? _primary : Colors.transparent, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
                            ),
                            child: Column(
                              children: [
                                // Pharmacy header
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _primary : const Color(0xFFF5F7FF),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                  ),
                                  child: Row(children: [
                                    Icon(isSelected ? Icons.check_circle_rounded : Icons.local_pharmacy_rounded,
                                        color: isSelected ? Colors.white : _primary, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(pharmacy['name'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : Colors.black87,
                                          )),
                                      Text(pharmacy['address'] ?? '',
                                          style: TextStyle(fontSize: 11, color: isSelected ? Colors.white70 : Colors.grey)),
                                    ])),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white.withOpacity(0.2) : _primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('UGX ${total.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : _primary,
                                            fontSize: 12,
                                          )),
                                    ),
                                  ]),
                                ),
                                // Drug items with prices
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: offers.asMap().entries.map((e) {
                                      final offer = e.value;
                                      final qty = e.key < widget.drugs.length ? (widget.drugs[e.key]['quantity'] as int? ?? 1) : 1;
                                      final price = (offer['price'] as num).toDouble();
                                      final stockQty = offer['stock_qty'] as int?;
                                      final inStock = stockQty == null || stockQty > 0;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(children: [
                                          Container(
                                            width: 28, height: 28,
                                            decoration: BoxDecoration(
                                              color: inStock ? _green.withOpacity(0.1) : _orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(inStock ? Icons.check : Icons.warning_amber,
                                                color: inStock ? _green : _orange, size: 14),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(offer['drug_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                            Text(
                                              inStock ? 'In Stock (${stockQty ?? "?"} units)' : 'Low/Unknown Stock',
                                              style: TextStyle(fontSize: 10, color: inStock ? _green : _orange),
                                            ),
                                          ])),
                                          Text(
                                            'UGX ${price.toStringAsFixed(0)} ×$qty',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ]),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                                    ),
                                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.check_circle, color: _green, size: 16),
                                      SizedBox(width: 6),
                                      Text('Selected — tap Confirm Order below', style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ]),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Bottom bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_selectedPharmacyId != null && !_submitting) ? _placeOrder : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _selectedPharmacyId == null ? 'Select a pharmacy above' : 'Confirm & Place Order',
                                style: TextStyle(
                                  color: _selectedPharmacyId == null ? Colors.grey.shade500 : Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
