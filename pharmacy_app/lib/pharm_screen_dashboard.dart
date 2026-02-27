import 'package:flutter/material.dart';

class PharmDashboardScreen extends StatelessWidget {
  final String pharmacyName;
  final VoidCallback onViewOrders;

  const PharmDashboardScreen({super.key, required this.pharmacyName, required this.onViewOrders});

  static const _primary = Color(0xFF1B5E20);
  static const _green = Color(0xFF2E7D32);
  static const _orange = Color(0xFFE65100);
  static const _blue = Color(0xFF0D47A1);
  static const _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome 👋', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(pharmacyName,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: onViewOrders,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_rounded, color: Color(0xFF1B5E20), size: 16),
                              SizedBox(width: 6),
                              Text('View Orders Inbox',
                                  style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats
          const Text("Today's Overview", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _StatCard('New Orders', '2', Icons.notifications_active_rounded, _orange),
              _StatCard('Accepted', '5', Icons.check_circle_rounded, _green),
              _StatCard('Ready/Transit', '3', Icons.local_shipping_rounded, _blue),
              _StatCard('Completed', '12', Icons.done_all_rounded, _primary),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Actions
          const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            _ActionButton(icon: Icons.inbox_rounded, label: 'Orders Inbox', color: _orange, onTap: onViewOrders),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.upload_file_rounded,
              label: 'Upload CSV',
              color: _green,
              onTap: () => Navigator.pushNamed(context, '/pricelist'),
            ),
            const SizedBox(width: 10),
            _ActionButton(icon: Icons.receipt_long_rounded, label: 'Invoices', color: _blue, onTap: () {}),
          ]),
          const SizedBox(height: 24),

          // Price list status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.list_alt_rounded, color: _green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Active Price List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Text('48 items · Expires in 36 hrs', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('ACTIVE', style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Recent Orders
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recent Orders', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            TextButton(onPressed: onViewOrders, child: const Text('See all', style: TextStyle(color: Color(0xFF1B5E20), fontSize: 12))),
          ]),
          const SizedBox(height: 4),
          _OrderTile(id: '#1045', items: 'Amoxicillin 500mg × 20', status: 'PENDING', time: '5 min ago'),
          _OrderTile(id: '#1044', items: 'Paracetamol 1g × 50', status: 'ACCEPTED', time: '1 hr ago'),
          _OrderTile(id: '#1043', items: 'Metformin 500mg × 30', status: 'READY_FOR_PICKUP', time: '2 hrs ago'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final String id, items, status, time;
  const _OrderTile({required this.id, required this.items, required this.status, required this.time});
  Color get _color {
    switch (status) {
      case 'PENDING': return const Color(0xFFE65100);
      case 'ACCEPTED': return const Color(0xFF2E7D32);
      case 'READY_FOR_PICKUP': return const Color(0xFF0D47A1);
      default: return Colors.grey;
    }
  }
  String get _label {
    switch (status) {
      case 'READY_FOR_PICKUP': return 'Ready for Pickup';
      default: return status[0] + status.substring(1).toLowerCase();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: _color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.receipt_long_rounded, color: _color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(items, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(_label, style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 3),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ]),
      ]),
    );
  }
}
