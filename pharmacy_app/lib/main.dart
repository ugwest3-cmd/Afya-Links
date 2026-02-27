import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'pharm_main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  // For UI testing bypass — set token to null to show login, or keep for direct access
  runApp(AfyaLinksPharmacyApp(
    initialRoute: (token == null) ? '/login' : '/home',
  ));
}

class AfyaLinksPharmacyApp extends StatelessWidget {
  final String initialRoute;
  const AfyaLinksPharmacyApp({super.key, required this.initialRoute});

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
        '/home': (context) => const PharmMainShell(pharmacyName: 'City Pharmacy'),
      },
    );
  }
}
