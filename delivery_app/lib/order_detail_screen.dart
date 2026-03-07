import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getOrderById(widget.orderId);
      if (res.statusCode == 200) {
        setState(() {
          _order = jsonDecode(res.body)['order'];
          _loading = false;
        });
        if (_order?['delivery_status'] == 'IN_TRANSIT') _startTracking();
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startTracking() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((p) => ApiService.updateLocation(p.latitude, p.longitude));
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _handleConfirmPickup() async {
    final code = await _showVerificationDialog(
      title: 'Confirm Pickup',
      instruction: 'Enter the Order Code from the Pharmacist to confirm drug collection.',
      hint: 'ORDER CODE',
      isOtp: false,
    );

    if (code == null) return;

    setState(() => _loading = true);
    try {
      final res = await ApiService.confirmPickup(widget.orderId, code);
      if (res.statusCode == 200) {
        _showSuccess('Pickup Confirmed! Starting transit...');
        _loadOrder();
      } else {
        _showError(jsonDecode(res.body)['message'] ?? 'Invalid code');
      }
    } catch (e) {
      _showError('Connection error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleConfirmDelivery() async {
    final otp = await _showVerificationDialog(
      title: 'Complete Delivery',
      instruction: 'Enter the 6-digit confirmation code provided by the Clinic receiver.',
      hint: '000000',
      isOtp: true,
    );

    if (otp == null) return;

    setState(() => _loading = true);
    try {
      final res = await ApiService.confirmDelivery(widget.orderId, otp);
      if (res.statusCode == 200) {
        _showSuccess('Delivery Completed! Earnings updated.');
        _loadOrder();
        _stopTracking();
      } else {
        _showError(jsonDecode(res.body)['message'] ?? 'Invalid verification code');
      }
    } catch (e) {
      _showError('Connection error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _showVerificationDialog({required String title, required String instruction, required String hint, bool isOtp = false}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF312E81))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(instruction, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: isOtp ? TextInputType.number : TextInputType.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: isOtp ? 8 : 2, color: const Color(0xFF312E81)),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(letterSpacing: isOtp ? 8 : 2, color: const Color(0xFFE2E8F0)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase()),
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 48)),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF312E81),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF312E81);
    const accentCyan = Color(0xFF0891B2);

    if (_loading && _order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('TASK DETAILS')),
        body: Center(child: Text('Task expired or unavailable', style: TextStyle(color: Colors.grey.shade400))),
      );
    }

    final status = _order!['delivery_status'] ?? 'UNKNOWN';
    final id = _order!['order_code'] ?? 'ORD-#';
    final pharmacy = _order!['pharmacy'] ?? {};
    final clinic = _order!['clinic'] ?? {};
    final fee = _order!['delivery_fee']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('JOB $id'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Fee: UGX $fee',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Status Stepper
            _buildStepper(status, primaryIndigo),
            const SizedBox(height: 32),

            // Route Cards
            _buildRouteCard('PICKUP POINT', pharmacy['name'], pharmacy['address'], pharmacy['phone'], Icons.storefront_rounded, primaryIndigo),
            const SizedBox(height: 16),
            _buildRouteCard('DELIVERY DESTINATION', clinic['name'], clinic['address'], clinic['phone'], Icons.medical_services_outlined, accentCyan),
            
            const SizedBox(height: 32),

            // Item Checklist
            _buildHeader('ORDER MANIFEST'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  if (_order!['order_items'] != null)
                    ...(_order!['order_items'] as List).map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Text('${i['quantity']}x ', style: const TextStyle(fontWeight: FontWeight.w900, color: primaryIndigo)),
                          Expanded(child: Text(i['products']?['name'] ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        ],
                      ),
                    )),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Action Button
            _buildActionButton(status, primaryIndigo, accentCyan),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper(String status, Color color) {
    bool isPicked = status != 'ASSIGNED' && status != 'READY_FOR_PICKUP';
    bool isDone = status == 'DELIVERED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          _stepIcon(Icons.assignment_turned_in_rounded, true, color),
          _stepLine(isPicked, color),
          _stepIcon(Icons.local_shipping_rounded, isPicked, color),
          _stepLine(isDone, color),
          _stepIcon(Icons.verified_rounded, isDone, color),
        ],
      ),
    );
  }

  Widget _stepIcon(IconData icon, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active ? color : const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: active ? Colors.white : const Color(0xFFCBD5E1), size: 18),
    );
  }

  Widget _stepLine(bool active, Color color) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? color : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildRouteCard(String label, String? name, String? address, String? phone, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text(address ?? 'No address provided', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    if (phone != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.phone_rounded, color: color, size: 14),
                          const SizedBox(width: 6),
                          Text(phone, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
      ),
    );
  }

  Widget _buildActionButton(String status, Color indigo, Color cyan) {
    if (status == 'ASSIGNED' || status == 'READY_FOR_PICKUP') {
      return ElevatedButton(onPressed: _handleConfirmPickup, child: const Text('CONFIRM PICKUP'));
    } else if (status == 'IN_TRANSIT') {
      return ElevatedButton(
        onPressed: _handleConfirmDelivery, 
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
        child: const Text('COMPLETE DELIVERY'),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: Text(
            'ORDER ${status.toUpperCase()}', 
            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), fontSize: 12, letterSpacing: 1)
          ),
        ),
      );
    }
  }
}
