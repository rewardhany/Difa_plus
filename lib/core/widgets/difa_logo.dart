import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Logo Difa+ (hati + sosok manusia). Bisa diganti aset logo asli nanti
/// tanpa mengubah Page yang memakainya.
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
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.favorite, color: AppColors.primaryDark, size: size),
                Padding(
                  padding: EdgeInsets.only(bottom: size * 0.04),
                  child: Icon(
                    Icons.accessibility_new,
                    color: Colors.white,
                    size: size * 0.42,
                  ),
                ),
              ],
            ),
          ),
          if (showText) ...[
            SizedBox(width: size * 0.18),
            Text(
              'Difa+',
              style: TextStyle(
                fontSize: size * 0.72,
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
