import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/rupiah_denomination.dart';
import '../theme/sudepi_theme.dart';
import '../utils/indonesian_number_parser.dart';

/// Layar 4 — Cek Kembalian Sekuensial.
/// Arsitektur Clean UI 100% Zero-Button:
/// - Ketuk 1x: Info target kembalian, terkumpul, & sisa
/// - Ketuk 2x: Senter On / Off
/// - Tahan (Hold): Reset / Ulangi Scan Kembalian ke Rp 0
/// - Usap Kiri: Selesai Transaksi (kembali ke Mode Siaga)
/// - Usap Kanan: Kembali ke Input Uang yang Diberikan (Layar 3)
class ChangeVerificationScreen extends StatefulWidget {
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final bool isTorchOn;
  final bool isTorchAutoLatched;
  final int targetChange;
  final int totalScannedChange;
  final bool isWaitingBillRemoval;
  final bool showSimulationBar;
  final VoidCallback onSingleTapAnywhere;
  final VoidCallback onFinishTransaction;
  final VoidCallback onResetScan;
  final VoidCallback onToggleTorchManual;
  final VoidCallback onTorchIndicatorTapInfo;
  final VoidCallback onBackPressed;
  final VoidCallback onToggleSimulationMode;
  final void Function(RupiahDenomination denom) onSimulateBill;
  final VoidCallback onSimulateClearFrame;

  const ChangeVerificationScreen({
    super.key,
    required this.cameraController,
    required this.isCameraInitialized,
    required this.isTorchOn,
    required this.isTorchAutoLatched,
    required this.targetChange,
    required this.totalScannedChange,
    required this.isWaitingBillRemoval,
    required this.showSimulationBar,
    required this.onSingleTapAnywhere,
    required this.onFinishTransaction,
    required this.onResetScan,
    required this.onToggleTorchManual,
    required this.onTorchIndicatorTapInfo,
    required this.onBackPressed,
    required this.onToggleSimulationMode,
    required this.onSimulateBill,
    required this.onSimulateClearFrame,
  });

  @override
  State<ChangeVerificationScreen> createState() =>
      _ChangeVerificationScreenState();
}

class _ChangeVerificationScreenState extends State<ChangeVerificationScreen> {
  int _titleTapCount = 0;
  DateTime? _lastTitleTapTime;

  void _handleTitleTap() {
    final now = DateTime.now();
    if (_lastTitleTapTime == null ||
        now.difference(_lastTitleTapTime!) > const Duration(milliseconds: 900)) {
      _titleTapCount = 1;
    } else {
      _titleTapCount++;
    }
    _lastTitleTapTime = now;

    if (_titleTapCount >= 3) {
      _titleTapCount = 0;
      widget.onToggleSimulationMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int remaining = widget.targetChange - widget.totalScannedChange;
    final bool isUnderTarget = widget.totalScannedChange < widget.targetChange;
    final bool isExactMatch = widget.totalScannedChange == widget.targetChange;

    return Scaffold(
      backgroundColor: SudepiColors.background,
      body: SafeArea(
        child: SudepiFullScreenGestureCanvas(
          onSingleTap: widget.onSingleTapAnywhere,
          onDoubleTap: widget.onToggleTorchManual,
          onLongPress: widget.onResetScan,
          onSwipeLeft: widget.onFinishTransaction,
          onSwipeRight: widget.onBackPressed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Putih Bersih (#FFFFFF): Judul Kiri + Pill Target Kembalian Kanan
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
                      onTap: _handleTitleTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Cek kembalian',
                          style: SudepiTextStyles.sans(
                            size: 18,
                            weight: FontWeight.w700,
                            color: SudepiColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: SudepiColors.primaryTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Target ${IndonesianNumberParser.formatRupiah(widget.targetChange, withSpace: true)}',
                            maxLines: 1,
                            style: SudepiTextStyles.mono(
                              size: 13,
                              weight: FontWeight.w600,
                              color: SudepiColors.primaryBlue,
                            ),
                          ),
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

                    // 2. Bar Atas Kamera: Pill jeda pergantian uang (hanya saat menunggu) + Indikator Senter
                    Positioned(
                      top: 16,
                      left: 20,
                      right: 20,
                      child: Row(
                        children: [
                          const SizedBox(width: 44),
                          Expanded(
                            child: widget.isWaitingBillRemoval && !isExactMatch
                                ? Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SudepiColors.cameraScrim,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Ganti ke lembar berikutnya...',
                                        textAlign: TextAlign.center,
                                        style: SudepiTextStyles.sans(
                                          size: 13,
                                          weight: FontWeight.w500,
                                          color: SudepiColors.cameraTextPrimary,
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          TorchToggleButton(
                            isTorchOn: widget.isTorchOn,
                            isAutoLatched: widget.isTorchAutoLatched,
                            onTap: widget.onTorchIndicatorTapInfo,
                            onDoubleTap: widget.onToggleTorchManual,
                          ),
                        ],
                      ),
                    ),

                    // 3. Kotak Bidik Siku Putih 200x200 dp di Tengah
                    const Align(
                      alignment: Alignment(0, -0.18),
                      child: IgnorePointer(
                        child: CameraCornerBrackets(size: 200),
                      ),
                    ),

                    // 4. Panel Simulasi Debug Opsional
                    if (widget.showSimulationBar)
                      Positioned(
                        top: 68,
                        left: 20,
                        right: 20,
                        child: SimulationDebugPanel(
                          onSimulateBill: widget.onSimulateBill,
                          onSimulateClearFrame: widget.onSimulateClearFrame,
                          showClearButton: true,
                        ),
                      ),

                    // 5. Satu Kartu Floating Tunggal di Bawah Kamera
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
                              'Terbaca',
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
                                IndonesianNumberParser.formatRupiah(
                                  widget.totalScannedChange,
                                  withSpace: true,
                                ),
                                textAlign: TextAlign.center,
                                style: SudepiTextStyles.mono(
                                  size: 38,
                                  weight: FontWeight.w700,
                                  color: SudepiColors.cameraTextPrimary,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isExactMatch)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: SudepiColors.statusSuccess,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Kembalian pas',
                                  textAlign: TextAlign.center,
                                  style: SudepiTextStyles.sans(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: SudepiColors.cameraTextPrimary,
                                  ),
                                ),
                              )
                            else if (isUnderTarget)
                              Text(
                                'Kurang ${IndonesianNumberParser.formatRupiah(remaining, withSpace: true)}',
                                textAlign: TextAlign.center,
                                style: SudepiTextStyles.mono(
                                  size: 14,
                                  weight: FontWeight.w500,
                                  color: SudepiColors.cameraTextSecondary,
                                ),
                              )
                            else
                              Text(
                                'Melebihi target',
                                textAlign: TextAlign.center,
                                style: SudepiTextStyles.sans(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: SudepiColors.statusAlert,
                                ),
                              ),
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
