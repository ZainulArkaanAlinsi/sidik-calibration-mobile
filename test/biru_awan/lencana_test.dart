// Lencana (koral 22, kuning 26, titik 10) dan LoncengBerlencana (lonceng 48).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan_lanjut.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/lencana.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_bulat.dart';

import '../support/uji_lanjut_biru_awan.dart';

void main() {
  setUpAll(muatFontUji);

  group('Lencana: ukuran dan angka', () {
    testWidgets('koral 22, kuning 26, titik 10; lebar min = tinggi', (
      tester,
    ) async {
      await pasang(tester, const Center(child: Lencana(jumlah: 7)));
      expect(tester.getSize(find.byType(Lencana)), const Size(22, 22));
      await pasang(
        tester,
        const Center(child: Lencana(jumlah: 7, ragam: RagamLencana.kuning)),
      );
      expect(tester.getSize(find.byType(Lencana)), const Size(26, 26));
      await pasang(tester, const Center(child: Lencana.titik()));
      expect(tester.getSize(find.byType(Lencana)), const Size(10, 10));
    });

    testWidgets('melebar bila angka dua digit, tinggi tetap', (tester) async {
      await pasang(tester, const Center(child: Lencana(jumlah: 88)));
      final u = tester.getSize(find.byType(Lencana));
      expect(u.height, 22);
      expect(u.width, greaterThan(22));
    });

    testWidgets('nol dan negatif tidak digambar; di atas 99 jadi "99+"', (
      tester,
    ) async {
      for (final n in [0, -3]) {
        await pasang(tester, Center(child: Lencana(jumlah: n)));
        expect(tester.getSize(find.byType(Lencana)), Size.zero, reason: '$n');
        expect(find.byType(Text), findsNothing);
      }
      expect(Lencana.teksJumlah(99), '99');
      expect(Lencana.teksJumlah(100), '99+');
      await pasang(tester, const Center(child: Lencana(jumlah: 250)));
      expect(find.text('99+'), findsOneWidget);
      await pasang(tester, const Center(child: Lencana(jumlah: 12)));
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('angka 12/800 dan tepi 2 warna latar halaman', (tester) async {
      await pasang(tester, const Center(child: Lencana(jumlah: 5)));
      final gaya = tester.widget<Text>(find.text('5')).style!;
      expect(gaya.fontSize, 12);
      expect(gaya.fontWeight, FontWeight.w800);
      final kotak = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(Lencana),
          matching: find.byType(DecoratedBox),
        ),
      );
      final dekor = kotak.decoration as BoxDecoration;
      expect(dekor.border!.top.width, UkuranLanjutBiruAwan.lencanaTepi);
      expect(dekor.border!.top.color, bahan(tester).meja);
    });
  });

  group('Lencana: warna dan kontras', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('koral dan kuning dari token ($nama)', (tester) async {
        for (final r in RagamLencana.values) {
          await pasang(
            tester,
            Center(child: Lencana(jumlah: 3, ragam: r)),
            gelap: gelap,
          );
          final w = warna(tester);
          final pilihan = r == RagamLencana.koral
              ? IsiBiruAwan.koral
              : IsiBiruAwan.kuning;
          expect(isiKotak(tester, find.byType(Lencana)), w.isi(pilihan));
          expect(
            tester.widget<Text>(find.text('3')).style!.color,
            w.tinta(pilihan),
          );
          expect(
            pelanggaranKontrasTeks(tester, find.byType(Lencana)),
            isEmpty,
            reason: '$r ($nama)',
          );
        }
      });
    }
  });

  group('Lencana: semantik', () {
    testWidgets('label terpasang bila diberikan; tanpa label hiasan', (
      tester,
    ) async {
      final s = tester.ensureSemantics();
      await pasang(
        tester,
        const Center(child: Lencana(jumlah: 12, label: '12 belum dibaca')),
      );
      expect(find.bySemanticsLabel('12 belum dibaca'), findsOneWidget);
      expect(
        semantik(tester, find.byType(Lencana)).flagsCollection.isButton,
        isFalse,
      );
      await pasang(tester, const Center(child: Lencana(jumlah: 12)));
      expect(find.bySemanticsLabel('12'), findsNothing);
      await pasang(
        tester,
        const Center(child: Lencana.titik(label: 'Ada yang baru')),
      );
      expect(find.bySemanticsLabel('Ada yang baru'), findsOneWidget);
      s.dispose();
    });
  });

  group('LoncengBerlencana', () {
    Widget lonceng({int jumlah = 12, VoidCallback? onPressed}) => Center(
      child: LoncengBerlencana(
        label: 'Notifikasi, $jumlah belum dibaca',
        jumlah: jumlah,
        onPressed: onPressed,
      ),
    );

    testWidgets('tombol 48; lencana di kanan atas (atas 4, kanan 2)', (
      tester,
    ) async {
      await pasang(tester, lonceng(onPressed: () {}));
      final tombol = tester.getRect(find.byType(TombolBulat));
      expect(tombol.size, const Size(48, 48));
      final badge = tester.getRect(find.byType(Lencana));
      expect(badge.top - tombol.top, UkuranLanjutBiruAwan.lencanaAtas);
      expect(tombol.right - badge.right, UkuranLanjutBiruAwan.lencanaKanan);
    });

    testWidgets('ketuk di mana pun, termasuk tepat di bawah lencana', (
      tester,
    ) async {
      var n = 0;
      await pasang(tester, lonceng(onPressed: () => n++));
      await tester.tapAt(tester.getCenter(find.byType(Lencana)));
      await tester.tapAt(tester.getCenter(find.byType(TombolBulat)));
      final r = tester.getRect(find.byType(TombolBulat));
      await tester.tapAt(r.bottomLeft + const Offset(2, -2));
      expect(n, 3);
    });

    testWidgets('jumlah 0: tanpa lencana; label tombol tetap dari pemanggil', (
      tester,
    ) async {
      final s = tester.ensureSemantics();
      await pasang(tester, lonceng(jumlah: 0, onPressed: () {}));
      expect(find.byType(Lencana), findsNothing);
      expect(
        find.bySemanticsLabel('Notifikasi, 0 belum dibaca'),
        findsOneWidget,
      );
      s.dispose();
    });

    testWidgets('semantik: satu tombol berlabel berisi jumlah, angka tidak '
        'dibaca dua kali', (tester) async {
      final s = tester.ensureSemantics();
      await pasang(tester, lonceng(onPressed: () {}));
      final d = semantik(tester, find.byType(TombolBulat));
      expect(d.label, 'Notifikasi, 12 belum dibaca');
      expect(d.flagsCollection.isButton, isTrue);
      expect(d.hasAction(SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel('12'), findsNothing);
      await periksaPedomanSentuh(tester);
      s.dispose();
    });

    testWidgets('mati (onPressed null): ditandai mati, lencana tetap tampil', (
      tester,
    ) async {
      final s = tester.ensureSemantics();
      await pasang(tester, lonceng());
      final d = semantik(tester, find.byType(TombolBulat));
      expect(semantikAktif(d), isFalse);
      expect(find.byType(Lencana), findsOneWidget);
      s.dispose();
    });

    testWidgets('320 dp x huruf 1,3 tanpa luapan', (tester) async {
      await periksaSkala13(
        tester,
        Row(
          children: [
            LoncengBerlencana(
              label: 'Notifikasi',
              jumlah: 120,
              onPressed: () {},
            ),
            const Lencana(jumlah: 99, ragam: RagamLencana.kuning),
          ],
        ),
      );
    });
  });
}
