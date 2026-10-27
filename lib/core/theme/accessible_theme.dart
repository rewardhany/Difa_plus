import 'package:flutter/material.dart';
import '../../models/disability_profile.dart';
import 'app_theme.dart';

/// Menghasilkan varian ThemeData berdasarkan kategori disabilitas
/// yang dipilih mahasiswa (UC-03) dan dimuat ulang tiap sesi (UC-04).
///
/// Ini adalah implementasi dari konsep "UI adaptif" yang jadi
/// pembeda utama Difa+: satu backend/model yang sama, tapi
/// tampilan berubah sesuai AccessibilityController.loadAccessibilityProfile().
///
/// Fase 1 baru menangani 3 kategori (netra, rungu/wicara, fisik) —
/// intelektual & mental/psikososial disiapkan sebagai TODO di Fase 2+
/// karena kebutuhannya lebih ke penyederhanaan konten, bukan ThemeData.
class AccessibleTheme {
  AccessibleTheme._();

  static ThemeData resolve(List<DisabilityCategory> categories) {
    if (categories.isEmpty) return AppTheme.base;

    // Prioritas netra paling tinggi: kontras tinggi + teks besar
    // dibutuhkan juga oleh kategori lain, jadi aman digabung.
    if (categories.contains(DisabilityCategory.netra)) {
      return _highContrastLargeText();
    }

    if (categories.contains(DisabilityCategory.fisik)) {
      return _largeTapTargets();
    }

    // Rungu/wicara: UI visual standar, bedanya ada di notification
    // channel (getar/visual) yang diatur di NotificationService,
    // bukan di ThemeData.
    return AppTheme.base;
  }

  static ThemeData _highContrastLargeText() {
    final base = AppTheme.base;
    return base.copyWith(
      colorScheme: const ColorScheme.highContrastLight(),
      textTheme: base.textTheme.apply(fontSizeFactor: 1.3),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          minimumSize: const Size.fromHeight(60),
        ),
      ),
    );
  }

  static ThemeData _largeTapTargets() {
    final base = AppTheme.base;
    return base.copyWith(
      visualDensity: VisualDensity.comfortable,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
        ),
      ),
    );
  }
}
