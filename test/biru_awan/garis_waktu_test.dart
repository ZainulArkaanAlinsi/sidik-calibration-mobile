// GarisWaktu: riwayat perubahan (simpul 12 primer, garis halus 2, pelaku tebal).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/widgets/biru_awan/garis_waktu.dart';

import '../support/uji_lanjut_biru_awan.dart';

const _butir = [
  ButirGarisWaktu(
    waktu: 'Hari ini, 08.42',
    pelaku: 'Admin',
    kalimat: 'mengubah U standar Buffer pH 10,01',
    detail: Text('0,02 menjadi 0,03'),
  ),
  ButirGarisWaktu(
    waktu: 'Kemarin, 16.10',
    kalimat: 'Sesi dikirim untuk approval',
  ),
  ButirGarisWaktu(
    waktu: '12 Nov, 09.00',
    pelaku: 'Siti',
    kalimat: 'membuat draf',
  ),
];

void main() {
  setUpAll(muatFontUji);

  group('bentuk', () {
    testWidgets('simpul 12 primer, garis 2 halus, tersambung ke butir berikut', (
      tester,
    ) async {
      await pasang(tester, const GarisWaktu(butir: _butir));
      final s = skemaWarna(tester);
      final m = bahan(tester);
      // Simpul: lingkaran 12 primer.
      final simpul = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(simpul, findsNWidgets(3));
      for (final e in tester.widgetList<DecoratedBox>(simpul)) {
        expect((e.decoration as BoxDecoration).color, s.primary);
      }
      expect(tester.getSize(simpul.first), const Size(12, 12));
      // Garis: 2 buah (butir terakhir tanpa garis), lebar 2, warna garis halus.
      final garis = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == m.kertasTepi,
      );
      expect(garis, findsNWidgets(2));
      expect(tester.getSize(garis.first).width, 2);
      // Garis butir 1 menyambung dari simpul 1 ke simpul 2.
      final titik = [
        for (final e in simpul.evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      final garis1 = tester.getRect(garis.first);
      expect(garis1.top, closeTo(titik[0].bottom, 0.5));
      expect(garis1.bottom, closeTo(titik[1].top, 0.5 + 6));
    });

    testWidgets('simpul turun 6 dari atas butir; jarak simpul ke teks 12', (
      tester,
    ) async {
      await pasang(tester, const GarisWaktu(butir: _butir));
      final waktu = tester.getRect(find.text('Hari ini, 08.42'));
      final simpul = tester.getRect(
        find
            .byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).shape == BoxShape.circle,
            )
            .first,
      );
      expect(simpul.top - tester.getTopLeft(find.byType(GarisWaktu)).dy, 6);
      expect(waktu.left - simpul.right, 12);
    });

    testWidgets('pelaku tebal 800, kalimat 15/400; tanpa pelaku tanpa spasi '
        'depan', (tester) async {
      await pasang(tester, const GarisWaktu(butir: _butir));
      final teks = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((r) => r.text)
          .whereType<TextSpan>()
          .toList();
      final akar = teks.firstWhere(
        (t) => t.toPlainText() == 'Admin mengubah U standar Buffer pH 10,01',
      );
      final kalimat1 = akar.children!.single as TextSpan;
      expect(kalimat1.style!.fontSize, 15);
      expect(kalimat1.style!.fontWeight, FontWeight.w400);
      final pelaku = kalimat1.children!.first as TextSpan;
      expect(pelaku.text, 'Admin');
      expect(pelaku.style!.fontWeight, FontWeight.w800);
      expect(
        teks.any((t) => t.toPlainText() == 'Sesi dikirim untuk approval'),
        isTrue,
      );
      expect(
        tester.widget<Text>(find.text('Hari ini, 08.42')).style!.fontSize,
        12,
      );
    });

    testWidgets('urutan tampil = urutan data; detail tampil di bawah kalimat', (
      tester,
    ) async {
      await pasang(tester, const GarisWaktu(butir: _butir));
      final atas = tester.getTopLeft(find.text('Hari ini, 08.42')).dy;
      final tengah = tester.getTopLeft(find.text('Kemarin, 16.10')).dy;
      final bawah = tester.getTopLeft(find.text('12 Nov, 09.00')).dy;
      expect(atas, lessThan(tengah));
      expect(tengah, lessThan(bawah));
      expect(
        tester.getTopLeft(find.text('0,02 menjadi 0,03')).dy,
        greaterThan(atas),
      );
    });

    testWidgets('daftar kosong tidak error', (tester) async {
      await pasang(tester, const GarisWaktu(butir: []));
      expect(tester.takeException(), isNull);
    });
  });

  group('kontras dan semantik', () {
    for (final gelap in [false, true]) {
      testWidgets('kontras teks ≥ 4,5 (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        await pasang(tester, const GarisWaktu(butir: _butir), gelap: gelap);
        expect(
          pelanggaranKontrasTeks(tester, find.byType(GarisWaktu)),
          isEmpty,
        );
        expect(
          rasioKontras(skemaWarna(tester).primary, bahan(tester).kertas),
          greaterThanOrEqualTo(3),
          reason: 'simpul primer terhadap kertas',
        );
      });
    }

    testWidgets('satu node per butir: waktu, pelaku + kalimat, detail', (
      tester,
    ) async {
      final s = tester.ensureSemantics();
      await pasang(tester, const GarisWaktu(butir: _butir));
      final d = semantik(tester, find.text('Hari ini, 08.42'));
      expect(d.label, contains('Hari ini, 08.42'));
      expect(d.label, contains('Admin mengubah U standar Buffer pH 10,01'));
      expect(d.label, contains('0,02 menjadi 0,03'));
      expect(d.label, isNot(contains('Kemarin')));
      s.dispose();
    });

    testWidgets('bukan kontrol: tanpa aksi ketuk', (tester) async {
      final s = tester.ensureSemantics();
      await pasang(tester, const GarisWaktu(butir: _butir));
      final d = semantik(tester, find.text('Hari ini, 08.42'));
      expect(d.flagsCollection.isButton, isFalse);
      s.dispose();
    });
  });

  group('gerak dan huruf', () {
    testWidgets('tanpa animasi', (tester) async {
      await pasang(tester, const GarisWaktu(butir: _butir));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('320 dp x huruf 1,3: kalimat panjang membungkus', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        const GarisWaktu(
          butir: [
            ButirGarisWaktu(
              waktu: 'Hari ini, 08.42',
              pelaku: 'Admin Master Data Laboratorium',
              kalimat:
                  'mengubah ketidakpastian standar Buffer pH 10,01 dan '
                  'memperbarui tanggal jatuh tempo kalibrasi ulang',
              detail: Wrap(children: [Text('0,02'), Text('0,03')]),
            ),
            ButirGarisWaktu(waktu: 'Kemarin', kalimat: 'dibuat'),
          ],
        ),
        tinggi: 1400,
      );
    });
  });
}
