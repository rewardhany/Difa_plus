import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';

/// Boundary: LoginPage
/// Merealisasikan UC-02 Login.
///
/// Setelah login valid, UC-02 memanggil UC-04 Load Accessibility
/// Profile lewat <<include>> (lihat Ringkasan bagian 4 dokumen
/// Sequence Diagram P6). Pemanggilan itu dilakukan di sini, karena
/// AuthController dan AccessibilityController sengaja dipisah
/// supaya tiap Controller tetap fokus ke satu use case.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final authController = context.read<AuthController>();
    final accessibilityController = context.read<AccessibilityController>();

    final success = await authController.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!success || !mounted) return;

    // <<include>> UC-04 Load Accessibility Profile, dijalankan
    // tepat setelah sesi login terbentuk.
    final uid = authController.sessionToken!.uid;
    await accessibilityController.loadAccessibilityProfile(uid);

    if (!mounted) return;

    // Decision "Status Profil Disabilitas?" pada Activity Diagram UC-04.
    if (accessibilityController.needsProfileSetup) {
      Navigator.of(context).pushReplacementNamed('/profile');
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Masuk ke Difa+')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Text(
                'Selamat Datang Kembali',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
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

              if (controller.status == AuthStatus.error &&
                  controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    controller.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              AccessibleButton(
                label: 'Masuk',
                isLoading: controller.status == AuthStatus.loading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/register'),
                child: const Text('Belum punya akun? Daftar di sini'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
