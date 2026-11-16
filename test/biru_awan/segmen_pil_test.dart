// SegmenPil: 2 sampai 3 pilihan dalam jalur 48 sudut 12; terpilih = biru muda
// + tepi biru + kata navy (REVISI 16 Nov 2026).
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/widgets/biru_awan/segmen_pil.dart';

import '../support/uji_biru_awan.dart';

enum _Peran { teknisi, admin, viewer }

SegmenPil<_Peran> _s({
  _Peran nilai = _Peran.teknisi,
  ValueChanged<_Peran>? onChanged,
  List<_Peran> peran = _Peran.values,
}) => SegmenPil<_Peran>(
  label: 'Peran',
  nilai: nilai,
  onChanged: onChanged,
  item: [
    for (final p in peran)
      SegmenPilItem(
        nilai: p,
        label: p.name[0].toUpperCase() + p.name.substring(1),
      ),
  ],
);

void main() {
  setUpAll(muatFontUji);

  group('bentuk', () {
    testWidgets('jalur 48, sudut 12, segmen sama lebar', (tester) async {
      layarUji(tester, lebar: 360, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          Padding(
            padding: const EdgeInsets.all(16),
            child: _s(onChanged: (_) {}),
          ),
        ),
      );
      final jalur = tester.getSize(find.byType(SegmenPil<_Peran>));
      expect(jalur.height, 48);
      expect(jalur.width, 360 - 32);
      final bahan = tester.widget<Material>(
        find.descendant(
          of: find.byType(SegmenPil<_Peran>),
          matching: find.byType(Material),
        ),
      );
      expect(
        (bahan.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(BentukBiruAwan.saringan),
      );
      expect(BentukBiruAwan.saringan, 12);
      final lebar = [
        for (final t in ['Teknisi', 'Admin', 'Viewer'])
          tester
              .getSize(
                find
                    .ancestor(of: find.text(t), matching: find.byType(InkWell))
                    .first,
              )
              .width,
      ];
      expect(lebar[0], closeTo(lebar[1], 0.01));
      expect(lebar[1], closeTo(lebar[2], 0.01));
    });

    testWidgets('dua pilihan juga bisa', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          _s(peran: [_Peran.teknisi, _Peran.admin], onChanged: (_) {}),
        ),
      );
      expect(find.text('Viewer'), findsNothing);
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('kurang dari dua pilihan ditolak', (tester) async {
      expect(
        () => SegmenPil<_Peran>(
          label: 'Peran',
          nilai: _Peran.admin,
          onChanged: (_) {},
          item: const [SegmenPilItem(nilai: _Peran.admin, label: 'Admin')],
        ),
        throwsAssertionError,
      );
    });
  });

  group('warna dari tema', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets(
        'terpilih = biru muda + tepi biru bertulisan navy; jalur = latar ($nama)',
        (tester) async {
          await tester.pumpWidget(
            aplikasiUji(
              _s(nilai: _Peran.admin, onChanged: (_) {}),
              gelap: gelap,
            ),
          );
          final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
          Color? pil(String t) {
            final d = tester.widget<DecoratedBox>(
              find
                  .ancestor(
                    of: find.text(t),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            );
            return (d.decoration as BoxDecoration).color;
          }

          Color teks(String t) =>
              tester.widget<Text>(find.text(t)).style!.color!;
          expect(pil('Admin'), m.biruTipis);
          expect(teks('Admin'), m.tinta);
          // Pilihan dibawa tepi biru 2 dp (biru muda sendirian 1,1:1).
          final tepi =
              (tester
                          .widget<DecoratedBox>(
                            find
                                .ancestor(
                                  of: find.text('Admin'),
                                  matching: find.byType(DecoratedBox),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration)
                  .border!
                  .top;
          expect(tepi.color, m.biru);
          expect(tepi.width, 2);
          expect(
            pil('Teknisi'),
            m.meja,
            reason: 'tidak terpilih = menyatu jalur',
          );
          expect(teks('Teknisi'), m.tinta);
          final bahan = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(SegmenPil<_Peran>),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(bahan.color, m.meja);
        },
      );

      testWidgets('kontras teks >= 4,5:1: aktif dan mati ($nama)', (
        tester,
      ) async {
        for (final aktif in [true, false]) {
          await tester.pumpWidget(
            aplikasiUji(
              _s(nilai: _Peran.admin, onChanged: aktif ? (_) {} : null),
              gelap: gelap,
            ),
          );
          expect(
            pelanggaranKontrasTeks(tester, find.byType(SegmenPil<_Peran>)),
            isEmpty,
            reason: aktif ? 'aktif' : 'mati',
          );
        }
      });
    }
  });

  group('perilaku dan semantik', () {
    testWidgets('ketuk segmen memanggil onChanged dengan nilainya', (
      tester,
    ) async {
      final dipilih = <_Peran>[];
      await tester.pumpWidget(aplikasiUji(_s(onChanged: dipilih.add)));
      await tester.tap(find.text('Viewer'));
      await tester.tap(find.text('Admin'));
      expect(dipilih, [_Peran.viewer, _Peran.admin]);
    });

    testWidgets('bidang sentuh = seluruh segmen 48 dp, bukan hanya penandanya', (
      tester,
    ) async {
      final dipilih = <_Peran>[];
      await tester.pumpWidget(aplikasiUji(_s(onChanged: dipilih.add)));
      final segmen = tester.getRect(
        find
            .ancestor(of: find.text('Admin'), matching: find.byType(InkWell))
            .first,
      );
      expect(segmen.height, 48);
      // Tepi atas segmen: di luar penanda (bantalan 6 dp), di dalam bidang sentuh.
      await tester.tapAt(segmen.topCenter + const Offset(0, 1));
      expect(dipilih, [_Peran.admin]);
    });

    testWidgets('mati: onChanged null mengabaikan ketukan; tiap segmen mati '
        'di semantik, tanpa aksi ketuk', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(aplikasiUji(_s(onChanged: null)));
      await tester.tap(find.text('Admin'), warnIfMissed: false);
      expect(tester.takeException(), isNull);
      for (final nama in ['Teknisi', 'Admin', 'Viewer']) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(nama))
            .getSemanticsData();
        expect(semantikAktif(data), isFalse, reason: '$nama harus mati');
        expect(data.hasAction(SemanticsAction.tap), isFalse, reason: nama);
        expect(data.flagsCollection.isButton, isTrue, reason: nama);
      }

      await tester.pumpWidget(aplikasiUji(_s(onChanged: (_) {})));
      for (final nama in ['Teknisi', 'Admin', 'Viewer']) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(nama))
            .getSemanticsData();
        expect(semantikAktif(data), isTrue, reason: '$nama harus aktif');
        expect(data.hasAction(SemanticsAction.tap), isTrue, reason: nama);
      }
      semantik.dispose();
    });

    testWidgets('semantik: kelompok bernama, tiap segmen tombol + terpilih', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      final dipilih = <_Peran>[];
      await tester.pumpWidget(
        aplikasiUji(_s(nilai: _Peran.admin, onChanged: dipilih.add)),
      );
      final admin = tester
          .getSemantics(find.bySemanticsLabel('Admin'))
          .getSemanticsData();
      expect(admin.flagsCollection.isSelected, Tristate.isTrue);
      expect(admin.flagsCollection.isButton, isTrue);
      expect(admin.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(admin.hasAction(SemanticsAction.tap), isTrue);
      final teknisi = tester
          .getSemantics(find.bySemanticsLabel('Teknisi'))
          .getSemanticsData();
      expect(teknisi.flagsCollection.isSelected, Tristate.isFalse);
      expect(find.bySemanticsLabel('Peran'), findsWidgets);
      tester.semantics.tap(find.semantics.byLabel('Viewer'));
      expect(dipilih, [_Peran.viewer]);
      semantik.dispose();
    });

    testWidgets('kurangi gerak: tekan langsung berskala', (tester) async {
      await tester.pumpWidget(aplikasiUji(kurangiGerak(_s(onChanged: (_) {}))));
      final gestur = await tester.startGesture(
        tester.getCenter(find.text('Admin')),
      );
      await tester.pump();
      final skala = tester.widgetList<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(skala.where((s) => s.scale == 0.97), hasLength(1));
      expect(skala.every((s) => s.duration == Duration.zero), isTrue);
      await gestur.up();
    });
  });

  group('tangguh', () {
    testWidgets('320 dp x huruf 1,3: tiga segmen, label panjang membungkus', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        SegmenPil<int>(
          label: 'Rentang',
          nilai: 1,
          onChanged: (_) {},
          item: const [
            SegmenPilItem(nilai: 0, label: 'Teknisi'),
            SegmenPilItem(nilai: 1, label: 'Master Data'),
            SegmenPilItem(nilai: 2, label: 'Hanya baca'),
          ],
        ),
      );
    });

    testWidgets('jalur tumbuh bersama huruf (>= 48)', (tester) async {
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          Padding(
            padding: const EdgeInsets.all(16),
            child: _s(onChanged: (_) {}),
          ),
          skala: 1.3,
        ),
      );
      expect(
        tester.getSize(find.byType(SegmenPil<_Peran>)).height,
        greaterThanOrEqualTo(48),
      );
    });

    for (final gelap in [false, true]) {
      testWidgets('pedoman sentuh dan label (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(_s(onChanged: (_) {}), gelap: gelap),
        );
        await periksaPedomanSentuh(tester);
        semantik.dispose();
      });
    }
  });
}
