import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudepi/constants/sudepi_prompts.dart';
import 'package:sudepi/models/rupiah_denomination.dart';
import 'package:sudepi/screens/standby_screen.dart';
import 'package:sudepi/utils/indonesian_number_parser.dart';

void main() {
  group('SUDEPI 7-Class Denomination & Indonesian Voice Parser Tests', () {
    test('Urutan 7 kelas uang kertas sesuai data.yaml (0..6)', () {
      expect(RupiahDenomination.values.length, 7);
      expect(RupiahDenomination.fromClassId(0)?.code, 'rp1000');
      expect(RupiahDenomination.fromClassId(1)?.code, 'rp2000');
      expect(RupiahDenomination.fromClassId(2)?.code, 'rp5000');
      expect(RupiahDenomination.fromClassId(3)?.code, 'rp10000');
      expect(RupiahDenomination.fromClassId(4)?.code, 'rp20000');
      expect(RupiahDenomination.fromClassId(5)?.code, 'rp50000');
      expect(RupiahDenomination.fromClassId(6)?.code, 'rp100000');
      expect(RupiahDenomination.fromClassId(-1), isNull);
      expect(RupiahDenomination.fromClassId(7), isNull);
    });

    test('Parser angka Bahasa Indonesia dan perintah satu napas', () {
      final cmd1 = IndonesianNumberParser.parseVoiceInput('dua puluh lima ribu');
      expect(cmd1.amount, 25000);
      expect(cmd1.hasAdvanceIntent, isFalse);

      final cmd2 = IndonesianNumberParser.parseVoiceInput(
        'dua puluh lima ribu lanjut',
      );
      expect(cmd2.amount, 25000);
      expect(cmd2.hasAdvanceIntent, isTrue);

      final cmd3 = IndonesianNumberParser.parseVoiceInput('seratus ribu');
      expect(cmd3.amount, 100000);

      final cmd4 = IndonesianNumberParser.parseVoiceInput('Rp 50.000 lanjutkan');
      expect(cmd4.amount, 50000);
      expect(cmd4.hasAdvanceIntent, isTrue);

      final cmd5 = IndonesianNumberParser.parseVoiceInput(
        'dua puluh ribu ulangi lima belas ribu',
      );
      expect(cmd5.amount, 15000);
      expect(cmd5.hasRepeatIntent, isTrue);

      final cmd6 = IndonesianNumberParser.parseVoiceInput(
        'lima puluh ribu hapus',
      );
      expect(cmd6.amount, isNull);
      expect(cmd6.hasRepeatIntent, isTrue);

      // Multi-ulangi & multi-nominal tanpa batas dalam 1 tahanan
      final cmd7 = IndonesianNumberParser.parseVoiceInput(
        'dua puluh ribu ulangi lima belas ribu ulangi lima puluh ribu',
      );
      expect(cmd7.amount, 50000);
      expect(cmd7.hasRepeatIntent, isTrue);

      final cmd8 = IndonesianNumberParser.parseVoiceInput(
        'dua puluh ribu lima belas ribu empat puluh ribu',
      );
      expect(cmd8.amount, 40000);

      final cmd9 = IndonesianNumberParser.parseVoiceInput(
        '20.000 15.000 50.000',
      );
      expect(cmd9.amount, 50000);

      final cmd10 = IndonesianNumberParser.parseVoiceInput(
        '20 ribu 15 ribu 35 ribu',
      );
      expect(cmd10.amount, 35000);

      final cmd11 = IndonesianNumberParser.parseVoiceInput(
        'dua puluh lima ribu lima ratus',
      );
      expect(cmd11.amount, 25500);

      final cmd12 = IndonesianNumberParser.parseVoiceInput(
        'dua puluh lima ribu lima ratus tiga puluh ribu',
      );
      expect(cmd12.amount, 30000);
    });

    test('Parser istilah sehari-hari (goceng, ceban, goban, seceng, setengah) & intent kembali', () {
      expect(IndonesianNumberParser.parseVoiceInput('goceng').amount, 5000);
      expect(IndonesianNumberParser.parseVoiceInput('ceban').amount, 10000);
      expect(IndonesianNumberParser.parseVoiceInput('goban').amount, 50000);
      expect(IndonesianNumberParser.parseVoiceInput('seceng').amount, 1000);
      expect(
        IndonesianNumberParser.parseVoiceInput('dua puluh lima ribu setengah').amount,
        25500,
      );

      final backCmd = IndonesianNumberParser.parseVoiceInput('kembali');
      expect(backCmd.hasBackIntent, isTrue);
      expect(backCmd.amount, isNull);

      final emptyCmd = IndonesianNumberParser.parseVoiceInput('   ');
      expect(emptyCmd.hasAnyAction, isFalse);
    });

    test('Konversi terbilang Rupiah dan format tampilan Rupiah (tanpa & dengan spasi)', () {
      expect(IndonesianNumberParser.formatRupiah(25000), 'Rp25.000');
      expect(
        IndonesianNumberParser.formatRupiah(25000, withSpace: true),
        'Rp 25.000',
      );
      expect(IndonesianNumberParser.formatRupiah(0, withSpace: true), 'Rp 0');
      expect(
        IndonesianNumberParser.formatRupiah(100000, withSpace: true),
        'Rp 100.000',
      );
      expect(
        IndonesianNumberParser.terbilangRupiah(25000),
        'dua puluh lima ribu rupiah',
      );
      expect(
        IndonesianNumberParser.terbilangRupiah(50000),
        'lima puluh ribu rupiah',
      );
      expect(IndonesianNumberParser.digitToWord('7'), 'tujuh');
    });

    test('Konsistensi skrip suara Blind-First UX pada SudepiPrompts', () {
      // Orientasi murni Mode Siaga tidak menyebut nominal uang bekas sebelumnya
      expect(
        SudepiPrompts.standbySingleTapInfo,
        'Mode siaga. Arahkan kamera ke uang, atau usap layar ke kiri untuk mulai transaksi.',
      );

      // Respons instan 0 ms saat lepas tahan layar diawali kata konfirmasi "Baik,"
      final capturedPrompt = SudepiPrompts.voiceAmountCaptured(
        'dua puluh lima ribu rupiah',
      );
      expect(capturedPrompt.startsWith('Baik, dua puluh lima ribu rupiah.'), isTrue);

      // Pengingat khusus sisa kembalian koin (< Rp1.000)
      final coinPrompt = SudepiPrompts.changeCoinRemainder(
        billSpoken: 'sepuluh ribu rupiah',
        totalSpoken: 'sepuluh ribu rupiah',
        selisihSpoken: 'lima ratus rupiah',
      );
      expect(coinPrompt.contains('berupa koin'), isTrue);
      expect(coinPrompt.contains('usap layar ke kiri'), isTrue);
    });

    testWidgets(
      'Header Mode Siaga memuat simbol logo SUDEPI (excludeFromSemantics) dan mendukung ketuk 3x simulasi',
      (WidgetTester tester) async {
        var simulationToggled = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: StandbyScreen(
              cameraController: null,
              isCameraInitialized: false,
              isTorchOn: false,
              isTorchAutoLatched: false,
              lockedDenomination: null,
              lockedAccuracyPercent: 0,
              showSimulationBar: false,
              onSingleTapAnywhere: () {},
              onStartTransaction: () {},
              onToggleTorchManual: () {},
              onTorchIndicatorTapInfo: () {},
              onToggleSimulationMode: () {
                simulationToggled++;
              },
              onSimulateBill: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);

        final imageWidget = tester.widget<Image>(imageFinder);
        expect(imageWidget.excludeFromSemantics, isTrue);
        expect(imageWidget.width, 26);
        expect(imageWidget.height, 26);

        // Ketuk 3x pada area brand (simbol / teks SUDEPI) memicu toggle simulasi
        // (jeda virtual > kDoubleTapTimeout 300ms agar arena menyelesaikan onTap anak)
        await tester.tap(imageFinder);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.text('SUDEPI'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(imageFinder);
        await tester.pump(const Duration(milliseconds: 350));

        expect(simulationToggled, 1);
      },
    );
  });
}
