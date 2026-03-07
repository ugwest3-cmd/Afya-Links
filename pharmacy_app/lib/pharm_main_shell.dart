import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pharm_screen_dashboard.dart';
import 'pharm_screen_orders.dart';
import 'pharm_screen_pricelist.dart';
import 'pharm_screen_profile.dart';
import 'pharm_screen_notifications.dart';
import 'pharm_screen_payouts.dart';

class PharmMainShell extends StatefulWidget {
  final String pharmacyName;
  const PharmMainShell({super.key, required this.pharmacyName});

  @override
  State<PharmMainShell> createState() => _PharmMainShellState();
}

class _PharmMainShellState extends State<PharmMainShell> {
  int _currentIndex = 0;
  int _notificationCount = 2;
  String? _activeFilter;

  final _pageTitles = ['Dashboard', 'Orders', 'Price List', 'Wallet', 'Profile'];
  final _icons = [
    Icons.home_outlined,
    Icons.inbox_outlined,
    Icons.upload_file_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.person_outline,
  ];
  final _activeIcons = [
    Icons.home_rounded,
    Icons.inbox_rounded,
    Icons.upload_file_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.person_rounded,
  ];

  void _onDashboardViewOrders(String? filter) {
    if (filter == 'WALLET') {
      setState(() => _currentIndex = 3);
      return;
    }
    setState(() {
      _activeFilter = filter;
      _currentIndex = 1;
    });
  }

  void _openNotifications() {
    setState(() => _notificationCount = 0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PharmNotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    const primary = Color(0xFF1B5E20);

    final List<Widget> pages = [
      PharmDashboardScreen(pharmacyName: widget.pharmacyName, onViewOrders: _onDashboardViewOrders),
      PharmOrdersScreen(initialFilter: _activeFilter),
      const PharmPriceListScreen(),
      const PharmPayoutsScreen(),
      PharmProfileScreen(pharmacyName: widget.pharmacyName),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F1),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        toolbarHeight: 62,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_pageTitles[_currentIndex],
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            Text(widget.pharmacyName,
                style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)),
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
                      top: -4, right: -4,
                      child: Container(
                        width: 16, height: 16,
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
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(5, (i) {
                final isActive = _currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        i == 1 && _notificationCount > 0
                            ? Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                                Icon(isActive ? _activeIcons[i] : _icons[i],
                                    color: isActive ? primary : Colors.grey.shade400, size: 24),
                                Positioned(
                                  top: -4, right: -4,
                                  child: Container(
                                    width: 14, height: 14,
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    alignment: Alignment.center,
                                    child: Text('$_notificationCount',
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ])
                            : Icon(isActive ? _activeIcons[i] : _icons[i],
                                color: isActive ? primary : Colors.grey.shade400, size: 24),
                        const SizedBox(height: 3),
                        Text(_pageTitles[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? primary : Colors.grey.shade400,
                            )),
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
