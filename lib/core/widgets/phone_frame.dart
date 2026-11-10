import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Di layar lebar (Chrome/desktop), seluruh aplikasi ditampilkan di dalam
/// bingkai seukuran HP supaya tampilannya sama seperti di perangkat mobile.
/// Di HP sungguhan (layar sempit) widget ini tidak melakukan apa-apa.
class PhoneFrame extends StatelessWidget {
  final Widget child;

  const PhoneFrame({super.key, required this.child});

  static const double phoneWidth = 420;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= phoneWidth + 48) return child;

    final frameHeight = math.min(mq.size.height - 32, 900.0);

    return ColoredBox(
      color: const Color(0xFFDDE5F0),
      child: Center(
        child: Container(
          width: phoneWidth,
          height: frameHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFF0F172A), width: 8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: MediaQuery(
              data: mq.copyWith(
                size: Size(phoneWidth - 16, frameHeight - 16),
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
