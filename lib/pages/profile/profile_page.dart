import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/centered_content.dart';
import '../../core/widgets/error_banner.dart';
import '../../models/disability_profile.dart';

/// Boundary: ProfilePage
/// Merealisasikan UC-03 Set Disability Profile.
///
/// Halaman ini juga dipakai untuk mengubah profil dari Beranda:
/// saat dibuka, pilihan awal diisi dari profil yang tersimpan.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = context.read<AccessibilityController>().profile;
      // Mengisi pilihan awal dari profil tersimpan (kosong kalau baru).
      context.read<ProfileController>().cancelEditing(profile);
    });
  }

  Future<void> _handleSave() async {
    final profileController = context.read<ProfileController>();
    final authController = context.read<AuthController>();
    final accessibilityController = context.read<AccessibilityController>();

    final uid = authController.sessionToken?.uid;
    if (uid == null) return;

    final success = await profileController.saveProfile(uid);

    if (success && mounted) {
      // Muat ulang profil supaya tema adaptif langsung ter-apply.
      await accessibilityController.loadAccessibilityProfile(uid);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileController = context.watch<ProfileController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Atur Profil Disabilitas')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pilih kategori disabilitas Anda',
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Boleh pilih lebih dari satu. Sistem akan menyesuaikan '
                  'tampilan dan fitur berdasarkan pilihan ini.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Hanya 3 kategori yang sudah punya efek nyata di fase ini.
                for (final category in _implementedCategories)
                  _CategoryTile(
                    category: category,
                    selected: profileController.selectedCategories
                        .contains(category),
                    onTap: () => profileController.toggleCategory(category),
                  ),

                if (profileController.status == ProfileSaveStatus.error &&
                    profileController.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  ErrorBanner(message: profileController.errorMessage!),
                ],

                const SizedBox(height: 20),
                AccessibleButton(
                  label: 'Simpan Profil',
                  isLoading:
                      profileController.status == ProfileSaveStatus.saving,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _implementedCategories = [
    DisabilityCategory.netra,
    DisabilityCategory.runguWicara,
    DisabilityCategory.fisik,
  ];
}

class _CategoryTile extends StatelessWidget {
  final DisabilityCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  String get _description {
    switch (category) {
      case DisabilityCategory.netra:
        return 'Tampilan kontras tinggi, teks besar, dan panduan suara.';
      case DisabilityCategory.runguWicara:
        return 'Teks dan notifikasi visual/getar sebagai pengganti suara.';
      case DisabilityCategory.fisik:
        return 'Tombol lebih besar dan informasi akses ramp/lift.';
      default:
        return '';
    }
  }

  IconData get _icon {
    switch (category) {
      case DisabilityCategory.netra:
        return Icons.visibility_off;
      case DisabilityCategory.runguWicara:
        return Icons.hearing_disabled;
      case DisabilityCategory.fisik:
        return Icons.accessible;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      checked: selected,
      label: '${category.label}. $_description',
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: selected ? AppColors.surfaceTint : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? scheme.primary : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(_icon, size: 32, color: scheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? scheme.primary : AppColors.textSecondary,
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