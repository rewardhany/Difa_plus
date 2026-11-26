/// Aktor Sekunder: Maps Service
/// Dipakai pada UC-05 Show Campus Maps (penyedia data denah kampus).
///
/// Untuk sekarang datanya masih DATA CONTOH di bawah. Ganti isi
/// _seedCampusData dengan hasil survei kampus kalian sendiri
/// (nama gedung, posisi, ada ramp/lift/toilet difabel atau tidak).
/// Nanti bisa dipindah ke Firestore tanpa mengubah Controller,
/// karena kontraknya (requestMapData) sudah sama dengan sequence diagram.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
class MapsService {
  MapsService({this.simulateFailure = false});

  /// Set true untuk menguji Exception Flow "Data denah gagal diterima".
  final bool simulateFailure;

  /// requestMapData() pada sequence diagram UC-05.
  /// Mengembalikan null kalau data gagal diterima.
    /// requestMapData() pada sequence diagram UC-05.
  /// Memuat graf Gedung G1 (5 lantai) dari assets/data/difa_G1_graph.json.
  /// Mengembalikan null kalau data gagal diterima.
  Future<Map<String, dynamic>?> requestMapData() async {
    if (simulateFailure) return null;
    try {
      final raw = await rootBundle.loadString('assets/data/difa_G1_graph.json');
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
