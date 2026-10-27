import 'package:flutter/material.dart';

/// Tema dasar Difa+ sebelum disesuaikan ke kategori disabilitas.
/// Dipakai sebagai fallback saat DisabilityProfile masih kosong
/// (mis. sebelum UC-03 selesai dijalankan).
class AppTheme {
  AppTheme._();

  static ThemeData get base {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2962FF)),
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
