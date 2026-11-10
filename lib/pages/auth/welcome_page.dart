import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/centered_content.dart';
import '../../core/widgets/difa_logo.dart';
import '../../core/widgets/scene_illustration.dart';
import '../../models/disability_profile.dart';

/// Boundary: WelcomePage
/// Halaman pembuka sebelum Register / Login. Hanya navigasi.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  /// MODE DEMO (hanya di debug): lihat tampilan tanpa login/database.
  Future<void> _openDemoSheet(BuildContext context) async {
    final accessibility = context.read<AccessibilityController>();
    final choice = await showModalBottomSheet<List<DisabilityCategory>>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Mode demo (hanya debug)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Lihat tampilan tanpa login. Data tidak disimpan.'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('Netra'),
              onTap: () =>
                  Navigator.pop(sheetContext, [DisabilityCategory.netra]),
            ),
            ListTile(
              leading: const Icon(Icons.hearing_disabled),
              title: const Text('Rungu / Wicara'),
              onTap: () =>
                  Navigator.pop(sheetContext, [DisabilityCategory.runguWicara]),
            ),
            ListTile(
              leading: const Icon(Icons.accessible),
              title: const Text('Fisik'),
              onTap: () =>
                  Navigator.pop(sheetContext, [DisabilityCategory.fisik]),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Tanpa kategori'),
              onTap: () =>
                  Navigator.pop(sheetContext, const <DisabilityCategory>[]),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    accessibility.applyDemoProfile(choice);
    Navigator.of(context).pushNamed('/home');
  }

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
          child: SingleChildScrollView(
            child: CenteredContent(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: DifaLogo(size: 56)),
                  const SizedBox(height: 24),
                  Text(
                    'Akses lebih mudah,\nuntuk semua.',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Temukan peta kampus, materi kuliah yang aksesibel, '
                    'dan pendamping yang kamu butuhkan.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AspectRatio(
                    aspectRatio: 1.05,
                    child: SceneIllustration(variant: SceneVariant.welcome),
                  ),
                  const SizedBox(height: 16),
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
                  if (kDebugMode)
                    TextButton.icon(
                      onPressed: () => _openDemoSheet(context),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Lihat tampilan demo (debug)'),
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
