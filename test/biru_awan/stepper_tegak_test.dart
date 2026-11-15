// StepperTegak: penanda 32 (selesai centang, sekarang cincin awan, belum tepi 2).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan_lanjut.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/stempel_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/stepper_tegak.dart';
import 'package:sidik_calibration/widgets/sidik/status_tampil.dart';

import '../support/uji_lanjut_biru_awan.dart';

final _langkah = [
  const LangkahStepper(
    judul: 'Lembar kerja',
    keadaan: KeadaanLangkah.selesai,
    keterangan: 'Beres',
  ),
  LangkahStepper(
    judul: 'Perhitungan & approval',
    keadaan: KeadaanLangkah.sekarang,
    penanda: StempelSidik.teks(
      teks: 'Lagi di sini',
      nada: NadaStempel.tunggu,
      ikon: Icons.place_outlined,
    ),
  ),
  const LangkahStepper(
    judul: 'Sertifikat terbit',
    keadaan: KeadaanLangkah.belum,
  ),
  const LangkahStepper(
    judul: 'Kekirim ke pelanggan',
    keadaan: KeadaanLangkah.belum,
  ),
];

/// Lingkaran penanda ke-[i] (32 x 32 bulat).
Finder _penanda() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).shape == BoxShape.circle,
);

BoxDecoration _dekor(WidgetTester tester, int i) =>
    tester.widget<DecoratedBox>(_penanda().at(i)).decoration as BoxDecoration;

void main() {
  setUpAll(muatFontUji);

  group('penanda dan garis', () {
    testWidgets('ukuran 32; tiga keadaan berbeda bentuk', (tester) async {
      await pasang(tester, StepperTegak(langkah: _langkah));
      expect(_penanda(), findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(tester.getSize(_penanda().at(i)), const Size(32, 32));
      }
      final s = skemaWarna(tester);
      final m = bahan(tester);
      final w = warna(tester);
      // Selesai: primer penuh tanpa tepi + centang.
      expect(_dekor(tester, 0).color, s.primary);
      expect(_dekor(tester, 0).border, isNull);
      expect(find.byIcon(Icons.check), findsOneWidget, reason: 'hanya selesai');
      // Sekarang: primer + cincin awan 4.
      expect(_dekor(tester, 1).color, s.primary);
      expect(_dekor(tester, 1).border!.top.color, w.isi(IsiBiruAwan.awan));
      expect(
        _dekor(tester, 1).border!.top.width,
        UkuranLanjutBiruAwan.stepperCincin,
      );
      // Belum: kertas + tepi 2 garisTegas.
      for (final i in [2, 3]) {
        expect(_dekor(tester, i).color, m.kertas);
        expect(_dekor(tester, i).border!.top.color, m.garisTegas);
        expect(
          _dekor(tester, i).border!.top.width,
          UkuranLanjutBiruAwan.stepperTepiBelum,
        );
      }
    });

    testWidgets('garis 2 dp: primer setelah langkah selesai, garisTegas '
        'selainnya, tidak ada setelah langkah terakhir', (tester) async {
      await pasang(tester, StepperTegak(langkah: _langkah));
      final s = skemaWarna(tester);
      final m = bahan(tester);
      final garis = find.byWidgetPredicate(
        (w) =>
            w is ColoredBox &&
            (w.color == s.primary || w.color == m.garisTegas),
      );
      expect(garis, findsNWidgets(3));
      final warnaGaris = [
        for (final g in tester.widgetList<ColoredBox>(garis)) g.color,
      ];
      expect(warnaGaris, [s.primary, m.garisTegas, m.garisTegas]);
      for (var i = 0; i < 3; i++) {
        final r = tester.getRect(garis.at(i));
        expect(r.width, 2);
        expect(r.height, greaterThanOrEqualTo(28));
        // Garis menyambung dari bawah penanda i ke atas penanda i + 1.
        expect(r.top, tester.getRect(_penanda().at(i)).bottom);
        expect(r.bottom, tester.getRect(_penanda().at(i + 1)).top);
      }
    });

    testWidgets('jarak penanda ke judul 14; judul sekarang 800, lainnya 600', (
      tester,
    ) async {
      await pasang(tester, StepperTegak(langkah: _langkah));
      final p = tester.getRect(_penanda().at(0));
      expect(tester.getTopLeft(find.text('Lembar kerja')).dx - p.right, 14);
      expect(
        tester
            .widget<Text>(find.text('Perhitungan & approval'))
            .style!
            .fontWeight,
        FontWeight.w800,
      );
      expect(
        tester.widget<Text>(find.text('Lembar kerja')).style!.fontWeight,
        FontWeight.w600,
      );
      expect(find.text('Lagi di sini'), findsOneWidget, reason: 'penanda');
      expect(find.text('Beres'), findsOneWidget, reason: 'keterangan');
    });

    testWidgets('satu langkah saja: tanpa garis', (tester) async {
      await pasang(
        tester,
        const StepperTegak(
          langkah: [
            LangkahStepper(judul: 'Satu', keadaan: KeadaanLangkah.sekarang),
          ],
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == bahan(tester).garisTegas,
        ),
        findsNothing,
      );
    });
  });

  group('kontras', () {
    for (final gelap in [false, true]) {
      testWidgets(
        'teks ≥ 4,5:1 dan penanda primer ≥ 3:1 (${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          await pasang(tester, StepperTegak(langkah: _langkah), gelap: gelap);
          expect(
            pelanggaranKontrasTeks(tester, find.byType(StepperTegak)),
            isEmpty,
          );
          expect(
            rasioKontras(skemaWarna(tester).primary, bahan(tester).kertas),
            greaterThanOrEqualTo(ambangBukanTeks),
          );
          expect(
            rasioKontras(
              skemaWarna(tester).onPrimary,
              skemaWarna(tester).primary,
            ),
            greaterThanOrEqualTo(3),
            reason: 'centang di atas primer',
          );
        },
      );
    }
  });

  group('semantik', () {
    testWidgets(
      'satu node per langkah: "Langkah n dari total, keadaan, judul"',
      (tester) async {
        final s = tester.ensureSemantics();
        await pasang(tester, StepperTegak(langkah: _langkah));
        expect(
          find.bySemanticsLabel(RegExp(r'^Langkah 1 dari 4, selesai')),
          findsOneWidget,
        );
        final sekarang = find.bySemanticsLabel(
          RegExp(r'^Langkah 2 dari 4, langkah sekarang'),
        );
        expect(sekarang, findsOneWidget);
        expect(
          semantik(tester, sekarang).label,
          allOf(contains('Perhitungan & approval'), contains('Lagi di sini')),
          reason: 'judul dan penanda ikut satu node',
        );
        expect(
          find.bySemanticsLabel(RegExp(r'^Langkah 3 dari 4, belum')),
          findsOneWidget,
        );
        expect(
          semantik(tester, sekarang).hasAction(SemanticsAction.tap),
          isFalse,
          reason: 'bukan kontrol',
        );
        s.dispose();
      },
    );

    testWidgets('bahasa Inggris memakai kata l10n bahasa itu', (tester) async {
      final s = tester.ensureSemantics();
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(StepperTegak(langkah: _langkah), bahasa: 'en'),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Step 2 of 4, current step')),
        findsOneWidget,
      );
      s.dispose();
    });
  });

  group('gerak dan huruf', () {
    testWidgets('tanpa animasi', (tester) async {
      await pasang(tester, StepperTegak(langkah: _langkah));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('320 dp x huruf 1,3: judul panjang membungkus, garis ikut', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        const StepperTegak(
          langkah: [
            LangkahStepper(
              judul: 'Perhitungan dan persetujuan oleh pemeriksa laboratorium',
              keadaan: KeadaanLangkah.sekarang,
              keterangan: 'Menunggu keputusan pemeriksa yang ditugaskan lab',
            ),
            LangkahStepper(judul: 'Terbit', keadaan: KeadaanLangkah.belum),
          ],
        ),
        tinggi: 1200,
      );
    });
  });
}
