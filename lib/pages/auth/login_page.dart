import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../core/widgets/centered_content.dart';
import '../../core/widgets/difa_logo.dart';
import '../../core/widgets/error_banner.dart';

/// Boundary: LoginPage
/// Merealisasikan UC-02 Login.
///
/// Setelah login valid, UC-02 memanggil UC-04 Load Accessibility
/// Profile lewat <<include>>. Logic tidak berubah dari sebelumnya,
/// hanya tampilan yang diperbarui.
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

    // <<include>> UC-04 Load Accessibility Profile
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
                  'Selamat Datang Kembali',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk untuk melanjutkan perjalananmu.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                AccessibleTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                ),
                const SizedBox(height: 16),
                AccessibleTextField(
                  label: 'Kata Sandi',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                ),
                if (controller.status == AuthStatus.error &&
                    controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: controller.errorMessage!),
                ],
                const SizedBox(height: 24),
                AccessibleButton(
                  label: 'Masuk',
                  isLoading: controller.status == AuthStatus.loading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Belum punya akun?'),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/register'),
                      child: const Text('Daftar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}