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
        
        // Start tracking if in transit
        if (_order?['delivery_status'] == 'IN_TRANSIT') {
          _startTracking();
        }
      }
    } catch (e) {
      debugPrint('Error loading order: $e');
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      ApiService.updateLocation(position.latitude, position.longitude);
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _handleConfirmPickup() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.confirmPickup(widget.orderId);
      if (res.statusCode == 200) {
        _loadOrder();
      }
    } catch (e) {
      debugPrint('Error confirming pickup: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleConfirmDelivery() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.confirmDelivery(widget.orderId);
      if (res.statusCode == 200) {
        _loadOrder();
        _stopTracking();
      }
    } catch (e) {
      debugPrint('Error confirming delivery: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _order == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

    if (_order == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Order not found')));
    }

    final pharmacy = _order!['pharmacy'] ?? {};
    final clinic = _order!['clinic'] ?? {};
    final status = _order!['delivery_status'] ?? 'UNKNOWN';

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, 8)}'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard('Pharmacy (Pickup)', pharmacy['name'] ?? 'N/A', pharmacy['address'] ?? 'N/A', Icons.store),
            const SizedBox(height: 16),
            _buildInfoCard('Clinic (Destination)', clinic['name'] ?? 'N/A', clinic['address'] ?? 'N/A', Icons.local_hospital),
            const SizedBox(height: 32),
            if (status == 'ASSIGNED' || status == 'READY_FOR_PICKUP')
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirm Pickup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _loading ? null : _handleConfirmPickup,
              )
            else if (status == 'IN_TRANSIT')
              ElevatedButton.icon(
                icon: const Icon(Icons.delivery_dining),
                label: const Text('Confirm Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _loading ? null : _handleConfirmDelivery,
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Status: $status',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String name, String address, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0D47A1), size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(address, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
