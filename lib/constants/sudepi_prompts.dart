/// Kumpulan konstanta skrip suara (TTS) terpusat untuk aplikasi SUDEPI.
///
/// Seluruh kalimat disusun ringkas, ramah pendengaran tunanetra, dan konsisten
/// menggunakan istilah "usap layar" / "usap ke ..." pada navigasi berbasis gestur.
abstract final class SudepiPrompts {
  // ===========================================================================
  // LAYAR 1 — MODE SIAGA & SENTER
  // ===========================================================================

  static const String standbyBoot = 'Mode siaga.';

  static const String standbySingleTapInfo =
      'Mode siaga. Arahkan kamera ke uang, atau usap layar ke kiri untuk mulai transaksi.';

  static const String lowLightWarning =
      'Cahaya redup. Arahkan kamera ke uang agar senter menyala otomatis, atau ketuk layar dua kali.';

  static const String torchAutoOnInfo =
      'Senter otomatis menyala selama ada uang di kamera. Ketuk layar dua kali untuk mematikan.';

  static const String torchManualOnInfo =
      'Senter sedang menyala. Ketuk layar dua kali untuk mematikan.';

  static const String torchOffInfo =
      'Senter sedang mati. Ketuk layar dua kali untuk menyalakan.';

  static const String torchTurnedOn = 'Senter menyala.';

  static const String torchTurnedOff = 'Senter mati.';

  static const String unfoldBillPrompt = 'Mohon rentangkan uang kertas.';

  static const String returnToStandbyShort = 'Kembali ke mode siaga.';

  // ===========================================================================
  // LAYAR 2 & 3 — DIALOG TRANSAKSI, PUSH-TO-TALK, & NUMPAD DARURAT
  // ===========================================================================

  static const String stepTwoLabel = 'Total belanja';

  static const String stepThreeLabel = 'Uang yang diberikan';

  static const String emptyAmountLabel = 'belum diisi';

  static const String zeroRupiahSpoken = 'nol rupiah';

  static const String enterTotalBelanjaFresh =
      'Sebutkan total belanja. Tahan layar untuk bicara.';

  static String returnTotalBelanja(String belanjaSpoken) =>
      'Kembali ke total belanja, saat ini $belanjaSpoken. Tahan layar untuk bicara.';

  static String enterUangDiberikanSaved(String belanjaSpoken) =>
      'Belanja $belanjaSpoken disimpan. Sebutkan uang yang diberikan. Tahan layar untuk bicara.';

  static String returnUangDiberikan(String uangSpoken) =>
      'Kembali ke uang yang diberikan, saat ini $uangSpoken. Tahan layar untuk bicara.';

  static const String dialogSingleTapNumpadHint =
      'Papan angka terbuka. Usap layar ke kiri untuk lanjut, usap ke kanan untuk kembali, atau usap ke bawah untuk menutup papan angka.';

  static const String dialogSingleTapVoiceHint =
      'Tahan layar untuk bicara, usap ke kiri untuk lanjut, atau usap ke kanan untuk kembali.';

  static String dialogSingleTapSummary({
    required String stepName,
    required String valSpoken,
    required String modeHint,
  }) =>
      '$stepName, saat ini $valSpoken. $modeHint';

  static const String voiceClearedToZero =
      'Angka dihapus menjadi nol rupiah. Tahan layar untuk bicara lagi.';

  static String voiceAmountCaptured(String amountSpoken) =>
      'Baik, $amountSpoken. Usap layar ke kiri untuk lanjut, tahan untuk ubah, atau usap ke kanan untuk kembali.';

  static const String voiceNotHeard =
      'Suara belum terdengar. Tahan layar untuk bicara, usap ke atas untuk papan angka, atau usap ke kanan untuk kembali.';

  static const String numpadOpened =
      'Papan angka terbuka. Usap layar ke bawah untuk menutup.';

  static const String numpadClosed =
      'Papan angka ditutup. Tahan layar untuk bicara.';

  static String numpadDigitAppended({
    required String digitWord,
    required String totalWord,
  }) =>
      '$digitWord, tertulis $totalWord.';

  static const String numpadBackspaceAlreadyZero =
      'Tombol hapus satu angka. Saat ini nol rupiah.';

  static String numpadBackspaceRemoved({
    required String removedWord,
    required String remainingWord,
  }) =>
      'Hapus $removedWord, sisa $remainingWord.';

  static const String numpadAcSingleTapInfo =
      'Tombol hapus semua. Tahan tombol ini untuk mengosongkan angka.';

  static const String numpadClearedAll = 'Angka dikosongkan. Nol rupiah.';

  static const String dialogEmptyAmountWarning =
      'Nominal belum diisi. Tahan layar untuk bicara, atau usap ke atas untuk papan angka.';

  static String dialogInsufficientPayment(String kurangSpoken) =>
      'Uang yang diberikan kurang $kurangSpoken dari total belanja.';

  static const String exactPaymentCompleted =
      'Uang pas, tanpa kembalian. Transaksi selesai, kembali ke mode siaga.';

  // ===========================================================================
  // LAYAR 4 — CEK KEMBALIAN SEKUENSIAL
  // ===========================================================================

  static String enterVerifyChange(String targetSpoken) =>
      'Cek kembalian. Target $targetSpoken. Arahkan kamera ke uang kembalian satu per satu.';

  static String changeCoinRemainder({
    required String billSpoken,
    required String totalSpoken,
    required String selisihSpoken,
  }) =>
      '$billSpoken. Terkumpul $totalSpoken. Sisa $selisihSpoken berupa koin, cek manual lalu usap layar ke kiri untuk selesai.';

  static String changeRemaining({
    required String billSpoken,
    required String totalSpoken,
    required String selisihSpoken,
  }) =>
      '$billSpoken. Terkumpul $totalSpoken, kurang $selisihSpoken. Pindai lembar berikutnya.';

  static String changeExactMatch({
    required String billSpoken,
    required String totalSpoken,
  }) =>
      '$billSpoken. Total $totalSpoken, kembalian sudah pas. Usap layar ke kiri untuk selesai.';

  static String changeExceeded({
    required String billSpoken,
    required String totalSpoken,
    required String targetSpoken,
  }) =>
      '$billSpoken. Terkumpul $totalSpoken, melebihi target $targetSpoken. Tahan layar untuk ulangi dari nol.';

  static String verifyChangeSingleTapRemaining({
    required String targetSpoken,
    required String scannedSpoken,
    required String sisaSpoken,
  }) =>
      'Cek kembalian. Target $targetSpoken, terkumpul $scannedSpoken, kurang $sisaSpoken. Usap layar ke kiri untuk selesai, atau usap ke kanan untuk kembali.';

  static String verifyChangeSingleTapExact({
    required String targetSpoken,
    required String scannedSpoken,
  }) =>
      'Cek kembalian. Target $targetSpoken, terkumpul $scannedSpoken, kembalian sudah pas. Usap layar ke kiri untuk selesai, atau usap ke kanan untuk kembali.';

  static String verifyChangeSingleTapExceeded({
    required String targetSpoken,
    required String scannedSpoken,
  }) =>
      'Cek kembalian. Target $targetSpoken, terkumpul $scannedSpoken, melebihi target. Tahan layar untuk ulangi dari nol, atau usap ke kanan untuk kembali.';

  static const String verifyChangeReset =
      'Hitungan kembalian diulang dari nol. Silakan pindai kembali.';

  static const String transactionFinishedReturnStandby =
      'Transaksi selesai. Kembali ke mode siaga.';

  // ===========================================================================
  // MODE SIMULASI DEBUG OPSIONAL
  // ===========================================================================

  static const String simulationEnabled = 'Mode simulasi aktif.';

  static const String simulationDisabled = 'Mode simulasi nonaktif.';

  static const String simulationRemoveBillFirst =
      'Jauhkan uang sebelumnya terlebih dahulu, atau tekan tombol Ganti Lembar pada panel simulasi.';

  static const String simulationReadyNextBill =
      'Siap memindai lembar berikutnya.';
}
