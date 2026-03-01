import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class PharmNotificationsSheet extends StatefulWidget {
  const PharmNotificationsSheet({super.key});

  @override
  State<PharmNotificationsSheet> createState() => _PharmNotificationsSheetState();
}

class _PharmNotificationsSheetState extends State<PharmNotificationsSheet> {
  static const _primary = Color(0xFF1B5E20);
  static const _orange = Color(0xFFE65100);
  static const _blue = Color(0xFF0D47A1);

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

  Color _tagColor(String tag) {
    if (tag.toLowerCase().contains('order')) return _orange;
    if (tag.toLowerCase().contains('driver')) return _primary;
    if (tag.toLowerCase().contains('invoice') || tag.toLowerCase().contains('pay')) return _blue;
    return Colors.grey;
  }

  IconData _tagIcon(String tag) {
    if (tag.toLowerCase().contains('order')) return Icons.inbox_rounded;
    if (tag.toLowerCase().contains('driver')) return Icons.directions_bike_rounded;
    if (tag.toLowerCase().contains('invoice') || tag.toLowerCase().contains('pay')) return Icons.receipt_long_rounded;
    return Icons.notifications_rounded;
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
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // handle
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Mark all read', style: TextStyle(color: Color(0xFF1B5E20), fontSize: 12)),
                ),
              ]),
            ),
            const Divider(height: 0),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                      ? const Center(child: Text('No notifications yet.', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          controller: ctrl,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const Divider(height: 0, indent: 16, endIndent: 16),
                          itemBuilder: (_, i) {
                            final n = _notifications[i];
                            final title = n['title'] ?? 'Alert';
                            final tag = title.toString().split(' ').first.toUpperCase(); // Derived tag
                            final color = _tagColor(tag);
                            final isRead = n['is_read'] == true;
                            
                            return Container(
                              color: isRead ? Colors.transparent : color.withOpacity(0.04),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(_tagIcon(tag), color: color, size: 20),
                                ),
                                title: Row(children: [
                                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                                    child: Text('ALERT', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ]),
                                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const SizedBox(height: 3),
                                  Text(n['message'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(_formatDate(n['created_at'] ?? ''), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                ]),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
