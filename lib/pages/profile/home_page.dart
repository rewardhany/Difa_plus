import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/disability_profile.dart';

/// Boundary: HomePage
/// Merealisasikan bagian "viewAdaptedHomeScreen()" pada UC-04
/// Load Accessibility Profile.
///
/// Halaman ini SENGAJA tidak berisi fitur navigasi/AI/buddy yang
/// sesungguhnya (itu Fase 2) — tugasnya di Fase 1 adalah membuktikan
/// bahwa tampilan benar-benar berubah mengikuti DisabilityProfile
/// yang tersimpan, sebelum fitur lain dibangun di atasnya.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibility = context.watch<AccessibilityController>();
    final auth = context.watch<AuthController>();
    final profile = accessibility.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda Difa+'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await auth.logout();
              accessibility.reset();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, ${auth.currentAccount?.fullName ?? 'Pengguna'} 👋',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_modeDescription(profile)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (profile?.categories ?? [])
                    .map((c) => Chip(label: Text(c.label)))
                    .toList(),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Fitur berikut akan aktif pada Fase 2:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _PlaceholderTile(
                icon: Icons.map_outlined,
                label: 'Navigasi Kampus (UC-05–UC-08)',
              ),
              _PlaceholderTile(
                icon: Icons.menu_book_outlined,
                label: 'Konversi Materi Kuliah (UC-09)',
              ),
              _PlaceholderTile(
                icon: Icons.volunteer_activism_outlined,
                label: 'Pendamping / Buddy (UC-12–UC-14)',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeDescription(DisabilityProfile? profile) {
    if (profile == null || profile.isEmpty) {
      return 'Tampilan standar — belum ada kategori disabilitas yang diatur.';
    }
    if (profile.isNetra) {
      return 'Mode tampilan: kontras tinggi & teks besar, dioptimalkan untuk screen reader.';
    }
    if (profile.isFisik) {
      return 'Mode tampilan: target sentuh diperbesar untuk kemudahan navigasi.';
    }
    return 'Mode tampilan: standar, notifikasi disesuaikan untuk kebutuhan dengar/bicara.';
  }
}

class _PlaceholderTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PlaceholderTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.lock_outline, size: 18),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
