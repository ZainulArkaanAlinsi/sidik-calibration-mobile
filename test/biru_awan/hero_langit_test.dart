// HeroLangit: panel langit sudut 16 (REVISI 16 Nov) + motif skala (BUKAN awan) dari
// `docs/desain-ulang/aset/motif_skala.svg`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/palet_lab.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan_lanjut.dart';
import 'package:sidik_calibration/widgets/biru_awan/hero_langit.dart';

import '../support/uji_lanjut_biru_awan.dart';

Widget _hero({double? tinggiMin, Widget? visual, Widget? isi}) => HeroLangit(
  tinggiMin: tinggiMin ?? UkuranBiruAwan.hero,
  visual: visual,
  child: isi ?? const Text('Antrean approval'),
);

void main() {
  setUpAll(muatFontUji);

  group('motif = cermin motif_skala.svg', () {
    final svg = File(
      'docs/desain-ulang/aset/motif_skala.svg',
    ).readAsStringSync();

    // `M x y L x y`, `M x y V y` dan `M x y H x` dengan tebal garisnya.
    final pola = RegExp(
      r'<path d="M([\d.]+) ([\d.]+)(?:L([\d.]+) ([\d.]+)|V([\d.]+)|H([\d.]+))" '
      r'stroke-width="([\d.]+)"/>',
    );
    final dariSvg = <GarisMotif>[
      for (final c in pola.allMatches(svg))
        (
          dari: Offset(double.parse(c[1]!), double.parse(c[2]!)),
          ke: c[3] != null
              ? Offset(double.parse(c[3]!), double.parse(c[4]!))
              : c[5] != null
              ? Offset(double.parse(c[1]!), double.parse(c[5]!))
              : Offset(double.parse(c[6]!), double.parse(c[2]!)),
          tebal: double.parse(c[7]!),
        ),
    ];

    bool sama(GarisMotif a, GarisMotif b) =>
        (a.dari - b.dari).distance < 0.1 &&
        (a.ke - b.ke).distance < 0.1 &&
        (a.tebal - b.tebal).abs() < 1e-9;

    test('jumlah garis lurus sama persis (16 tik + jarum + penggaris 20)', () {
      expect(dariSvg, hasLength(16 + 1 + 20));
      expect(MotifSkala.garis(), hasLength(dariSvg.length));
    });

    test('setiap garis SVG punya pasangan di painter, dan sebaliknya', () {
      final saya = MotifSkala.garis();
      for (final g in dariSvg) {
        expect(
          saya.where((s) => sama(s, g)),
          isNotEmpty,
          reason: 'garis SVG ${g.dari}->${g.ke} (${g.tebal}) tidak ada',
        );
      }
      for (final s in saya) {
        expect(
          dariSvg.where((g) => sama(s, g)),
          isNotEmpty,
          reason: 'garis painter ${s.dari}->${s.ke} (${s.tebal}) tidak di SVG',
        );
      }
    });

    test('dua busur dan poros sama dengan konstanta', () {
      final r1 = MotifSkala.jariBusur.toInt();
      final r2 = MotifSkala.jariTitik.toInt();
      final px = MotifSkala.poros.dx.toInt();
      final py = MotifSkala.poros.dy.toInt();
      expect(svg, contains('M${px - r1} ${py}A$r1 $r1 0 0 1 $px ${py - r1}'));
      expect(svg, contains('M${px - r2} ${py}A$r2 $r2 0 0 1 $px ${py - r2}'));
      expect(svg, contains('stroke-width="${MotifSkala.tebalBusur.toInt()}"'));
      expect(svg, contains('stroke-dasharray="2 6"'));
      expect(MotifSkala.titikPanjang, 2);
      expect(MotifSkala.titikJeda, 6);
      expect(
        svg,
        contains('cx="$px" cy="$py" r="${MotifSkala.jariPoros.toInt()}"'),
      );
      expect(
        svg,
        contains(
          'viewBox="0 0 ${MotifSkala.lebar.toInt()} '
          '${MotifSkala.tinggi.toInt()}"',
        ),
      );
    });

    testWidgets('painter benar-benar menggambar: poros, penggaris, kosong', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const lebar = UkuranLanjutBiruAwan.motifLebar;
        const tinggi = UkuranLanjutBiruAwan.motifTinggi;
        final rekam = ui.PictureRecorder();
        const PelukisMotifSkala(
          warna: Color(0xFFFFFFFF),
        ).paint(Canvas(rekam), const Size(lebar, tinggi));
        final gambar = await rekam.endRecording().toImage(
          lebar.toInt(),
          tinggi.toInt(),
        );
        final data = (await gambar.toByteData())!;
        int alfa(int x, int y) =>
            data.getUint8((y * lebar.toInt() + x) * 4 + 3);
        final s = lebar / MotifSkala.lebar;
        // Poros (lingkaran penuh, jari 9) hampir di sudut: titik di dalamnya.
        final px = (MotifSkala.poros.dx * s - 4).round();
        final py = (MotifSkala.poros.dy * s - 4).round();
        expect(
          alfa(px, py),
          closeTo(255 * UkuranLanjutBiruAwan.motifAlfa, 3),
          reason: 'poros: putih 50 %',
        );
        // Garis penggaris (y 118) di x 60.
        expect(
          alfa((60 * s).round(), (MotifSkala.penggarisY * s).round()),
          closeTo(255 * UkuranLanjutBiruAwan.motifAlfa, 3),
          reason: 'garis penggaris',
        );
        // Ruang kosong di tengah-atas kanvas.
        expect(alfa((60 * s).round(), (20 * s).round()), 0, reason: 'kosong');
        // Garis tumpuk tidak menjadi lebih pekat dari 50 % (satu lapisan).
        var maks = 0;
        for (var y = 0; y < tinggi.toInt(); y++) {
          for (var x = 0; x < lebar.toInt(); x++) {
            if (alfa(x, y) > maks) maks = alfa(x, y);
          }
        }
        expect(
          maks,
          lessThanOrEqualTo((255 * UkuranLanjutBiruAwan.motifAlfa).ceil() + 1),
          reason: 'opasitas elemen, bukan per garis',
        );
      });
    });
  });

  group('bentuk dan ukuran', () {
    testWidgets('tinggi minimum 140 (bawaan; dulu 212) dan bisa diubah, '
        'sudut 16', (tester) async {
      await pasang(tester, Center(child: _hero()));
      expect(tester.getSize(find.byType(HeroLangit)).height, 140);
      await pasang(tester, Center(child: _hero(tinggiMin: 196)));
      expect(tester.getSize(find.byType(HeroLangit)).height, 196);
      final klip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(HeroLangit),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(klip.borderRadius, BorderRadius.circular(BentukBiruAwan.hero));
      expect(BentukBiruAwan.hero, 16);
    });

    testWidgets(
      'tumbuh bila isi lebih tinggi dari minimum, isi tidak terpotong',
      (tester) async {
        await pasang(
          tester,
          Center(child: _hero(isi: const SizedBox(height: 300, width: 50))),
        );
        expect(
          tester.getSize(find.byType(HeroLangit)).height,
          300 + 2 * UkuranLanjutBiruAwan.heroBantalan,
        );
      },
    );

    testWidgets('bantalan 20 di sekeliling isi', (tester) async {
      await pasang(tester, Align(alignment: Alignment.topLeft, child: _hero()));
      final hero = tester.getRect(find.byType(HeroLangit));
      final teks = tester.getTopLeft(find.text('Antrean approval'));
      expect(teks.dx - hero.left, UkuranLanjutBiruAwan.heroBantalan);
      expect(teks.dy - hero.top, UkuranLanjutBiruAwan.heroBantalan);
    });

    testWidgets('motif: kanvas 260 x 104 digeser -40 / -34, terpotong hero', (
      tester,
    ) async {
      await pasang(tester, Align(alignment: Alignment.topLeft, child: _hero()));
      final hero = tester.getRect(find.byType(HeroLangit));
      final motif = tester.getRect(
        find.descendant(
          of: find.byType(HeroLangit),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(motif.size, const Size(260, 104));
      expect(motif.left - hero.left, UkuranLanjutBiruAwan.motifGeserKiri);
      expect(hero.bottom - motif.bottom, UkuranLanjutBiruAwan.motifGeserBawah);
    });

    testWidgets('visual menumpang kanan bawah dan keluar dari hero', (
      tester,
    ) async {
      await pasang(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: _hero(
            visual: const SizedBox.square(
              dimension: UkuranBiruAwan.visualHero,
              key: ValueKey('visual'),
            ),
          ),
        ),
      );
      final hero = tester.getRect(find.byType(HeroLangit));
      final v = tester.getRect(find.byKey(const ValueKey('visual')));
      expect(hero.right - v.right, UkuranLanjutBiruAwan.visualGeserKanan);
      expect(hero.bottom - v.bottom, UkuranLanjutBiruAwan.visualGeserBawah);
    });
  });

  group('warna dan kontras', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('isi langit, motif, teks navy ($nama)', (tester) async {
        await pasang(tester, Center(child: _hero()), gelap: gelap);
        final w = warnaLanjut(tester);
        final hero = find.byType(HeroLangit);
        expect(
          isiKotak(tester, hero),
          gelap ? PaletLab.langitGelap : PaletLab.langit,
        );
        expect(w.isiHero, isiKotak(tester, hero));
        final pelukis = tester.widget<CustomPaint>(
          find.descendant(of: hero, matching: find.byType(CustomPaint)),
        );
        expect(
          (pelukis.painter! as PelukisMotifSkala).warna,
          gelap ? bahan(tester).tinta : bahan(tester).kertas,
        );
        // Teks bawaan = tintaHero (navy); kontras >= 4,5 di atas langit.
        expect(pelanggaranKontrasTeks(tester, hero), isEmpty, reason: nama);
        expect(
          rasioKontras(w.tintaHero, w.isiHero),
          greaterThanOrEqualTo(4.5),
          reason: 'tinta hero di atas langit ($nama)',
        );
      });
    }

    test('putih di atas langit memang DILARANG (2,26:1): bukan tinta hero', () {
      expect(rasioKontras(PaletLab.kertas, PaletLab.langit), lessThan(3));
    });
  });

  group('semantik', () {
    testWidgets('teks anak terbaca; motif dan visual tidak ada di pohon', (
      tester,
    ) async {
      final s = tester.ensureSemantics();
      await pasang(
        tester,
        Center(
          child: _hero(
            visual: Semantics(
              label: 'GAMBAR-ALAT',
              child: const SizedBox.square(dimension: 20),
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Antrean approval'), findsOneWidget);
      expect(find.bySemanticsLabel('GAMBAR-ALAT'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(HeroLangit),
          matching: find.byType(ExcludeSemantics),
        ),
        findsNWidgets(2),
        reason: 'motif dan visual keluar dari pembaca layar',
      );
      s.dispose();
    });

    testWidgets('hero bukan kontrol: tak ada aksi ketuk', (tester) async {
      final s = tester.ensureSemantics();
      await pasang(tester, Center(child: _hero()));
      final data = semantik(tester, find.text('Antrean approval'));
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      s.dispose();
    });

    testWidgets('tombol di dalam hero tetap bisa diketuk', (tester) async {
      var n = 0;
      await pasang(
        tester,
        Center(
          child: _hero(
            isi: TextButton(
              onPressed: () => n++,
              child: const Text('Buka antrean'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka antrean'));
      expect(n, 1);
    });
  });

  group('gerak dan huruf', () {
    testWidgets('diam: tanpa animasi, juga dengan kurangi gerak', (
      tester,
    ) async {
      await pasang(tester, Center(child: _hero()));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      layarUji(tester);
      await tester.pumpWidget(
        aplikasiUji(kurangiGerak(Center(child: _hero()))),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('320 dp x huruf 1,3 tanpa luapan, isi panjang membungkus', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        _hero(
          isi: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Antrean approval'),
              Text(
                'menunggu, 1 ada FAIL dan beberapa lembar kerja lagi yang '
                'masih menunggu keputusan pemeriksa',
              ),
            ],
          ),
        ),
        tinggi: 1200,
      );
    });
  });
}
