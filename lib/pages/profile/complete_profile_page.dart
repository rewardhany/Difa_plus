import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/account_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../core/widgets/centered_content.dart';
import '../../core/widgets/error_banner.dart';
import '../../models/disability_profile.dart';
import '../../models/user_account.dart';

/// Boundary: CompleteProfilePage
/// Halaman "Lengkapi Profil" / "Edit Profil".
///
/// Dibuka dari banner di Beranda atau dari tab Profil. Mengisi/mengubah:
/// nama, no. telepon (wajib), jenis disabilitas (wajib untuk Mahasiswa),
/// dan password (opsional; hanya tampil untuk akun yang belum punya
/// password, mis. akun yang daftar lewat Google).
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _scroll = ScrollController();
  final Set<DisabilityCategory> _categories = {};

  bool _saving = false;
  String? _categoriesError;
  String? _profileError;

  static const _chipCategories = [
    DisabilityCategory.netra,
    DisabilityCategory.runguWicara,
    DisabilityCategory.fisik,
  ];

  @override
  void initState() {
    super.initState();
    final account = context.read<AuthController>().currentAccount;
    _nameController = TextEditingController(text: account?.fullName ?? '');
    _phoneController = TextEditingController(text: account?.phone ?? '');
    _categories.addAll(
      context.read<AccessibilityController>().profile?.categories ??
          const <DisabilityCategory>[],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AccountController>().reset();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  IconData _iconFor(DisabilityCategory c) {
    switch (c) {
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

  void _scrollTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _handleSave() async {
    final auth = context.read<AuthController>();
    final account = context.read<AccountController>();
    final profileController = context.read<ProfileController>();
    final accessibility = context.read<AccessibilityController>();
    final current = auth.currentAccount;
    final isMahasiswa = current == null || current.role == UserRole.mahasiswa;
    final needPassword = !auth.hasPassword;
    final password = needPassword ? _passwordController.text : '';
    final confirm = needPassword ? _confirmController.text : '';

    setState(() {
      _categoriesError = null;
      _profileError = null;
    });

    final fieldsOk = account.validate(
      fullName: _nameController.text,
      phone: _phoneController.text,
      password: password,
      confirm: confirm,
    );
    var categoriesOk = true;
    if (isMahasiswa && _categories.isEmpty) {
      categoriesOk = false;
      setState(() => _categoriesError = 'Pilih minimal satu jenis disabilitas.');
    }
    if (!fieldsOk || !categoriesOk) {
      if (!fieldsOk) _scrollTop();
      return;
    }

    // ---- mode demo: simpan hanya di memori ----
    if (auth.isDemo) {
      auth.applyDemoUpdate(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        hasPassword: password.isNotEmpty ? true : null,
      );
      if (isMahasiswa) accessibility.applyDemoProfile(_categories.toList());
      _finish();
      return;
    }

    final uid = auth.sessionToken?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    final saved = await account.save(
      uid: uid,
      fullName: _nameController.text,
      phone: _phoneController.text,
      newPassword: password,
    );
    if (account.detailsSaved) await auth.refreshAccount();
    if (!mounted) return;

    if (!saved) {
      setState(() => _saving = false);
      _scrollTop();
      return;
    }

    if (isMahasiswa) {
      profileController.selectedCategories = _categories.toList();
      final ok = await profileController.saveProfile(uid);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _saving = false;
          _profileError =
              profileController.errorMessage ?? 'Profil disabilitas gagal disimpan.';
        });
        return;
      }
      await accessibility.loadAccessibilityProfile(uid); // tema ikut berubah
      if (!mounted) return;
    }

    setState(() => _saving = false);
    _finish();
  }

  void _finish() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil diperbarui.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final accountCtrl = context.watch<AccountController>();
    final accessibility = context.watch<AccessibilityController>();
    final textTheme = Theme.of(context).textTheme;
    final account = auth.currentAccount;
    final isMahasiswa = account == null || account.role == UserRole.mahasiswa;
    final needPassword = !auth.hasPassword;
    final errors = accountCtrl.fieldErrors;

    final incomplete = account != null &&
        (!account.hasPhone ||
            (isMahasiswa && (accessibility.profile?.isEmpty ?? true)) ||
            needPassword);
    final title = incomplete ? 'Lengkapi Profil' : 'Edit Profil';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.isGoogleAccount)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Kamu masuk dengan Google, jadi baru nama dan email yang terisi. '
                      'Lengkapi data di bawah ini.',
                    ),
                  ),

                // Email: hanya informasi (tidak bisa diubah)
                Text(
                  'Email',
                  style: textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F8),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(account?.email ?? '-')),
                      const Icon(Icons.lock_outline,
                          size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                AccessibleTextField(
                  labelAbove: true,
                  label: 'Nama Lengkap',
                  hintText: 'Masukkan nama lengkap',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                  errorText: errors['name'],
                  onChanged: (_) => accountCtrl.clearFieldError('name'),
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  labelAbove: true,
                  label: 'No. Telepon',
                  hintText: 'Masukkan nomor telepon',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  errorText: errors['phone'],
                  onChanged: (_) => accountCtrl.clearFieldError('phone'),
                ),

                if (isMahasiswa) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Jenis Disabilitas',
                    style: textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _chipCategories)
                        FilterChip(
                          avatar: Icon(_iconFor(c), size: 18),
                          label: Text(c.label),
                          selected: _categories.contains(c),
                          onSelected: (v) => setState(() {
                            _categoriesError = null;
                            if (v) {
                              _categories.add(c);
                            } else {
                              _categories.remove(c);
                            }
                          }),
                        ),
                    ],
                  ),
                  if (_categoriesError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _categoriesError!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],

                if (needPassword) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Buat Password (opsional)',
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dengan password, kamu juga bisa login memakai email, tidak hanya Google.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  AccessibleTextField(
                    labelAbove: true,
                    label: 'Password',
                    hintText: 'Minimal 8 karakter',
                    controller: _passwordController,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    errorText: errors['password'],
                    onChanged: (_) => accountCtrl.clearFieldError('password'),
                  ),
                  const SizedBox(height: 16),
                  AccessibleTextField(
                    labelAbove: true,
                    label: 'Konfirmasi Password',
                    hintText: 'Ulangi password',
                    controller: _confirmController,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    errorText: errors['confirm'],
                    onChanged: (_) => accountCtrl.clearFieldError('confirm'),
                  ),
                ],

                if (accountCtrl.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: accountCtrl.errorMessage!),
                ],
                if (_profileError != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _profileError!),
                ],

                const SizedBox(height: 24),
                AccessibleButton(
                  label: 'Simpan',
                  isLoading: _saving,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
