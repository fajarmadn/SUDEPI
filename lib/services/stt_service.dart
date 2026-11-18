import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'haptic_service.dart';

/// Layanan Speech-To-Text (STT) Offline-First dengan Auto-Fallback,
/// Contextual Phrases Rupiah, Earcon Getaran `tik-tik`, dan No Silent Timeout.
class SttService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isInitialized = false;
  bool _preferOffline = true;
  bool _isListening = false;
  bool _manualStopRequested = false;
  bool _keepAliveWhileHolding = false;
  bool _isRestartingKeepAlive = false;
  bool _capturedInCurrentSession = false;
  String _lastRecognizedWords = '';
  int _sessionId = 0;

  VoidCallback? _onListeningStateChanged;
  VoidCallback? _activeSilentTimeoutCallback;
  void Function(String recognizedWords, bool isFinal)? _activeResultCallback;

  bool get isListening => _isListening;
  bool get isPreferOffline => _preferOffline;
  String get lastRecognizedWords => _lastRecognizedWords;

  static const List<String> rupiahContextualPhrases = [
    'seribu',
    'dua ribu',
    'lima ribu',
    'sepuluh ribu',
    'dua puluh ribu',
    'dua puluh lima ribu',
    'lima puluh ribu',
    'seratus ribu',
    'lanjut',
    'lanjutkan',
    'ulang',
    'ulangi',
    'hapus',
    'ganti',
    'kembali',
  ];

  void setStateListener(VoidCallback? listener) {
    _onListeningStateChanged = listener;
  }

  Future<bool> ensureInitialized() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      return _isInitialized;
    } catch (_) {
      _isInitialized = false;
      return false;
    }
  }

  void _handleStatus(String status) {
    if (status == 'listening') {
      _isListening = true;
      _onListeningStateChanged?.call();
    } else if (status == 'notListening' || status == 'done') {
      // Jika pengguna masih menahan layar (Continuous Hold Keep-Alive),
      // segera nyalakan ulang sesi pengenalan suara Android tanpa memutus status listening.
      if (_keepAliveWhileHolding && !_manualStopRequested) {
        if (status == 'done' || !_speechToText.isListening) {
          _scheduleKeepAliveRestart(_sessionId, delayMs: 70);
        }
        return;
      }

      final wasListening = _isListening;
      _isListening = false;
      _onListeningStateChanged?.call();

      if (wasListening &&
          !_manualStopRequested &&
          !_capturedInCurrentSession &&
          status == 'done') {
        final callback = _activeSilentTimeoutCallback;
        _activeSilentTimeoutCallback = null;
        callback?.call();
      }
    }
  }

  void _handleError(SpeechRecognitionError error) {
    final msg = error.errorMsg.toLowerCase();

    // Auto-fallback jika paket bahasa offline belum diunduh di HP
    if (_preferOffline &&
        (msg.contains('language') ||
            msg.contains('offline') ||
            msg.contains('client') ||
            msg.contains('unavailable'))) {
      _preferOffline = false;
      final resCb = _activeResultCallback;
      final timeoutCb = _activeSilentTimeoutCallback;
      if (resCb != null && timeoutCb != null && !_manualStopRequested) {
        startListening(
          onResult: resCb,
          onSilentTimeout: timeoutCb,
          playEarcon: false,
          keepAliveWhileHolding: _keepAliveWhileHolding,
        );
        return;
      }
    }

    // Jika sedang dalam mode tahan layar (Continuous Hold Keep-Alive) dan terjadi jeda hening
    // (error_speech_timeout / error_no_match / error_client), otomatis buka kembali mikrofon!
    if (_keepAliveWhileHolding && !_manualStopRequested) {
      _scheduleKeepAliveRestart(_sessionId, delayMs: 120);
      return;
    }

    _isListening = false;
    _onListeningStateChanged?.call();

    if (!_manualStopRequested && !_capturedInCurrentSession) {
      final callback = _activeSilentTimeoutCallback;
      _activeSilentTimeoutCallback = null;
      callback?.call();
    }
  }

  Future<void> _scheduleKeepAliveRestart(
    int expectedSessionId, {
    int delayMs = 70,
  }) async {
    if (_isRestartingKeepAlive) return;
    _isRestartingKeepAlive = true;
    try {
      await Future.delayed(Duration(milliseconds: delayMs));
      if (!_keepAliveWhileHolding ||
          _manualStopRequested ||
          expectedSessionId != _sessionId) {
        return;
      }
      if (_speechToText.isListening) return;
      await _startListenPass(expectedSessionId);
    } finally {
      _isRestartingKeepAlive = false;
    }
  }

  Future<void> _startListenPass(int currentSession) async {
    if (_manualStopRequested || currentSession != _sessionId) return;
    try {
      _isListening = true;
      _onListeningStateChanged?.call();

      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          if (currentSession != _sessionId) return;
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            _lastRecognizedWords = words;
            _activeResultCallback?.call(words, result.finalResult);
          }
          // Jika Android SpeechRecognizer mengakhiri 1 segmen kalimat (finalResult == true)
          // padahal jari pengguna masih menahan layar, jadwalkan sambungan sesi berikutnya.
          if (result.finalResult &&
              _keepAliveWhileHolding &&
              !_manualStopRequested) {
            _scheduleKeepAliveRestart(currentSession, delayMs: 80);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: 'id_ID',
          onDevice: _preferOffline,
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          pauseFor: const Duration(seconds: 10),
          listenFor: const Duration(seconds: 60),
          contextualPhrases: rupiahContextualPhrases,
        ),
      );
    } catch (_) {
      if (_preferOffline) {
        _preferOffline = false;
        if (!_manualStopRequested && currentSession == _sessionId) {
          await _startListenPass(currentSession);
        }
      } else if (_keepAliveWhileHolding &&
          !_manualStopRequested &&
          currentSession == _sessionId) {
        _scheduleKeepAliveRestart(currentSession, delayMs: 180);
      } else {
        _isListening = false;
        _onListeningStateChanged?.call();
        _activeSilentTimeoutCallback?.call();
      }
    }
  }

  /// Membuka mikrofon STT (mendukung mode Continuous Hold Keep-Alive agar pengguna
  /// dapat menyebut nominal atau "ulangi" berkali-kali tanpa batas selama jari menahan layar).
  Future<void> startListening({
    required void Function(String recognizedWords, bool isFinal) onResult,
    required VoidCallback onSilentTimeout,
    bool playEarcon = true,
    bool keepAliveWhileHolding = true,
  }) async {
    final int currentSession = ++_sessionId;
    _manualStopRequested = true;
    _keepAliveWhileHolding = false;
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}

    final available = await ensureInitialized();
    if (currentSession != _sessionId) return;

    if (!available) {
      _isListening = false;
      _onListeningStateChanged?.call();
      onSilentTimeout();
      return;
    }

    _manualStopRequested = false;
    _keepAliveWhileHolding = keepAliveWhileHolding;
    _capturedInCurrentSession = false;
    _lastRecognizedWords = '';
    _activeResultCallback = onResult;
    _activeSilentTimeoutCallback = onSilentTimeout;

    if (playEarcon) {
      await HapticService.micListeningEarcon();
    }
    if (currentSession != _sessionId) return;

    await _startListenPass(currentSession);
  }

  /// Menonaktifkan penyambungan ulang otomatis ketika jari pengguna sudah dilepas dari layar,
  /// sambil membiarkan segmen suara terakhir menyelesaikan Smart Tail-Buffer.
  void stopKeepAlive() {
    _keepAliveWhileHolding = false;
  }

  /// Menandai bahwa sesi saat ini sudah berhasil menangkap angka/perintah valid
  /// sehingga tidak memicu peringatan No Silent Timeout saat mikrofon berhenti.
  void markCapturedValidInput() {
    _capturedInCurrentSession = true;
  }

  /// Menghentikan mikrofon STT secara sengaja (misal saat pengguna melepas Push-to-Talk atau mengetik Numpad).
  Future<void> stopListening() async {
    _manualStopRequested = true;
    _keepAliveWhileHolding = false;
    _activeSilentTimeoutCallback = null;
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
    _sessionId++;
    _isListening = false;
    _onListeningStateChanged?.call();
  }

  Future<void> dispose() async {
    await stopListening();
  }
}
