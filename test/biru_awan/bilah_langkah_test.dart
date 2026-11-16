// BilahLangkah: 4 segmen tinggi 6, sudut 3, label 12 ("1 Alat").
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/widgets/biru_awan/bilah_langkah.dart';

import '../support/uji_lanjut_biru_awan.dart';

const _label = ['Alat', 'Data', 'Lembar', 'Kirim'];

Widget _b({int aktif = 0, List<String> label = _label}) => Padding(
  padding: const EdgeInsets.all(16),
  child: BilahLangkah(label: label, aktif: aktif),
);

/// Segmen bilah (kotak berwarna tinggi 6).
Finder _segmen() => find.byWidgetPredicate(
  (w) =>
      w is SizedBox &&
      w.height == UkuranBiruAwan.bilahLangkah &&
      w.child is DecoratedBox,
);

Color? _warna(WidgetTester tester, int i) =>
    ((tester.widget<SizedBox>(_segmen().at(i)).child! as DecoratedBox)
                .decoration
            as BoxDecoration)
        .color;

void main() {
  setUpAll(muatFontUji);

  group('bentuk', () {
    testWidgets('empat segmen sama lebar, tinggi 6, sudut 3, jarak 6', (
      tester,
    ) async {
      await pasang(tester, _b());
      expect(_segmen(), findsNWidgets(4));
      final r = [for (var i = 0; i < 4; i++) tester.getRect(_segmen().at(i))];
      for (final k in r) {
        expect(k.height, 6);
        expect(k.width, closeTo(r.first.width, 0.01));
      }
      for (var i = 0; i < 3; i++) {
        expect(r[i + 1].left - r[i].right, 6);
      }
      final dekor =
          (tester.widget<SizedBox>(_segmen().first).child! as DecoratedBox)
                  .decoration
              as BoxDecoration;
      expect(dekor.borderRadius, BorderRadius.circular(3));
    });

    testWidgets('segmen terisi primer sampai langkah sekarang, sisanya '
        'garisDekor; label menebal pada langkah sekarang', (tester) async {
      for (var aktif = 0; aktif < 4; aktif++) {
        await pasang(tester, _b(aktif: aktif));
        final primer = skemaWarna(tester).primary;
        final dekor = warnaLanjut(tester).garisDekor;
        for (var i = 0; i < 4; i++) {
          expect(
            _warna(tester, i),
            i <= aktif ? primer : dekor,
            reason: 'aktif=$aktif segmen $i',
          );
          final berat = tester
              .widget<Text>(find.text('${i + 1} ${_label[i]}'))
              .style!
              .fontWeight;
          expect(
            berat,
            i == aktif
                ? FontWeight.w600
                : i < aktif
                ? FontWeight.w500
                : FontWeight.w400,
            reason: 'aktif=$aktif label $i',
          );
        }
      }
    });

    testWidgets('aktif di luar rentang dibatasi; daftar kosong tidak error', (
      tester,
    ) async {
      await pasang(tester, _b(aktif: 99));
      expect(_warna(tester, 3), skemaWarna(tester).primary);
      await pasang(tester, _b(aktif: -5));
      expect(_warna(tester, 0), skemaWarna(tester).primary);
      expect(_warna(tester, 1), warnaLanjut(tester).garisDekor);
      await pasang(tester, _b(label: const []));
      expect(tester.takeException(), isNull);
    });
  });

  group('kontras', () {
    for (final gelap in [false, true]) {
      testWidgets(
        'label ≥ 4,5:1 dan segmen primer ≥ 3:1 (${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          await pasang(tester, _b(aktif: 1), gelap: gelap);
          expect(
            pelanggaranKontrasTeks(tester, find.byType(BilahLangkah)),
            isEmpty,
          );
          expect(
            rasioKontras(skemaWarna(tester).primary, bahan(tester).meja),
            greaterThanOrEqualTo(ambangBukanTeks),
          );
        },
      );
    }
  });

  group('semantik', () {
    testWidgets('satu node per segmen: "Langkah n dari 4, keadaan, label"', (
      tester,
    ) async {
      final s = tester.ensureSemantics();
      await pasang(tester, _b(aktif: 1));
      expect(
        find.bySemanticsLabel('Langkah 1 dari 4, selesai, Alat'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Langkah 2 dari 4, langkah sekarang, Data'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Langkah 4 dari 4, belum, Kirim'),
        findsOneWidget,
      );
      expect(
        semantik(
          tester,
          find.bySemanticsLabel('Langkah 2 dari 4, langkah sekarang, Data'),
        ).hasAction(SemanticsAction.tap),
        isFalse,
      );
      s.dispose();
    });
  });

  group('gerak dan huruf', () {
    testWidgets('tanpa animasi', (tester) async {
      await pasang(tester, _b());
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('320 dp x huruf 1,3: label membungkus maks 2 baris', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        const BilahLangkah(
          label: ['Pilih alat', 'Isi data', 'Lembar kerja', 'Kirim'],
          aktif: 2,
        ),
      );
    });
  });
}
