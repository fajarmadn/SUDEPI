import 'package:flutter/services.dart';

/// Layanan umpan balik taktil/getaran (Haptic & Tactile Earcon) untuk Blind-First UX.
class HapticService {
  static const MethodChannel _channel = MethodChannel('com.sudepi.app/yolo26');

  static Future<void> _vibratePattern(List<int> pattern) async {
    try {
      await _channel.invokeMethod('vibratePattern', {'pattern': pattern});
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Earcon getaran 2 ketukan cepat (`tik-tik`) tepat saat mikrofon STT aktif mendengarkan.
  static Future<void> micListeningEarcon() async {
    await _vibratePattern(const [0, 35, 55, 35]);
  }

  /// Getaran 1x mantap saat STT berhasil menangkap nominal ucapan.
  static Future<void> sttCapturedPulse() async {
    await _vibratePattern(const [0, 95]);
  }

  /// Getaran *soft tick* halus saat kandidat uang `0.35 <= confidence < 0.65` terlihat selama 2 detik.
  static Future<void> subThresholdTick() async {
    await _vibratePattern(const [0, 20]);
  }

  /// Getaran tegas saat uang kertas berhasil dikunci di buffer konsistensi 4/5 frame.
  static Future<void> detectionLockedPulse() async {
    await _vibratePattern(const [0, 85, 45, 115]);
  }

  /// Matriks Haptik Terdiferensiasi Per Nominal Rupiah (7 Kelas):
  /// - Pecahan kecil (Rp1.000, Rp2.000, Rp5.000): 1x, 2x, 3x getar pendek (70 ms)
  /// - Pecahan menengah (Rp10.000, Rp20.000): 1x, 2x getar sedang (220 ms)
  /// - Pecahan besar (Rp50.000, Rp100.000): 1x, 2x getar panjang-kuat (450 ms)
  static Future<void> vibrateForDenomination(int classId) async {
    switch (classId) {
      case 0: // Rp1.000 -> 1x pendek
        await _vibratePattern(const [0, 70]);
        break;
      case 1: // Rp2.000 -> 2x pendek
        await _vibratePattern(const [0, 70, 65, 70]);
        break;
      case 2: // Rp5.000 -> 3x pendek
        await _vibratePattern(const [0, 70, 65, 70, 65, 70]);
        break;
      case 3: // Rp10.000 -> 1x sedang
        await _vibratePattern(const [0, 220]);
        break;
      case 4: // Rp20.000 -> 2x sedang
        await _vibratePattern(const [0, 220, 90, 220]);
        break;
      case 5: // Rp50.000 -> 1x panjang-kuat
        await _vibratePattern(const [0, 450]);
        break;
      case 6: // Rp100.000 -> 2x panjang-kuat
        await _vibratePattern(const [0, 450, 110, 450]);
        break;
      default:
        await detectionLockedPulse();
    }
  }

  /// Getaran pendek per ketukan tombol angka Numpad.
  static Future<void> numpadKeyTap() async {
    await _vibratePattern(const [0, 28]);
  }

  /// Getaran ganda saat menekan tombol Hapus pada Numpad.
  static Future<void> numpadDeletePulse() async {
    await _vibratePattern(const [0, 42, 45, 42]);
  }

  /// Getaran panjang saat menekan tombol AC atau mereset hitungan kembalian.
  static Future<void> numpadClearPulse() async {
    await _vibratePattern(const [0, 145]);
  }

  /// Getaran peringatan saat validasi gagal (misal nominal masih 0 atau uang kurang).
  static Future<void> warningPulse() async {
    await _vibratePattern(const [0, 70, 50, 70, 50, 95]);
  }

  /// Getaran sukses panjang saat kembalian pas (`totalTerbaca == targetKembalian`).
  static Future<void> successLongPulse() async {
    await _vibratePattern(const [0, 130, 60, 230]);
  }

  /// Getaran saat senter menyala/mati.
  static Future<void> torchTogglePulse() async {
    await _vibratePattern(const [0, 65]);
  }

  /// Getaran hitung mundur saat menahan 3 detik untuk membatalkan transaksi.
  static Future<void> holdCountdownTick() async {
    await _vibratePattern(const [0, 35]);
  }
}
