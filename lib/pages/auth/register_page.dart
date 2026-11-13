import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/registration_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auth_flow.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../core/widgets/centered_content.dart';
import '../../core/widgets/difa_logo.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/social_button.dart';
import '../../models/disability_profile.dart';
import '../../models/user_account.dart';

/// Boundary: RegisterPage
/// Merealisasikan UC-01 Register Account.
///
/// Semua kolom wajib diisi (pesan "wajib diisi" muncul per kolom).
/// Khusus Mahasiswa, jenis disabilitas juga wajib. Alternatif: daftar
/// dengan Google, lalu melengkapi profil di Beranda.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _scroll = ScrollController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  UserRole _selectedRole = UserRole.mahasiswa;
  final Set<DisabilityCategory> _selectedCategories = {};
  bool _googleLoading = false;
  String? _googleError;

  static const _chipCategories = [
    DisabilityCategory.netra,
    DisabilityCategory.runguWicara,
    DisabilityCategory.fisik,
  ];

  @override
  void initState() {
    super.initState();
    // Bersihkan sisa error dari kunjungan sebelumnya.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RegistrationController>().clearAllErrors();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  // submitRegistrationForm() -> register(role, personalData)
  Future<void> _handleSubmit() async {
    final controller = context.read<RegistrationController>();
    setState(() => _googleError = null);

    final success = await controller.register(
      role: _selectedRole,
      fullName: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      categories: _selectedRole == UserRole.mahasiswa
          ? _selectedCategories.toList()
          : const [],
    );

    if (!mounted) return;

    if (!success && controller.fieldErrors.isNotEmpty && _scroll.hasClients) {
      // Gulir ke kolom yang bermasalah (atas), atau ke chip kalau hanya itu.
      final onlyCategories = controller.fieldErrors.length == 1 &&
          controller.fieldErrors.containsKey('categories');
      _scroll.animateTo(
        onlyCategories ? _scroll.position.maxScrollExtent : 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    if (success) {
      // showRegistrationConfirmation()
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi berhasil. Silakan login.')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  /// Daftar dengan Google: hanya nama + email yang terisi. No. telepon,
  /// jenis disabilitas, dan password dilengkapi nanti lewat banner di Beranda.
  Future<void> _handleGoogle() async {
    final auth = context.read<AuthController>();
    context.read<RegistrationController>().clearAllErrors();
    setState(() {
      _googleLoading = true;
      _googleError = null;
    });

    final result = await auth.signInWithGoogle(roleIfNew: _selectedRole);
    if (!mounted) return;
    setState(() => _googleLoading = false);

    switch (result) {
      case GoogleAuthResult.cancelled:
        return;
      case GoogleAuthResult.failed:
        setState(() => _googleError = auth.errorMessage);
        return;
      case GoogleAuthResult.existingAccount:
        await goAfterAuth(context, viaGoogle: true);
        return;
      case GoogleAuthResult.newAccount:
      case GoogleAuthResult.needsRole:
        await goAfterAuth(context, viaGoogle: true, isNewAccount: true);
        return;
    }
  }

  // cancelRegistration() — Alternative Flow UC-01
  void _handleCancel() {
    context.read<RegistrationController>().cancelRegistration();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RegistrationController>();
    final errors = controller.fieldErrors;
    final textTheme = Theme.of(context).textTheme;
    final isMahasiswa = _selectedRole == UserRole.mahasiswa;

    return Scaffold(
      appBar: AppBar(
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: DifaLogo(size: 28)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Daftar Akun',
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bergabunglah dengan Difa+ untuk akses layanan yang lebih baik.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // selectRoleAndFillData(role, personalData)
                Text(
                  'Daftar sebagai',
                  style: textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Pilih peran pendaftaran',
                  child: SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(
                        value: UserRole.mahasiswa,
                        icon: Icon(Icons.school_outlined),
                        label: Text('Mahasiswa'),
                      ),
                      ButtonSegment(
                        value: UserRole.pendamping,
                        icon: Icon(Icons.volunteer_activism_outlined),
                        label: Text('Pendamping'),
                      ),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (set) {
                      setState(() => _selectedRole = set.first);
                      controller.clearAllErrors();
                    },
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
                  onChanged: (_) => controller.clearFieldError('name'),
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  labelAbove: true,
                  label: 'Email',
                  hintText: 'Masukkan email kamu',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                  errorText: errors['email'],
                  onChanged: (_) => controller.clearFieldError('email'),
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
                  onChanged: (_) => controller.clearFieldError('phone'),
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  labelAbove: true,
                  label: 'Password',
                  hintText: 'Minimal 8 karakter',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  errorText: errors['password'],
                  onChanged: (_) => controller.clearFieldError('password'),
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  labelAbove: true,
                  label: 'Konfirmasi Password',
                  hintText: 'Ulangi password',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                  errorText: errors['confirm'],
                  onChanged: (_) => controller.clearFieldError('confirm'),
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
                          selected: _selectedCategories.contains(c),
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedCategories.add(c);
                              } else {
                                _selectedCategories.remove(c);
                              }
                            });
                            controller.clearFieldError('categories');
                          },
                        ),
                    ],
                  ),
                  if (errors['categories'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          errors['categories']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],

                // Error umum (mis. dari Firebase) atau error Google
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: controller.errorMessage!),
                ],
                if (_googleError != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _googleError!),
                ],

                const SizedBox(height: 24),
                AccessibleButton(
                  label: 'Daftar',
                  isLoading: controller.status == RegistrationStatus.loading,
                  onPressed: _googleLoading ? null : _handleSubmit,
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'atau',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                SocialButton(
                  label: 'Daftar dengan Google',
                  leading: const GoogleMark(),
                  isLoading: _googleLoading,
                  onPressed: _handleGoogle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Dengan Google, nama dan email terisi otomatis. '
                  'No. telepon, jenis disabilitas, dan password dilengkapi nanti di Beranda.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Sudah punya akun?'),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/login'),
                      child: const Text('Login'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _handleCancel,
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
