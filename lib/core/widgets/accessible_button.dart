import 'package:flutter/material.dart';

/// Tombol standar Difa+.
///
/// Kenapa dibikin reusable dari Fase 1 (bukan dipakai `ElevatedButton`
/// polos di tiap Page): semua kebutuhan aksesibilitas (label semantik,
/// target sentuh minimal 48x48, state loading) harus konsisten di
/// SELURUH fitur, bukan ditambal belakangan per halaman.
class AccessibleButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? semanticHint;
  final IconData? icon;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.semanticHint,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: semanticHint,
      enabled: onPressed != null && !isLoading,
      child: SizedBox(
        width: double.infinity,
        height: 52, // > 48dp, memenuhi target sentuh minimum aksesibilitas
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon),
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: const TextStyle(fontSize: 16)),
                  ],
                ),
        ),
      ),
    );
  }
}
