import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/accessibility_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/registration_controller.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/profile/home_page.dart';
import 'pages/profile/profile_page.dart';

/// Root widget Difa+.
///
/// Semua Controller Fase 1 di-provide di level tertinggi lewat
/// MultiProvider supaya Page mana pun bisa mengaksesnya, mengikuti
/// pola "satu backend/state yang sama, tampilan yang menyesuaikan" —
/// bukan state lokal per halaman yang terputus-putus.
class DifaPlusApp extends StatelessWidget {
  const DifaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RegistrationController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => AccessibilityController()),
      ],
      child: Consumer<AccessibilityController>(
        builder: (context, accessibility, _) {
          return MaterialApp(
            title: 'Difa+',
            debugShowCheckedModeBanner: false,
            // Tema otomatis mengikuti AccessibilityController —
            // ini yang membuat "UI adaptif" terasa di SELURUH app,
            // bukan cuma di satu halaman.
            theme: accessibility.currentTheme,
            initialRoute: '/login',
            routes: {
              '/login': (_) => const LoginPage(),
              '/register': (_) => const RegisterPage(),
              '/profile': (_) => const ProfilePage(),
              '/home': (_) => const HomePage(),
            },
          );
        },
      ),
    );
  }
}
