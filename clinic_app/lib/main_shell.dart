import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screen_dashboard.dart';
import 'screen_orders.dart';
import 'screen_new_order.dart';
import 'screen_profile.dart';
import 'screen_notifications.dart';

class MainShell extends StatefulWidget {
  final String clinicName;
  final String clinicId;
  const MainShell({super.key, required this.clinicName, required this.clinicId});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _notificationCount = 3;

  final List<String> _pageTitles = ['Dashboard', 'My Orders', 'New Order', 'Profile'];
  final List<IconData> _icons = [
    Icons.home_outlined,
    Icons.receipt_long_outlined,
    Icons.add_circle_outline,
    Icons.person_outline,
  ];
  final List<IconData> _activeIcons = [
    Icons.home_rounded,
    Icons.receipt_long_rounded,
    Icons.add_circle_rounded,
    Icons.person_rounded,
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(clinicName: widget.clinicName, onNewOrder: () => setState(() => _currentIndex = 2)),
      const OrdersScreen(),
      const NewOrderScreen(),
      ProfileScreen(clinicName: widget.clinicName),
    ];
  }

  void _openNotifications() {
    setState(() => _notificationCount = 0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        toolbarHeight: 62,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pageTitles[_currentIndex],
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.clinicName,
              style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _openNotifications,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                  if (_notificationCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(color: Color(0xFFFF4444), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text('$_notificationCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(4, (i) {
                final isActive = _currentIndex == i;
                // New Order tab (index 2) gets a special treatment
                if (i == 2) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentIndex = i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF0D47A1) : const Color(0xFFE8EDFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isActive ? Icons.add_circle_rounded : Icons.add_circle_outline,
                              color: isActive ? Colors.white : const Color(0xFF0D47A1),
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text('New Order',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive ? const Color(0xFF0D47A1) : Colors.grey.shade400,
                              )),
                        ],
                      ),
                    ),
                  );
                }
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? _activeIcons[i] : _icons[i],
                          color: isActive ? const Color(0xFF0D47A1) : Colors.grey.shade400,
                          size: 24,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _pageTitles[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? const Color(0xFF0D47A1) : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
