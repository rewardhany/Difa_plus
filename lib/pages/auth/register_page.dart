import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/registration_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../core/widgets/centered_content.dart';
import '../../core/widgets/difa_logo.dart';
import '../../core/widgets/error_banner.dart';
import '../../models/disability_profile.dart';
import '../../models/user_account.dart';

/// Boundary: RegisterPage
/// Merealisasikan UC-01 Register Account.
///
/// Dipakai bersama oleh Mahasiswa dan Pendamping (actor "Pengguna"
/// pada Sequence Diagram UC-01). Pilihan "Jenis Disabilitas" (opsional,
/// hanya untuk Mahasiswa) menjadi pilihan awal di UC-03 setelah login.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  UserRole _selectedRole = UserRole.mahasiswa;
  final Set<DisabilityCategory> _selectedCategories = {};

  static const _chipCategories = [
    DisabilityCategory.netra,
    DisabilityCategory.runguWicara,
    DisabilityCategory.fisik,
  ];

  @override
  void dispose() {
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
    final success = await controller.register(
      role: _selectedRole,
      fullName: _nameController.text,
      email: _emailController.text.trim(),
      phone: _phoneController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      categories: _selectedRole == UserRole.mahasiswa
          ? _selectedCategories.toList()
          : const [],
    );

    if (success && mounted) {
      // showRegistrationConfirmation()
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi berhasil. Silakan login.')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
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
    final textTheme = Theme.of(context).textTheme;

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
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  labelAbove: true,
                  label: 'Email',
                  hintText: 'Masukkan email kamu',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  labelAbove: true,
                  label: 'No. Telepon (opsional)',
                  hintText: 'Masukkan nomor telepon',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  labelAbove: true,
                  label: 'Password',
                  hintText: 'Minimal 8 karakter',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  labelAbove: true,
                  label: 'Konfirmasi Password',
                  hintText: 'Ulangi password',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                ),

                if (_selectedRole == UserRole.mahasiswa) ...[
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      text: 'Jenis Disabilitas ',
                      style: textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                      children: const [
                        TextSpan(
                          text: '(opsional)',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
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
                          onSelected: (value) => setState(() {
                            if (value) {
                              _selectedCategories.add(c);
                            } else {
                              _selectedCategories.remove(c);
                            }
                          }),
                        ),
                    ],
                  ),
                ],

                // showValidationError(errors) — Exception Flow
                if (controller.status == RegistrationStatus.error &&
                    controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: controller.errorMessage!),
                ],

                const SizedBox(height: 24),
                AccessibleButton(
                  label: 'Daftar',
                  isLoading: controller.status == RegistrationStatus.loading,
                  onPressed: _handleSubmit,
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
