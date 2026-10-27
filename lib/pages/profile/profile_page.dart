import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../core/widgets/accessible_button.dart';
import '../../models/disability_profile.dart';

/// Boundary: ProfilePage
/// Merealisasikan UC-03 Set Disability Profile.
///
/// Ini adalah titik di mana konsep "UI adaptif per kategori
/// disabilitas" pertama kali ditetapkan oleh mahasiswa, lalu
/// dipakai ulang oleh UC-04 di setiap sesi berikutnya.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _handleSave(BuildContext context) async {
    final profileController = context.read<ProfileController>();
    final authController = context.read<AuthController>();
    final accessibilityController = context.read<AccessibilityController>();

    final uid = authController.sessionToken?.uid;
    if (uid == null) return;

    final success = await profileController.saveProfile(uid);

    if (success && context.mounted) {
      // showConfirmation() -> muat ulang profil supaya tema ter-apply
      await accessibilityController.loadAccessibilityProfile(uid);
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileController = context.watch<ProfileController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Atur Profil Disabilitas')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pilih kategori disabilitas Anda',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Boleh pilih lebih dari satu. Sistem akan menyesuaikan '
                'tampilan dan fitur berdasarkan pilihan ini.',
              ),
              const SizedBox(height: 20),

              // Fase 1 menampilkan 3 kategori yang sudah diimplementasikan
              // penuh (netra, rungu/wicara, fisik). Intelektual &
              // mental/psikososial tetap ditampilkan di model (lihat
              // DisabilityCategory) tapi disembunyikan dari pilihan UI
              // sampai fitur pendukungnya siap di Fase 2+, supaya tidak
              // ada pilihan yang "nyala" tapi belum ada efeknya.
              ..._implementedCategories.map(
                (category) => Semantics(
                  label: category.label,
                  checked: profileController.selectedCategories
                      .contains(category),
                  child: CheckboxListTile(
                    title: Text(category.label),
                    value: profileController.selectedCategories
                        .contains(category),
                    onChanged: (_) =>
                        profileController.toggleCategory(category),
                  ),
                ),
              ),

              if (profileController.status == ProfileSaveStatus.error &&
                  profileController.errorMessage != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    profileController.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              AccessibleButton(
                label: 'Simpan Profil',
                isLoading:
                    profileController.status == ProfileSaveStatus.saving,
                onPressed: () => _handleSave(context),
              ),
            ],
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
