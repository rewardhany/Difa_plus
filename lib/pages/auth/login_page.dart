import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auth_flow.dart';
import '../../core/widgets/accessible_button.dart';
import '../../core/widgets/accessible_text_field.dart';
import '../../core/widgets/centered_content.dart';
import '../../core/widgets/difa_logo.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/social_button.dart';

/// Boundary: LoginPage
/// Merealisasikan UC-02 Login (email/password dan Google).
///
/// Setelah login valid, UC-02 memanggil UC-04 Load Accessibility
/// Profile lewat <<include>> (lihat core/utils/auth_flow.dart).
/// "Ingat saya", "Lupa password?", dan login Apple masih tampilan saja.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _googleLoading = false;

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
    final success = await authController.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!success || !mounted) return;
    await goAfterAuth(context);
  }

  Future<void> _handleGoogle() async {
    final auth = context.read<AuthController>();
    setState(() => _googleLoading = true);

    final result = await auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);

    switch (result) {
      case GoogleAuthResult.cancelled:
      case GoogleAuthResult.failed:
        return; // pesan error (kalau ada) tampil lewat AuthController
      case GoogleAuthResult.existingAccount:
        await goAfterAuth(context, viaGoogle: true);
        return;
      case GoogleAuthResult.newAccount:
        await goAfterAuth(context, viaGoogle: true, isNewAccount: true);
        return;
      case GoogleAuthResult.needsRole:
        // Akun Google ini belum terdaftar: tanyakan peran dulu.
        final role = await askRole(context);
        if (!mounted) return;
        if (role == null) {
          await auth.logout();
          return;
        }
        final ok = await auth.finishGoogleSignUp(role);
        if (!ok || !mounted) return;
        await goAfterAuth(context, viaGoogle: true, isNewAccount: true);
        return;
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
                  isLoading: controller.status == AuthStatus.loading &&
                      !_googleLoading,
                  onPressed: _googleLoading ? null : _handleLogin,
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
                SocialButton(
                  label: 'Login dengan Google',
                  leading: const GoogleMark(),
                  isLoading: _googleLoading,
                  onPressed: _handleGoogle,
                ),
                const SizedBox(height: 12),
                SocialButton(
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
