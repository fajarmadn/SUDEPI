import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../models/rupiah_denomination.dart';

/// Jembatan komunikasi MethodChannel ke mesin inferensi Kotlin ONNX Runtime YOLO26n.
class YoloChannelService {
  static const MethodChannel _channel = MethodChannel('com.sudepi.app/yolo26');

  bool _modelLoaded = false;
  bool _isAnalyzing = false;

  bool get isModelLoaded => _modelLoaded;
  bool get isAnalyzing => _isAnalyzing;

  /// Memuat model `assets/models/sudepi_yolo26n_640.onnx` di sisi native Android.
  Future<bool> initModel() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'initModel',
        {'assetPath': 'assets/models/sudepi_yolo26n_640.onnx'},
      );
      _modelLoaded = res != null && res['loaded'] == true;
      return _modelLoaded;
    } catch (_) {
      _modelLoaded = false;
      return false;
    }
  }

  /// Mengirimkan plane YUV_420_888 ke Kotlin untuk kalkulasi luminance Y-plane,
  /// rotasi sensor 90 derajat, letterbox 640x640, dan inferensi NMS-Free [1, 300, 6].
  Future<FrameAnalysisResult?> analyzeCameraFrame({
    required CameraImage image,
    required int sensorOrientation,
    double confThreshold = 0.25,
  }) async {
    if (_isAnalyzing || image.planes.length < 3) return null;
    _isAnalyzing = true;
    try {
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'analyzeFrame',
        {
          'yBytes': yPlane.bytes,
          'uBytes': uPlane.bytes,
          'vBytes': vPlane.bytes,
          'width': image.width,
          'height': image.height,
          'yRowStride': yPlane.bytesPerRow,
          'uvRowStride': uPlane.bytesPerRow,
          'uvPixelStride': uPlane.bytesPerPixel ?? 1,
          'sensorOrientation': sensorOrientation,
          'confThreshold': confThreshold,
        },
      );

      if (res == null) return null;
      final parsed = FrameAnalysisResult.fromMap(res);
      if (parsed.skipped) return null;
      return parsed;
    } catch (_) {
      return null;
    } finally {
      _isAnalyzing = false;
    }
  }

  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('disposeModel');
    } catch (_) {}
  }
}
