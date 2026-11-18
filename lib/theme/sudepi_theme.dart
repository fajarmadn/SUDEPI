import 'package:flutter/material.dart';

import '../models/rupiah_denomination.dart';

/// Sistem Token Warna Disiplin Tinggi (8 Token Inti Tanpa Redundansi):
/// - 4 Netral (`background` #FFFFFF, `surface` #F1F3F4, `textPrimary` #202124, `textSecondary` #5F6368)
/// - 2 Aksen Interaktif (`primaryBlue` #1967D2, `primaryTint` #E8F0FE)
/// - 2 Semantik Status (`statusSuccess` #137333, `statusAlert` #F28B82)
/// - Scrim & Teks Kamera diturunkan 100% dari basis `#202124` dan `#FFFFFF` (hanya 2 tingkat putih: 100% & 70%).
class SudepiColors {
  // 1. Fondasi Netral & Tipografi
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF1F3F4);
  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);

  // 2. Aksen Biru Interaktif
  static const Color primaryBlue = Color(0xFF1967D2);
  static const Color primaryTint = Color(0xFFE8F0FE);

  // 3. Semantik Umpan Balik Status
  static const Color statusSuccess = Color(0xFF137333);
  static const Color statusAlert = Color(0xFFF28B82);

  // 4. Turunan Scrim & Teks Khusus Viewport Kamera (Berbasis #202124 & #FFFFFF)
  static const Color cameraScrim = Color(0xD9202124); // 85% #202124
  static const Color cameraControlScrim = Color(0x73202124); // 45% #202124
  static const Color cameraTextPrimary = Color(0xFFFFFFFF); // 100% putih
  static const Color cameraTextSecondary = Color(0xB3FFFFFF); // 70% putih
}

class SudepiTextStyles {
  static const String fontFamilyName = 'GoogleSans';

  static TextStyle sans({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = SudepiColors.textPrimary,
    double? height,
    double letterSpacing = -0.1,
  }) {
    return TextStyle(
      fontFamily: fontFamilyName,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Tipografi angka sejajar (keluarga GoogleSans tunggal + tabularFigures).
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color color = SudepiColors.textPrimary,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamilyName,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: -0.3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

/// Kotak siku putih `200x200 dp` di tengah viewport kamera.
class CameraCornerBrackets extends StatelessWidget {
  final double size;
  final double armLength;
  final double strokeWidth;

  const CameraCornerBrackets({
    super.key,
    this.size = 200,
    this.armLength = 30,
    this.strokeWidth = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerBracketsPainter(
          armLength: armLength,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  final double armLength;
  final double strokeWidth;

  const _CornerBracketsPainter({
    required this.armLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SudepiColors.cameraTextPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final a = armLength;

    final path = Path()
      // Top-left
      ..moveTo(0, a)
      ..lineTo(0, 0)
      ..lineTo(a, 0)
      // Top-right
      ..moveTo(w - a, 0)
      ..lineTo(w, 0)
      ..lineTo(w, a)
      // Bottom-left
      ..moveTo(0, h - a)
      ..lineTo(0, h)
      ..lineTo(a, h)
      // Bottom-right
      ..moveTo(w - a, h)
      ..lineTo(w, h)
      ..lineTo(w, h - a);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) => false;
}

/// Indikator Senter minimalis di kanan atas kamera:
/// - Ketuk 1x (`onTap`): membacakan status senter & cara menyalakan/mematikan.
/// - Ketuk 2x (`onDoubleTap`): menyalakan atau mematikan senter secara langsung.
class TorchToggleButton extends StatelessWidget {
  final bool isTorchOn;
  final bool isAutoLatched;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const TorchToggleButton({
    super.key,
    required this.isTorchOn,
    this.isAutoLatched = false,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isTorchOn
          ? 'Senter sedang menyala. Ketuk layar dua kali untuk mematikan.'
          : 'Senter sedang mati. Ketuk layar dua kali untuk menyalakan.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isTorchOn
                ? SudepiColors.primaryBlue
                : SudepiColors.cameraControlScrim,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            color: SudepiColors.cameraTextPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

/// Kanvas Gestur Layar Penuh (100% Zero-Button Full-Screen Gesture Canvas):
/// - Menerapkan filter vektor arah anti-miring:
///   * Horizontal Swipe: `dx.abs() > dy.abs() * 1.5` dan (`dx.abs() >= 60` atau kecepatan `>= 300 px/s`)
///   * Vertical Swipe  : `dy.abs() > dx.abs() * 1.5` dan (`dy.abs() >= 60` atau kecepatan `>= 300 px/s`)
/// - Menggunakan `Listener` untuk deteksi vektor usapan dan `GestureDetector` untuk Tap / Double-Tap / Hold,
///   sehingga bebas konflik Gesture Arena dengan Push-to-Talk maupun tombol NumPad.
class SudepiFullScreenGestureCanvas extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSingleTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;

  const SudepiFullScreenGestureCanvas({
    super.key,
    required this.child,
    this.onSingleTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onSwipeUp,
    this.onSwipeDown,
  });

  @override
  State<SudepiFullScreenGestureCanvas> createState() =>
      _SudepiFullScreenGestureCanvasState();
}

class _SudepiFullScreenGestureCanvasState
    extends State<SudepiFullScreenGestureCanvas> {
  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;
  bool _isHoldActive = false;

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDownPos = event.position;
    _pointerDownTime = DateTime.now();
    _isHoldActive = false;
  }

  void _handlePointerUp(PointerUpEvent event) {
    final startPos = _pointerDownPos;
    final startTime = _pointerDownTime;
    final wasHold = _isHoldActive;

    _pointerDownPos = null;
    _pointerDownTime = null;
    _isHoldActive = false;

    if (wasHold || startPos == null || startTime == null) return;

    final dx = event.position.dx - startPos.dx;
    final dy = event.position.dy - startPos.dy;
    final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
    final elapsedSec = (elapsedMs <= 10 ? 10 : elapsedMs) / 1000.0;
    final vx = dx / elapsedSec;
    final vy = dy / elapsedSec;

    // Filter Vektor Horizontal: dx.abs() > dy.abs() * 1.5
    if (dx.abs() > dy.abs() * 1.5 &&
        (dx.abs() >= 60.0 || (dx.abs() >= 36.0 && vx.abs() >= 300.0))) {
      if (dx > 0) {
        widget.onSwipeRight?.call();
      } else {
        widget.onSwipeLeft?.call();
      }
      return;
    }

    // Filter Vektor Vertikal: dy.abs() > dx.abs() * 1.5
    if (dy.abs() > dx.abs() * 1.5 &&
        (dy.abs() >= 60.0 || (dy.abs() >= 36.0 && vy.abs() >= 300.0))) {
      if (dy < 0) {
        widget.onSwipeUp?.call();
      } else {
        widget.onSwipeDown?.call();
      }
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _pointerDownPos = null;
    _pointerDownTime = null;
    _isHoldActive = false;
  }

  @override
  Widget build(BuildContext context) {
    final hasHoldCallbacks = widget.onLongPress != null ||
        widget.onLongPressStart != null ||
        widget.onLongPressEnd != null;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSingleTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress != null
            ? () {
                _isHoldActive = true;
                widget.onLongPress?.call();
              }
            : null,
        onLongPressStart: hasHoldCallbacks
            ? (_) {
                _isHoldActive = true;
                widget.onLongPressStart?.call();
              }
            : null,
        onLongPressEnd: hasHoldCallbacks
            ? (_) {
                widget.onLongPressEnd?.call();
              }
            : null,
        child: SizedBox.expand(child: widget.child),
      ),
    );
  }
}

/// Panel Simulasi Debug opsional (muncul jika judul diketuk 3x
/// atau jika kamera tidak tersedia di emulator).
class SimulationDebugPanel extends StatelessWidget {
  final void Function(RupiahDenomination denom) onSimulateBill;
  final VoidCallback? onSimulateClearFrame;
  final bool showClearButton;

  const SimulationDebugPanel({
    super.key,
    required this.onSimulateBill,
    this.onSimulateClearFrame,
    this.showClearButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SudepiColors.cameraScrim,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Simulasi Debug',
            style: SudepiTextStyles.sans(
              size: 11,
              weight: FontWeight.w600,
              color: SudepiColors.cameraTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final denom in RupiahDenomination.values)
                InkWell(
                  onTap: () => onSimulateBill(denom),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SudepiColors.primaryBlue,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      denom.shortLabel,
                      style: SudepiTextStyles.mono(
                        size: 11,
                        weight: FontWeight.w600,
                        color: SudepiColors.cameraTextPrimary,
                      ),
                    ),
                  ),
                ),
              if (showClearButton && onSimulateClearFrame != null)
                InkWell(
                  onTap: onSimulateClearFrame,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: SudepiColors.primaryTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Ganti Lembar',
                      style: SudepiTextStyles.sans(
                        size: 11,
                        weight: FontWeight.w600,
                        color: SudepiColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
