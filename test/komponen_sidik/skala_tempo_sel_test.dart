// SkalaTempo (batang jatuh tempo + kata) dan SkalaSel (satu tik per sel).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/widgets/sidik/skala_sel.dart';
import 'package:sidik_calibration/widgets/sidik/skala_tempo.dart';

import '../support/komponen_uji.dart';

const _batang = Key('skala-tempo-batang');
const _ekor = Key('skala-tempo-ekor');
const _jadwal = Key('skala-tempo-jadwal');
const _hariIni = Key('skala-tempo-hari-ini');

Future<void> _pasang(
  WidgetTester tester,
  Widget skala, {
  bool gelap = false,
  double skalaHuruf = 1.0,
  double lebar = 392,
}) async {
  layarUji(tester, lebar: lebar, tinggi: 900);
  await tester.pumpWidget(
    aplikasiUji(
      Padding(padding: const EdgeInsets.all(16), child: skala),
      gelap: gelap,
      skala: skalaHuruf,
    ),
  );
  // Tema berganti dengan animasi 200 ms (AnimatedTheme): tunggu selesai supaya
  // yang diukur tema akhir, bukan campuran terang-gelap.
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(muatFontUji);

  group('SkalaTempo: aturan dan geometri', () {
    test('hari null (overdue tanpa tanggal): tanpa batang dan tanpa angka', () {
      expect(SkalaTempo.tampilkanBatang(null), isFalse);
      expect(SkalaTempo.tampilkanBatang(null, detail: true), isFalse);
      expect(
        SkalaTempo.kataTempo(null, null),
        'Lewat jadwal. Tanggal belum diketahui',
      );
      expect(
        SkalaTempo.kataTempo(null, '1 Nov 2026'),
        'Lewat jadwal. Tanggal belum diketahui',
        reason: 'tanggal tak dipercaya bila hari tidak diketahui',
      );
      expect(SkalaTempo.kataTempo(null, null), isNot(contains(RegExp(r'\d'))));
    });

    test('tanggal null dengan hari terisi: kalimat tanpa bagian Jadwal', () {
      expect(SkalaTempo.kataTempo(12, null), '12 hari lagi');
      expect(SkalaTempo.kataTempo(-3, null), 'Lewat 3 hari');
      expect(SkalaTempo.kataTempo(0, null), 'Hari ini');
      expect(SkalaTempo.kataTempo(240, null), '8 bulan lagi');
    });

    test(
      'batang hanya untuk Segera (<= 30 hari), Lewat jadwal, dan detail',
      () {
        expect(SkalaTempo.tampilkanBatang(-200), isTrue);
        expect(SkalaTempo.tampilkanBatang(-1), isTrue);
        expect(SkalaTempo.tampilkanBatang(0), isTrue);
        expect(SkalaTempo.tampilkanBatang(30), isTrue);
        expect(SkalaTempo.tampilkanBatang(31), isFalse);
        expect(SkalaTempo.tampilkanBatang(240), isFalse);
        expect(SkalaTempo.tampilkanBatang(240, detail: true), isTrue);
      },
    );

    test(
      'posisi: lewat jadwal menaruh tik jadwal di 80% dan ekor ke kanan',
      () {
        final p = SkalaTempo.posisi(-12);
        expect(p.jadwal, closeTo(0.8, 1e-9));
        expect(p.sekarang, closeTo(0.8 + 12 / 150, 1e-9));
        // Terlambat lebih dari 30 hari: ekor mentok di ujung kanan.
        expect(SkalaTempo.posisi(-30).sekarang, closeTo(1.0, 1e-9));
        expect(SkalaTempo.posisi(-200).sekarang, closeTo(1.0, 1e-9));
      },
    );

    test('posisi: belum lewat, tik jadwal di kanan dan penanda mendekat', () {
      expect(SkalaTempo.posisi(0), (sekarang: 1.0, jadwal: 1.0));
      expect(SkalaTempo.posisi(45).sekarang, closeTo(0.5, 1e-9));
      expect(SkalaTempo.posisi(90).sekarang, closeTo(0.0, 1e-9));
      expect(SkalaTempo.posisi(240).sekarang, 0.0, reason: 'menempel di kiri');
      expect(SkalaTempo.posisi(12).jadwal, 1.0);
    });

    test('ekor terlambat dilebarkan paling sedikit 8%, posisi asli utuh', () {
      final nyata = SkalaTempo.posisi(-1);
      final tampak = SkalaTempo.posisiTampak(-1);
      expect(nyata.sekarang - nyata.jadwal, closeTo(1 / 150, 1e-9));
      expect(tampak.sekarang - tampak.jadwal, closeTo(0.08, 1e-9));
      // Yang cukup panjang tidak diubah.
      expect(
        SkalaTempo.posisiTampak(-12).sekarang,
        SkalaTempo.posisi(-12).sekarang,
      );
      expect(SkalaTempo.posisiTampak(5), SkalaTempo.posisi(5));
    });

    test('tik bulanan: tiap 30 hari, tanpa tik di tempat tik jadwal', () {
      final lewat = SkalaTempo.posisiTik(-12);
      expect(lewat.length, 3);
      expect(lewat[0], closeTo(0.2, 1e-9));
      expect(lewat[1], closeTo(0.4, 1e-9));
      expect(lewat[2], closeTo(0.6, 1e-9));
      final belum = SkalaTempo.posisiTik(12);
      expect(belum.length, 2);
      expect(belum[0], closeTo(1 / 3, 1e-9));
      expect(belum[1], closeTo(2 / 3, 1e-9));
    });

    test('kalimat bawaan: hari, bulan, lewat; tanpa istilah terlarang', () {
      String k(int h) => SkalaTempo.kataTempo(h, '1 Nov 2026');
      expect(k(-12), 'Lewat 12 hari. Jadwal 1 Nov 2026');
      expect(k(0), 'Hari ini. Jadwal 1 Nov 2026');
      expect(k(12), '12 hari lagi. Jadwal 1 Nov 2026');
      expect(k(60), '60 hari lagi. Jadwal 1 Nov 2026');
      expect(k(61), '2 bulan lagi. Jadwal 1 Nov 2026');
      expect(k(240), '8 bulan lagi. Jadwal 1 Nov 2026');
      for (final h in [-12, 0, 12, 240]) {
        expect(k(h).toLowerCase(), isNot(contains('daluwarsa')));
        expect(k(h).toLowerCase(), isNot(contains('jatuh tempo')));
      }
    });

    test('label berpusat pada tiknya dan dijepit di dalam batang', () {
      double b(double lebar, double label, double p) =>
          SkalaTempo.biasTengah(lebar: lebar, lebarLabel: label, posisi: p);
      expect(b(300, 60, 0.5), closeTo(0, 1e-9));
      expect(b(300, 60, 0), -1, reason: 'jepit kiri');
      expect(b(300, 60, 1), 1, reason: 'jepit kanan');
      expect(b(50, 60, 0.5), -1, reason: 'label lebih lebar dari batang');
    });
  });

  group('SkalaTempo: widget', () {
    for (final detail in [false, true]) {
      testWidgets(
        'hari null (detail=$detail): "Lewat jadwal. Tanggal belum diketahui", '
        'tanpa batang, ekor, atau angka palsu',
        (tester) async {
          final semantik = tester.ensureSemantics();
          await _pasang(tester, SkalaTempo(hari: null, detail: detail));
          const kalimat = 'Lewat jadwal. Tanggal belum diketahui';
          expect(find.text(kalimat), findsOneWidget);
          for (final k in [_batang, _ekor, _jadwal, _hariIni]) {
            expect(find.byKey(k), findsNothing);
          }
          expect(find.textContaining(RegExp(r'\d')), findsNothing);
          expect(find.text('Hari ini'), findsNothing);
          expect(
            tester
                .getSemantics(find.byType(SkalaTempo))
                .getSemanticsData()
                .label,
            kalimat,
          );
          semantik.dispose();
        },
      );
    }

    testWidgets('tanpa tanggal: batang tetap, label jadwal tanpa tanggal', (
      tester,
    ) async {
      await _pasang(tester, const SkalaTempo(hari: 12, detail: true));
      expect(find.byKey(_batang), findsOneWidget);
      expect(find.text('12 hari lagi'), findsOneWidget);
      expect(find.text('Jadwal'), findsOneWidget);
    });

    testWidgets('"Berlaku" jauh: satu kalimat, TANPA batang', (tester) async {
      await _pasang(
        tester,
        const SkalaTempo(hari: 240, tanggal: '13 Jul 2027'),
      );
      expect(find.text('8 bulan lagi. Jadwal 13 Jul 2027'), findsOneWidget);
      expect(find.byKey(_batang), findsNothing);
    });

    testWidgets('Segera: batang + kata; tik jadwal di ujung kanan', (
      tester,
    ) async {
      await _pasang(tester, const SkalaTempo(hari: 12, tanggal: '26 Nov 2026'));
      expect(find.text('12 hari lagi. Jadwal 26 Nov 2026'), findsOneWidget);
      final batang = tester.getRect(find.byKey(_batang));
      final jadwal = tester.getRect(find.byKey(_jadwal));
      final hariIni = tester.getRect(find.byKey(_hariIni));
      expect(jadwal.right, closeTo(batang.right, 0.5));
      expect(
        hariIni.center.dx,
        closeTo(batang.left + batang.width * (1 - 12 / 90), 3),
      );
      expect(find.byKey(_ekor), findsNothing);
    });

    testWidgets(
      'Lewat jadwal: tik jadwal di 80%, ekor merah = lama terlambat',
      (tester) async {
        final m = SidikMaterial.terangDefault;
        await _pasang(
          tester,
          const SkalaTempo(hari: -12, tanggal: '1 Nov 2026'),
        );
        expect(find.text('Lewat 12 hari. Jadwal 1 Nov 2026'), findsOneWidget);
        final batang = tester.getRect(find.byKey(_batang));
        final jadwal = tester.getRect(find.byKey(_jadwal));
        final ekor = tester.getRect(find.byKey(_ekor));
        expect(
          jadwal.center.dx,
          closeTo(batang.left + batang.width * 0.8, 1.5),
        );
        expect(ekor.left, closeTo(jadwal.center.dx, 1.5));
        expect(ekor.width, closeTo(batang.width * 12 / 150, 1.5));
        final warna =
            (tester
                        .widget<DecoratedBox>(
                          find.descendant(
                            of: find.byKey(_ekor),
                            matching: find.byType(DecoratedBox),
                          ),
                        )
                        .decoration
                    as BoxDecoration)
                .color;
        expect(warna, m.gagal);
        // Tik bulanan: 3 tik selain tik jadwal.
        expect(find.byKey(const Key('skala-tempo-tik-0')), findsOneWidget);
        expect(find.byKey(const Key('skala-tempo-tik-2')), findsOneWidget);
        expect(find.byKey(const Key('skala-tempo-tik-3')), findsNothing);
      },
    );

    testWidgets('terlambat 1 hari: ekor tetap tampak (>= 8% lebar batang)', (
      tester,
    ) async {
      await _pasang(tester, const SkalaTempo(hari: -1, tanggal: '13 Nov 2026'));
      final batang = tester.getRect(find.byKey(_batang));
      expect(
        tester.getSize(find.byKey(_ekor)).width,
        greaterThanOrEqualTo(batang.width * 0.08 - 0.5),
      );
    });

    testWidgets(
      'detail alat: batang selalu ada, label "Hari ini" dan "Jadwal"',
      (tester) async {
        await _pasang(
          tester,
          const SkalaTempo(hari: 240, tanggal: '13 Jul 2027', detail: true),
        );
        expect(find.byKey(_batang), findsOneWidget);
        expect(find.text('Hari ini'), findsOneWidget);
        expect(find.text('Jadwal 13 Jul 2027'), findsOneWidget);
        expect(find.text('8 bulan lagi. Jadwal 13 Jul 2027'), findsOneWidget);
      },
    );

    testWidgets('kata pengganti dipakai bila diberikan', (tester) async {
      await _pasang(
        tester,
        const SkalaTempo(
          hari: -3,
          tanggal: '11 Nov 2026',
          kata: 'Terlambat 3 hari',
        ),
      );
      expect(find.text('Terlambat 3 hari'), findsOneWidget);
      expect(find.textContaining('Lewat 3 hari'), findsNothing);
    });

    testWidgets('pembaca layar: satu kalimat, bukan aksi', (tester) async {
      final semantik = tester.ensureSemantics();
      await _pasang(
        tester,
        const SkalaTempo(hari: -12, tanggal: '1 Nov 2026', detail: true),
      );
      final data = tester
          .getSemantics(find.byType(SkalaTempo))
          .getSemanticsData();
      expect(data.label, 'Lewat 12 hari. Jadwal 1 Nov 2026');
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      semantik.dispose();
    });

    for (final gelap in [false, true]) {
      testWidgets('detail, 320 dp x 1,3: tanpa luapan, kontras >= 4,5:1 '
          '(${gelap ? 'gelap' : 'terang'})', (tester) async {
        for (final h in [-200, -12, 0, 12, 240]) {
          await _pasang(
            tester,
            SkalaTempo(hari: h, tanggal: '13 Jul 2027', detail: true),
            gelap: gelap,
            skalaHuruf: 1.3,
            lebar: 320,
          );
          expect(tester.takeException(), isNull, reason: 'hari $h');
          expect(
            pelanggaranKontrasTeks(tester, find.byType(SkalaTempo)),
            isEmpty,
            reason: 'hari $h',
          );
        }
      });
    }

    testWidgets('komponen grafik terlihat >= 3:1 terhadap latar', (
      tester,
    ) async {
      for (final gelap in [false, true]) {
        final m = gelap
            ? SidikMaterial.gelapDefault
            : SidikMaterial.terangDefault;
        await _pasang(
          tester,
          const SkalaTempo(hari: -12, tanggal: '1 Nov 2026'),
          gelap: gelap,
        );
        final skema = Theme.of(
          tester.element(find.byType(SkalaTempo)),
        ).colorScheme;
        for (final (nama, warna) in [
          ('isi batang', skema.primary),
          ('ekor', m.gagal),
          ('tik jadwal', skema.onSurface),
          ('tik bulan', m.garisTegas),
        ]) {
          expect(
            rasioKontras(warna, m.kertas),
            greaterThanOrEqualTo(3.0),
            reason: '$nama ${gelap ? 'gelap' : 'terang'}',
          );
        }
      }
    });
  });

  group('SkalaSel: susunan tik', () {
    test('satu tik per sel sampai 60 sel', () {
      final t = SkalaSel.susunTik(terisi: 12, total: 30);
      expect(t.length, 30);
      expect(t.take(12).every((x) => x == KeadaanTik.penuh), isTrue);
      expect(t.skip(12).every((x) => x == KeadaanTik.kosong), isTrue);
      expect(SkalaSel.susunTik(terisi: 0, total: 60).length, 60);
      expect(SkalaSel.susunTik(terisi: 60, total: 60).length, 60);
    });

    test('nilai di luar jangkauan dijepit; tanpa sel = tanpa tik', () {
      expect(
        SkalaSel.susunTik(
          terisi: 99,
          total: 30,
        ).every((x) => x == KeadaanTik.penuh),
        isTrue,
      );
      expect(
        SkalaSel.susunTik(
          terisi: -4,
          total: 30,
        ).every((x) => x == KeadaanTik.kosong),
        isTrue,
      );
      expect(SkalaSel.susunTik(terisi: 3, total: 0), isEmpty);
      expect(SkalaSel.susunTik(terisi: 3, total: -2), isEmpty);
    });

    test('lebih dari 60 sel dikelompokkan, paling banyak 30 tik', () {
      final t61 = SkalaSel.susunTik(terisi: 0, total: 61);
      expect(t61.length, lessThanOrEqualTo(30));
      expect(t61.length, 21, reason: '61 sel / 3 per kelompok');
      final t150 = SkalaSel.susunTik(terisi: 67, total: 150);
      expect(t150.length, 30, reason: '150 sel / 5 per kelompok');
      // 67 sel = 13 kelompok penuh (65) + 2 dari 5 = sebagian.
      expect(t150.take(13).every((x) => x == KeadaanTik.penuh), isTrue);
      expect(t150[13], KeadaanTik.sebagian);
      expect(t150.skip(14).every((x) => x == KeadaanTik.kosong), isTrue);
      expect(
        SkalaSel.susunTik(
          terisi: 150,
          total: 150,
        ).every((x) => x == KeadaanTik.penuh),
        isTrue,
      );
    });

    test('kata bawaan', () {
      expect(SkalaSel.kataSel(12, 30), '12 dari 30 sel');
      expect(SkalaSel.kataSel(99, 30), '30 dari 30 sel');
      expect(SkalaSel.kataSel(0, 0), 'Belum ada sel');
    });
  });

  group('SkalaSel: widget', () {
    int hitung(WidgetTester tester, String keadaan) => find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('tik-sel-') &&
              (w.key! as ValueKey<String>).value.endsWith('-$keadaan'),
        )
        .evaluate()
        .length;

    testWidgets(
      '12 dari 30: tik penuh kobalt, tik kosong bergaris tepi tegas',
      (tester) async {
        final m = SidikMaterial.terangDefault;
        await _pasang(tester, const SkalaSel(terisi: 12, total: 30));
        expect(hitung(tester, 'penuh'), 12);
        expect(hitung(tester, 'kosong'), 18);
        expect(hitung(tester, 'sebagian'), 0);
        expect(find.text('12 dari 30 sel'), findsOneWidget);
        final skema = Theme.of(
          tester.element(find.byType(SkalaSel)),
        ).colorScheme;

        BoxDecoration dekor(String kunci) =>
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byKey(ValueKey(kunci)),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        final penuh = dekor('tik-sel-0-penuh');
        expect(penuh.color, skema.primary);
        expect(penuh.border, isNull);
        final kosong = dekor('tik-sel-12-kosong');
        expect(kosong.color, isNull, reason: 'bentuk beda: hanya garis tepi');
        expect((kosong.border! as Border).top.color, m.garisTegas);
      },
    );

    testWidgets('kelompok: satu tik sebagian digambar setengah terisi', (
      tester,
    ) async {
      await _pasang(tester, const SkalaSel(terisi: 67, total: 150));
      expect(hitung(tester, 'penuh'), 13);
      expect(hitung(tester, 'sebagian'), 1);
      expect(hitung(tester, 'kosong'), 16);
      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });

    testWidgets('tampilkanKata=false menyembunyikan kalimat; tanpa sel', (
      tester,
    ) async {
      await _pasang(
        tester,
        const SkalaSel(terisi: 12, total: 30, tampilkanKata: false),
      );
      expect(find.text('12 dari 30 sel'), findsNothing);
      expect(hitung(tester, 'penuh'), 12);
      await _pasang(tester, const SkalaSel(terisi: 0, total: 0));
      expect(find.text('Belum ada sel'), findsOneWidget);
      expect(hitung(tester, 'penuh') + hitung(tester, 'kosong'), 0);
    });

    testWidgets(
      'kalimat buatan layar dibacakan apa adanya, bukan "terisi terisi"',
      (tester) async {
        final semantik = tester.ensureSemantics();
        await _pasang(
          tester,
          const SkalaSel(terisi: 12, total: 30, kata: '12 dari 30 sel terisi'),
        );
        expect(
          tester.getSemantics(find.byType(SkalaSel)).getSemanticsData().label,
          '12 dari 30 sel terisi',
        );
        await _pasang(
          tester,
          const SkalaSel(terisi: 0, total: 0, kata: 'Belum ada sel'),
        );
        expect(
          tester.getSemantics(find.byType(SkalaSel)).getSemanticsData().label,
          'Belum ada sel',
        );
        semantik.dispose();
      },
    );

    testWidgets('pembaca layar: "12 dari 30 sel terisi"', (tester) async {
      final semantik = tester.ensureSemantics();
      await _pasang(tester, const SkalaSel(terisi: 12, total: 30));
      expect(
        tester.getSemantics(find.byType(SkalaSel)).getSemanticsData().label,
        '12 dari 30 sel terisi',
      );
      semantik.dispose();
    });

    for (final gelap in [false, true]) {
      testWidgets(
        '60 dan 150 sel di 320 dp x 1,3: tanpa luapan, kontras >= 4,5:1 '
        '(${gelap ? 'gelap' : 'terang'})',
        (tester) async {
          for (final (isi, total) in [(41, 60), (67, 150), (0, 30)]) {
            await _pasang(
              tester,
              SkalaSel(terisi: isi, total: total),
              gelap: gelap,
              skalaHuruf: 1.3,
              lebar: 320,
            );
            expect(tester.takeException(), isNull, reason: '$isi/$total');
            expect(
              pelanggaranKontrasTeks(tester, find.byType(SkalaSel)),
              isEmpty,
            );
          }
        },
      );
    }
  });
}
