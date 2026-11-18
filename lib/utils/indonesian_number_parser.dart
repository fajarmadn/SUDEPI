/// Utilitas pemformat nominal Rupiah, konversi angka ke ucapan Bahasa Indonesia
/// (terbilang), dan parser ucapan STT Bahasa Indonesia (termasuk perintah satu napas).
class ParsedVoiceCommand {
  final int? amount;
  final bool hasAdvanceIntent;
  final bool hasRepeatIntent;
  final bool hasBackIntent;
  final String rawText;

  const ParsedVoiceCommand({
    required this.amount,
    required this.hasAdvanceIntent,
    required this.hasRepeatIntent,
    required this.hasBackIntent,
    required this.rawText,
  });

  bool get hasAnyAction =>
      amount != null || hasAdvanceIntent || hasRepeatIntent || hasBackIntent;
}

class IndonesianNumberParser {
  static const List<String> _digitWords = [
    'nol',
    'satu',
    'dua',
    'tiga',
    'empat',
    'lima',
    'enam',
    'tujuh',
    'delapan',
    'sembilan',
  ];

  /// Mengubah digit tunggal ('0'..'9') menjadi kata Bahasa Indonesia.
  static String digitToWord(String digit) {
    final val = int.tryParse(digit);
    if (val == null || val < 0 || val > 9) return digit;
    return _digitWords[val];
  }

  /// Memformat integer menjadi string Rupiah seperti "Rp25.000" atau "Rp 25.000".
  static String formatRupiah(int amount, {bool withSpace = false}) {
    final absVal = amount.abs();
    final str = absVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    final prefix = amount < 0
        ? (withSpace ? '-Rp ' : '-Rp')
        : (withSpace ? 'Rp ' : 'Rp');
    return '$prefix${buffer.toString()}';
  }

  /// Mengubah angka integer menjadi kalimat terbilang Bahasa Indonesia (tanpa kata "rupiah").
  static String terbilangAngka(int number) {
    if (number == 0) return 'nol';
    if (number < 0) return 'minus ${terbilangAngka(number.abs())}';

    if (number < 10) {
      return _digitWords[number];
    } else if (number == 10) {
      return 'sepuluh';
    } else if (number == 11) {
      return 'sebelas';
    } else if (number < 20) {
      return '${_digitWords[number - 10]} belas';
    } else if (number < 100) {
      final puluh = number ~/ 10;
      final sisa = number % 10;
      return sisa == 0
          ? '${_digitWords[puluh]} puluh'
          : '${_digitWords[puluh]} puluh ${_digitWords[sisa]}';
    } else if (number < 200) {
      final sisa = number - 100;
      return sisa == 0 ? 'seratus' : 'seratus ${terbilangAngka(sisa)}';
    } else if (number < 1000) {
      final ratus = number ~/ 100;
      final sisa = number % 100;
      return sisa == 0
          ? '${_digitWords[ratus]} ratus'
          : '${_digitWords[ratus]} ratus ${terbilangAngka(sisa)}';
    } else if (number < 2000) {
      final sisa = number - 1000;
      return sisa == 0 ? 'seribu' : 'seribu ${terbilangAngka(sisa)}';
    } else if (number < 1000000) {
      final ribu = number ~/ 1000;
      final sisa = number % 1000;
      return sisa == 0
          ? '${terbilangAngka(ribu)} ribu'
          : '${terbilangAngka(ribu)} ribu ${terbilangAngka(sisa)}';
    } else if (number < 1000000000) {
      final juta = number ~/ 1000000;
      final sisa = number % 1000000;
      return sisa == 0
          ? '${terbilangAngka(juta)} juta'
          : '${terbilangAngka(juta)} juta ${terbilangAngka(sisa)}';
    }
    return number.toString();
  }

  /// Mengubah angka integer menjadi kalimat terbilang disertai kata "rupiah".
  static String terbilangRupiah(int number) {
    return '${terbilangAngka(number)} rupiah';
  }

  /// Mem-parsing hasil transkripsi STT Bahasa Indonesia menjadi nominal & intent aksi.
  static ParsedVoiceCommand parseVoiceInput(String rawInput) {
    final cleaned = rawInput
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s.,]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) {
      return const ParsedVoiceCommand(
        amount: null,
        hasAdvanceIntent: false,
        hasRepeatIntent: false,
        hasBackIntent: false,
        rawText: '',
      );
    }

    final words = cleaned.split(' ');

    final hasAdvance = words.any((w) =>
        w == 'lanjut' ||
        w == 'lanjutkan' ||
        w == 'konfirmasi' ||
        w == 'simpan' ||
        w == 'benar' ||
        w == 'betul' ||
        w == 'oke' ||
        w == 'ok' ||
        w == 'ya' ||
        w == 'iya');

    const repeatKeywords = {
      'ulang',
      'ulangi',
      'hapus',
      'reset',
      'koreksi',
      'ralat',
      'salah',
      'bukan',
      'ganti',
    };

    int lastRepeatIndex = -1;
    for (int i = 0; i < words.length; i++) {
      if (repeatKeywords.contains(words[i])) {
        lastRepeatIndex = i;
      }
    }

    final hasRepeat = lastRepeatIndex >= 0;

    final hasBack = words.any((w) =>
        w == 'kembali' || w == 'batal' || w == 'batalkan' || w == 'keluar');

    // Jika pengguna mengucapkan kata "ulangi"/"hapus"/"koreksi" berkali-kali
    // (misal: "20 ribu ulangi 15 ribu ulangi 50 ribu" atau "20 ribu hapus"),
    // selalu ambil segmen yang diucapkan SETELAH kata koreksi paling akhir.
    final List<String> effectiveWords = lastRepeatIndex >= 0
        ? words.sublist(lastRepeatIndex + 1)
        : words;
    final String effectiveCleaned = effectiveWords.join(' ');

    final parsedAmount = effectiveWords.isEmpty
        ? null
        : _extractNominal(effectiveCleaned, effectiveWords);

    return ParsedVoiceCommand(
      amount: parsedAmount,
      hasAdvanceIntent: hasAdvance,
      hasRepeatIntent: hasRepeat,
      hasBackIntent: hasBack,
      rawText: rawInput,
    );
  }

  /// Mengekstrak nominal Rupiah paling akhir (terbaru) dari deretan kata/angka.
  /// Mendukung penyebutan nominal berulang kali dalam 1 tahanan layar (tanpa batas 1x),
  /// baik dengan kata "ulangi" maupun langsung menyebut nominal baru.
  static int? _extractNominal(String cleaned, List<String> words) {
    const Map<String, int> unitMap = {
      'nol': 0,
      'kosong': 0,
      'satu': 1,
      'se': 1,
      'dua': 2,
      'tiga': 3,
      'empat': 4,
      'lima': 5,
      'enam': 6,
      'tujuh': 7,
      'delapan': 8,
      'lapan': 8,
      'sembilan': 9,
      'sepuluh': 10,
      'sebelas': 11,
    };

    const Map<String, int> slangMap = {
      'goceng': 5000,
      'ceban': 10000,
      'goban': 50000,
      'seceng': 1000,
      'gopek': 500,
    };

    int? lastCompletedNominal;
    int majorTotal = 0; // Akumulasi jutaan + ribuan pada nominal aktif saat ini
    bool hasRibuInCurrent = false;
    bool hasJutaInCurrent = false;
    int currentHundreds = 0; // 100..900
    int currentTensUnits = 0; // 0..99
    bool hasSetengah = false;
    bool hasAnyNumberInCurrent = false;

    int computeCurrentTotal() {
      if (hasRibuInCurrent || hasJutaInCurrent) {
        // Jika sudah memiliki komponen ribuan/jutaan (misal Rp 20.000),
        // hanya tambahkan komponen ratusan yang valid (misal "lima ratus" -> Rp 20.500).
        // Jangan menambahkan currentTensUnits yang masih menggantung sebelum kata "ribu"
        // berikutnya selesai diucapkan.
        final hundredsPart =
            currentHundreds > 0 ? (currentHundreds + currentTensUnits) : 0;
        return majorTotal + hundredsPart;
      }
      return majorTotal + currentHundreds + currentTensUnits;
    }

    void commitAndReset() {
      if (hasAnyNumberInCurrent) {
        final val = computeCurrentTotal();
        if (val > 0) {
          lastCompletedNominal = val;
        }
      }
      majorTotal = 0;
      hasRibuInCurrent = false;
      hasJutaInCurrent = false;
      currentHundreds = 0;
      currentTensUnits = 0;
      hasSetengah = false;
      hasAnyNumberInCurrent = false;
    }

    for (int i = 0; i < words.length; i++) {
      String w = words[i].trim();
      if (w.isEmpty) continue;

      // Pisahkan prefix "rp" yang menempel pada angka (misal "rp50.000")
      if (w.startsWith('rp') && w.length > 2 && RegExp(r'\d').hasMatch(w)) {
        commitAndReset();
        w = w.substring(2);
      }

      final stripped = w.replaceAll('.', '').replaceAll(',', '');
      if (stripped.isEmpty) continue;

      // Kata pembatas mata uang ("rp", "rupiah") menandai batas antar-nominal
      if (stripped == 'rp' || stripped == 'rupiah') {
        commitAndReset();
        continue;
      }

      // 1. Cek istilah populer sehari-hari (goceng, ceban, goban, seceng, gopek)
      if (slangMap.containsKey(stripped)) {
        final slangVal = slangMap[stripped]!;
        if (slangVal >= 1000) {
          commitAndReset();
          majorTotal = slangVal;
          hasRibuInCurrent = true;
          hasAnyNumberInCurrent = true;
        } else {
          // gopek (500) bisa berdiri sendiri atau melengkapi ribuan ("dua puluh ribu gopek")
          currentHundreds = slangVal;
          hasAnyNumberInCurrent = true;
        }
        continue;
      }

      // 2. Cek token angka digit langsung dari STT (misal "20000", "25.000", "25", "500")
      final numVal = int.tryParse(stripped);
      if (numVal != null) {
        hasAnyNumberInCurrent = true;
        if (numVal >= 1000000) {
          commitAndReset();
          majorTotal = numVal;
          hasJutaInCurrent = true;
          hasRibuInCurrent = true;
          hasAnyNumberInCurrent = true;
        } else if (numVal >= 1000) {
          // Angka ribuan penuh (misal "20.000" lalu disebut lagi "15.000") -> mulai nominal baru
          commitAndReset();
          majorTotal = numVal;
          hasRibuInCurrent = true;
          hasAnyNumberInCurrent = true;
        } else if (numVal >= 100) {
          if (currentHundreds > 0 && !hasRibuInCurrent) {
            commitAndReset();
          }
          currentHundreds = numVal;
          currentTensUnits = 0;
          hasAnyNumberInCurrent = true;
        } else {
          // numVal < 100 (misal "25" dalam "25 ribu")
          currentTensUnits = numVal;
          hasAnyNumberInCurrent = true;
        }
        continue;
      }

      // 3. Cek kata bilangan Bahasa Indonesia
      if (unitMap.containsKey(stripped)) {
        final val = unitMap[stripped]!;
        hasAnyNumberInCurrent = true;
        if (val >= 10) {
          // "sepuluh" atau "sebelas"
          currentTensUnits = val;
        } else if (currentTensUnits > 0 && currentTensUnits % 10 != 0) {
          // Jika satuan disebut berurutan tanpa "puluh"/"belas"/"ribu", ganti ke satuan baru
          currentTensUnits = val;
        } else {
          currentTensUnits += val;
        }
      } else if (stripped == 'belas') {
        hasAnyNumberInCurrent = true;
        final unit = currentTensUnits % 10;
        currentTensUnits = (unit == 0 ? 1 : unit) + 10;
      } else if (stripped == 'puluh') {
        hasAnyNumberInCurrent = true;
        final unit = currentTensUnits % 10;
        currentTensUnits = (unit == 0 ? 1 : unit) * 10;
      } else if (stripped == 'seratus') {
        hasAnyNumberInCurrent = true;
        currentHundreds = 100;
        currentTensUnits = 0;
      } else if (stripped == 'ratus') {
        hasAnyNumberInCurrent = true;
        final unit = currentTensUnits % 10;
        currentHundreds = (unit == 0 ? 1 : unit) * 100;
        currentTensUnits = 0;
      } else if (stripped == 'seribu') {
        if (hasRibuInCurrent) {
          commitAndReset();
        }
        majorTotal += 1000;
        hasRibuInCurrent = true;
        currentHundreds = 0;
        currentTensUnits = 0;
        hasAnyNumberInCurrent = true;
      } else if (stripped == 'ribu' || stripped == 'rb') {
        hasAnyNumberInCurrent = true;
        if (!hasRibuInCurrent) {
          final sub = currentHundreds + currentTensUnits;
          final mult = sub == 0 ? 1 : sub;
          majorTotal += mult * 1000 + (hasSetengah && sub > 0 ? 500 : 0);
          hasSetengah = false;
          hasRibuInCurrent = true;
          currentHundreds = 0;
          currentTensUnits = 0;
        } else {
          // Kata "ribu" muncul lagi di dalam kalimat yang sama (misal: "dua puluh ribu lima belas ribu")
          // -> Pengucapan nominal baru! Gantikan nominal sebelumnya dengan nominal ribuan yang baru ini.
          final newSub = currentTensUnits > 0
              ? (currentHundreds > 0 && currentHundreds != 500
                    ? currentHundreds + currentTensUnits
                    : currentTensUnits)
              : (currentHundreds > 0 ? currentHundreds : 1);
          lastCompletedNominal = computeCurrentTotal();
          majorTotal = newSub * 1000 + (hasSetengah ? 500 : 0);
          hasSetengah = false;
          hasRibuInCurrent = true;
          hasJutaInCurrent = false;
          currentHundreds = 0;
          currentTensUnits = 0;
        }
      } else if (stripped == 'sejuta') {
        if (hasJutaInCurrent || hasRibuInCurrent) {
          commitAndReset();
        }
        majorTotal = 1000000;
        hasJutaInCurrent = true;
        hasAnyNumberInCurrent = true;
      } else if (stripped == 'juta') {
        hasAnyNumberInCurrent = true;
        final sub = currentHundreds + currentTensUnits;
        if (hasJutaInCurrent || (hasRibuInCurrent && sub > 0)) {
          lastCompletedNominal = computeCurrentTotal();
          majorTotal = 0;
          hasRibuInCurrent = false;
        }
        final mult = sub == 0 ? 1 : sub;
        majorTotal = mult * 1000000 + (hasSetengah ? 500000 : 0);
        hasSetengah = false;
        hasJutaInCurrent = true;
        currentHundreds = 0;
        currentTensUnits = 0;
      } else if (stripped == 'setengah') {
        hasAnyNumberInCurrent = true;
        if (hasRibuInCurrent && currentHundreds == 0 && currentTensUnits == 0) {
          // Misal "dua puluh lima ribu setengah" -> +500
          currentHundreds = 500;
        } else {
          hasSetengah = true;
        }
      }
    }

    if (hasAnyNumberInCurrent) {
      final currentVal = computeCurrentTotal();
      if (currentVal > 0) {
        return currentVal;
      }
    }
    return lastCompletedNominal;
  }
}
