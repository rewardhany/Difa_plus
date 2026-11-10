import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Text field standar Difa+.
/// - [labelAbove] true: label (dengan ikon) di atas kolom dan [hintText]
///   di dalam kolom, seperti pada desain. Kalau false: label mengambang.
/// - Kalau [obscureText] true, otomatis ada tombol tampilkan/sembunyikan.
class AccessibleTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final String? errorText;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final bool labelAbove;

  const AccessibleTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.onChanged,
    this.hintText,
    this.labelAbove = false,
  });

  @override
  State<AccessibleTextField> createState() => _AccessibleTextFieldState();
}

class _AccessibleTextFieldState extends State<AccessibleTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.labelAbove ? null : widget.label,
        hintText: widget.hintText,
        errorText: widget.errorText,
        prefixIcon: (!widget.labelAbove && widget.prefixIcon != null)
            ? Icon(widget.prefixIcon)
            : null,
        suffixIcon: widget.obscureText
            ? IconButton(
                tooltip: _obscured
                    ? 'Tampilkan kata sandi'
                    : 'Sembunyikan kata sandi',
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
      ),
    );

    if (!widget.labelAbove) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Semantics(label: widget.label, child: field),
      ],
    );
  }
}
