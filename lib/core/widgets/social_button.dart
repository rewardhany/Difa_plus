import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tombol "Login/Daftar dengan ..." (Google, Apple). Dipakai di halaman
/// Login dan Daftar. Kalau [onPressed] null, tombol tampil nonaktif.
class SocialButton extends StatelessWidget {
  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final bool isLoading;

  const SocialButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Row(
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

/// Huruf "G" berwarna biru sebagai penanda Google.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
