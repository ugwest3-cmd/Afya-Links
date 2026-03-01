import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

// Bottom sheet shown when tapping the bell icon in the AppBar
class NotificationsSheet extends StatefulWidget {
  final VoidCallback? onRead;
  const NotificationsSheet({super.key, this.onRead});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await ApiService.getNotifications();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(data['notifications']);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
    setState(() => _isLoading = false);
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return DateFormat('hh:mm a').format(date);
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      }
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notifications & Alerts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: widget.onRead,
                  child: const Text('Mark all read', style: TextStyle(color: Color(0xFF0D6EFD), fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? const Center(child: Text('No notifications yet', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: _notifications.length,
                        itemBuilder: (context, i) {
                          final n = _notifications[i];
                          final isRead = n['is_read'] == true;
                          final title = n['title'] ?? 'Alert';
                          final message = n['message'] ?? '';
                          final timeStr = _formatDate(n['created_at'] ?? '');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isRead ? Colors.white : const Color(0xFFEEF3FF),
                              borderRadius: BorderRadius.circular(14),
                              border: isRead ? null : Border.all(color: const Color(0xFF0D6EFD).withOpacity(0.15)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D6EFD).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.notifications_active, color: Color(0xFF0D6EFD), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0D6EFD).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Alert',
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(message, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text(timeStr, style: const TextStyle(fontSize: 10, color: Color(0xFF0D6EFD))),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4, left: 6),
                                    child: CircleAvatar(radius: 4, backgroundColor: Color(0xFF0D6EFD)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Kept for backward compat (not used in new nav)
class NotificationsScreen extends StatelessWidget {
  final VoidCallback onRead;
  const NotificationsScreen({super.key, required this.onRead});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Notifications'));
  }
}
