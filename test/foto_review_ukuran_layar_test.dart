import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/review_foto.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/screens/calibration/widgets/keypad_angka.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

/// Isian cepat di berbagai ukuran layar dan skala huruf (probe peninjau 12 Nov
/// 2026): keypad ±310 dp membuat 320×568 hanya menyisakan 8 dp untuk daftar dan
/// mendorong tombol "Konfirmasi dan lanjut" keluar layar. Di layar sempit,
/// huruf besar, dan HP lanskap review memakai papan ketik sistem + panel
/// ringkas; di layar lega keypad adaptif. Di SEMUA ukuran: tidak ada overflow,
/// tombol Konfirmasi, penghitung sisa, dan sel aktif terlihat.
void main() {
  final png = Uint8List.fromList(
    img.encodePng(
      img.Image(width: 120, height: 48)..clear(img.ColorRgb8(240, 240, 240)),
    ),
  );

  BarisReviewFoto baris(int i, {bool merah = false}) => (
    titikUkur: i.toDouble(),
    repeatNo: 1,
    fieldId: 'pembacaan',
    judul: 'Sel $i',
    teks: merah ? '' : '$i,00',
    keyakinan: merah ? 0.0 : 0.99,
    vonis: NilaiVonisFoto.dari(merah ? 0.0 : 0.99),
    potongan: png,
  );

  // 8 kuning lalu 2 merah: probe menekan Konfirmasi di kuning berturut-turut.
  List<BarisReviewFoto> isi() => [
    for (var i = 1; i <= 8; i++) baris(i),
    baris(9, merah: true),
    baris(10, merah: true),
  ];

  Future<void> buka(
    WidgetTester tester,
    Size ukuran,
    double skala, {
    double papanKetik = 0,
  }) async {
    tester.view.physicalSize = ukuran;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: papanKetik);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('id'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(skala)),
          child: child!,
        ),
        home: FotoReviewScreen(baris: isi()),
      ),
    );
    await tester.pumpAndSettle();
  }

  final konfirmasi = find.byKey(const ValueKey('konfirmasi-lanjut'));
  final sisa = find.byKey(const ValueKey('keypad-sisa'));

  /// Judul baris di DAFTAR (bukan di kepala panel yang memakai teks sama).
  Finder judulBaris(int i) => find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.text('Sel $i'),
  );

  void periksaTerlihat(
    WidgetTester tester,
    Size ukuran,
    int aktif, {
    double papanKetik = 0,
  }) {
    expect(tester.takeException(), isNull, reason: 'overflow / galat render');

    final batas = Rect.fromLTWH(0, 0, ukuran.width, ukuran.height - papanKetik);
    final k = tester.getRect(konfirmasi);
    expect(
      batas.contains(k.topLeft) && batas.contains(k.bottomRight),
      isTrue,
      reason: 'tombol Konfirmasi di luar layar: $k vs $batas',
    );

    expect(sisa, findsOneWidget);
    final s = tester.getRect(sisa);
    expect(
      batas.contains(s.topLeft) && batas.contains(s.bottomRight),
      isTrue,
      reason: 'penghitung sisa di luar layar: $s',
    );

    // Sel aktif ada di daftar, di bawah app bar dan di atas panel.
    expect(
      judulBaris(aktif),
      findsOneWidget,
      reason: 'sel $aktif tidak dibangun',
    );
    final b = tester.getRect(judulBaris(aktif));
    expect(
      b.top,
      greaterThanOrEqualTo(kToolbarHeight - 1),
      reason: 'sel aktif di bawah app bar',
    );
    expect(
      b.bottom,
      lessThanOrEqualTo(s.top + 1),
      reason: 'sel aktif tertutup panel',
    );
  }

  // (lebar, tinggi, skala huruf, keypad layar dipakai?)
  final ukuranUji = <(double, double, double, bool)>[
    // sempit / pendek / huruf besar / lanskap HP -> papan ketik sistem
    (320, 568, 1.0, false),
    (320, 568, 1.3, false),
    (360, 640, 1.0, false),
    (360, 640, 1.3, false),
    (640, 360, 1.0, false),
    (640, 360, 1.3, false),
    (360, 800, 1.3, false),
    // aman -> keypad layar
    (360, 800, 1.0, true),
    (411, 891, 1.0, true),
    (600, 960, 1.0, true),
    (1280, 800, 1.0, true),
  ];

  for (final (w, h, skala, keypad) in ukuranUji) {
    testWidgets(
      '${w.toInt()}×${h.toInt()} huruf $skala×: ${keypad ? 'keypad layar' : 'papan ketik sistem'}, '
      'tombol Konfirmasi, sisa, dan sel aktif terlihat',
      (tester) async {
        final ukuran = Size(w, h);
        await buka(tester, ukuran, skala);

        await tester.tap(find.byKey(const ValueKey('mulai-isi-cepat')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('keypad-7')),
          keypad ? findsOneWidget : findsNothing,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField).first).keyboardType,
          keypad
              ? TextInputType.none
              : const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
        );
        periksaTerlihat(tester, ukuran, 1);

        // Beberapa sel berturut-turut: panel dan sel aktif tetap terlihat.
        for (var i = 2; i <= 5; i++) {
          await tester.tap(konfirmasi);
          await tester.pumpAndSettle();
          periksaTerlihat(tester, ukuran, i);
        }
      },
    );
  }

  testWidgets(
    'papan ketik sistem terbuka (360×640, huruf 1,3×): panel mini, tidak overflow',
    (tester) async {
      const ukuran = Size(360, 640);
      await buka(tester, ukuran, 1.3, papanKetik: 280);

      await tester.tap(find.byKey(const ValueKey('mulai-isi-cepat')));
      await tester.pumpAndSettle();

      periksaTerlihat(tester, ukuran, 1, papanKetik: 280);
      expect(
        find.byKey(const ValueKey('keypad-crop')),
        findsNothing,
        reason: 'mode mini: tanpa kepala',
      );

      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
      periksaTerlihat(tester, ukuran, 2, papanKetik: 280);
    },
  );

  testWidgets(
    'penghitung sisa menurun tiap konfirmasi dan tetap terlihat saat panel terbuka',
    (tester) async {
      const ukuran = Size(360, 800);
      await buka(tester, ukuran, 1.0);
      await tester.tap(find.byKey(const ValueKey('mulai-isi-cepat')));
      await tester.pumpAndSettle();

      String teksSisa() => tester.widget<Text>(sisa).data!;
      // 8 kuning belum dicek + 2 merah kosong.
      expect(teksSisa(), 'Sisa 10 sel');

      await tester.tap(konfirmasi);
      await tester.pumpAndSettle();
      expect(teksSisa(), 'Sisa 9 sel');
    },
  );

  testWidgets('kepala panel memuat crop sel aktif dan isi kotaknya', (
    tester,
  ) async {
    await buka(tester, const Size(360, 800), 1.0);
    await tester.tap(find.byKey(const ValueKey('mulai-isi-cepat')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('keypad-crop')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('keypad-teks'))).data,
      '1,00',
    );
  });

  group('bolehKeypadLayar', () {
    MediaQueryData mq(double w, double h, {double skala = 1.0}) =>
        MediaQueryData(size: Size(w, h), textScaler: TextScaler.linear(skala));

    test('layar lega boleh', () {
      expect(bolehKeypadLayar(mq(360, 800)), isTrue);
      expect(bolehKeypadLayar(mq(1280, 800)), isTrue, reason: 'tablet lanskap');
      expect(bolehKeypadLayar(mq(600, 960, skala: 1.15)), isTrue);
    });

    test('pendek, huruf besar, atau HP lanskap tidak', () {
      expect(bolehKeypadLayar(mq(360, 699)), isFalse);
      expect(bolehKeypadLayar(mq(360, 800, skala: 1.16)), isFalse);
      expect(bolehKeypadLayar(mq(640, 360)), isFalse);
      expect(
        bolehKeypadLayar(mq(800, 720)),
        isTrue,
        reason: 'lanskap tapi sisi pendek 720',
      );
    });
  });
}
