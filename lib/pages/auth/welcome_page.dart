import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/centered_content.dart';
import '../../core/widgets/difa_logo.dart';

/// Boundary: WelcomePage
/// Halaman pembuka sebelum Register / Login. Hanya navigasi,
/// tidak ada logic bisnis.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDCEBFF), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: CenteredContent(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: DifaLogo(size: 64)),
                    const SizedBox(height: 28),
                    Text(
                      'Akses lebih mudah,\nuntuk semua.',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Temukan peta kampus, materi kuliah yang aksesibel, '
                      'dan pendamping yang kamu butuhkan.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const _CategoryIllustration(),
                    const SizedBox(height: 40),
                    AccessibleButton(
                      label: 'Mulai',
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/register'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Sudah punya akun?'),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/login'),
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ilustrasi sementara berupa tiga ikon kategori. Bisa diganti gambar
/// asli (aset) nanti.
class _CategoryIllustration extends StatelessWidget {
  const _CategoryIllustration();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Bubble(icon: Icons.accessible, label: 'Fisik'),
          _Bubble(icon: Icons.hearing_disabled, label: 'Rungu/Wicara'),
          _Bubble(icon: Icons.visibility_off, label: 'Netra'),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Bubble({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 36, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
