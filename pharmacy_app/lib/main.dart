import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login.dart';
import 'pharm_main_shell.dart';
import 'fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FCMService.initialize();

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
          secondary: const Color(0xFF2E7D32),
          surface: const Color(0xFFF8FAF8),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
          ),
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => PharmMainShell(pharmacyName: pharmacyName),
      },
    );
  }
}
