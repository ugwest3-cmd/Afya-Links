import 'package:flutter/material.dart';

// Bottom sheet shown when tapping the bell icon in the AppBar
class NotificationsSheet extends StatelessWidget {
  final VoidCallback? onRead;
  const NotificationsSheet({super.key, this.onRead});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.local_shipping, 'color': const Color(0xFF0D6EFD), 'title': 'Order #1045 is on the way', 'body': 'Your driver left the pharmacy 10 mins ago.', 'time': '10 min ago', 'read': false, 'tag': 'Delivery'},
      {'icon': Icons.check_circle, 'color': const Color(0xFF26C87C), 'title': 'Order #1044 Delivered', 'body': 'Paracetamol 1g × 50 has been delivered.', 'time': '2 hrs ago', 'read': false, 'tag': 'Delivery'},
      {'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFFFA726), 'title': 'Stock Alert', 'body': 'Low stock on Amoxicillin at nearby pharmacy.', 'time': 'Yesterday', 'read': false, 'tag': 'Alert'},
      {'icon': Icons.info_outline, 'color': Colors.grey, 'title': 'System Update', 'body': 'AfyaLinks platform updated to v2.1', 'time': '2 days ago', 'read': true, 'tag': 'System'},
    ];

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
                  onPressed: onRead,
                  child: const Text('Mark all read', style: TextStyle(color: Color(0xFF0D6EFD), fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final n = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n['read'] ? Colors.white : const Color(0xFFEEF3FF),
                    borderRadius: BorderRadius.circular(14),
                    border: n['read'] ? null : Border.all(color: const Color(0xFF0D6EFD).withOpacity(0.15)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: (n['color'] as Color).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(n['icon'] as IconData, color: n['color'] as Color, size: 20),
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
                                    n['title'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: n['read'] ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (n['color'] as Color).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    n['tag'],
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: n['color'] as Color),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(n['body'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(n['time'], style: const TextStyle(fontSize: 10, color: Color(0xFF0D6EFD))),
                          ],
                        ),
                      ),
                      if (!(n['read'] as bool))
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
