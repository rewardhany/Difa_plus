import 'package:flutter/material.dart';

/// Tombol standar Difa+.
///
/// Gaya (warna, bentuk, ukuran font) diambil dari tema aktif, jadi
/// otomatis ikut berubah saat mode adaptif aktif (mis. teks besar
/// untuk netra). Kalau [outlined] true, dipakai sebagai tombol sekunder.
class AccessibleButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? semanticHint;
  final IconData? icon;
  final bool outlined;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.semanticHint,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final VoidCallback? handler = isLoading ? null : onPressed;

    final Widget content = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: outlined ? null : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );

    final Widget button = outlined
        ? OutlinedButton(onPressed: handler, child: content)
        : ElevatedButton(onPressed: handler, child: content);

    if (semanticHint == null) return button;
    return Semantics(hint: semanticHint, child: button);
  }
}
