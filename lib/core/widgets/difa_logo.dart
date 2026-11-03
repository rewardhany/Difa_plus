import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Logo Difa+ sederhana (ikon + teks). Bisa diganti aset logo asli
/// nanti tanpa mengubah Page yang memakainya.
class DifaLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const DifaLogo({super.key, this.size = 40, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Difa Plus',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
            child: Icon(
              Icons.accessibility_new,
              color: Colors.white,
              size: size * 0.62,
            ),
          ),
          if (showText) ...[
            SizedBox(width: size * 0.3),
            Text(
              'Difa+',
              style: TextStyle(
                fontSize: size * 0.7,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
