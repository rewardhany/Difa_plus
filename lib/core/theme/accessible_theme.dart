import 'package:flutter/material.dart';
import '../../models/disability_profile.dart';
import 'app_theme.dart';

/// Menghasilkan varian ThemeData berdasarkan kategori disabilitas
/// (UC-03 menyimpan, UC-04 memuat). Semua varian dibangun di atas
/// AppTheme.base, jadi desain tetap sama dan yang berubah hanya
/// bagian aksesibilitasnya.
///
/// Fase ini baru menangani 3 kategori (netra, rungu/wicara, fisik).
class AccessibleTheme {
  AccessibleTheme._();

  static ThemeData resolve(List<DisabilityCategory> categories) {
    if (categories.isEmpty) return AppTheme.base;

    // Prioritas netra paling tinggi: kontras tinggi + teks besar.
    if (categories.contains(DisabilityCategory.netra)) {
      return _highContrastLargeText();
    }
    if (categories.contains(DisabilityCategory.fisik)) {
      return _largeTapTargets();
    }
    // Rungu/wicara: UI visual standar; bedanya ada di jenis notifikasi
    // (getar/visual), bukan di ThemeData.
    return AppTheme.base;
  }

  static ThemeData _highContrastLargeText() {
    final base = AppTheme.base;
    const contrastBlue = Color(0xFF0000BA);
    return base.copyWith(
      colorScheme: const ColorScheme.highContrastLight(),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: Colors.white),
      textTheme: base.textTheme.apply(fontSizeFactor: 1.3),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: base.elevatedButtonTheme.style!.merge(
          ElevatedButton.styleFrom(
            backgroundColor: contrastBlue,
            foregroundColor: Colors.white,
            textStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            minimumSize: const Size.fromHeight(60),
          ),
        ),
      ),
    );
  }

  static ThemeData _largeTapTargets() {
    final base = AppTheme.base;
    return base.copyWith(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: base.elevatedButtonTheme.style!.merge(
          ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(60),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
