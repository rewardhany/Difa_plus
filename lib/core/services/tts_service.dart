import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

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
  bool _voiceSelected = false;

    Future<void> _init() async {
    if (!_ready) {
      try {
        await _tts.setLanguage('id-ID');

        // Skala kecepatan Web/Desktop normal di ~1.0, sedangkan Mobile di ~0.5
        final isDesktopOrWeb = kIsWeb ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux;
        await _tts.setSpeechRate(isDesktopOrWeb ? 0.95 : 0.5);
        await _tts.setPitch(1.0);
      } catch (_) {}
      _ready = true;
    }

    if (!_voiceSelected) {
      await _selectIndonesianVoice();
    }
  }

  Future<void> _selectIndonesianVoice() async {
    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is! List || rawVoices.isEmpty) return;

      Map<String, String>? bestVoice;
      for (final item in rawVoices) {
        if (item is! Map) continue;
        final name = (item['name'] ?? '').toString();
        final locale = (item['locale'] ?? '').toString();
        final lowerName = name.toLowerCase();
        final lowerLocale = locale.toLowerCase().replaceAll('_', '-');

        final isIndonesian =
            lowerLocale.startsWith('id') || lowerName.contains('indonesia');
        if (!isIndonesian) continue;

        final candidate = {'name': name, 'locale': locale};

        // Prioritaskan suara Google (paling natural di Chrome & Android)
        if (lowerName.contains('google')) {
          bestVoice = candidate;
          break;
        }
        bestVoice ??= candidate;
      }

      if (bestVoice != null) {
        await _tts.setVoice(bestVoice);
        _voiceSelected = true;
        debugPrint('TTS pakai voice: $bestVoice');
      } else {
        debugPrint('TTS: voice Bahasa Indonesia belum tersedia di perangkat ini.');
      }
    } catch (_) {}
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
