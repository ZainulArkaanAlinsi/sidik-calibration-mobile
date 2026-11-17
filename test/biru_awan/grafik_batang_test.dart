// GrafikBatang: 7 batang sudut 10, hari ini primer, lainnya awan, tumbuh 240 ms.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan_lanjut.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/grafik_batang.dart';

import '../support/uji_lanjut_biru_awan.dart';

const _hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _nilai = [5.0, 8.0, 0.0, 10.0, 2.5, 4.0, 1.0];

List<BatangGrafik> _data([List<double> nilai = _nilai]) => [
  for (var i = 0; i < 7; i++)
    BatangGrafik(
      label: _hari[i],
      nilai: nilai[i],
      teksNilai: nilai[i].toStringAsFixed(nilai[i] % 1 == 0 ? 0 : 1),
    ),
];

Widget _g({
  List<double> nilai = _nilai,
  int? sorot = 3,
  double? nilaiMaks,
  String? semantik = 'Grafik pekerjaan, 7 hari',
}) => Padding(
  padding: const EdgeInsets.all(16),
  child: GrafikBatang(
    batang: _data(nilai),
    sorot: sorot,
    penandaSorot: 'hari ini',
    semantik: semantik,
    nilaiMaks: nilaiMaks,
  ),
);

Finder _faktorTinggi() => find.descendant(
  of: find.byType(GrafikBatang),
  matching: find.byType(FractionallySizedBox),
);

List<double> _faktor(WidgetTester tester) => [
  for (final f in tester.widgetList<FractionallySizedBox>(_faktorTinggi()))
    f.heightFactor!,
];

void main() {
  setUpAll(muatFontUji);

  group('tinggi dan warna batang', () {
    testWidgets('tinggi = nilai / terbesar; nol = kosong; tanpa bagi nol', (
      tester,
    ) async {
      await pasang(tester, _g());
      await tester.pumpAndSettle();
      expect(_faktor(tester), [0.5, 0.8, 0, 1, 0.25, 0.4, 0.1]);
      await pasang(tester, _g(nilai: List.filled(7, 0)));
      await tester.pumpAndSettle();
      expect(_faktor(tester), everyElement(0));
    });

    testWidgets('nilaiMaks dipakai; nilai di atasnya dibatasi 1; negatif dan '
        'NaN = kosong', (tester) async {
      await pasang(
        tester,
        _g(
          nilai: [5, 20, -2, double.nan, 0, 10, double.infinity],
          nilaiMaks: 10,
        ),
      );
      await tester.pumpAndSettle();
      expect(_faktor(tester), [0.5, 1, 0, 0, 0, 1, 0]);
    });

    testWidgets('tinggi kolom 150; batang tertinggi mengisi ruang di antara '
        'angka dan nama', (tester) async {
      await pasang(tester, _g());
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(GrafikBatang)).height,
        UkuranLanjutBiruAwan.batangTinggi,
      );
      final tertinggi = tester.getRect(
        find
            .descendant(
              of: find.byType(GrafikBatang),
              matching: find.byType(DecoratedBox),
            )
            .at(3),
      );
      final angka = tester.getRect(find.text('10'));
      final nama = tester.getRect(find.text('Kam'));
      expect(tertinggi.top - angka.bottom, 6);
      expect(nama.top - tertinggi.bottom, 6);
    });

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('sorot primer, lainnya awan; sudut 10 ($nama)', (
        tester,
      ) async {
        await pasang(tester, _g(), gelap: gelap);
        await tester.pumpAndSettle();
        final batang = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(GrafikBatang),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((d) => d.decoration as BoxDecoration)
            .toList();
        expect(batang, hasLength(7));
        final primer = skemaWarna(tester).primary;
        final awan = warna(tester).isi(IsiBiruAwan.awan);
        for (var i = 0; i < 7; i++) {
          expect(batang[i].color, i == 3 ? primer : awan, reason: 'batang $i');
          expect(
            batang[i].borderRadius,
            BorderRadius.circular(UkuranLanjutBiruAwan.batangRadius),
          );
        }
        // Batang sorot: >= 3:1 terhadap kertas (objek grafis); angka dan nama
        // teks ≥ 4,5:1.
        expect(
          rasioKontras(primer, bahan(tester).kertas),
          greaterThanOrEqualTo(ambangBukanTeks),
        );
        expect(
          pelanggaranKontrasTeks(tester, find.byType(GrafikBatang)),
          isEmpty,
          reason: nama,
        );
      });
    }

    testWidgets('tanpa sorot: semua awan; sorot di luar rentang tidak error', (
      tester,
    ) async {
      await pasang(tester, _g(sorot: null));
      await pasang(tester, _g(sorot: 99));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('nama hari sorot menebal 800; lainnya 500', (tester) async {
      await pasang(tester, _g());
      expect(
        tester.widget<Text>(find.text('Kam')).style!.fontWeight,
        FontWeight.w600,
      );
      expect(
        tester.widget<Text>(find.text('Sen')).style!.fontWeight,
        FontWeight.w500,
      );
    });
  });

  group('gerak: tumbuh sekali, angka tidak dianimasikan', () {
    testWidgets('mulai kosong, jeda 240, penuh pada 480 ms, lalu selesai', (
      tester,
    ) async {
      await pasang(tester, _g());
      expect(_faktor(tester), everyElement(0), reason: 't = 0');
      expect(find.text('10'), findsOneWidget, reason: 'angka langsung final');
      await tester.pump(const Duration(milliseconds: 200));
      expect(_faktor(tester), everyElement(0), reason: 'masih dalam jeda');
      await tester.pump(const Duration(milliseconds: 140));
      final tengah = _faktor(tester);
      expect(tengah[3], inExclusiveRange(0, 1), reason: 'sedang tumbuh');
      await tester.pumpAndSettle();
      expect(_faktor(tester)[3], 1);
      expect(tester.hasRunningAnimations, isFalse, reason: 'tanpa repeat');
    });

    testWidgets('kurangi gerak: langsung penuh dan tanpa animasi', (
      tester,
    ) async {
      layarUji(tester);
      await tester.pumpWidget(aplikasiUji(kurangiGerak(_g())));
      await tester.pump();
      expect(_faktor(tester), [0.5, 0.8, 0, 1, 0.25, 0.4, 0.1]);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('semantik', () {
    testWidgets('grup berlabel; tiap kolom satu node "hari, angka" dan sorot '
        'menyebut penanda', (tester) async {
      final s = tester.ensureSemantics();
      await pasang(tester, _g());
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Grafik pekerjaan, 7 hari'), findsOneWidget);
      expect(find.bySemanticsLabel('Sen, 5'), findsOneWidget);
      expect(find.bySemanticsLabel('Rab, 0'), findsOneWidget);
      expect(find.bySemanticsLabel('Kam, 10, hari ini'), findsOneWidget);
      expect(
        find.bySemanticsLabel('10'),
        findsNothing,
        reason: 'angka di atas batang tidak dibaca dua kali',
      );
      expect(
        semantik(
          tester,
          find.bySemanticsLabel('Sen, 5'),
        ).hasAction(SemanticsAction.tap),
        isFalse,
      );
      s.dispose();
    });

    testWidgets('tanpa nama grup: tidak ada node grup', (tester) async {
      final s = tester.ensureSemantics();
      await pasang(tester, _g(semantik: null));
      expect(find.bySemanticsLabel('Grafik pekerjaan, 7 hari'), findsNothing);
      expect(find.bySemanticsLabel('Sen, 5'), findsOneWidget);
      s.dispose();
    });
  });

  group('huruf', () {
    testWidgets('320 dp x huruf 1,3: angka panjang mengecil, tanpa luapan', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        GrafikBatang(
          batang: [
            for (var i = 0; i < 7; i++)
              BatangGrafik(
                label: 'Sabtu',
                nilai: i + 1,
                teksNilai: '${(i + 1) * 1234}',
              ),
          ],
          sorot: 6,
        ),
      );
    });
  });
}
