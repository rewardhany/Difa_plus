import 'package:flutter/material.dart';

/// Membatasi lebar konten supaya tetap enak dilihat di layar lebar
/// (Chrome/desktop), tapi tetap penuh di HP.
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth = 440,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
