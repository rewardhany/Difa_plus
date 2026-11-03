import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/difa_logo.dart';
import '../../core/widgets/feature_card.dart';
import '../../models/disability_profile.dart';

/// Boundary: HomePage
/// Merealisasikan "viewAdaptedHomeScreen()" pada UC-04, sekaligus
/// pintu masuk ke fitur yang sudah selesai dibangun.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibility = context.watch<AccessibilityController>();
    final auth = context.watch<AuthController>();
    final profile = accessibility.profile;
    final textTheme = Theme.of(context).textTheme;
    final name = auth.currentAccount?.fullName ?? 'Pengguna';

    return Scaffold(
      appBar: AppBar(
        title: const DifaLogo(size: 32),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await auth.logout();
              accessibility.reset();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/welcome', (route) => false);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Halo, $name 👋',
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Semangat hari ini!',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                _Banner(),
                const SizedBox(height: 12),
                _ModeInfo(text: _modeDescription(profile)),
                const SizedBox(height: 24),
                Text(
                  'Fitur',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                FeatureCard(
                  icon: Icons.map_outlined,
                  title: 'Peta Kampus',
                  subtitle: 'Lihat denah dan fasilitas aksesibel',
                  onTap: () => Navigator.of(context).pushNamed('/campus-map'),
                ),
                const FeatureCard(
                  icon: Icons.alt_route,
                  title: 'Rute & Navigasi',
                  subtitle: 'Panduan rute menuju tujuan',
                  accent: Color(0xFF0D9488),
                  comingSoon: true,
                ),
                const FeatureCard(
                  icon: Icons.auto_awesome,
                  title: 'Materi Aksesibel (AI)',
                  subtitle: 'Ubah materi kuliah ke audio atau teks',
                  accent: Color(0xFF7C3AED),
                  comingSoon: true,
                ),
                const FeatureCard(
                  icon: Icons.volunteer_activism,
                  title: 'Pendamping',
                  subtitle: 'Cari pendamping sesuai kebutuhan',
                  accent: Color(0xFFEA580C),
                  comingSoon: true,
                ),
                const FeatureCard(
                  icon: Icons.feedback_outlined,
                  title: 'Lapor Hambatan',
                  subtitle: 'Sampaikan masukan ke ULD',
                  accent: Color(0xFFDB2777),
                  comingSoon: true,
                ),
                const SizedBox(height: 12),
                _ProfileCard(profile: profile),
              ],
            ),
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

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Setiap orang berhak mengakses layanan kampus dengan mudah.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(width: 12),
          ExcludeSemantics(
            child: Icon(Icons.accessible_forward, color: Colors.white, size: 48),
          ),
        ],
      ),
    );
  }
}

class _ModeInfo extends StatelessWidget {
  final String text;

  const _ModeInfo({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.tune, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final DisabilityProfile? profile;

  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final categories = profile?.categories ?? const <DisabilityCategory>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profil Disabilitas',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (categories.isEmpty)
            const Text('Belum diatur.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories) Chip(label: Text(c.label)),
              ],
            ),
          const SizedBox(height: 12),
          AccessibleButton(
            label: 'Ubah Profil',
            icon: Icons.edit_outlined,
            outlined: true,
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
          ),
        ],
      ),
    );
  }
}