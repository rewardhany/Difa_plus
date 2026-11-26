import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_account.dart';

/// Menentukan halaman tujuan setelah autentikasi berhasil
/// (login email, login Google, atau akun Google baru).
///
/// - Akun Google BARU            -> '/onboarding' (lalu Beranda).
/// - Login email, profil kosong  -> '/profile' (UC-04 -> UC-03).
/// - Selain itu                  -> '/home'.
///   (Akun Google yang profilnya belum lengkap tetap ke Beranda; di sana
///   muncul banner "Lengkapi profil".)
Future<void> goAfterAuth(
  BuildContext context, {
  bool viaGoogle = false,
  bool isNewAccount = false,
}) async {
  final auth = context.read<AuthController>();
  final accessibility = context.read<AccessibilityController>();
  final uid = auth.sessionToken?.uid;
  if (uid == null) return;

  // <<include>> UC-04 Load Accessibility Profile
  await accessibility.loadAccessibilityProfile(uid);
  if (!context.mounted) return;

  final nav = Navigator.of(context);
  if (isNewAccount) {
    nav.pushNamedAndRemoveUntil('/onboarding', (route) => false);
  } else if (!viaGoogle && accessibility.needsProfileSetup) {
    nav.pushReplacementNamed('/profile');
  } else {
    nav.pushNamedAndRemoveUntil('/home', (route) => false);
  }
}

/// Menanyakan peran untuk akun Google baru (dipakai di halaman Login,
/// karena di halaman Daftar peran sudah dipilih sebelumnya).
/// Mengembalikan null kalau user menutup pilihan.
Future<UserRole?> askRole(BuildContext context) {
  return showModalBottomSheet<UserRole>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Kamu mendaftar sebagai?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('Akun Google ini belum terdaftar di Difa+.'),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Mahasiswa'),
            onTap: () => Navigator.pop(sheetContext, UserRole.mahasiswa),
          ),
          ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: const Text('Pendamping'),
            onTap: () => Navigator.pop(sheetContext, UserRole.pendamping),
          ),
        ],
      ),
    ),
  );
}
