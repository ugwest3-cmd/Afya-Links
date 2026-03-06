import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'api_service.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  final String orderCode;

  const TrackingScreen({super.key, required this.orderId, required this.orderCode});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final WebViewController _controller;
  Timer? _timer;
  Map<String, dynamic>? _trackingData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startTracking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _updateMapMarker();
          },
        ),
      )
      ..loadHtmlString(_getLeafletHtml());
  }

  String _getLeafletHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>
        body { margin: 0; padding: 0; }
        #map { height: 100vh; width: 100vw; }
        .driver-marker {
            background: #0D47A1;
            border: 2px solid white;
            border-radius: 50%;
            width: 20px;
            height: 20px;
            box-shadow: 0 0 10px rgba(0,0,0,0.3);
        }
    </style>
</head>
<body>
    <div id="map"></div>
    <script>
        var map = L.map('map').setView([0, 0], 2);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap'
        }).addTo(map);

        var marker = null;

        window.updateLocation = function(lat, lng) {
            var latLng = [lat, lng];
            if (!marker) {
                marker = L.marker(latLng).addTo(map);
                map.setView(latLng, 15);
            } else {
                marker.setLatLng(latLng);
            }
        };
    </script>
</body>
</html>
''';
  }

  void _startTracking() {
    _fetchLocation();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchLocation();
    });
  }

  Future<void> _fetchLocation() async {
    try {
      final res = await ApiService.getTrackingInfo(widget.orderId);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() {
            _trackingData = data['tracking'];
            _loading = false;
          });
          _updateMapMarker();
        }
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
    }
  }

  void _updateMapMarker() {
    if (_trackingData != null) {
      final lat = _trackingData!['latitude'];
      final lng = _trackingData!['longitude'];
      _controller.runJavaScript('updateLocation($lat, $lng)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order #${widget.orderCode}'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.delivery_dining, color: Color(0xFF0D47A1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _trackingData != null ? 'Driver is on the way' : 'Locating driver...',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (_trackingData != null)
                              Text(
                                'Last updated: ${_formatTime(_trackingData!['updated_at'])}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'just now';
    try {
      final date = DateTime.parse(timestamp).toLocal();
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'just now';
    }
  }
}
