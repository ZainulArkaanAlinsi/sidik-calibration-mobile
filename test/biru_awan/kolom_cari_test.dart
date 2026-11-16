// KolomCari: kotak 48 sudut 12 (REVISI 16 Nov 2026), isian 14, tombol bulat cari
// 44 primer, cincin fokus di luar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/kolom_cari.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_bulat.dart';

import '../support/uji_lanjut_biru_awan.dart';

const _petunjuk = 'Cari nama, nomor seri, atau besaran';

Widget _k({
  bool enabled = true,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onCari,
  TextEditingController? controller,
  FocusNode? focusNode,
}) => Padding(
  padding: const EdgeInsets.all(16),
  child: KolomCari(
    petunjuk: _petunjuk,
    enabled: enabled,
    onChanged: onChanged,
    onCari: onCari,
    controller: controller,
    focusNode: focusNode,
  ),
);

void main() {
  setUpAll(muatFontUji);

  group('ukuran dan bentuk', () {
    testWidgets('kotak 48 sudut 12; isian 14; tombol 44 digambar, area 48', (
      tester,
    ) async {
      await pasang(tester, _k());
      final pil = tester.getRect(find.byType(KolomCari));
      expect(pil.height, 48);
      final dekor = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(KolomCari),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.borderRadius != null);
      expect(
        dekor.borderRadius,
        BorderRadius.circular(BentukBiruAwan.saringan),
      );
      expect(BentukBiruAwan.saringan, 12);
      expect(
        tester.widget<TextField>(find.byType(TextField)).style!.fontSize,
        14,
      );
      final tombol = find.byType(TombolBulat);
      expect(tester.getSize(tombol), const Size(48, 48));
      final gambar = tester.getSize(
        find.descendant(of: tombol, matching: find.byType(InkWell)),
      );
      expect(gambar, const Size(44, 44));
      // Tombol 44 duduk 6 dp dari tepi kanan pil.
      final lingkaran = tester.getRect(
        find.descendant(of: tombol, matching: find.byType(InkWell)),
      );
      expect(pil.right - lingkaran.right, 6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bantalan kiri 20: teks petunjuk mulai 20 dari tepi', (
      tester,
    ) async {
      await pasang(tester, _k());
      final pil = tester.getRect(find.byType(KolomCari));
      expect(tester.getTopLeft(find.byType(EditableText)).dx - pil.left, 20);
    });
  });

  group('perilaku', () {
    testWidgets('mengetik memanggil onChanged; tombol dan enter memanggil '
        'onCari dengan isi', (tester) async {
      final diubah = <String>[];
      final dicari = <String>[];
      await pasang(tester, _k(onChanged: diubah.add, onCari: dicari.add));
      await tester.enterText(find.byType(TextField), 'pH meter');
      expect(diubah, ['pH meter']);
      await tester.tap(find.byType(TombolBulat));
      expect(dicari, ['pH meter']);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(dicari, ['pH meter', 'pH meter']);
    });

    testWidgets('tanpa onCari: tombol hanya memfokuskan isian', (tester) async {
      final fokus = FocusNode();
      addTearDown(fokus.dispose);
      await pasang(tester, _k(focusNode: fokus));
      expect(fokus.hasFocus, isFalse);
      await tester.tap(find.byType(TombolBulat));
      await tester.pump();
      expect(fokus.hasFocus, isTrue);
    });

    testWidgets('ketukan di bantalan kiri dan sela memfokuskan isian', (
      tester,
    ) async {
      final fokus = FocusNode();
      addTearDown(fokus.dispose);
      await pasang(tester, _k(focusNode: fokus));
      final pil = tester.getRect(find.byType(KolomCari));
      await tester.tapAt(pil.centerLeft + const Offset(4, 0));
      await tester.pump();
      expect(fokus.hasFocus, isTrue, reason: 'bantalan kiri');
      fokus.unfocus();
      await tester.pump();
      await tester.tapAt(pil.topLeft + const Offset(10, 3));
      await tester.pump();
      expect(fokus.hasFocus, isTrue, reason: 'tepi atas pil');
    });

    testWidgets('controller dari luar dipakai dan tidak ikut dibuang', (
      tester,
    ) async {
      final c = TextEditingController(text: 'awal');
      addTearDown(c.dispose);
      await pasang(tester, _k(controller: c));
      expect(find.text('awal'), findsOneWidget);
      await pasang(tester, const SizedBox());
      c.text = 'masih hidup';
      expect(c.text, 'masih hidup');
    });
  });

  group('cincin fokus: di luar isi dengan jarak, kontras >= 3:1', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('geometri dan kontras ($nama)', (tester) async {
        await pasang(tester, _k(), gelap: gelap);
        expect(find.byKey(kunciCincinFokusKolomCari), findsNothing);
        await tester.tap(find.byType(TextField));
        await tester.pump();
        final cincinFinder = find.byKey(kunciCincinFokusKolomCari);
        expect(cincinFinder, findsOneWidget);
        final pil = tester.getRect(find.byType(KolomCari));
        final cincin = tester.getRect(cincinFinder);
        expect(
          cincin.deflate(AppUkuran.garisTebal),
          pil.inflate(UkuranKomponenBiruAwan.jarakCincinFokus),
          reason: 'sisi dalam cincin 2 dp di luar pil',
        );
        final dekor =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: cincinFinder,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        final garis = dekor.border!.top;
        expect(garis.width, AppUkuran.garisTebal);
        expect(garis.color, bahan(tester).tinta);
        // Cincin mengikuti sudut kotak (12) + celah 2 + garis 2.
        expect(
          dekor.borderRadius,
          BorderRadius.circular(UkuranKomponenBiruAwan.sudutCincinSaringan),
        );
        for (final e in {
          'meja': bahan(tester).meja,
          'kertas': bahan(tester).kertas,
          'scaffold': Theme.of(
            tester.element(find.byType(Scaffold)),
          ).scaffoldBackgroundColor,
        }.entries) {
          expect(
            rasioKontras(garis.color, e.value),
            greaterThanOrEqualTo(ambangBukanTeks),
            reason: 'cincin/${e.key} ($nama)',
          );
        }
        expect(
          tester.getSize(find.byType(KolomCari)).height,
          48,
          reason: 'cincin tidak mengubah ukuran',
        );
      });
    }

    testWidgets('cincin hilang saat fokus lepas', (tester) async {
      await pasang(tester, _k());
      await tester.tap(find.byType(TextField));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.byKey(kunciCincinFokusKolomCari), findsNothing);
    });

    testWidgets('mati: tidak bisa difokuskan, tanpa cincin', (tester) async {
      await pasang(tester, _k(enabled: false));
      await tester.tap(find.byType(KolomCari));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.byKey(kunciCincinFokusKolomCari), findsNothing);
    });
  });

  group('keadaan mati', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('isian, pil, tombol, dan semantik mati ($nama)', (
        tester,
      ) async {
        final s = tester.ensureSemantics();
        var n = 0;
        await pasang(
          tester,
          _k(enabled: false, onCari: (_) => n++),
          gelap: gelap,
        );
        final w = warna(tester);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        // Pil: latar mati bertepi.
        final pil = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(KolomCari),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.borderRadius != null);
        expect(pil.color, w.latarMati);
        expect(pil.border!.top.color, w.tepiMati);
        // Tombol mati: tidak memanggil, ditandai mati, isi netral.
        final tombol = tester.widget<TombolBulat>(find.byType(TombolBulat));
        expect(tombol.onPressed, isNull);
        await tester.tap(find.byType(TombolBulat));
        await tester.enterText(find.byType(TextField), 'x');
        expect(n, 0);
        expect(
          semantikAktif(semantik(tester, find.byType(TombolBulat))),
          isFalse,
        );
        expect(
          tester
              .widget<Material>(
                find
                    .descendant(
                      of: find.byType(TombolBulat),
                      matching: find.byType(Material),
                    )
                    .first,
              )
              .color,
          w.isiTombolMati,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).style!.color,
          bahan(tester).tinta2,
        );
        s.dispose();
      });
    }

    testWidgets('aktif: tombol primer, isi kertas tanpa tepi', (tester) async {
      await pasang(tester, _k(onCari: (_) {}));
      final tombol = tester.widget<TombolBulat>(find.byType(TombolBulat));
      expect(tombol.ragam, RagamTombolBulat.primer);
      expect(tombol.ukuran, UkuranTombolBulat.kecil);
      expect(tombol.onPressed, isNotNull);
      expect(isiKotak(tester, find.byType(KolomCari)), bahan(tester).kertas);
    });
  });

  group('semantik dan kontras', () {
    testWidgets('kolom teks berlabel petunjuk, tombol berlabel "Cari"', (
      tester,
    ) async {
      final s = tester.ensureSemantics();
      await pasang(tester, _k(onCari: (_) {}));
      final isian = semantik(tester, find.byType(TextField));
      expect(isian.label, contains(_petunjuk));
      expect(isian.flagsCollection.isTextField, isTrue);
      final tombol = semantik(tester, find.byType(TombolBulat));
      expect(tombol.label, 'Cari');
      expect(tombol.flagsCollection.isButton, isTrue);
      expect(tombol.hasAction(SemanticsAction.tap), isTrue);
      await periksaPedomanSentuh(tester);
      s.dispose();
    });

    for (final gelap in [false, true]) {
      testWidgets(
        'petunjuk dan teks ketikan ≥ 4,5:1 (${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          await pasang(
            tester,
            _k(controller: TextEditingController(text: 'pH')),
            gelap: gelap,
          );
          final m = bahan(tester);
          expect(rasioKontras(m.tinta, m.kertas), greaterThanOrEqualTo(4.5));
          expect(rasioKontras(m.tinta2, m.kertas), greaterThanOrEqualTo(4.5));
          expect(
            rasioKontras(m.tinta2, warna(tester).latarMati),
            greaterThanOrEqualTo(4.5),
            reason: 'petunjuk di pil mati',
          );
        },
      );
    }
  });

  group('gerak dan huruf', () {
    testWidgets('tanpa animasi, juga dengan kurangi gerak', (tester) async {
      layarUji(tester);
      await tester.pumpWidget(aplikasiUji(kurangiGerak(_k())));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('320 dp x huruf 1,3: tanpa luapan; isian tidak mengecil '
        'di bawah 48', (tester) async {
      await periksaSkala13(tester, _k());
      await pasang(tester, _k(), lebar: 320, skala: 1.3);
      expect(
        tester.getSize(find.byType(KolomCari)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
