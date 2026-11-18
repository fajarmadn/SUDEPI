import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/rupiah_denomination.dart';
import '../theme/sudepi_theme.dart';

/// Layar 1 — Mode Siaga.
/// Mendeteksi pecahan uang kertas tunggal (Single-Bill) dengan panduan suara & haptik.
class StandbyScreen extends StatefulWidget {
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final bool isTorchOn;
  final bool isTorchAutoLatched;
  final RupiahDenomination? lockedDenomination;
  final int lockedAccuracyPercent;
  final bool showSimulationBar;
  final VoidCallback onSingleTapAnywhere;
  final VoidCallback onStartTransaction;
  final VoidCallback onToggleTorchManual;
  final VoidCallback onTorchIndicatorTapInfo;
  final VoidCallback onToggleSimulationMode;
  final void Function(RupiahDenomination denom) onSimulateBill;

  const StandbyScreen({
    super.key,
    required this.cameraController,
    required this.isCameraInitialized,
    required this.isTorchOn,
    required this.isTorchAutoLatched,
    required this.lockedDenomination,
    required this.lockedAccuracyPercent,
    required this.showSimulationBar,
    required this.onSingleTapAnywhere,
    required this.onStartTransaction,
    required this.onToggleTorchManual,
    required this.onTorchIndicatorTapInfo,
    required this.onToggleSimulationMode,
    required this.onSimulateBill,
  });

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen> {
  int _brandTapCount = 0;
  DateTime? _lastBrandTapTime;

  void _handleBrandTap() {
    final now = DateTime.now();
    if (_lastBrandTapTime == null ||
        now.difference(_lastBrandTapTime!) > const Duration(milliseconds: 900)) {
      _brandTapCount = 1;
    } else {
      _brandTapCount++;
    }
    _lastBrandTapTime = now;

    if (_brandTapCount >= 3) {
      _brandTapCount = 0;
      widget.onToggleSimulationMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final denom = widget.lockedDenomination;

    return Scaffold(
      backgroundColor: SudepiColors.background,
      body: SafeArea(
        child: SudepiFullScreenGestureCanvas(
          onSingleTap: widget.onSingleTapAnywhere,
          onDoubleTap: widget.onToggleTorchManual,
          onSwipeLeft: widget.onStartTransaction,
          child: Column(
            children: [
              // Header Putih Bersih (#FFFFFF)
              Container(
                height: 56,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                color: SudepiColors.background,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleBrandTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/sudepi_mark.png',
                              width: 26,
                              height: 26,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SUDEPI',
                              style: SudepiTextStyles.sans(
                                size: 18,
                                weight: FontWeight.w700,
                                color: SudepiColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: SudepiColors.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Mode siaga',
                        style: SudepiTextStyles.sans(
                          size: 13,
                          weight: FontWeight.w500,
                          color: SudepiColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Viewport Kamera Bersih
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Live Camera Preview
                    _buildCameraPreview(),

                    // 2. Indikator Senter Bulat Minimalis di Pojok Kanan Atas
                    Positioned(
                      top: 16,
                      right: 20,
                      child: TorchToggleButton(
                        isTorchOn: widget.isTorchOn,
                        isAutoLatched: widget.isTorchAutoLatched,
                        onTap: widget.onTorchIndicatorTapInfo,
                        onDoubleTap: widget.onToggleTorchManual,
                      ),
                    ),

                    // 3. Kotak Bidik Siku Putih 200x200 dp di Tengah
                    const Align(
                      alignment: Alignment(0, -0.18),
                      child: IgnorePointer(
                        child: CameraCornerBrackets(size: 200),
                      ),
                    ),

                    // 4. Panel Simulasi Debug Opsional (Ketuk 3x pada SUDEPI)
                    if (widget.showSimulationBar)
                      Positioned(
                        top: 68,
                        left: 20,
                        right: 20,
                        child: SimulationDebugPanel(
                          onSimulateBill: widget.onSimulateBill,
                        ),
                      ),

                    // 5. Satu Kartu Floating Bersih di Bawah Kamera
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: SudepiColors.cameraScrim,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              denom != null ? 'Terdeteksi' : 'Memindai uang...',
                              textAlign: TextAlign.center,
                              style: SudepiTextStyles.sans(
                                size: 14,
                                weight: FontWeight.w500,
                                color: SudepiColors.cameraTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                denom != null
                                    ? denom.spacedDisplayText
                                    : 'Rp —',
                                textAlign: TextAlign.center,
                                style: SudepiTextStyles.mono(
                                  size: 38,
                                  weight: FontWeight.w700,
                                  color: SudepiColors.cameraTextPrimary,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            if (denom != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: SudepiColors.statusSuccess,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Akurasi ${widget.lockedAccuracyPercent}%',
                                  style: SudepiTextStyles.mono(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: SudepiColors.cameraTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = widget.cameraController;
    if (!widget.isCameraInitialized ||
        controller == null ||
        !controller.value.isInitialized) {
      return Container(
        color: SudepiColors.textPrimary,
        alignment: const Alignment(0, -0.18),
        child: SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  color: SudepiColors.cameraTextSecondary,
                  size: 42,
                ),
                const SizedBox(height: 8),
                Text(
                  'Menyiapkan kamera...',
                  textAlign: TextAlign.center,
                  style: SudepiTextStyles.sans(
                    size: 13,
                    weight: FontWeight.w400,
                    color: SudepiColors.cameraTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 480,
            height: controller.value.previewSize?.width ?? 640,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
