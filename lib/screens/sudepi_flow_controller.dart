import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../constants/sudepi_prompts.dart';
import '../models/rupiah_denomination.dart';
import '../services/haptic_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/yolo_channel_service.dart';
import '../utils/indonesian_number_parser.dart';
import 'change_verification_screen.dart';
import 'standby_screen.dart';
import 'transaction_dialog_screen.dart';

enum SudepiFlowStep {
  standby,
  inputTotalBelanja,
  inputUangDiberikan,
  verifyChange,
}

/// Pengendali utama 4 layar inti SUDEPI (Tanpa Layar Kasir) dengan arsitektur
/// 100% Zero-Button Blind-First UX, Object-Presence Auto-Torch, Smart Push-to-Talk
/// Continuous Hold Keep-Alive + Instant 0 ms Release, NumPad Darurat Tersembunyi,
/// Temporal Consistency Buffer 5-frame, dan Remove-Bill Gate.
class SudepiFlowController extends StatefulWidget {
  const SudepiFlowController({super.key});

  @override
  State<SudepiFlowController> createState() => _SudepiFlowControllerState();
}

class _SudepiFlowControllerState extends State<SudepiFlowController>
    with WidgetsBindingObserver {
  final TtsService _tts = TtsService();
  final SttService _stt = SttService();
  final YoloChannelService _yolo = YoloChannelService();

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isStreamActive = false;

  SudepiFlowStep _currentStep = SudepiFlowStep.standby;

  // State Senter (Object-Presence Auto-Torch di Cahaya Redup + Kendali Manual Ketuk 2x)
  bool _isTorchOn = false;
  bool _torchAutoLatched = false;
  DateTime? _autoTorchTurnedOnAt;
  DateTime? _noBillObjectSince;
  int _dimObjectFramesCount = 0;
  bool _userManuallyDisabledTorchForCurrentBill = false;
  DateTime? _lowLightSince;
  DateTime? _lastLowLightWarningTime;

  // State Deteksi & Temporal Consistency Buffer (5 frame)
  final List<int> _slidingBuffer = <int>[];
  DateTime? _subThresholdSince;
  DateTime? _lastSubThresholdTickTime;

  // State Layar 1 (Mode Siaga)
  RupiahDenomination? _standbyLockedDenom;
  int _standbyLockedAccuracy = 0;
  int? _lastStandbySpokenClassId;
  DateTime? _lastStandbySpokenTime;
  DateTime? _standbyNoBillSince;

  // State Simulasi Debug Opsional (Ketuk 3x pada judul)
  bool _showSimulationBar = false;

  // State Layar 2 & 3 (Dialog Transaksi, Smart Push-to-Talk & Hidden NumPad)
  int _totalBelanja = 0;
  int _uangDiberikan = 0;
  bool _isNumpadVisible = false;
  bool _isPushToTalkActive = false;
  int _pttSessionToken = 0;
  int? _pttCapturedAmount;
  bool _pttHasRepeatIntent = false;
  bool _pttHasAdvanceIntent = false;
  bool _pttHasBackIntent = false;
  bool _pttReceivedFinal = false;

  // State Layar 4 (Cek Kembalian & Remove-Bill Gate)
  int _totalScannedChange = 0;
  bool _waitingForBillRemoval = false;
  int _emptyFramesCount = 0;
  DateTime? _lastBillLockedTime;

  int get _expectedChange =>
      (_uangDiberikan - _totalBelanja).clamp(0, 999999999);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stt.setStateListener(() {
      if (mounted) setState(() {});
    });
    _initializeAllServices();
  }

  Future<void> _initializeAllServices() async {
    await _tts.init();
    final modelOk = await _yolo.initModel();
    if (!modelOk && mounted) {
      setState(() {
        _showSimulationBar = true;
      });
    }
    await _initCamera();
    await _tts.speakInterrupt(SudepiPrompts.standbyBoot);
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
            _showSimulationBar = true;
          });
        }
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      _cameraController = controller;
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }

      if (_isCameraScreen(_currentStep)) {
        await _startCameraStreamIfNeeded();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _showSimulationBar = true;
        });
      }
    }
  }

  bool _isCameraScreen(SudepiFlowStep step) {
    return step == SudepiFlowStep.standby ||
        step == SudepiFlowStep.verifyChange;
  }

  Future<void> _startCameraStreamIfNeeded() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isStreamActive) {
      return;
    }
    try {
      _isStreamActive = true;
      await controller.startImageStream(_onCameraFrame);
    } catch (_) {
      _isStreamActive = false;
    }
  }

  Future<void> _stopCameraStreamIfNeeded() async {
    final controller = _cameraController;
    if (controller == null || !_isStreamActive) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
    } finally {
      _isStreamActive = false;
    }
  }

  /// Pemrosesan setiap frame kamera dari stream YUV_420_888.
  Future<void> _onCameraFrame(CameraImage image) async {
    if (!_isCameraScreen(_currentStep) || _yolo.isAnalyzing) return;

    final sensorOrientation =
        _cameraController?.description.sensorOrientation ?? 90;

    final result = await _yolo.analyzeCameraFrame(
      image: image,
      sensorOrientation: sensorOrientation,
      confThreshold: 0.25,
    );

    if (result == null || !mounted || !_isCameraScreen(_currentStep)) return;

    // 1. Evaluasi Object-Presence Auto-Torch (Menyala otomatis saat ada objek uang di tempat redup,
    //    tetap menyala selama uang masih di kamera, dan otomatis mati saat uang dilepas dari kamera)
    final shouldWaitLightStabilization =
        await _evaluateObjectPresenceAutoTorch(result);
    if (shouldWaitLightStabilization || !mounted) return;

    // 2. Evaluasi Instruksi Suara "Rentangkan Uang" (tanpa getaran, karena getaran khusus saat mengunci deteksi)
    _evaluateUnfoldVoicePrompt(result);

    // 3. Evaluasi Deteksi Utama (Mode Siaga vs Cek Kembalian)
    if (_currentStep == SudepiFlowStep.standby) {
      _processStandbyFrame(result);
    } else if (_currentStep == SudepiFlowStep.verifyChange) {
      _processVerifyChangeFrame(result);
    }
  }

  /// Object-Presence Auto-Torch:
  /// - Saat senter mati dan terdeteksi objek uang di tempat redup (`meanLuminance < 95` atau
  ///   `< 115` dengan kandidat belum terkunci): nyalakan senter otomatis, bersihkan buffer frame gelap,
  ///   dan beri jeda adaptasi exposure 380 ms agar warna asli uang terbaca akurat.
  /// - Selama objek uang masih berada di depan kamera (`hasBillObject == true`): pertahankan senter
  ///   tetap menyala agar pemindaian berulang berjalan konsisten seperti kondisi cahaya terang.
  /// - Begitu objek uang dilepas/dijauhkan dari kamera (`hasBillObject == false` selama 1,8 detik):
  ///   matikan senter secara otomatis sehingga tidak pernah lupa dimatikan dan bebas kedap-kedip.
  Future<bool> _evaluateObjectPresenceAutoTorch(
    FrameAnalysisResult result,
  ) async {
    final now = DateTime.now();

    if (!_isTorchOn) {
      if (!result.hasBillObject) {
        _dimObjectFramesCount = 0;
        _userManuallyDisabledTorchForCurrentBill = false;
        _evaluateLowLightWarning(result.meanLuminance);
        return false;
      }

      if (_userManuallyDisabledTorchForCurrentBill) {
        return false;
      }

      if (result.meanLuminance < 95.0) {
        _dimObjectFramesCount += 2;
        _slidingBuffer.clear();
      } else if (result.meanLuminance < 115.0 && !result.detected) {
        _dimObjectFramesCount += 1;
      } else {
        _dimObjectFramesCount = 0;
      }

      if (_dimObjectFramesCount >= 3) {
        _dimObjectFramesCount = 0;
        await _setAutoTorch(true);
        return true;
      }

      // Selama 1-2 frame awal di cahaya redup sebelum senter menyala, tahan penguncian
      // agar frame kuning/gelap tidak sempat mendakwa nominal yang salah (misal Rp10rb lusuh -> Rp1rb).
      if (result.meanLuminance < 95.0) {
        return true;
      }
      return false;
    }

    // Jika senter sedang menyala karena Auto-Torch:
    if (_torchAutoLatched) {
      // Jeda stabilisasi Auto-Exposure kamera selama 380 ms tepat setelah senter otomatis menyala
      if (_autoTorchTurnedOnAt != null &&
          now.difference(_autoTorchTurnedOnAt!) <
              const Duration(milliseconds: 380)) {
        _slidingBuffer.clear();
        return true;
      }

      if (result.hasBillObject) {
        // Objek uang masih ada di depan kamera -> pertahankan senter tetap menyala
        _noBillObjectSince = null;
      } else {
        // Objek uang sudah tidak terlihat di kamera -> hitung mundur 1,8 detik lalu matikan otomatis
        _noBillObjectSince ??= now;
        if (now.difference(_noBillObjectSince!) >=
            const Duration(milliseconds: 1800)) {
          _noBillObjectSince = null;
          _dimObjectFramesCount = 0;
          await _setAutoTorch(false);
        }
      }
    }

    return false;
  }

  Future<void> _setAutoTorch(bool turnOn) async {
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setFlashMode(
          turnOn ? FlashMode.torch : FlashMode.off,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _isTorchOn = turnOn;
      _torchAutoLatched = turnOn;
      _lowLightSince = null;
      if (turnOn) {
        _autoTorchTurnedOnAt = DateTime.now();
        _noBillObjectSince = null;
        _slidingBuffer.clear();
      } else {
        _autoTorchTurnedOnAt = null;
        _noBillObjectSince = null;
      }
    });
  }

  /// Peringatan Cahaya Redup saat tidak ada objek uang di kamera (Y < 42 selama 3 detik).
  void _evaluateLowLightWarning(double meanLuminance) {
    if (_isTorchOn) {
      _lowLightSince = null;
      return;
    }

    final now = DateTime.now();
    if (meanLuminance < 42.0) {
      _lowLightSince ??= now;
      if (now.difference(_lowLightSince!) >= const Duration(seconds: 3)) {
        final canWarn = !_tts.isSpeaking &&
            (_lastLowLightWarningTime == null ||
                now.difference(_lastLowLightWarningTime!) >=
                    const Duration(seconds: 20));
        if (canWarn) {
          _lastLowLightWarningTime = now;
          _lowLightSince = now;
          _tts.speakInterrupt(SudepiPrompts.lowLightWarning);
        }
      }
    } else {
      _lowLightSince = null;
    }
  }

  /// Saat Ikon Senter di Kanan Atas Diketuk 1x:
  /// Memberikan info status senter & cara menyalakan atau mematikan senter.
  Future<void> _onTorchIndicatorTapInfo() async {
    await HapticService.numpadKeyTap();
    if (_isTorchOn) {
      await _tts.speakInterrupt(
        _torchAutoLatched
            ? SudepiPrompts.torchAutoOnInfo
            : SudepiPrompts.torchManualOnInfo,
      );
    } else {
      await _tts.speakInterrupt(SudepiPrompts.torchOffInfo);
    }
  }

  /// Kendali Senter Manual via Double Tap di Layar 1 & Layar 4.
  Future<void> _toggleTorchManual() async {
    final controller = _cameraController;
    final targetState = !_isTorchOn;

    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setFlashMode(
          targetState ? FlashMode.torch : FlashMode.off,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _isTorchOn = targetState;
      _torchAutoLatched = false;
      _autoTorchTurnedOnAt = null;
      _noBillObjectSince = null;
      _dimObjectFramesCount = 0;
      _userManuallyDisabledTorchForCurrentBill = !targetState;
      _lowLightSince = null;
    });

    await HapticService.torchTogglePulse();
    await _tts.speakInterrupt(
      targetState ? SudepiPrompts.torchTurnedOn : SudepiPrompts.torchTurnedOff,
    );
  }

  /// Mematikan senter saat keluar dari layar kamera (masuk ke Layar 2 atau Layar 3).
  Future<void> _turnOffTorchOnLeaveCamera() async {
    _lowLightSince = null;
    _noBillObjectSince = null;
    _autoTorchTurnedOnAt = null;
    _dimObjectFramesCount = 0;
    _userManuallyDisabledTorchForCurrentBill = false;
    if (_isTorchOn) {
      final controller = _cameraController;
      if (controller != null && controller.value.isInitialized) {
        try {
          await controller.setFlashMode(FlashMode.off);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isTorchOn = false;
          _torchAutoLatched = false;
        });
      }
    }
  }

  /// Instruksi Suara saat Uang Terlipat / Belum Memenuhi Standar Keyakinan Ketat:
  /// Jika kamera mendeteksi kandidat uang yang ditahan oleh Veto Lipatan atau ambang 3-Tier
  /// (`needsUnfoldPrompt == true`) selama 2,2 detik berturut-turut, ucapkan instruksi suara
  /// "Mohon rentangkan uang kertas." tanpa getaran (getaran hanya dipakai saat deteksi terkunci).
  void _evaluateUnfoldVoicePrompt(FrameAnalysisResult result) {
    final now = DateTime.now();
    if (!result.detected && result.needsUnfoldPrompt) {
      _subThresholdSince ??= now;
      if (now.difference(_subThresholdSince!) >=
          const Duration(milliseconds: 2200)) {
        final recentlySpokenDenom = _lastStandbySpokenTime != null &&
            now.difference(_lastStandbySpokenTime!) <
                const Duration(milliseconds: 3500);
        final canSpeakPrompt = !_tts.isSpeaking &&
            !recentlySpokenDenom &&
            (_lastSubThresholdTickTime == null ||
                now.difference(_lastSubThresholdTickTime!) >=
                    const Duration(seconds: 6));
        if (canSpeakPrompt) {
          _lastSubThresholdTickTime = now;
          _subThresholdSince = now;
          _tts.speakInterrupt(SudepiPrompts.unfoldBillPrompt);
        }
      }
    } else {
      _subThresholdSince = null;
    }
  }

  /// Kalibrasi Ambang Keyakinan Berjenjang 3 Tingkat (3-Tier Confidence Threshold):
  /// - Tier 1 (Kontras Tinggi & Nominal Besar: Rp20.000 [4], Rp50.000 [5], Rp100.000 [6]): >= 0.86 (86%)
  /// - Tier 2 (Kontras Menengah: Rp1.000 [0], Rp5.000 [2], Rp10.000 [3]): >= 0.80 (80%)
  /// - Tier 3 (Warna Netral: Rp2.000 [1]): >= 0.74 (74%)
  bool _isCandidateConfidentEnough(FrameAnalysisResult result) {
    if (!result.detected) return false;
    switch (result.classId) {
      case 4:
      case 5:
      case 6:
        return result.confidence >= 0.86;
      case 0:
      case 2:
      case 3:
        return result.confidence >= 0.80;
      case 1:
        return result.confidence >= 0.74;
      default:
        return false;
    }
  }

  /// Logika Layar 1 (Mode Siaga): Sliding buffer 5 frame, minimal 4 frame konsisten,
  /// serta auto-reset kartu tampilan saat uang dijauhkan dari kamera selama 1,4 detik.
  void _processStandbyFrame(FrameAnalysisResult result) {
    if (!result.hasBillObject) {
      _standbyNoBillSince ??= DateTime.now();
      if (_standbyLockedDenom != null &&
          DateTime.now().difference(_standbyNoBillSince!) >=
              const Duration(milliseconds: 1400)) {
        setState(() {
          _standbyLockedDenom = null;
          _standbyLockedAccuracy = 0;
          _slidingBuffer.clear();
        });
      }
      return;
    }

    _standbyNoBillSince = null;

    final candidateClass =
        _isCandidateConfidentEnough(result) ? result.classId : -1;

    _slidingBuffer.add(candidateClass);
    if (_slidingBuffer.length > 5) {
      _slidingBuffer.removeAt(0);
    }

    if (candidateClass == -1 || _slidingBuffer.length < 4) return;

    final matchCount =
        _slidingBuffer.where((c) => c == candidateClass).length;
    if (matchCount >= 4) {
      final denom = RupiahDenomination.fromClassId(candidateClass);
      if (denom != null) {
        _lockStandbyDenomination(denom, result.accuracyPercent);
      }
    }
  }

  void _lockStandbyDenomination(RupiahDenomination denom, int accuracyPercent) {
    final now = DateTime.now();
    final isSameClassOnCooldown = _lastStandbySpokenClassId == denom.classId &&
        _lastStandbySpokenTime != null &&
        now.difference(_lastStandbySpokenTime!) <
            const Duration(milliseconds: 3500);

    setState(() {
      _standbyLockedDenom = denom;
      _standbyLockedAccuracy = accuracyPercent.clamp(58, 100);
    });

    if (!isSameClassOnCooldown) {
      _lastStandbySpokenClassId = denom.classId;
      _lastStandbySpokenTime = now;
      _announceStandbyDenomination(denom);
    }
  }

  /// Matriks Haptik Per Nominal + Anti-Collision Delay 180 ms sebelum TTS berbicara.
  Future<void> _announceStandbyDenomination(RupiahDenomination denom) async {
    await HapticService.vibrateForDenomination(denom.classId);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted || _currentStep != SudepiFlowStep.standby) return;
    await _tts.speakInterrupt(denom.spokenName);
  }

  /// Logika Layar 4 (Cek Kembalian Sekuensial) + Remove-Bill Gate.
  void _processVerifyChangeFrame(FrameAnalysisResult result) {
    // Jika kembalian sudah pas, hentikan pemindaian otomatis
    if (_totalScannedChange == _expectedChange) return;

    final now = DateTime.now();

    // Remove-Bill Gate: tunggu sampai uang ditarik keluar minimal 4 frame tanpa deteksi + jeda 2 detik
    if (_waitingForBillRemoval) {
      final isFrameEmpty = !result.detected || result.confidence < 0.30;
      if (isFrameEmpty) {
        _emptyFramesCount++;
      } else {
        _emptyFramesCount = 0;
      }

      final cooldownPassed = _lastBillLockedTime != null &&
          now.difference(_lastBillLockedTime!) >= const Duration(seconds: 2);

      if (_emptyFramesCount >= 4 && cooldownPassed) {
        setState(() {
          _waitingForBillRemoval = false;
          _emptyFramesCount = 0;
          _slidingBuffer.clear();
        });
      }
      return;
    }

    final candidateClass =
        _isCandidateConfidentEnough(result) ? result.classId : -1;

    _slidingBuffer.add(candidateClass);
    if (_slidingBuffer.length > 5) {
      _slidingBuffer.removeAt(0);
    }

    if (candidateClass == -1 || _slidingBuffer.length < 4) return;

    final matchCount =
        _slidingBuffer.where((c) => c == candidateClass).length;
    if (matchCount >= 4) {
      final denom = RupiahDenomination.fromClassId(candidateClass);
      if (denom != null) {
        _addScannedChangeBill(denom);
      }
    }
  }

  /// Menambahkan 1 lembar uang kembalian yang telah terverifikasi dan mengaktifkan Remove-Bill Gate.
  Future<void> _addScannedChangeBill(RupiahDenomination denom) async {
    final newTotal = _totalScannedChange + denom.nominal;
    final target = _expectedChange;

    setState(() {
      _totalScannedChange = newTotal;
      _waitingForBillRemoval = true;
      _emptyFramesCount = 0;
      _lastBillLockedTime = DateTime.now();
      _slidingBuffer.clear();
    });

    final billSpoken = IndonesianNumberParser.terbilangRupiah(denom.nominal);
    final totalSpoken = IndonesianNumberParser.terbilangRupiah(newTotal);

    // Getaran Haptik Terdiferensiasi Per Nominal + Jeda 180 ms sebelum TTS
    await HapticService.vibrateForDenomination(denom.classId);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted || _currentStep != SudepiFlowStep.verifyChange) return;

    if (newTotal < target) {
      final selisih = target - newTotal;
      final selisihSpoken = IndonesianNumberParser.terbilangRupiah(selisih);
      if (selisih < 1000) {
        // Sisa di bawah Rp1.000 pasti berupa koin (tidak ada pecahan uang kertas < Rp1.000)
        await _tts.speakInterrupt(
          SudepiPrompts.changeCoinRemainder(
            billSpoken: billSpoken,
            totalSpoken: totalSpoken,
            selisihSpoken: selisihSpoken,
          ),
        );
      } else {
        await _tts.speakInterrupt(
          SudepiPrompts.changeRemaining(
            billSpoken: billSpoken,
            totalSpoken: totalSpoken,
            selisihSpoken: selisihSpoken,
          ),
        );
      }
    } else if (newTotal == target) {
      await HapticService.successLongPulse();
      await _tts.speakInterrupt(
        SudepiPrompts.changeExactMatch(
          billSpoken: billSpoken,
          totalSpoken: totalSpoken,
        ),
      );
    } else {
      final targetSpoken = IndonesianNumberParser.terbilangRupiah(target);
      await HapticService.warningPulse();
      await _tts.speakInterrupt(
        SudepiPrompts.changeExceeded(
          billSpoken: billSpoken,
          totalSpoken: totalSpoken,
          targetSpoken: targetSpoken,
        ),
      );
    }
  }

  // ===========================================================================
  // INTERAKSI & NAVIGASI ANTAR-LAYAR (100% ZERO-BUTTON GESTURE MAP)
  // ===========================================================================

  /// Toggle Mode Simulasi Debug (ketuk 3x pada judul).
  Future<void> _toggleSimulationMode() async {
    final nextState = !_showSimulationBar;
    setState(() {
      _showSimulationBar = nextState;
    });
    await HapticService.numpadKeyTap();
    await _tts.speakInterrupt(
      nextState
          ? SudepiPrompts.simulationEnabled
          : SudepiPrompts.simulationDisabled,
    );
  }

  /// Layar 1: Ketuk 1x di mana saja (Where-Am-I murni tanpa menyebut uang bekas sebelumnya).
  Future<void> _onStandbySingleTap() async {
    await HapticService.numpadKeyTap();
    await _tts.speakInterrupt(SudepiPrompts.standbySingleTapInfo);
  }

  /// Masuk ke Layar 2 (Total Belanja) — Tanpa Auto-Listen, NumPad Tersembunyi.
  Future<void> _enterStepTwoTotalBelanja({bool resetValues = true}) async {
    _isPushToTalkActive = false;
    _pttSessionToken++;
    await _stt.stopListening();
    await _stopCameraStreamIfNeeded();
    await _turnOffTorchOnLeaveCamera();

    setState(() {
      _currentStep = SudepiFlowStep.inputTotalBelanja;
      _isNumpadVisible = false;
      if (resetValues) {
        _totalBelanja = 0;
        _uangDiberikan = 0;
      }
    });

    await HapticService.numpadKeyTap();
    if (resetValues) {
      await _tts.speakInterrupt(SudepiPrompts.enterTotalBelanjaFresh);
    } else {
      final belanjaSpoken = _totalBelanja == 0
          ? SudepiPrompts.emptyAmountLabel
          : IndonesianNumberParser.terbilangRupiah(_totalBelanja);
      await _tts.speakInterrupt(
        SudepiPrompts.returnTotalBelanja(belanjaSpoken),
      );
    }
  }

  /// Masuk ke Layar 3 (Uang yang Diberikan) — Tanpa Auto-Listen, NumPad Tersembunyi.
  /// Sekaligus mematikan kamera & senter apabila kembali (Usap Kanan) dari Layar Cek Kembalian.
  Future<void> _enterStepThreeUangDiberikan({bool announceSaved = true}) async {
    _isPushToTalkActive = false;
    _pttSessionToken++;
    await _stt.stopListening();
    await _stopCameraStreamIfNeeded();
    await _turnOffTorchOnLeaveCamera();

    setState(() {
      _currentStep = SudepiFlowStep.inputUangDiberikan;
      _isNumpadVisible = false;
    });

    if (announceSaved) {
      final belanjaSpoken =
          IndonesianNumberParser.terbilangRupiah(_totalBelanja);
      await _tts.speakInterrupt(
        SudepiPrompts.enterUangDiberikanSaved(belanjaSpoken),
      );
    } else {
      await HapticService.numpadKeyTap();
      final uangSpoken = _uangDiberikan == 0
          ? SudepiPrompts.emptyAmountLabel
          : IndonesianNumberParser.terbilangRupiah(_uangDiberikan);
      await _tts.speakInterrupt(SudepiPrompts.returnUangDiberikan(uangSpoken));
    }
  }

  /// Layar 2 & 3: Ketuk 1x di mana saja (Info tahap, nominal saat ini, & instruksi singkat).
  Future<void> _onDialogSingleTap() async {
    if (_isPushToTalkActive) return;
    await HapticService.numpadKeyTap();

    final isStep3 = _currentStep == SudepiFlowStep.inputUangDiberikan;
    final currentVal = isStep3 ? _uangDiberikan : _totalBelanja;
    final stepName = isStep3
        ? SudepiPrompts.stepThreeLabel
        : SudepiPrompts.stepTwoLabel;
    final valSpoken = currentVal == 0
        ? SudepiPrompts.emptyAmountLabel
        : IndonesianNumberParser.terbilangRupiah(currentVal);
    final modeHint = _isNumpadVisible
        ? SudepiPrompts.dialogSingleTapNumpadHint
        : SudepiPrompts.dialogSingleTapVoiceHint;

    await _tts.speakInterrupt(
      SudepiPrompts.dialogSingleTapSummary(
        stepName: stepName,
        valSpoken: valSpoken,
        modeHint: modeHint,
      ),
    );
  }

  /// Layar 2 & 3: Smart Push-to-Talk Mulai (`onLongPressStart` — Hanya saat NumPad Tertutup).
  Future<void> _handlePushToTalkStart() async {
    if (_isNumpadVisible) return;
    if (_currentStep != SudepiFlowStep.inputTotalBelanja &&
        _currentStep != SudepiFlowStep.inputUangDiberikan) {
      return;
    }

    final int myToken = ++_pttSessionToken;
    _isPushToTalkActive = true;
    _pttCapturedAmount = null;
    _pttHasRepeatIntent = false;
    _pttHasAdvanceIntent = false;
    _pttHasBackIntent = false;
    _pttReceivedFinal = false;

    if (mounted) setState(() {});

    await _tts.stop();
    await HapticService.numpadKeyTap();

    if (!_isPushToTalkActive || myToken != _pttSessionToken || !mounted) return;

    await _stt.startListening(
      onResult: _onPttSpeechResult,
      onSilentTimeout: () {},
      playEarcon: false,
      keepAliveWhileHolding: true,
    );
  }

  /// Callback real-time selama jari menahan layar maupun selama micro-flush:
  /// Memproses nominal secara live tanpa batas percobaan (mendukung "ulangi"/"hapus"
  /// maupun penyebutan nominal baru berkali-kali secara beruntun dalam 1 tahanan).
  void _onPttSpeechResult(String rawWords, bool isFinal) {
    final parsed = IndonesianNumberParser.parseVoiceInput(rawWords);
    _pttReceivedFinal = isFinal;
    if (parsed.hasAdvanceIntent) {
      _pttHasAdvanceIntent = true;
    }
    if (parsed.hasBackIntent) {
      _pttHasBackIntent = true;
    }

    final isStep3 = _currentStep == SudepiFlowStep.inputUangDiberikan;

    if (parsed.amount != null && parsed.amount! >= 100) {
      final isNewAmount = _pttCapturedAmount != parsed.amount;
      _pttCapturedAmount = parsed.amount;
      _pttHasRepeatIntent = false;
      _stt.markCapturedValidInput();
      if (mounted) {
        setState(() {
          if (isStep3) {
            _uangDiberikan = parsed.amount!;
          } else {
            _totalBelanja = parsed.amount!;
          }
        });
      }
      if (isNewAmount) {
        HapticService.sttCapturedPulse();
      }
    } else if (parsed.hasRepeatIntent &&
        (parsed.amount == null || parsed.amount! < 100)) {
      final wasNotCleared =
          !_pttHasRepeatIntent || _pttCapturedAmount != null;
      _pttCapturedAmount = null;
      _pttHasRepeatIntent = true;
      _pttHasAdvanceIntent = false;
      _pttHasBackIntent = false;
      _stt.markCapturedValidInput();
      if (mounted) {
        setState(() {
          if (isStep3) {
            _uangDiberikan = 0;
          } else {
            _totalBelanja = 0;
          }
        });
      }
      if (wasNotCleared) {
        HapticService.numpadDeletePulse();
      }
    }
  }

  /// Layar 2 & 3: Smart Push-to-Talk Selesai (`onLongPressEnd` — Instant 0 ms + Micro-Flush 300 ms).
  Future<void> _handlePushToTalkEnd() async {
    if (!_isPushToTalkActive) return;
    final int myToken = _pttSessionToken;
    _stt.stopKeepAlive();

    final bool alreadyCapturedWhileHolding =
        _pttCapturedAmount != null ||
        _pttHasRepeatIntent ||
        _pttHasBackIntent ||
        _pttHasAdvanceIntent;

    if (!alreadyCapturedWhileHolding) {
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted || myToken != _pttSessionToken) return;
        if (_pttCapturedAmount != null ||
            _pttHasRepeatIntent ||
            _pttHasBackIntent ||
            _pttReceivedFinal ||
            !_stt.isListening) {
          break;
        }
      }
    }

    _isPushToTalkActive = false;
    await _stt.stopListening();

    if (!mounted || myToken != _pttSessionToken) return;
    if (_currentStep != SudepiFlowStep.inputTotalBelanja &&
        _currentStep != SudepiFlowStep.inputUangDiberikan) {
      return;
    }

    if (_pttHasBackIntent) {
      await _handleDialogBack();
      return;
    }

    final isStep3 = _currentStep == SudepiFlowStep.inputUangDiberikan;
    final int? captured = _pttCapturedAmount;

    if (_pttHasRepeatIntent && (captured == null || captured == 0)) {
      setState(() {
        if (isStep3) {
          _uangDiberikan = 0;
        } else {
          _totalBelanja = 0;
        }
      });
      await HapticService.numpadClearPulse();
      await _tts.speakInterrupt(SudepiPrompts.voiceClearedToZero);
      return;
    }

    if (captured != null && captured > 0) {
      setState(() {
        if (isStep3) {
          _uangDiberikan = captured;
        } else {
          _totalBelanja = captured;
        }
      });

      if (_pttHasAdvanceIntent) {
        await _handleDialogConfirmContinue();
        return;
      }

      await HapticService.sttCapturedPulse();
      final amountSpoken = IndonesianNumberParser.terbilangRupiah(captured);
      await _tts.speakInterrupt(SudepiPrompts.voiceAmountCaptured(amountSpoken));
    } else {
      // Jangan menimpa atau menghapus nominal yang sudah ada sebelumnya!
      await HapticService.numpadDeletePulse();
      await _tts.speakInterrupt(SudepiPrompts.voiceNotHeard);
    }
  }

  /// Usap ke Atas (Swipe Up) di Layar 2 & 3: Buka Papan Angka (NumPad) Darurat.
  Future<void> _handleOpenNumpad() async {
    if (_isNumpadVisible) return;
    _isPushToTalkActive = false;
    _pttSessionToken++;
    await _stt.stopListening();

    setState(() {
      _isNumpadVisible = true;
    });
    await HapticService.numpadKeyTap();
    await _tts.speakInterrupt(SudepiPrompts.numpadOpened);
  }

  /// Usap ke Bawah (Swipe Down) di Layar 2 & 3: Tutup Papan Angka (NumPad) Darurat.
  Future<void> _handleCloseNumpad() async {
    if (!_isNumpadVisible) return;
    setState(() {
      _isNumpadVisible = false;
    });
    await HapticService.numpadKeyTap();
    await _tts.speakInterrupt(SudepiPrompts.numpadClosed);
  }

  /// Penekanan tombol angka Numpad (`0`..`9`) dengan suara per tombol + nilai saat ini.
  Future<void> _handleDialogDigit(String digit) async {
    await _stt.stopListening();
    await HapticService.numpadKeyTap();

    final isStep3 = _currentStep == SudepiFlowStep.inputUangDiberikan;
    final currentVal = isStep3 ? _uangDiberikan : _totalBelanja;
    final nextStr = currentVal == 0 ? digit : '$currentVal$digit';

    // Batasi maksimal 9 digit (ratusan juta Rupiah)
    if (nextStr.length > 9) return;
    final nextVal = int.tryParse(nextStr) ?? currentVal;

    setState(() {
      if (isStep3) {
        _uangDiberikan = nextVal;
      } else {
        _totalBelanja = nextVal;
      }
    });

    final digitWord = IndonesianNumberParser.digitToWord(digit);
    if (nextVal < 10) {
      await _tts.speakInterrupt(digitWord);
    } else {
      final totalWord = IndonesianNumberParser.terbilangAngka(nextVal);
      await _tts.speakInterrupt(
        SudepiPrompts.numpadDigitAppended(
          digitWord: digitWord,
          totalWord: totalWord,
        ),
      );
    }
  }

  /// Tombol `Hapus` pada Numpad: menghapus 1 digit terakhir + sebut sisa nominal.
  Future<void> _handleDialogBackspace() async {
    await _stt.stopListening();
    await HapticService.numpadDeletePulse();

    final isStep3 = _currentStep == SudepiFlowStep.inputUangDiberikan;
    final currentVal = isStep3 ? _uangDiberikan : _totalBelanja;

    if (currentVal == 0) {
      await _tts.speakInterrupt(SudepiPrompts.numpadBackspaceAlreadyZero);
      return;
    }

    final str = currentVal.toString();
    final removedDigit = str[str.length - 1];
    final remainingStr =
        str.length <= 1 ? '0' : str.substring(0, str.length - 1);
    final nextVal = int.tryParse(remainingStr) ?? 0;

    setState(() {
      if (isStep3) {
        _uangDiberikan = nextVal;
      } else {
        _totalBelanja = nextVal;
      }
    });

    final removedWord = IndonesianNumberParser.digitToWord(removedDigit);
    final remainingWord = nextVal == 0
        ? SudepiPrompts.zeroRupiahSpoken
        : IndonesianNumberParser.terbilangRupiah(nextVal);
    await _tts.speakInterrupt(
      SudepiPrompts.numpadBackspaceRemoved(
        removedWord: removedWord,
        remainingWord: remainingWord,
      ),
    );
  }

  /// Tombol `AC` pada Numpad saat Diketuk 1x (`onTap`):
  /// JANGAN menghapus angka — hanya berikan info suara cara pakai.
  Future<void> _handleDialogAcSingleTapInfo() async {
    await _stt.stopListening();
    await HapticService.numpadKeyTap();
    await _tts.speakInterrupt(SudepiPrompts.numpadAcSingleTapInfo);
  }

  /// Tombol `AC` pada Numpad saat Ditahan (`onLongPress`):
  /// Kosongkan seluruh nominal kembali ke Rp 0.
  Future<void> _handleDialogClear() async {
    await _stt.stopListening();
    await HapticService.numpadClearPulse();

    final isStep3 = _currentStep == SudepiFlowStep.inputUangDiberikan;
    setState(() {
      if (isStep3) {
        _uangDiberikan = 0;
      } else {
        _totalBelanja = 0;
      }
    });

    await _tts.speakInterrupt(SudepiPrompts.numpadClearedAll);
  }

  /// Usap Kiri (Swipe Left) di Layar 2 & 3: Validasi & Lanjut ke Tahap Berikutnya.
  /// Dari Layar 3 (Uang yang Diberikan):
  /// - Jika uang pas (`_uangDiberikan == _totalBelanja`), langsung selesai & kembali ke Mode Siaga.
  /// - Jika ada kembalian (`_uangDiberikan > _totalBelanja`), langsung buka kamera Cek Kembalian.
  Future<void> _handleDialogConfirmContinue() async {
    _isPushToTalkActive = false;
    _pttSessionToken++;
    await _stt.stopListening();

    if (_currentStep == SudepiFlowStep.inputTotalBelanja) {
      if (_totalBelanja <= 0) {
        await HapticService.warningPulse();
        await _tts.speakInterrupt(SudepiPrompts.dialogEmptyAmountWarning);
        return;
      }
      await HapticService.sttCapturedPulse();
      await _enterStepThreeUangDiberikan(announceSaved: true);
    } else if (_currentStep == SudepiFlowStep.inputUangDiberikan) {
      if (_uangDiberikan <= 0) {
        await HapticService.warningPulse();
        await _tts.speakInterrupt(SudepiPrompts.dialogEmptyAmountWarning);
        return;
      }
      if (_uangDiberikan < _totalBelanja) {
        final kurang = _totalBelanja - _uangDiberikan;
        final kurangSpoken = IndonesianNumberParser.terbilangRupiah(kurang);
        await HapticService.warningPulse();
        await _tts.speakInterrupt(
          SudepiPrompts.dialogInsufficientPayment(kurangSpoken),
        );
        return;
      }

      if (_expectedChange == 0) {
        await HapticService.successLongPulse();
        await _returnToStandby(
          spokenPrefix: SudepiPrompts.exactPaymentCompleted,
        );
      } else {
        await HapticService.sttCapturedPulse();
        await _enterVerifyChangeStep();
      }
    }
  }

  /// Usap Kanan (Swipe Right) di Layar 2 & 3: Kembali / Mundur 1 Tahap.
  Future<void> _handleDialogBack() async {
    _isPushToTalkActive = false;
    _pttSessionToken++;
    await _stt.stopListening();
    if (_currentStep == SudepiFlowStep.inputUangDiberikan) {
      await _enterStepTwoTotalBelanja(resetValues: false);
    } else {
      await _returnToStandby(spokenPrefix: SudepiPrompts.returnToStandbyShort);
    }
  }

  /// Masuk langsung ke Layar 4 (Cek Kembalian Sekuensial) dari Layar 3.
  Future<void> _enterVerifyChangeStep() async {
    _isPushToTalkActive = false;
    _pttSessionToken++;
    await _stt.stopListening();

    setState(() {
      _currentStep = SudepiFlowStep.verifyChange;
      _isNumpadVisible = false;
      _totalScannedChange = 0;
      _waitingForBillRemoval = false;
      _emptyFramesCount = 0;
      _lastBillLockedTime = null;
      _slidingBuffer.clear();
    });

    await _startCameraStreamIfNeeded();
    final targetSpoken =
        IndonesianNumberParser.terbilangRupiah(_expectedChange);
    await _tts.speakInterrupt(SudepiPrompts.enterVerifyChange(targetSpoken));
  }

  /// Layar 4 (Cek Kembalian): Ketuk 1x di mana saja (Where-Am-I check).
  Future<void> _onVerifyChangeSingleTap() async {
    await HapticService.numpadKeyTap();
    final target = _expectedChange;
    final scanned = _totalScannedChange;
    final targetSpoken = IndonesianNumberParser.terbilangRupiah(target);
    final scannedSpoken = IndonesianNumberParser.terbilangRupiah(scanned);

    if (scanned < target) {
      final sisaSpoken =
          IndonesianNumberParser.terbilangRupiah(target - scanned);
      await _tts.speakInterrupt(
        SudepiPrompts.verifyChangeSingleTapRemaining(
          targetSpoken: targetSpoken,
          scannedSpoken: scannedSpoken,
          sisaSpoken: sisaSpoken,
        ),
      );
    } else if (scanned == target) {
      await _tts.speakInterrupt(
        SudepiPrompts.verifyChangeSingleTapExact(
          targetSpoken: targetSpoken,
          scannedSpoken: scannedSpoken,
        ),
      );
    } else {
      await _tts.speakInterrupt(
        SudepiPrompts.verifyChangeSingleTapExceeded(
          targetSpoken: targetSpoken,
          scannedSpoken: scannedSpoken,
        ),
      );
    }
  }

  /// Layar 4 (Cek Kembalian): Tahan Layar (Hold / Long Press) -> Reset Hitungan Kembalian ke Rp 0.
  Future<void> _handleResetChangeScan() async {
    await HapticService.numpadClearPulse();
    setState(() {
      _totalScannedChange = 0;
      _waitingForBillRemoval = false;
      _emptyFramesCount = 0;
      _lastBillLockedTime = null;
      _slidingBuffer.clear();
    });
    await _tts.speakInterrupt(SudepiPrompts.verifyChangeReset);
  }

  /// Menyelesaikan atau membatalkan transaksi dan kembali ke Layar 1 (Mode Siaga).
  Future<void> _returnToStandby({required String spokenPrefix}) async {
    _isPushToTalkActive = false;
    _pttSessionToken++;
    await _stt.stopListening();
    await _turnOffTorchOnLeaveCamera();

    setState(() {
      _currentStep = SudepiFlowStep.standby;
      _isNumpadVisible = false;
      _slidingBuffer.clear();
      _standbyLockedDenom = null;
      _standbyLockedAccuracy = 0;
      _totalBelanja = 0;
      _uangDiberikan = 0;
      _totalScannedChange = 0;
      _waitingForBillRemoval = false;
    });

    await _startCameraStreamIfNeeded();
    await _tts.speakInterrupt(spokenPrefix);
  }

  // ===========================================================================
  // HANDLER SIMULASI DEBUG OPSIONAL
  // ===========================================================================

  void _handleSimulateBill(RupiahDenomination denom) {
    if (_currentStep == SudepiFlowStep.standby) {
      _lockStandbyDenomination(denom, 99);
    } else if (_currentStep == SudepiFlowStep.verifyChange) {
      if (_waitingForBillRemoval) {
        _tts.speakInterrupt(SudepiPrompts.simulationRemoveBillFirst);
        return;
      }
      _addScannedChangeBill(denom);
    }
  }

  void _handleSimulateClearFrame() {
    setState(() {
      _waitingForBillRemoval = false;
      _emptyFramesCount = 0;
      _slidingBuffer.clear();
    });
    _tts.speakInterrupt(SudepiPrompts.simulationReadyNextBill);
  }

  // ===========================================================================
  // LIFECYCLE & BUILD
  // ===========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _isPushToTalkActive = false;
      _pttSessionToken++;
      _stt.stopListening();
      _tts.stop();
      _stopCameraStreamIfNeeded();
      _turnOffTorchOnLeaveCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (_isCameraScreen(_currentStep)) {
        _startCameraStreamIfNeeded();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCameraStreamIfNeeded();
    _cameraController?.dispose();
    _stt.dispose();
    _tts.dispose();
    _yolo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case SudepiFlowStep.standby:
        return StandbyScreen(
          cameraController: _cameraController,
          isCameraInitialized: _isCameraInitialized,
          isTorchOn: _isTorchOn,
          isTorchAutoLatched: _torchAutoLatched,
          lockedDenomination: _standbyLockedDenom,
          lockedAccuracyPercent: _standbyLockedAccuracy,
          showSimulationBar: _showSimulationBar,
          onSingleTapAnywhere: _onStandbySingleTap,
          onStartTransaction: () =>
              _enterStepTwoTotalBelanja(resetValues: true),
          onToggleTorchManual: _toggleTorchManual,
          onTorchIndicatorTapInfo: _onTorchIndicatorTapInfo,
          onToggleSimulationMode: _toggleSimulationMode,
          onSimulateBill: _handleSimulateBill,
        );

      case SudepiFlowStep.inputTotalBelanja:
        return TransactionDialogScreen(
          isStepThree: false,
          currentAmount: _totalBelanja,
          isMicListening: _stt.isListening || _isPushToTalkActive,
          isNumpadVisible: _isNumpadVisible,
          onDigitPressed: _handleDialogDigit,
          onBackspacePressed: _handleDialogBackspace,
          onAcSingleTapInfo: _handleDialogAcSingleTapInfo,
          onClearPressed: _handleDialogClear,
          onSingleTapAnywhere: _onDialogSingleTap,
          onPushToTalkStart: _handlePushToTalkStart,
          onPushToTalkEnd: _handlePushToTalkEnd,
          onConfirmContinue: _handleDialogConfirmContinue,
          onBackPressed: _handleDialogBack,
          onOpenNumpad: _handleOpenNumpad,
          onCloseNumpad: _handleCloseNumpad,
        );

      case SudepiFlowStep.inputUangDiberikan:
        return TransactionDialogScreen(
          isStepThree: true,
          currentAmount: _uangDiberikan,
          isMicListening: _stt.isListening || _isPushToTalkActive,
          isNumpadVisible: _isNumpadVisible,
          onDigitPressed: _handleDialogDigit,
          onBackspacePressed: _handleDialogBackspace,
          onAcSingleTapInfo: _handleDialogAcSingleTapInfo,
          onClearPressed: _handleDialogClear,
          onSingleTapAnywhere: _onDialogSingleTap,
          onPushToTalkStart: _handlePushToTalkStart,
          onPushToTalkEnd: _handlePushToTalkEnd,
          onConfirmContinue: _handleDialogConfirmContinue,
          onBackPressed: _handleDialogBack,
          onOpenNumpad: _handleOpenNumpad,
          onCloseNumpad: _handleCloseNumpad,
        );

      case SudepiFlowStep.verifyChange:
        return ChangeVerificationScreen(
          cameraController: _cameraController,
          isCameraInitialized: _isCameraInitialized,
          isTorchOn: _isTorchOn,
          isTorchAutoLatched: _torchAutoLatched,
          targetChange: _expectedChange,
          totalScannedChange: _totalScannedChange,
          isWaitingBillRemoval: _waitingForBillRemoval,
          showSimulationBar: _showSimulationBar,
          onSingleTapAnywhere: _onVerifyChangeSingleTap,
          onFinishTransaction: () => _returnToStandby(
            spokenPrefix: SudepiPrompts.transactionFinishedReturnStandby,
          ),
          onResetScan: _handleResetChangeScan,
          onToggleTorchManual: _toggleTorchManual,
          onTorchIndicatorTapInfo: _onTorchIndicatorTapInfo,
          onBackPressed: () =>
              _enterStepThreeUangDiberikan(announceSaved: false),
          onToggleSimulationMode: _toggleSimulationMode,
          onSimulateBill: _handleSimulateBill,
          onSimulateClearFrame: _handleSimulateClearFrame,
        );
    }
  }
}
