import 'package:flutter/material.dart';

import '../theme/sudepi_theme.dart';
import '../utils/indonesian_number_parser.dart';

/// Layar 2 (Total Belanja) & Layar 3 (Uang yang Diberikan).
/// Arsitektur Clean UI 100% Zero-Button dengan Smart Push-to-Talk,
/// Navigasi Usap 4 Arah, dan Papan Angka (NumPad) Darurat Tersembunyi (`[AC] [0] [Hapus]`).
class TransactionDialogScreen extends StatelessWidget {
  final bool isStepThree;
  final int currentAmount;
  final bool isMicListening;
  final bool isNumpadVisible;
  final void Function(String digit) onDigitPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback onAcSingleTapInfo;
  final VoidCallback onClearPressed;
  final VoidCallback onSingleTapAnywhere;
  final VoidCallback onPushToTalkStart;
  final VoidCallback onPushToTalkEnd;
  final VoidCallback onConfirmContinue;
  final VoidCallback onBackPressed;
  final VoidCallback onOpenNumpad;
  final VoidCallback onCloseNumpad;

  const TransactionDialogScreen({
    super.key,
    required this.isStepThree,
    required this.currentAmount,
    required this.isMicListening,
    required this.isNumpadVisible,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    required this.onAcSingleTapInfo,
    required this.onClearPressed,
    required this.onSingleTapAnywhere,
    required this.onPushToTalkStart,
    required this.onPushToTalkEnd,
    required this.onConfirmContinue,
    required this.onBackPressed,
    required this.onOpenNumpad,
    required this.onCloseNumpad,
  });

  @override
  Widget build(BuildContext context) {
    final questionText = isStepThree
        ? 'Berapa uang yang diberikan?'
        : 'Berapa total belanjaan?';

    return Scaffold(
      backgroundColor: SudepiColors.background,
      body: SafeArea(
        child: SudepiFullScreenGestureCanvas(
          onSingleTap: onSingleTapAnywhere,
          onLongPressStart: isNumpadVisible ? null : onPushToTalkStart,
          onLongPressEnd: isNumpadVisible ? null : onPushToTalkEnd,
          onSwipeLeft: onConfirmContinue,
          onSwipeRight: onBackPressed,
          onSwipeUp: onOpenNumpad,
          onSwipeDown: onCloseNumpad,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kartu Nominal Bersih (#F1F3F4 Borderless)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: SudepiColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          questionText,
                          maxLines: 1,
                          style: SudepiTextStyles.sans(
                            size: 16,
                            weight: FontWeight.w500,
                            color: SudepiColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          IndonesianNumberParser.formatRupiah(
                            currentAmount,
                            withSpace: true,
                          ),
                          style: SudepiTextStyles.mono(
                            size: 40,
                            weight: FontWeight.w700,
                            color: SudepiColors.textPrimary,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Area Interaksi Bawah: Kanvas Push-to-Talk ATAU Grid NumPad 3x4
                Expanded(
                  child: isNumpadVisible
                      ? _buildNumpadGrid()
                      : _buildPushToTalkCanvasCard(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPushToTalkCanvasCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: isMicListening
            ? SudepiColors.primaryTint
            : SudepiColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isMicListening
                  ? SudepiColors.primaryBlue
                  : SudepiColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMicListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              size: 32,
              color: isMicListening
                  ? SudepiColors.background
                  : SudepiColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isMicListening ? 'Mendengarkan...' : 'Tahan untuk bicara',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: SudepiTextStyles.sans(
                size: 17,
                weight: FontWeight.w600,
                color: isMicListening
                    ? SudepiColors.primaryBlue
                    : SudepiColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadGrid() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              _buildDigitKey('7'),
              const SizedBox(width: 10),
              _buildDigitKey('8'),
              const SizedBox(width: 10),
              _buildDigitKey('9'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              _buildDigitKey('4'),
              const SizedBox(width: 10),
              _buildDigitKey('5'),
              const SizedBox(width: 10),
              _buildDigitKey('6'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              _buildDigitKey('1'),
              const SizedBox(width: 10),
              _buildDigitKey('2'),
              const SizedBox(width: 10),
              _buildDigitKey('3'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: [
              _buildAcKey(),
              const SizedBox(width: 10),
              _buildDigitKey('0'),
              const SizedBox(width: 10),
              _buildDeleteKey(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDigitKey(String digit) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Angka $digit',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onDigitPressed(digit),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SudepiColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              digit,
              style: SudepiTextStyles.mono(
                size: 24,
                weight: FontWeight.w600,
                color: SudepiColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tombol `AC` (Kiri Bawah) dengan Pengaman Anti-Salah Pencet:
  /// - Ketuk 1x (`onTap`): Hanya info suara cara pakai tanpa menghapus angka.
  /// - Tahan (`onLongPress`): Mengosongkan nominal kembali ke Rp 0.
  Widget _buildAcKey() {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Tombol hapus semua. Tahan untuk mengosongkan angka.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAcSingleTapInfo,
          onLongPress: onClearPressed,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SudepiColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'AC',
              style: SudepiTextStyles.sans(
                size: 18,
                weight: FontWeight.w600,
                color: SudepiColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Hapus satu angka terakhir',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBackspacePressed,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SudepiColors.primaryTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Hapus',
              style: SudepiTextStyles.sans(
                size: 16,
                weight: FontWeight.w600,
                color: SudepiColors.primaryBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
