/// Definisi 7 kelas uang kertas Rupiah sesuai urutan baku data.yaml (0..6)
/// pada pelatihan model NMS-Free YOLO26n SUDEPI.
class RupiahDenomination {
  final int classId;
  final String code;
  final int nominal;
  final String displayText;
  final String spacedDisplayText;
  final String spokenName;
  final String shortLabel;

  const RupiahDenomination({
    required this.classId,
    required this.code,
    required this.nominal,
    required this.displayText,
    required this.spacedDisplayText,
    required this.spokenName,
    required this.shortLabel,
  });

  static const List<RupiahDenomination> values = [
    RupiahDenomination(
      classId: 0,
      code: 'rp1000',
      nominal: 1000,
      displayText: 'Rp1.000',
      spacedDisplayText: 'Rp 1.000',
      spokenName: 'Seribu rupiah',
      shortLabel: 'Rp1rb',
    ),
    RupiahDenomination(
      classId: 1,
      code: 'rp2000',
      nominal: 2000,
      displayText: 'Rp2.000',
      spacedDisplayText: 'Rp 2.000',
      spokenName: 'Dua ribu rupiah',
      shortLabel: 'Rp2rb',
    ),
    RupiahDenomination(
      classId: 2,
      code: 'rp5000',
      nominal: 5000,
      displayText: 'Rp5.000',
      spacedDisplayText: 'Rp 5.000',
      spokenName: 'Lima ribu rupiah',
      shortLabel: 'Rp5rb',
    ),
    RupiahDenomination(
      classId: 3,
      code: 'rp10000',
      nominal: 10000,
      displayText: 'Rp10.000',
      spacedDisplayText: 'Rp 10.000',
      spokenName: 'Sepuluh ribu rupiah',
      shortLabel: 'Rp10rb',
    ),
    RupiahDenomination(
      classId: 4,
      code: 'rp20000',
      nominal: 20000,
      displayText: 'Rp20.000',
      spacedDisplayText: 'Rp 20.000',
      spokenName: 'Dua puluh ribu rupiah',
      shortLabel: 'Rp20rb',
    ),
    RupiahDenomination(
      classId: 5,
      code: 'rp50000',
      nominal: 50000,
      displayText: 'Rp50.000',
      spacedDisplayText: 'Rp 50.000',
      spokenName: 'Lima puluh ribu rupiah',
      shortLabel: 'Rp50rb',
    ),
    RupiahDenomination(
      classId: 6,
      code: 'rp100000',
      nominal: 100000,
      displayText: 'Rp100.000',
      spacedDisplayText: 'Rp 100.000',
      spokenName: 'Seratus ribu rupiah',
      shortLabel: 'Rp100rb',
    ),
  ];

  static RupiahDenomination? fromClassId(int id) {
    if (id < 0 || id >= values.length) return null;
    return values[id];
  }
}

/// Representasi hasil analisis 1 frame kamera dari MethodChannel Kotlin YOLO26n.
class FrameAnalysisResult {
  final bool skipped;
  final bool modelLoaded;
  final double meanLuminance;
  final int inferenceTimeMs;
  final bool detected;
  final bool hasBillObject;
  final bool needsUnfoldPrompt;
  final int classId;
  final double confidence;
  final List<double> box;

  const FrameAnalysisResult({
    required this.skipped,
    required this.modelLoaded,
    required this.meanLuminance,
    required this.inferenceTimeMs,
    required this.detected,
    this.hasBillObject = false,
    this.needsUnfoldPrompt = false,
    required this.classId,
    required this.confidence,
    this.box = const [0, 0, 0, 0],
  });

  RupiahDenomination? get denomination =>
      detected ? RupiahDenomination.fromClassId(classId) : null;

  int get accuracyPercent => (confidence * 100).round().clamp(0, 100);

  factory FrameAnalysisResult.fromMap(Map<dynamic, dynamic> map) {
    final skipped = map['skipped'] == true;
    if (skipped) {
      return const FrameAnalysisResult(
        skipped: true,
        modelLoaded: true,
        meanLuminance: 128.0,
        inferenceTimeMs: 0,
        detected: false,
        hasBillObject: false,
        needsUnfoldPrompt: false,
        classId: -1,
        confidence: 0.0,
      );
    }

    final rawBox = map['box'];
    final parsedBox = rawBox is List
        ? rawBox.map((e) => (e as num).toDouble()).toList()
        : const <double>[0, 0, 0, 0];

    final isDetected = map['detected'] == true;
    final isNeedsUnfold = map['needsUnfoldPrompt'] == true;
    final hasObject =
        map['hasBillObject'] == true || isDetected || isNeedsUnfold;

    return FrameAnalysisResult(
      skipped: false,
      modelLoaded: map['modelLoaded'] != false,
      meanLuminance: (map['meanLuminance'] as num?)?.toDouble() ?? 128.0,
      inferenceTimeMs: (map['inferenceTimeMs'] as num?)?.toInt() ?? 0,
      detected: isDetected,
      hasBillObject: hasObject,
      needsUnfoldPrompt: isNeedsUnfold,
      classId: (map['classId'] as num?)?.toInt() ?? -1,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      box: parsedBox,
    );
  }
}
