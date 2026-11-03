import 'package:flutter_tts/flutter_tts.dart';

/// Pembungkus flutter_tts supaya Controller/Page tidak bergantung
/// langsung ke package-nya. Dipakai mulai UC-05 untuk mahasiswa netra
/// (dan nanti UC-07 Navigate by Audio).
///
/// Semua pemanggilan dibungkus try/catch: kalau TTS tidak tersedia di
/// device/browser, aplikasi tetap jalan, hanya tanpa suara.
/// Catatan: di Chrome, suara baru keluar setelah pengguna pernah
/// menyentuh/mengklik halaman sekali (aturan browser).
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
    _ready = true;
  }

  Future<void> speak(String text) async {
    try {
      await _init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}