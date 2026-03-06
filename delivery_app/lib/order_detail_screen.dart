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
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: _buildEmptyState('Order not found', Icons.search_off_rounded),
      );
    }

    final pharmacy = _order!['pharmacy'] ?? {};
    final clinic = _order!['clinic'] ?? {};
    final status = _order!['delivery_status'] ?? 'UNKNOWN';
    final orderCode = widget.orderId.substring(0, 8).toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderCode'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Status Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == 'IN_TRANSIT' ? Icons.local_shipping_rounded : 
                      (status == 'ASSIGNED' || status == 'READY_FOR_PICKUP' ? Icons.inventory_2_rounded : Icons.check_circle_rounded),
                      size: 32,
                      color: const Color(0xFF1E40AF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    status.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827), letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review the route and confirm your progress below.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Route Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Route Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        _buildRouteLocation('Pickup', pharmacy['name'] ?? 'N/A', pharmacy['address'] ?? 'N/A', Icons.storefront_rounded, const Color(0xFF6B7280), true),
                        const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 56),
                        _buildRouteLocation('Dropoff', clinic['name'] ?? 'N/A', clinic['address'] ?? 'N/A', Icons.medical_services_outlined, const Color(0xFF2563EB), false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Order Items & Financials
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (_order!['order_items'] != null && (_order!['order_items'] as List).isNotEmpty)
                          ...(_order!['order_items'] as List).map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('${item['quantity']}x', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item['products']?['name'] ?? 'Unknown Item',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        
                        // Fallback if empty
                        if (_order!['order_items'] == null || (_order!['order_items'] as List).isEmpty)
                           const Text('No item details available.', style: TextStyle(color: Color(0xFF6B7280))),
                           
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                        ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                            Text(
                              'UGX ${_order!['total_amount'] ?? '---'}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: _buildActionSection(status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRouteLocation(String label, String name, String address, IconData icon, Color iconColor, bool isTop) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(address, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection(String status) {
    if (status == 'ASSIGNED' || status == 'READY_FOR_PICKUP') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.check_circle_outline_rounded),
        label: const Text('Confirm Pickup'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B),
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: _loading ? null : _handleConfirmPickup,
      );
    } else if (status == 'IN_TRANSIT') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.where_to_vote_rounded),
        label: const Text('Confirm Delivery'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        onPressed: _loading ? null : _handleConfirmDelivery,
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF4B5563), size: 20),
            const SizedBox(width: 8),
            Text(
              'Order is $status',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563), fontSize: 15),
            ),
          ],
        ),
      );
    }
  }
}
