// NavigasiAdaptif: bar (HP), rail 80 dp (tablet), tanpa navigasi (teknisi di
// layar lebar); lencana angka; keadaan aktif kapsul kobalt tipis (bukan hijau).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/widgets/sidik/navigasi_adaptif.dart';

import '../support/komponen_uji.dart';

Widget _bar({
  int persetujuan = 3,
  int indeks = 1,
  ValueChanged<int>? onPilih,
  List<TujuanNavigasi>? tujuan,
}) => Align(
  alignment: Alignment.bottomCenter,
  child: BarNavigasi(
    tujuan: tujuan ?? TujuanLab.admin(_l, persetujuan: persetujuan),
    indeks: indeks,
    onPilih: onPilih ?? (_) {},
  ),
);

Iterable<RenderParagraph> _label(WidgetTester tester) => tester
    .widgetList<Text>(find.byKey(const ValueKey('navigasi-label')))
    .map((t) => tester.renderObject<RenderParagraph>(find.byWidget(t)));

final _l = l10nUji();

void main() {
  setUpAll(muatFontUji);

  group('aturan bentuk', () {
    test('bar di bawah 900 dp, rail mulai 900 dp, tanpa bila < 3 tujuan', () {
      TataNavigasi t(double l, int n) =>
          NavigasiAdaptif.tata(lebar: l, jumlah: n);
      expect(t(320, 5), TataNavigasi.bar);
      expect(t(392, 2), TataNavigasi.bar);
      expect(t(899.9, 5), TataNavigasi.bar);
      expect(t(900, 5), TataNavigasi.rail);
      expect(t(1280, 3), TataNavigasi.rail);
      expect(t(900, 2), TataNavigasi.tanpa);
      expect(t(1280, 2), TataNavigasi.tanpa);
    });

    test('tujuan admin: lima tab; teknisi: dua tab; lencana hanya Antrean', () {
      final admin = TujuanLab.admin(_l, persetujuan: 3);
      expect(admin.map((t) => t.label), [
        'Beranda',
        'Antrean',
        'Kalibrasi',
        'Arsip',
        'Lainnya',
      ]);
      expect(admin.map((t) => t.lencana), [0, 3, 0, 0, 0]);
      expect(TujuanLab.teknisi(_l).map((t) => t.label), [
        'Kalibrasi',
        'Profil',
      ]);
      for (final t in [...admin, ...TujuanLab.teknisi(_l)]) {
        expect(t.label, isNot(equals(t.label.toUpperCase())));
        expect(t.ikon, isNot(t.ikonAktif), reason: '${t.label}: aktif terisi');
      }
    });

    test(
      'semantik menyebut lencana; denganLencana tidak mengubah yang lain',
      () {
        final t = TujuanLab.admin(_l, persetujuan: 3)[1];
        expect(t.semantik, 'Antrean persetujuan, 3 menunggu');
        expect(TujuanLab.admin(_l)[1].semantik, 'Antrean persetujuan');
        expect(
          t.semantik.toLowerCase(),
          contains(t.label.toLowerCase()),
          reason: 'nama semantik memuat kata yang terlihat (Voice Access)',
        );
        final baru = t.denganLencana(7);
        expect(baru.lencana, 7);
        expect(baru.label, t.label);
        expect(baru.namaSemantik, t.namaSemantik);
        expect(baru.satuanLencana, t.satuanLencana);
      },
    );
  });

  group('BarNavigasi', () {
    testWidgets('ketuk butir memanggil onPilih dengan indeksnya', (
      tester,
    ) async {
      layarUji(tester);
      final dipilih = <int>[];
      await tester.pumpWidget(
        aplikasiUji(_bar(onPilih: dipilih.add), bergulir: false),
      );
      await tester.tap(find.text('Kalibrasi'));
      await tester.tap(find.text('Arsip'));
      await tester.tap(find.text('Lainnya'));
      await tester.tap(find.text('Beranda'));
      expect(dipilih, [2, 3, 4, 0]);
    });

    for (final gelap in [false, true]) {
      testWidgets(
        'aktif = kapsul kobalt tipis + ikon terisi + kata tebal, bukan hijau '
        '(${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          layarUji(tester);
          final m = gelap
              ? SidikMaterial.gelapDefault
              : SidikMaterial.terangDefault;
          await tester.pumpWidget(
            aplikasiUji(_bar(indeks: 2), bergulir: false, gelap: gelap),
          );
          await tester.pumpAndSettle();
          // Ikon terisi hanya pada butir aktif.
          expect(find.byIcon(Icons.straighten), findsOneWidget);
          expect(find.byIcon(Icons.straighten_outlined), findsNothing);
          expect(find.byIcon(Icons.home_outlined), findsOneWidget);
          expect(find.byIcon(Icons.home), findsNothing);
          // Kapsul: kobalt tipis, bukan latar hijau "lulus".
          final kapsul = tester
              .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
              .map((a) => (a.decoration as BoxDecoration).color)
              .toList();
          expect(kapsul.where((c) => c == m.biruTipis).length, 1);
          expect(kapsul, isNot(contains(m.lulusTipis)));
          expect(kapsul, isNot(contains(m.lulus)));
          // Kata tebal hanya pada yang aktif.
          final berat = {
            for (final t in tester.widgetList<Text>(
              find.byKey(const ValueKey('navigasi-label')),
            ))
              t.data: t.style!.fontWeight,
          };
          expect(berat['Kalibrasi'], FontWeight.w700);
          expect(berat['Beranda'], FontWeight.w500);
          // Warna ikon aktif = kobalt tinta; tidak aktif = tinta kedua.
          expect(
            tester.widget<Icon>(find.byIcon(Icons.straighten)).color,
            m.biruTinta,
          );
          expect(
            tester.widget<Icon>(find.byIcon(Icons.home_outlined)).color,
            m.tinta2,
          );
        },
      );
    }

    testWidgets('lencana: angka, 99+ untuk > 99, tidak ada bila 0', (
      tester,
    ) async {
      layarUji(tester);
      final m = SidikMaterial.terangDefault;
      await tester.pumpWidget(
        aplikasiUji(_bar(persetujuan: 3), bergulir: false),
      );
      expect(find.text('3'), findsOneWidget);
      var lencana = tester.widget<DecoratedBox>(
        find
            .ancestor(of: find.text('3'), matching: find.byType(DecoratedBox))
            .first,
      );
      expect((lencana.decoration as BoxDecoration).color, m.gagal);
      expect(
        (lencana.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(999),
        reason: 'pil penuh hanya untuk lencana angka',
      );
      expect(tester.widget<Text>(find.text('3')).style!.color, m.teksDiGagal);

      await tester.pumpWidget(
        aplikasiUji(_bar(persetujuan: 120), bergulir: false),
      );
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('120'), findsNothing);
      await tester.pumpWidget(
        aplikasiUji(_bar(persetujuan: 99), bergulir: false),
      );
      expect(find.text('99'), findsOneWidget);
      await tester.pumpWidget(
        aplikasiUji(_bar(persetujuan: 0), bergulir: false),
      );
      expect(find.byType(Positioned), findsNothing);
    });

    testWidgets('lencana besar tidak menutupi ikon Antrean', (tester) async {
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(_bar(persetujuan: 120, indeks: 0), bergulir: false),
      );
      final ikon = tester.getRect(find.byIcon(Icons.fact_check_outlined));
      final lencana = tester.getRect(find.text('99+'));
      expect(lencana.left, greaterThanOrEqualTo(ikon.center.dx));
    });

    testWidgets('pembaca layar: label + lencana, terpilih, urutan tab, ketuk', (
      tester,
    ) async {
      layarUji(tester);
      final semantik = tester.ensureSemantics();
      final dipilih = <int>[];
      await tester.pumpWidget(
        aplikasiUji(_bar(onPilih: dipilih.add), bergulir: false),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('Antrean persetujuan, 3 menunggu'),
      );
      final data = node.getSemanticsData();
      expect(data.hint, 'Tab 2 dari 5');
      expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      final lain = tester
          .getSemantics(find.bySemanticsLabel('Kalibrasi'))
          .getSemanticsData();
      expect(lain.flagsCollection.isSelected, ui.Tristate.isFalse);
      tester.semantics.tap(find.semantics.byLabel('Kalibrasi'));
      expect(dipilih, [2], reason: 'aksi ketuk semantik memilih tab');
      semantik.dispose();
    });

    testWidgets(
      'pedoman sentuh: sasaran >= 48 dp dan berlabel (320 dp x 1,3)',
      (tester) async {
        layarUji(tester, lebar: 320, tinggi: 640);
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(_bar(), bergulir: false, skala: 1.3),
        );
        await periksaPedomanSentuh(tester);
        semantik.dispose();
      },
    );

    for (final (lebar, skala) in [
      (392.0, 1.0),
      (360.0, 1.0),
      (320.0, 1.0),
      (320.0, 1.3),
    ]) {
      testWidgets(
        'label tidak terpotong: ${lebar.toInt()} dp x $skala, huruf >= 12 sp',
        (tester) async {
          layarUji(tester, lebar: lebar, tinggi: 640);
          await tester.pumpWidget(
            aplikasiUji(_bar(), bergulir: false, skala: skala),
          );
          expect(tester.takeException(), isNull);
          for (final p in _label(tester)) {
            expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
            expect(
              p.textScaler.scale(12),
              greaterThanOrEqualTo(12),
              reason: 'huruf label tidak boleh di bawah 12 sp',
            );
          }
          // Satu skala untuk semua butir.
          expect(
            _label(tester).map((p) => p.textScaler.scale(12)).toSet().length,
            1,
          );
        },
      );
    }

    testWidgets(
      'sangat sempit (260 dp): huruf label tidak pernah di bawah 12 sp, '
      'label boleh dipotong sebagai pilihan terakhir',
      (tester) async {
        layarUji(tester, lebar: 260, tinggi: 640);
        await tester.pumpWidget(aplikasiUji(_bar(), bergulir: false));
        expect(tester.takeException(), isNull);
        for (final p in _label(tester)) {
          expect(
            p.textScaler.scale(12),
            greaterThanOrEqualTo(12),
            reason: '${p.text.toPlainText()}: label di bawah 12 sp',
          );
        }
      },
    );

    testWidgets(
      'kata tab SAMA di semua lebar: "Antrean", tidak pernah "Persetujuan"',
      (tester) async {
        final semantik = tester.ensureSemantics();
        final kata = <String>{};
        for (final lebar in [320.0, 360.0, 375.0, 392.0, 400.0, 411.0, 430.0]) {
          for (final skala in [1.0, 1.3]) {
            layarUji(tester, lebar: lebar, tinggi: 640);
            await tester.pumpWidget(
              aplikasiUji(_bar(), bergulir: false, skala: skala),
            );
            final tampil = tester
                .widgetList<Text>(find.byKey(const ValueKey('navigasi-label')))
                .map((t) => t.data)
                .join('|');
            kata.add(tampil);
            expect(find.text('Persetujuan'), findsNothing, reason: '$lebar');
            expect(find.text('Antrean'), findsOneWidget, reason: '$lebar');
            // Nama untuk pembaca layar memuat kata yang terlihat.
            expect(
              find.bySemanticsLabel('Antrean persetujuan, 3 menunggu'),
              findsOneWidget,
              reason: '$lebar x $skala',
            );
          }
        }
        expect(kata, {
          'Beranda|Antrean|Kalibrasi|Arsip|Lainnya',
        }, reason: 'label identik di semua lebar dan skala huruf');
        semantik.dispose();
      },
    );

    testWidgets('kata tab mengikuti bahasa (id dan en) dari ARB', (
      tester,
    ) async {
      final en = l10nUji('en');
      layarUji(tester, lebar: 392, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          _bar(tujuan: TujuanLab.admin(en, persetujuan: 3)),
          bergulir: false,
          bahasa: 'en',
        ),
      );
      final tampil = tester
          .widgetList<Text>(find.byKey(const ValueKey('navigasi-label')))
          .map((t) => t.data)
          .toList();
      expect(tampil, ['Home', 'Queue', 'Calibrate', 'Archive', 'More']);
      expect(
        TujuanLab.admin(en, persetujuan: 3)[1].semantik,
        'Approval queue, 3 waiting',
      );
      expect(en.navLabTabHint(2, 5), 'Tab 2 of 5');
      expect(_l.navLabTabHint(2, 5), 'Tab 2 dari 5');
      // Hint tab di pohon semantik juga berbahasa English.
      final semantik = tester.ensureSemantics();
      final data = tester
          .getSemantics(find.bySemanticsLabel('Approval queue, 3 waiting'))
          .getSemanticsData();
      expect(data.hint, 'Tab 2 of 5');
      semantik.dispose();
    });

    testWidgets('English: tidak ada label terpotong di 320 dp dan 360 dp', (
      tester,
    ) async {
      final en = l10nUji('en');
      for (final lebar in [320.0, 360.0]) {
        layarUji(tester, lebar: lebar, tinggi: 640);
        await tester.pumpWidget(
          aplikasiUji(
            _bar(tujuan: TujuanLab.admin(en, persetujuan: 3)),
            bergulir: false,
            bahasa: 'en',
          ),
        );
        for (final p in _label(tester)) {
          expect(
            p.didExceedMaxLines,
            isFalse,
            reason: '"${p.text.toPlainText()}" terpotong di $lebar dp',
          );
        }
      }
    });

    testWidgets('dua tab (teknisi): butir lebar, kata penuh', (tester) async {
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          _bar(tujuan: TujuanLab.teknisi(_l), indeks: 0),
          bergulir: false,
          skala: 1.3,
        ),
      );
      expect(find.text('Kalibrasi'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final p in _label(tester)) {
        expect(
          p.textScaler.scale(12),
          closeTo(15.6, 0.01),
          reason: 'ruang lega',
        );
      }
    });

    testWidgets('tinggi bar >= 72 dp dan garis halus di atasnya', (
      tester,
    ) async {
      layarUji(tester);
      await tester.pumpWidget(aplikasiUji(_bar(), bergulir: false));
      expect(
        tester.getSize(find.byType(BarNavigasi)).height,
        greaterThanOrEqualTo(72),
      );
    });

    for (final gelap in [false, true]) {
      testWidgets('kontras teks >= 4,5:1 (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        layarUji(tester);
        await tester.pumpWidget(
          aplikasiUji(_bar(persetujuan: 120), bergulir: false, gelap: gelap),
        );
        await tester.pumpAndSettle();
        expect(
          pelanggaranKontrasTeks(tester, find.byType(BarNavigasi)),
          isEmpty,
        );
      });
    }
  });

  group('RailNavigasi dan NavigasiAdaptif', () {
    testWidgets(
      'rail: lebar 80 dp, butir >= 72 dp, label penuh, aktif kapsul',
      (tester) async {
        layarUji(tester, lebar: 1280, tinggi: 800);
        final dipilih = <int>[];
        await tester.pumpWidget(
          aplikasiUji(
            Align(
              alignment: Alignment.centerLeft,
              child: RailNavigasi(
                tujuan: TujuanLab.admin(_l, persetujuan: 3),
                indeks: 2,
                onPilih: dipilih.add,
              ),
            ),
            bergulir: false,
          ),
        );
        expect(tester.getSize(find.byType(RailNavigasi)).width, 80);
        expect(find.text('Antrean'), findsOneWidget);
        expect(find.text('Persetujuan'), findsNothing);
        for (final p in _label(tester)) {
          expect(p.didExceedMaxLines, isFalse);
        }
        expect(find.byIcon(Icons.straighten), findsOneWidget);
        await tester.tap(find.text('Arsip'));
        expect(dipilih, [3]);
      },
    );

    testWidgets('NavigasiAdaptif memilih bar atau rail menurut lebar', (
      tester,
    ) async {
      Widget pasang(double lebar, List<TujuanNavigasi> tujuan) => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: lebar,
          height: 600,
          child: NavigasiAdaptif(
            tujuan: tujuan,
            indeks: 0,
            onPilih: (_) {},
            isi: const Center(child: Text('Isi layar')),
          ),
        ),
      );
      layarUji(tester, lebar: 1280, tinggi: 800);

      await tester.pumpWidget(
        aplikasiUji(pasang(392, TujuanLab.admin(_l)), bergulir: false),
      );
      expect(find.byType(BarNavigasi), findsOneWidget);
      expect(find.byType(RailNavigasi), findsNothing);
      expect(find.text('Isi layar'), findsOneWidget);

      await tester.pumpWidget(
        aplikasiUji(pasang(1000, TujuanLab.admin(_l)), bergulir: false),
      );
      expect(find.byType(RailNavigasi), findsOneWidget);
      expect(find.byType(BarNavigasi), findsNothing);
      expect(find.text('Isi layar'), findsOneWidget);

      await tester.pumpWidget(
        aplikasiUji(pasang(1000, TujuanLab.teknisi(_l)), bergulir: false),
      );
      expect(find.byType(RailNavigasi), findsNothing);
      expect(find.byType(BarNavigasi), findsNothing);
      expect(find.text('Isi layar'), findsOneWidget);

      await tester.pumpWidget(
        aplikasiUji(pasang(392, TujuanLab.teknisi(_l)), bergulir: false),
      );
      expect(find.byType(BarNavigasi), findsOneWidget);
    });

    testWidgets('rail: pedoman sentuh dan kontras, terang dan gelap', (
      tester,
    ) async {
      layarUji(tester, lebar: 1280, tinggi: 800);
      for (final gelap in [false, true]) {
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(
            Align(
              alignment: Alignment.centerLeft,
              child: RailNavigasi(
                tujuan: TujuanLab.admin(_l, persetujuan: 120),
                indeks: 1,
                onPilih: (_) {},
              ),
            ),
            bergulir: false,
            gelap: gelap,
          ),
        );
        await tester.pumpAndSettle();
        await periksaPedomanSentuh(tester);
        expect(
          pelanggaranKontrasTeks(tester, find.byType(RailNavigasi)),
          isEmpty,
          reason: gelap ? 'gelap' : 'terang',
        );
        semantik.dispose();
      }
    });
  });
}
