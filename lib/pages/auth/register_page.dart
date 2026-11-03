import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/registration_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../core/widgets/centered_content.dart';
import '../../core/widgets/difa_logo.dart';
import '../../core/widgets/error_banner.dart';
import '../../models/user_account.dart';

/// Boundary: RegisterPage
/// Merealisasikan UC-01 Register Account.
///
/// Dipakai bersama oleh Mahasiswa dan Pendamping (actor "Pengguna"
/// pada Sequence Diagram UC-01). Logic tidak berubah, hanya tampilan.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  UserRole _selectedRole = UserRole.mahasiswa;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // submitRegistrationForm() -> register(role, personalData)
  Future<void> _handleSubmit() async {
    final controller = context.read<RegistrationController>();
    final success = await controller.register(
      role: _selectedRole,
      fullName: _nameController.text,
      email: _emailController.text.trim(),
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
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
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: DifaLogo(size: 48)),
                const SizedBox(height: 24),
                Text(
                  'Daftar Akun',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bergabunglah dengan Difa+ untuk akses layanan yang lebih baik.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),

                // selectRoleAndFillData(role, personalData)
                Text('Daftar sebagai', style: textTheme.labelLarge),
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
                  label: 'Nama Lengkap',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  label: 'Kata Sandi (minimal 8 karakter)',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  label: 'Konfirmasi Kata Sandi',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                ),

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