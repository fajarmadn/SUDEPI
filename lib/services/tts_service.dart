import 'package:flutter_tts/flutter_tts.dart';

/// Layanan suara Instant Barge-In TTS Bahasa Indonesia (`id-ID`).
/// Memotong kalimat lama secara instan (`stop()` sebelum `speak()`) tanpa memblokir UI.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;
  int _speechToken = 0;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _flutterTts.setLanguage('id-ID');
      await _flutterTts.setSpeechRate(0.57);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
      });
      _flutterTts.setErrorHandler((_) {
        _isSpeaking = false;
      });

      _initialized = true;
    } catch (_) {
      // Tetap aman jika berjalan pada perangkat/emulator tanpa engine TTS
    }
  }

  /// Memotong ucapan yang sedang berjalan detik itu juga, lalu mengucapkan [text].
  /// Mengembalikan `true` jika ucapan selesai penuh tanpa dipotong oleh panggilan TTS baru.
  Future<bool> speakInterrupt(String text) async {
    if (!_initialized) {
      await init();
    }
    final int myToken = ++_speechToken;
    try {
      _isSpeaking = false;
      await _flutterTts.stop();
      if (myToken != _speechToken) return false;
      _isSpeaking = true;
      await _flutterTts.speak(text);
      if (myToken == _speechToken) {
        _isSpeaking = false;
        return true;
      }
      return false;
    } catch (_) {
      _isSpeaking = false;
      return false;
    }
  }

  /// Menghentikan suara TTS seketika (digunakan saat Barge-In ke mikrofon STT).
  Future<void> stop() async {
    _speechToken++;
    _isSpeaking = false;
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
  }
}
