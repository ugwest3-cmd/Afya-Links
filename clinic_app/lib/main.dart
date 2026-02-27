import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final name = prefs.getString('clinicName') ?? 'AfyaLinks Clinic';

  runApp(AfyaLinksClinicApp(
    initialRoute: (token == null) ? '/login' : '/home',
    clinicName: name,
  ));
}

class AfyaLinksClinicApp extends StatelessWidget {
  final String initialRoute;
  final String clinicName;

  const AfyaLinksClinicApp({super.key, required this.initialRoute, required this.clinicName});

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
        '/home': (context) => MainShell(clinicName: clinicName, clinicId: ''),
      },
    );
  }
}
