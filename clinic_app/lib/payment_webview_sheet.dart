import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewSheet extends StatefulWidget {
  final String url;
  final String title;
  final String orderId; // needed to poll status after redirect

  const PaymentWebViewSheet({super.key, required this.url, required this.orderId, this.title = 'Payment'});

  @override
  State<PaymentWebViewSheet> createState() => _PaymentWebViewSheetState();

  /// Returns the OrderTrackingId if Pesapal included it in the callback URL, else null.
  static Future<String?> show(BuildContext context, String url, String orderId, {String title = 'Payment Gateway'}) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentWebViewSheet(url: url, orderId: orderId, title: title),
    );
  }
}

class _PaymentWebViewSheetState extends State<PaymentWebViewSheet> {
  late final WebViewController _controller;
  bool _loading = true;

  static const String _callbackHost = 'afya-links-production.up.railway.app';
  static const String _callbackPath = '/api/payments/callback';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _loading = true);
            _checkIfCallbackUrl(url);
          },
          onPageFinished: (String url) {
            setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _checkIfCallbackUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      if (uri.host == _callbackHost && uri.path == _callbackPath) {
        // Pesapal redirected back — extract tracking ID if present and close the sheet
        final trackingId = uri.queryParameters['OrderTrackingId'];
        debugPrint('[WebView] Callback detected. TrackingId=$trackingId');
        // Pop and return the tracking ID so the caller can poll for status
        if (mounted) Navigator.of(context).pop(trackingId);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primary = const Color(0xFF0D47A1);

    return Container(
      height: size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(
                  controller: _controller,
                  gestureRecognizers: {
                    Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
                    Factory<LongPressGestureRecognizer>(() => LongPressGestureRecognizer()),
                  },
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          
          // Add extra space for the keyboard if it overlaps
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
