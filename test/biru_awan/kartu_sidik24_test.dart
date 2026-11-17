// KartuSidik24: putih, sudut 16, datar, garis halus 1 dp; bisa diketuk dengan
// skala 0,97 (REVISI 16 Nov 2026).
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/kartu_sidik24.dart';

import '../support/uji_biru_awan.dart';

Material _bahan(WidgetTester tester) => tester.widget<Material>(
  find
      .descendant(
        of: find.byType(KartuSidik24),
        matching: find.byType(Material),
      )
      .first,
);

void main() {
  setUpAll(muatFontUji);

  group('bentuk', () {
    testWidgets('putih, sudut 16, datar (tanpa bayangan), garis halus 1 dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(const KartuSidik24(child: Text('Isi kartu'))),
      );
      final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
      final b = _bahan(tester);
      expect(b.color, m.kertas);
      expect(b.elevation, 0);
      final bentuk = b.shape! as RoundedRectangleBorder;
      expect(bentuk.borderRadius, BorderRadius.circular(BentukBiruAwan.kartu));
      expect(BentukBiruAwan.kartu, 16);
      expect(bentuk.side, BorderSide(color: m.kertasTepi));
    });

    testWidgets('tinggi = isi; tumbuh bersama huruf', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(const KartuSidik24(child: Text('Isi kartu'))),
      );
      final biasa = tester.getSize(find.byType(KartuSidik24)).height;
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(const KartuSidik24(child: Text('Isi kartu')), skala: 1.3),
      );
      expect(
        tester.getSize(find.byType(KartuSidik24)).height,
        greaterThan(biasa),
      );
    });

    testWidgets('latar kabut, galat, dan awas (krem) mengikuti WarnaBiruAwan; '
        'kartu berisi warna tanpa garis', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          const Column(
            children: [
              KartuSidik24(
                key: ValueKey('k'),
                latar: LatarKartu.kabut,
                child: Text('a'),
              ),
              KartuSidik24(
                key: ValueKey('g'),
                latar: LatarKartu.galat,
                child: Text('b'),
              ),
              KartuSidik24(
                key: ValueKey('a'),
                latar: LatarKartu.awas,
                child: Text('c'),
              ),
            ],
          ),
        ),
      );
      final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
      Color warna(String k) => tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byKey(ValueKey(k)),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      expect(warna('k'), w.isi(IsiBiruAwan.kabut));
      expect(warna('g'), w.isi(IsiBiruAwan.koralTipis));
      expect(warna('a'), w.isi(IsiBiruAwan.kuning));
      for (final k in ['k', 'g', 'a']) {
        final bahan = tester.widget<Material>(
          find
              .descendant(
                of: find.byKey(ValueKey(k)),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(
          (bahan.shape! as RoundedRectangleBorder).side,
          BorderSide.none,
          reason: 'kartu berisi warna tanpa garis: $k',
        );
      }
    });

    for (final gelap in [false, true]) {
      testWidgets(
        'terpilih: kabut + garis primer 2 dp (${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          await tester.pumpWidget(
            aplikasiUji(
              const KartuSidik24(terpilih: true, child: Text('Ubin alat')),
              gelap: gelap,
            ),
          );
          final ctx = tester.element(find.byType(Scaffold));
          final m = SidikMaterial.of(ctx);
          final w = WarnaBiruAwan.of(ctx);
          final b = _bahan(tester);
          expect(b.color, w.isi(IsiBiruAwan.kabut));
          final tepi = (b.shape! as RoundedRectangleBorder).side;
          expect(tepi.color, m.biru);
          expect(tepi.width, 2);
        },
      );

      testWidgets(
        'kontras teks >= 4,5:1 di semua latar (${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          await tester.pumpWidget(
            aplikasiUji(
              const Column(
                children: [
                  KartuSidik24(child: Text('Kertas')),
                  KartuSidik24(latar: LatarKartu.kabut, child: Text('Kabut')),
                  KartuSidik24(latar: LatarKartu.galat, child: Text('Galat')),
                  KartuSidik24(terpilih: true, child: Text('Terpilih')),
                ],
              ),
              gelap: gelap,
            ),
          );
          expect(
            pelanggaranKontrasTeks(tester, find.byType(Column).first),
            isEmpty,
          );
        },
      );
    }
  });

  group('perilaku dan semantik', () {
    testWidgets('tanpa onTap: bukan tombol, tanpa skala tekan', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(const KartuSidik24(child: Text('Hanya baca'))),
      );
      expect(find.byType(AnimatedScale), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(
        tester
            .getSemantics(find.text('Hanya baca'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
      semantik.dispose();
    });

    testWidgets('onTap: ketuk memanggil, tinggi minimum 48', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          Align(
            alignment: Alignment.topLeft,
            child: KartuSidik24(
              padding: EdgeInsets.zero,
              onTap: () => n++,
              child: const SizedBox(width: 120, height: 10),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(KartuSidik24)).height, 48);
      await tester.tap(find.byType(KartuSidik24));
      expect(n, 1);
    });

    testWidgets('semantik gabungan: isi + tombol + aksi ketuk', (tester) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          KartuSidik24(
            onTap: () => n++,
            child: const Column(
              children: [Text('Oven Memmert'), Text('PT Karya Logam')],
            ),
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(KartuSidik24))
          .getSemanticsData();
      expect(data.label, contains('Oven Memmert'));
      expect(data.label, contains('PT Karya Logam'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isSelected, Tristate.none);
      tester.semantics.tap(find.semantics.byLabel(RegExp('Oven Memmert')));
      expect(n, 1);
      semantik.dispose();
    });

    testWidgets('semantik pengganti dan status terpilih', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          KartuSidik24(
            terpilih: true,
            onTap: () {},
            semantik: 'Oven, terpilih',
            child: const Text('Oven'),
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(KartuSidik24))
          .getSemanticsData();
      expect(data.label, 'Oven, terpilih');
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      semantik.dispose();
    });

    testWidgets('semantik pengganti tetap dipasang tanpa onTap (wadah)', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          const KartuSidik24(
            semantik: 'Ringkasan oven',
            child: Text('Teks isi yang tidak dibaca'),
          ),
        ),
      );
      final data = tester
          .getSemantics(find.bySemanticsLabel('Ringkasan oven'))
          .getSemanticsData();
      expect(data.label, 'Ringkasan oven');
      expect(
        data.flagsCollection.isButton,
        isFalse,
        reason: 'wadah, bukan tombol',
      );
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(
        find.bySemanticsLabel('Teks isi yang tidak dibaca'),
        findsNothing,
        reason: 'label pengganti menggantikan teks isi',
      );
      semantik.dispose();
    });

    testWidgets('tekan: skala 0,97 lalu kembali', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          Center(
            child: KartuSidik24(onTap: () {}, child: const Text('Kartu')),
          ),
        ),
      );
      AnimatedScale skala() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      final g = await tester.startGesture(tester.getCenter(find.text('Kartu')));
      await tester.pump();
      expect(skala().scale, 0.97);
      await g.up();
      await tester.pump();
      expect(skala().scale, 1);
    });

    testWidgets('kurangi gerak: skala langsung, tanpa animasi', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          kurangiGerak(
            Center(
              child: KartuSidik24(onTap: () {}, child: const Text('Kartu')),
            ),
          ),
        ),
      );
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
      );
    });
  });

  group('tangguh', () {
    testWidgets('320 dp x huruf 1,3: isi panjang membungkus', (tester) async {
      await periksaSkala13(
        tester,
        KartuSidik24(
          onTap: () {},
          child: const Text(
            'Timbangan analitik elektronik kapasitas 220 g dengan resolusi 0,1 mg',
          ),
        ),
      );
    });

    for (final gelap in [false, true]) {
      testWidgets('pedoman sentuh dan label (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(
            KartuSidik24(onTap: () {}, child: const Text('Oven Memmert')),
            gelap: gelap,
          ),
        );
        await periksaPedomanSentuh(tester);
        semantik.dispose();
      });
    }
  });
}
