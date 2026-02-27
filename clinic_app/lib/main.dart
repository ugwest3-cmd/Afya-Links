import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  runApp(AfyaLinksClinicApp(initialRoute: (token == null) ? '/login' : '/home'));
}

class AfyaLinksClinicApp extends StatelessWidget {
  final String initialRoute;

  const AfyaLinksClinicApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AfyaLinks Clinic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D6EFD)),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainShell(clinicName: 'St. Luke\'s Clinic', clinicId: ''),
      },
    );
  }
}
