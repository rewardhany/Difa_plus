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
/// Profile lewat <<include>>. Logic tidak berubah, hanya tampilan.
/// "Ingat saya", "Lupa password?", dan login Google/Apple masih
/// tampilan saja (belum ada fiturnya).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _notAvailable(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature belum tersedia.')),
    );
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
                const Center(child: DifaLogo(size: 52)),
                const SizedBox(height: 24),
                Text(
                  'Selamat Datang Kembali',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masuk untuk melanjutkan perjalananmu.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
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
                  label: 'Password',
                  hintText: 'Masukkan password',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    ),
                    const Text('Ingat saya'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _notAvailable('Reset password'),
                      child: const Text('Lupa password?'),
                    ),
                  ],
                ),
                if (controller.status == AuthStatus.error &&
                    controller.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  ErrorBanner(message: controller.errorMessage!),
                  const SizedBox(height: 8),
                ],
                AccessibleButton(
                  label: 'Login',
                  isLoading: controller.status == AuthStatus.loading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                _SocialButton(
                  label: 'Login dengan Google',
                  leading: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                  onPressed: () => _notAvailable('Login dengan Google'),
                ),
                const SizedBox(height: 12),
                _SocialButton(
                  label: 'Login dengan Apple',
                  leading: const Icon(Icons.apple, size: 22),
                  onPressed: () => _notAvailable('Login dengan Apple'),
                ),
                const SizedBox(height: 16),
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

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 10),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}
