// UbinKpi: ubin angka 2 x 2 beranda admin (min 112, sudut 24, angka 36/800).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/motion/gerak_bersama.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan_lanjut.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/ubin_kpi.dart';

import '../support/uji_lanjut_biru_awan.dart';

Widget _ubin({
  RagamUbinKpi ragam = RagamUbinKpi.putih,
  VoidCallback? onTap,
  String nilai = '128',
  String? catatan = 'se-lab',
  String label = 'Total alat',
}) => SizedBox(
  width: 170,
  child: UbinKpi(
    label: label,
    nilai: nilai,
    catatan: catatan,
    ragam: ragam,
    onTap: onTap,
  ),
);

Finder _material() =>
    find.descendant(of: find.byType(UbinKpi), matching: find.byType(Material));

void main() {
  setUpAll(muatFontUji);

  group('ukuran dan bentuk', () {
    testWidgets('minimum 112, bantalan 16, angka 36/800, label 13/700', (
      tester,
    ) async {
      await pasang(tester, Center(child: _ubin()));
      expect(tester.getSize(find.byType(UbinKpi)).height, 112);
      final ubin = tester.getRect(find.byType(UbinKpi));
      expect(
        tester.getTopLeft(find.text('Total alat')) - ubin.topLeft,
        const Offset(16, 16),
      );
      expect(
        ubin.bottom - tester.getBottomLeft(find.text('128')).dy,
        16,
        reason: 'angka duduk di dasar, bantalan 16',
      );
      final angka = tester.widget<Text>(find.text('128')).style!;
      expect(angka.fontSize, 36);
      expect(angka.fontWeight, FontWeight.w800);
      final label = tester.widget<Text>(find.text('Total alat')).style!;
      expect(label.fontSize, 13);
      expect(label.fontWeight, FontWeight.w700);
    });

    testWidgets('sudut 24; ragam navy sudut 28', (tester) async {
      await pasang(tester, Center(child: _ubin()));
      expect(
        tester.widget<Material>(_material()).borderRadius,
        BorderRadius.circular(BentukBiruAwan.kartu),
      );
      await pasang(tester, Center(child: _ubin(ragam: RagamUbinKpi.navy)));
      expect(
        tester.widget<Material>(_material()).borderRadius,
        BorderRadius.circular(BentukBiruAwan.hero),
      );
    });

    testWidgets('tumbuh bila label membungkus; tidak lebih kecil dari 112', (
      tester,
    ) async {
      await pasang(
        tester,
        Center(
          child: _ubin(
            label: 'Sertifikat yang terbit bulan ini untuk semua pelanggan',
          ),
        ),
      );
      expect(tester.getSize(find.byType(UbinKpi)).height, greaterThan(112));
    });

    testWidgets('angka dan catatan apa adanya, tanpa diformat', (tester) async {
      await pasang(
        tester,
        Center(
          child: _ubin(nilai: '0,50', catatan: '+4'),
        ),
      );
      expect(find.text('0,50'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
    });

    testWidgets('tanpa catatan: hanya label dan angka', (tester) async {
      await pasang(tester, Center(child: _ubin(catatan: null)));
      expect(find.text('se-lab'), findsNothing);
      expect(find.text('128'), findsOneWidget);
    });
  });

  group('warna per ragam dan kontras', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('isi dan tinta tiap ragam ($nama)', (tester) async {
        for (final r in RagamUbinKpi.values) {
          await pasang(
            tester,
            Center(child: _ubin(ragam: r)),
            gelap: gelap,
          );
          final m = bahan(tester);
          final w = warna(tester);
          final (Color isi, Color tinta) = switch (r) {
            RagamUbinKpi.putih => (m.kertas, m.tinta),
            RagamUbinKpi.kabut => (
              w.isi(IsiBiruAwan.kabut),
              w.tinta(IsiBiruAwan.kabut),
            ),
            RagamUbinKpi.hijau => (
              w.isi(IsiBiruAwan.hijau),
              w.tinta(IsiBiruAwan.hijau),
            ),
            RagamUbinKpi.kuning => (
              w.isi(IsiBiruAwan.kuning),
              w.tinta(IsiBiruAwan.kuning),
            ),
            RagamUbinKpi.awan => (
              w.isi(IsiBiruAwan.awan),
              w.tinta(IsiBiruAwan.awan),
            ),
            RagamUbinKpi.koral => (
              w.isi(IsiBiruAwan.koral),
              w.tinta(IsiBiruAwan.koral),
            ),
            RagamUbinKpi.navy => (m.tinta, m.kertas),
          };
          expect(tester.widget<Material>(_material()).color, isi, reason: '$r');
          for (final t in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(UbinKpi),
              matching: find.byType(Text),
            ),
          )) {
            expect(t.style!.color, tinta, reason: '$r ${t.data} ($nama)');
          }
          expect(
            pelanggaranKontrasTeks(tester, find.byType(UbinKpi)),
            isEmpty,
            reason: '$r ($nama)',
          );
        }
      });
    }

    testWidgets('koral tidak dipakai ragam lain; hijau hanya ragam hijau', (
      tester,
    ) async {
      await pasang(tester, Center(child: _ubin()));
      final w = warna(tester);
      expect(
        tester.widget<Material>(_material()).color,
        isNot(w.isi(IsiBiruAwan.hijau)),
      );
    });
  });

  group('semantik dan ketuk', () {
    testWidgets('satu node berlabel "label, angka, catatan"; tanpa onTap tanpa '
        'aksi dan bukan tombol', (tester) async {
      final s = tester.ensureSemantics();
      await pasang(tester, Center(child: _ubin()));
      final d = semantik(tester, find.byType(UbinKpi));
      expect(d.label, 'Total alat, 128, se-lab');
      expect(d.hasAction(SemanticsAction.tap), isFalse);
      expect(d.flagsCollection.isButton, isFalse);
      expect(find.byType(InkWell), findsNothing);
      s.dispose();
    });

    testWidgets('dengan onTap: tombol berlabel yang sama + aksi ketuk', (
      tester,
    ) async {
      final s = tester.ensureSemantics();
      await pasang(tester, Center(child: _ubin(onTap: () {})));
      final d = semantik(tester, find.byType(UbinKpi));
      expect(d.label, 'Total alat, 128, se-lab');
      expect(d.hasAction(SemanticsAction.tap), isTrue);
      expect(d.flagsCollection.isButton, isTrue);
      await periksaPedomanSentuh(tester);
      s.dispose();
    });

    testWidgets('ketuk di sudut mana pun ubin bekerja', (tester) async {
      var n = 0;
      await pasang(tester, Center(child: _ubin(onTap: () => n++)));
      final r = tester.getRect(find.byType(UbinKpi));
      for (final p in [
        r.topLeft + const Offset(10, 10),
        r.topRight + const Offset(-10, 10),
        r.bottomLeft + const Offset(10, -10),
        r.bottomRight + const Offset(-10, -10),
        r.center,
      ]) {
        await tester.tapAt(p);
      }
      expect(n, 5);
    });

    testWidgets('ketuk pada ubin tanpa onTap tidak melakukan apa-apa', (
      tester,
    ) async {
      await pasang(tester, Center(child: _ubin()));
      await tester.tap(find.byType(UbinKpi));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('tekan: skala 0,97 hanya bila bisa diketuk', (tester) async {
      for (final bisa in [true, false]) {
        await pasang(tester, Center(child: _ubin(onTap: bisa ? () {} : null)));
        final g = await tester.startGesture(
          tester.getCenter(find.byType(UbinKpi)),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final skala = tester
            .widget<AnimatedScale>(
              find.descendant(
                of: find.byType(UbinKpi),
                matching: find.byType(AnimatedScale),
              ),
            )
            .scale;
        expect(skala, bisa ? GerakBersama.skalaTekan : 1, reason: 'bisa=$bisa');
        await g.up();
        await tester.pump();
      }
    });
  });

  group('gerak dan huruf', () {
    testWidgets('angka tidak dianimasikan dan tanpa animasi apa pun', (
      tester,
    ) async {
      await pasang(tester, Center(child: _ubin(onTap: () {})));
      expect(find.text('128'), findsOneWidget, reason: 'angka langsung final');
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('angka sangat panjang mengecil, tidak meluap', (tester) async {
      await pasang(
        tester,
        Center(
          child: _ubin(nilai: '1.234.567.890', catatan: 'se-lab'),
        ),
        skala: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(UbinKpi),
          matching: find.byType(FittedBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('320 dp x huruf 1,3: dua kolom sebelahan tanpa luapan', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        const Row(
          children: [
            Expanded(
              child: UbinKpi(
                label: 'Total alat',
                nilai: '1.284',
                catatan: 'se-lab',
              ),
            ),
            SizedBox(width: UkuranLanjutBiruAwan.kpiBantalan),
            Expanded(
              child: UbinKpi(
                label: 'Sertifikat bulan ini',
                nilai: '21',
                catatan: '+4',
                ragam: RagamUbinKpi.hijau,
              ),
            ),
          ],
        ),
      );
    });
  });
}
