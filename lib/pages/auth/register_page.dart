import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/registration_controller.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../models/user_account.dart';

/// Boundary: RegisterPage
/// Merealisasikan UC-01 Register Account.
///
/// Dipakai bersama oleh Mahasiswa maupun Pendamping (digabung
/// sebagai actor "Pengguna" pada Sequence Diagram UC-01, karena
/// alurnya identik).
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RegistrationController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun Difa+')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Buat Akun',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Daftar sebagai Mahasiswa atau Pendamping untuk mulai menggunakan Difa+.',
              ),
              const SizedBox(height: 24),

              // selectRoleAndFillData(role, personalData)
              Semantics(
                label: 'Pilih peran pendaftaran',
                child: SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.mahasiswa,
                      label: Text('Mahasiswa'),
                    ),
                    ButtonSegment(
                      value: UserRole.pendamping,
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
              ),
              const SizedBox(height: 16),
              AccessibleTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AccessibleTextField(
                label: 'Kata Sandi',
                controller: _passwordController,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              AccessibleTextField(
                label: 'Konfirmasi Kata Sandi',
                controller: _confirmPasswordController,
                obscureText: true,
              ),

              // showValidationError(errors) — Exception Flow
              if (controller.status == RegistrationStatus.error &&
                  controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true, // diumumkan otomatis oleh screen reader
                  child: Text(
                    controller.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              AccessibleButton(
                label: 'Daftar',
                isLoading: controller.status == RegistrationStatus.loading,
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: 12),

              // cancelRegistration() — Alternative Flow
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
