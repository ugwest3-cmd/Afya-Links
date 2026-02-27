import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'pharm_main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final name = prefs.getString('pharmacyName') ?? 'AfyaLinks Pharmacy';

  // For UI testing bypass — set token to null to show login, or keep for direct access
  runApp(AfyaLinksPharmacyApp(
    initialRoute: (token == null) ? '/login' : '/home',
    pharmacyName: name,
  ));
}

class AfyaLinksPharmacyApp extends StatelessWidget {
  final String initialRoute;
  final String pharmacyName;
  const AfyaLinksPharmacyApp({super.key, required this.initialRoute, required this.pharmacyName});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AfyaLinks Pharmacy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => PharmMainShell(pharmacyName: pharmacyName),
      },
    );
  }
}
