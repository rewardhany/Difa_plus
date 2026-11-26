import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';

/// Boundary: OnboardingPage
/// Sambutan untuk user baru (setelah daftar dengan Google), berupa
/// beberapa slide "Lanjut" sebelum masuk ke Beranda.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _Slide(this.icon, this.color, this.title, this.body);
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Slide> _slides(String firstName) => [
        _Slide(
          Icons.waving_hand_outlined,
          AppColors.primary,
          'Selamat datang, $firstName!',
          'Akunmu sudah dibuat dengan Google. Difa+ membantu mahasiswa disabilitas '
              'mengakses kampus dan materi kuliah dengan lebih mudah.',
        ),
        const _Slide(
          Icons.map_outlined,
          Color(0xFF0D9488),
          'Peta kampus yang aksesibel',
          'Temukan ramp, lift, dan toilet difabel. Untuk pengguna netra tersedia '
              'mode suara.',
        ),
        const _Slide(
          Icons.auto_awesome,
          Color(0xFF7C3AED),
          'Materi dan pendamping',
          'Ubah materi kuliah ke audio atau teks, dan cari pendamping sesuai '
              'kebutuhanmu. Fitur ini segera hadir.',
        ),
        const _Slide(
          Icons.verified_user_outlined,
          Color(0xFFEA580C),
          'Lengkapi profilmu',
          'Karena masuk dengan Google, no. telepon, jenis disabilitas, dan password '
              'belum terisi. Lengkapi lewat banner di Beranda atau menu Profil.',
        ),
      ];

  void _finish() {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _next(int last) {
    if (_index >= last) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthController>().currentAccount?.fullName ?? '';
    final firstName =
        name.trim().isEmpty ? 'teman' : name.trim().split(' ').first;
    final slides = _slides(firstName);
    final last = slides.length - 1;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text('Lewati'),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: slides.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) {
                        final s = slides[i];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: s.color.withAlpha(31),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(s.icon, size: 68, color: s.color),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              s.title,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.body,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? AppColors.primary
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AccessibleButton(
                    label: _index == last ? 'Mulai' : 'Lanjut',
                    onPressed: () => _next(last),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
