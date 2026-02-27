import 'package:flutter/material.dart';

class PharmNotificationsSheet extends StatelessWidget {
  const PharmNotificationsSheet({super.key});

  static const _primary = Color(0xFF1B5E20);
  static const _orange = Color(0xFFE65100);
  static const _blue = Color(0xFF0D47A1);

  final List<Map<String, dynamic>> _notifications = const [
    {'title': 'New Order Received', 'body': 'St. Luke\'s Clinic placed an order for Amoxicillin 500mg ×20', 'tag': 'ORDER', 'time': '5 min ago', 'read': false},
    {'title': 'Driver Assigned', 'body': 'John Driver has been assigned for Order #1044. Code: HX7K2P', 'tag': 'DRIVER', 'time': '1 hr ago', 'read': false},
    {'title': 'Payment Due', 'body': 'Your weekly invoice is ready. Please upload payment proof.', 'tag': 'INVOICE', 'time': '2 hrs ago', 'read': true},
    {'title': 'Price List Expiring', 'body': 'Your active price list expires in 12 hours. Upload a new one.', 'tag': 'SYSTEM', 'time': '5 hrs ago', 'read': true},
  ];

  Color _tagColor(String tag) {
    switch (tag) {
      case 'ORDER': return _orange;
      case 'DRIVER': return _primary;
      case 'INVOICE': return _blue;
      default: return Colors.grey;
    }
  }

  IconData _tagIcon(String tag) {
    switch (tag) {
      case 'ORDER': return Icons.inbox_rounded;
      case 'DRIVER': return Icons.directions_bike_rounded;
      case 'INVOICE': return Icons.receipt_long_rounded;
      default: return Icons.notifications_rounded;
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
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 0, indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  final n = _notifications[i];
                  final color = _tagColor(n['tag']);
                  return Container(
                    color: n['read'] == true ? Colors.transparent : color.withOpacity(0.04),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(_tagIcon(n['tag']), color: color, size: 20),
                      ),
                      title: Row(children: [
                        Expanded(child: Text(n['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                          child: Text(n['tag'], style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 3),
                        Text(n['body'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(n['time'], style: const TextStyle(color: Colors.grey, fontSize: 10)),
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
