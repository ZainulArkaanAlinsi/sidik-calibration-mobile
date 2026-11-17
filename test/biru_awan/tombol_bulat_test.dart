// TombolBulat (44, 48, 60): gambar menurut ukuran, area sentuh >= 48.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_bulat.dart';

import '../support/uji_biru_awan.dart';

TombolBulat _t({
  UkuranTombolBulat ukuran = UkuranTombolBulat.standar,
  RagamTombolBulat ragam = RagamTombolBulat.putih,
  VoidCallback? onPressed,
  String label = 'Buka menu',
}) => TombolBulat(
  ikon: Icons.menu,
  label: label,
  onPressed: onPressed,
  ukuran: ukuran,
  ragam: ragam,
);

/// Gambar bulat di dalam tombol (bukan bidang sentuhnya).
Finder _gambar() => find.descendant(
  of: find.byType(TombolBulat),
  matching: find.byType(InkWell),
);

void main() {
  setUpAll(muatFontUji);

  group('ukuran', () {
    final peta = {
      UkuranTombolBulat.kecil: (gambar: 44.0, sentuh: 48.0),
      UkuranTombolBulat.standar: (gambar: 48.0, sentuh: 48.0),
      UkuranTombolBulat.mulai: (gambar: 60.0, sentuh: 60.0),
    };
    for (final e in peta.entries) {
      testWidgets('${e.key.name}: gambar ${e.value.gambar}, sentuh '
          '${e.value.sentuh}', (tester) async {
        await tester.pumpWidget(
          aplikasiUji(
            Center(
              child: _t(ukuran: e.key, onPressed: () {}),
            ),
          ),
        );
        expect(
          tester.getSize(_gambar()),
          Size.square(e.value.gambar),
          reason: 'gambar bulat',
        );
        expect(
          tester.getSize(find.byType(TombolBulat)),
          Size.square(e.value.sentuh),
          reason: 'bidang sentuh >= 48',
        );
      });
    }

    testWidgets('44 dp: ketukan di bidang transparan 2 dp tetap diterima', (
      tester,
    ) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          Center(
            child: _t(ukuran: UkuranTombolBulat.kecil, onPressed: () => n++),
          ),
        ),
      );
      final kotak = tester.getRect(find.byType(TombolBulat));
      await tester.tapAt(kotak.topLeft + const Offset(1, 1));
      expect(n, 1, reason: 'sudut bidang 48 di luar lingkaran 44');
      await tester.tapAt(kotak.center);
      expect(n, 2);
    });

    testWidgets('bentuk lingkaran', (tester) async {
      await tester.pumpWidget(aplikasiUji(Center(child: _t(onPressed: () {}))));
      final bahan = tester.widget<Material>(
        find.descendant(
          of: find.byType(TombolBulat),
          matching: find.byType(Material),
        ),
      );
      expect((bahan.shape! as CircleBorder), isA<CircleBorder>());
    });

    testWidgets('bayangan HANYA pada Mulai (60)', (tester) async {
      bool adaBayangan() => tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(TombolBulat),
              matching: find.byType(DecoratedBox),
            ),
          )
          .any((d) {
            final dek = d.decoration;
            return dek is BoxDecoration && (dek.boxShadow?.isNotEmpty ?? false);
          });
      for (final u in UkuranTombolBulat.values) {
        await tester.pumpWidget(
          aplikasiUji(
            Center(
              child: _t(ukuran: u, onPressed: () {}),
            ),
          ),
        );
        expect(adaBayangan(), u == UkuranTombolBulat.mulai, reason: u.name);
      }
    });
  });

  group('warna dari tema', () {
    for (final gelap in [false, true]) {
      testWidgets('isi dan ikon tiap ragam (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        await tester.pumpWidget(
          aplikasiUji(
            Row(
              children: [
                for (final r in RagamTombolBulat.values)
                  _t(ragam: r, label: r.name, onPressed: () {}),
              ],
            ),
            gelap: gelap,
          ),
        );
        final ctx = tester.element(find.byType(Scaffold));
        final m = SidikMaterial.of(ctx);
        final s = Theme.of(ctx).colorScheme;
        Color isi(RagamTombolBulat r) => tester
            .widget<Material>(
              find.descendant(
                of: find.byWidgetPredicate(
                  (w) => w is TombolBulat && w.ragam == r,
                ),
                matching: find.byType(Material),
              ),
            )
            .color!;
        Color ikon(RagamTombolBulat r) => tester
            .widget<Icon>(
              find.descendant(
                of: find.byWidgetPredicate(
                  (w) => w is TombolBulat && w.ragam == r,
                ),
                matching: find.byType(Icon),
              ),
            )
            .color!;
        expect(isi(RagamTombolBulat.primer), s.primary);
        expect(ikon(RagamTombolBulat.primer), s.onPrimary);
        expect(isi(RagamTombolBulat.putih), m.kertas);
        expect(ikon(RagamTombolBulat.putih), m.tinta);
        expect(isi(RagamTombolBulat.navy), m.tinta);
        expect(ikon(RagamTombolBulat.navy), m.kertas);
      });
    }
  });

  group('perilaku', () {
    testWidgets('ketuk memanggil onPressed', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(Center(child: _t(onPressed: () => n++))),
      );
      await tester.tap(find.byType(TombolBulat));
      expect(n, 1);
    });

    for (final gelap in [false, true]) {
      testWidgets('mati: isi dan ikon dari token tombol mati, tanpa penangan '
          'ketuk (${gelap ? 'gelap' : 'terang'})', (tester) async {
        for (final r in RagamTombolBulat.values) {
          await tester.pumpWidget(
            aplikasiUji(
              Center(child: _t(ragam: r, onPressed: null)),
              gelap: gelap,
            ),
          );
          final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
          final bahan = tester.widget<Material>(
            find.descendant(
              of: find.byType(TombolBulat),
              matching: find.byType(Material),
            ),
          );
          expect(bahan.color, w.isiTombolMati, reason: '${r.name}: isi mati');
          expect(
            tester
                .widget<Icon>(
                  find.descendant(
                    of: find.byType(TombolBulat),
                    matching: find.byType(Icon),
                  ),
                )
                .color,
            w.tintaTombolMati,
            reason: '${r.name}: ikon mati',
          );
          expect(
            (bahan.shape! as CircleBorder).side,
            BorderSide.none,
            reason: '${r.name}: mati tanpa tepi',
          );
          // Tidak ada callback yang bisa terpanggil, di bidang gambar maupun
          // bidang sentuh.
          expect(tester.widget<InkWell>(_gambar()).onTap, isNull);
          expect(
            tester
                .widget<GestureDetector>(
                  find
                      .descendant(
                        of: find.byType(TombolBulat),
                        matching: find.byType(GestureDetector),
                      )
                      .first,
                )
                .onTap,
            isNull,
          );
          await tester.tap(find.byType(TombolBulat), warnIfMissed: false);
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('semantik: label, tombol, aksi ketuk; mati tanpa aksi', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          Center(
            child: _t(onPressed: () => n++, label: 'Buka menu'),
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(TombolBulat))
          .getSemanticsData();
      expect(data.label, 'Buka menu');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      expect(semantikAktif(data), isTrue, reason: 'aktif ditandai aktif');
      tester.semantics.tap(find.semantics.byLabel('Buka menu'));
      expect(n, 1);

      await tester.pumpWidget(
        aplikasiUji(Center(child: _t(onPressed: null, label: 'Buka menu'))),
      );
      final mati = tester
          .getSemantics(find.byType(TombolBulat))
          .getSemanticsData();
      expect(mati.hasAction(SemanticsAction.tap), isFalse);
      expect(mati.flagsCollection.isButton, isTrue, reason: 'tetap tombol');
      expect(
        semantikAktif(mati),
        isFalse,
        reason: 'pembaca layar harus menyebutnya mati (dimmed)',
      );
      semantik.dispose();
    });

    testWidgets('kurangi gerak: tekan langsung berskala, tanpa animasi', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(kurangiGerak(Center(child: _t(onPressed: () {})))),
      );
      final gestur = await tester.startGesture(
        tester.getCenter(find.byType(TombolBulat)),
      );
      await tester.pump();
      final skala = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(skala.scale, 0.97);
      expect(skala.duration, Duration.zero);
      await gestur.up();
    });
  });

  group('tangguh', () {
    testWidgets('huruf 1,3x di 320 dp: tanpa galat, ukuran tetap', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        Row(
          children: [
            for (final u in UkuranTombolBulat.values)
              _t(ukuran: u, onPressed: () {}),
          ],
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
            Row(
              children: [
                for (final u in UkuranTombolBulat.values)
                  _t(ukuran: u, onPressed: () {}, label: 'Aksi ${u.name}'),
              ],
            ),
            gelap: gelap,
          ),
        );
        await periksaPedomanSentuh(tester);
        semantik.dispose();
      });
    }
  });
}
