// StempelSidik: pil 30, nada dari pemetaan status yang ADA; FAIL navy pekat;
// keputusan null = netral, tidak pernah hijau.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/stempel_sidik.dart';
import 'package:sidik_calibration/widgets/sidik/status_tampil.dart';

import '../support/uji_biru_awan.dart';

/// Kotak berwarna di dalam stempel.
BoxDecoration _kotak(WidgetTester tester) {
  final d = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(StempelSidik),
      matching: find.byType(DecoratedBox),
    ),
  );
  return d.decoration as BoxDecoration;
}

TextStyle _gayaTeks(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(StempelSidik),
        matching: find.byType(Text),
      ),
    )
    .style!;

Color _tintaTeks(WidgetTester tester) => _gayaTeks(tester).color!;

void main() {
  setUpAll(muatFontUji);

  group('bentuk', () {
    testWidgets('pil, tinggi minimum 30, ikon + kata 12/700', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          Center(
            child: StempelSidik(StatusTampil.dariKode('menunggu_approval')),
          ),
        ),
      );
      expect(tester.getSize(find.byType(StempelSidik)).height, 30);
      expect(
        _kotak(tester).borderRadius,
        BorderRadius.circular(BentukBiruAwan.pil),
      );
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.text('Menunggu'), findsOneWidget);
      final gaya = _gayaTeks(tester);
      expect(gaya.fontSize, 12);
      expect(gaya.fontWeight, FontWeight.w700);
    });

    testWidgets('selalu ikon + kata, untuk semua nada dan FAIL', (
      tester,
    ) async {
      for (final kode in [
        'draft',
        'menunggu_approval',
        'perlu_revisi',
        'disetujui',
        'PASS',
        'FAIL',
        'overdue',
        'dibatalkan',
      ]) {
        await tester.pumpWidget(
          aplikasiUji(StempelSidik(StatusTampil.dariKode(kode))),
        );
        expect(find.byType(Icon), findsOneWidget, reason: kode);
        expect(
          find.descendant(
            of: find.byType(StempelSidik),
            matching: find.byType(Text),
          ),
          findsOneWidget,
          reason: kode,
        );
      }
    });
  });

  group('nada dari pemetaan yang ada', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('isi tiap nada mengikuti WarnaBiruAwan ($nama)', (
        tester,
      ) async {
        final peta = <String, IsiBiruAwan>{
          'draft': IsiBiruAwan.netral,
          'menunggu_approval': IsiBiruAwan.awan,
          'perlu_revisi': IsiBiruAwan.kuning,
          'disetujui': IsiBiruAwan.hijau,
          'PASS': IsiBiruAwan.hijau,
          'overdue': IsiBiruAwan.koral,
          'dibatalkan': IsiBiruAwan.koral,
          'expired': IsiBiruAwan.koral,
          'warning': IsiBiruAwan.kuning,
          'terbit': IsiBiruAwan.hijau,
        };
        for (final e in peta.entries) {
          await tester.pumpWidget(
            aplikasiUji(
              StempelSidik(StatusTampil.dariKode(e.key)),
              gelap: gelap,
            ),
          );
          final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
          expect(_kotak(tester).color, w.isi(e.value), reason: e.key);
          expect(_tintaTeks(tester), w.tinta(e.value), reason: e.key);
        }
      });

      testWidgets('FAIL: navy pekat + putih, TIDAK dilunakkan ($nama)', (
        tester,
      ) async {
        await tester.pumpWidget(
          aplikasiUji(
            StempelSidik(StatusTampil.dariKode('FAIL')),
            gelap: gelap,
          ),
        );
        final ctx = tester.element(find.byType(Scaffold));
        final w = WarnaBiruAwan.of(ctx);
        final m = SidikMaterial.of(ctx);
        expect(_kotak(tester).color, w.isiFail);
        expect(_tintaTeks(tester), w.tintaFail);
        expect(find.text('FAIL'), findsOneWidget);
        if (!gelap) {
          expect(w.isiFail, m.tinta, reason: 'navy pekat');
          expect(w.tintaFail, m.kertas, reason: 'teks putih');
        }
        expect(
          _kotak(tester).color,
          isNot(w.isi(IsiBiruAwan.koral)),
          reason: 'FAIL bukan koral',
        );
        expect(_kotak(tester).color, isNot(w.isi(IsiBiruAwan.koralTipis)));
      });

      testWidgets(
        'keputusan "FAIL" dari sesi disetujui juga navy pekat ($nama)',
        (tester) async {
          await tester.pumpWidget(
            aplikasiUji(
              StempelSidik(
                StatusTampil.dariKode('disetujui', keputusan: 'FAIL'),
              ),
              gelap: gelap,
            ),
          );
          final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
          expect(_kotak(tester).color, w.isiFail);
        },
      );

      testWidgets(
        'keputusan null = netral "Tanpa PASS/FAIL", TIDAK hijau ($nama)',
        (tester) async {
          await tester.pumpWidget(
            aplikasiUji(StempelSidik.keputusan(null), gelap: gelap),
          );
          final ctx = tester.element(find.byType(Scaffold));
          final w = WarnaBiruAwan.of(ctx);
          final m = SidikMaterial.of(ctx);
          final s = tester.widget<StempelSidik>(find.byType(StempelSidik));
          expect(s.nada, NadaStempel.netral);
          expect(s.adalahFail, isFalse);
          expect(find.text('Tanpa PASS/FAIL'), findsOneWidget);
          expect(_kotak(tester).color, w.isi(IsiBiruAwan.netral));
          expect(_kotak(tester).color, isNot(w.isi(IsiBiruAwan.hijau)));
          expect(_kotak(tester).color, isNot(m.lulusTipis));
          expect(find.byType(Icon), findsOneWidget, reason: 'ikon + kata');
        },
      );

      testWidgets(
        'keputusan PASS hijau; nilai asing apa adanya, netral ($nama)',
        (tester) async {
          await tester.pumpWidget(
            aplikasiUji(StempelSidik.keputusan('PASS'), gelap: gelap),
          );
          final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
          expect(_kotak(tester).color, w.isi(IsiBiruAwan.hijau));

          await tester.pumpWidget(
            aplikasiUji(StempelSidik.keputusan('LULUS?'), gelap: gelap),
          );
          expect(find.text('LULUS?'), findsOneWidget);
          expect(_kotak(tester).color, w.isi(IsiBiruAwan.netral));
          expect(_kotak(tester).color, isNot(w.isi(IsiBiruAwan.hijau)));
        },
      );

      testWidgets('keputusan kosong ("") diperlakukan seperti null ($nama)', (
        tester,
      ) async {
        await tester.pumpWidget(
          aplikasiUji(StempelSidik.keputusan(''), gelap: gelap),
        );
        expect(find.text('Tanpa PASS/FAIL'), findsOneWidget);
      });

      testWidgets('kontras teks >= 4,5:1 untuk semua status ($nama)', (
        tester,
      ) async {
        final kode = [
          'draft',
          'menunggu_approval',
          'perlu_revisi',
          'disetujui',
          'PASS',
          'FAIL',
          'overdue',
          'warning',
          'valid',
          'dibatalkan',
        ];
        await tester.pumpWidget(
          aplikasiUji(
            Wrap(
              children: [
                for (final k in kode) StempelSidik(StatusTampil.dariKode(k)),
                StempelSidik.keputusan(null),
                const StempelSidik.teks(
                  teks: '1 FAIL',
                  nada: NadaStempel.gagal,
                  ikon: Icons.cancel_outlined,
                ),
              ],
            ),
            gelap: gelap,
          ),
        );
        expect(pelanggaranKontrasTeks(tester, find.byType(Wrap)), isEmpty);
      });
    }

    testWidgets('.teks: kata dan nada dari pemanggil, ikon wajib', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          const StempelSidik.teks(
            teks: 'Belum tersinkron',
            nada: NadaStempel.awas,
            ikon: Icons.sync_problem,
          ),
        ),
      );
      final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
      expect(find.text('Belum tersinkron'), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);
      expect(_kotak(tester).color, w.isi(IsiBiruAwan.kuning));
    });

    testWidgets('kode asing tampil apa adanya dengan nada netral', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(StempelSidik(StatusTampil.dariKode('kode_baru_server'))),
      );
      expect(find.text('kode_baru_server'), findsOneWidget);
      final w = WarnaBiruAwan.of(tester.element(find.byType(Scaffold)));
      expect(_kotak(tester).color, w.isi(IsiBiruAwan.netral));
    });
  });

  // Pemetaan `StempelSidik.keputusan` dikunci (dartdoc-nya menyebut persis ini).
  // Nada diturunkan dari `StatusTampil.dariKode` APA ADANYA; yang diutamakan
  // di sini: null dan '' tidak pernah hijau, FAIL tidak pernah melunak, dan
  // ejaan lain dari 'PASS'/'FAIL' tidak diam-diam dianggap PASS.
  group('StempelSidik.keputusan: pemetaan dikunci', () {
    test('PASS hijau; FAIL navy pekat (nada gagal, bukan koral)', () {
      final pass = StempelSidik.keputusan('PASS');
      expect(pass.nada, NadaStempel.lulus);
      expect(pass.adalahFail, isFalse);
      final fail = StempelSidik.keputusan('FAIL');
      expect(fail.nada, NadaStempel.gagal);
      expect(fail.adalahFail, isTrue);
    });

    test('null dan "" netral: bukan hijau, bukan FAIL, tanpa status', () {
      for (final k in <String?>[null, '']) {
        final s = StempelSidik.keputusan(k);
        expect(s.nada, NadaStempel.netral, reason: 'keputusan: "$k"');
        expect(s.nada, isNot(NadaStempel.lulus));
        expect(s.adalahFail, isFalse);
        expect(s.status, isNull, reason: 'tidak meminjam status apa pun');
      }
    });

    test('kode status lain mengikuti StatusTampil.dariKode apa adanya', () {
      // Hijau: kode ini BUKAN vonis, tetapi pemetaan yang ada memberinya hijau.
      for (final k in ['disetujui', 'terbit', 'selesai', 'aktif', 'valid']) {
        expect(StempelSidik.keputusan(k).nada, NadaStempel.lulus, reason: k);
      }
      const lain = <String, NadaStempel>{
        'draft': NadaStempel.netral,
        'menunggu_approval': NadaStempel.tunggu,
        'perlu_revisi': NadaStempel.awas,
        'warning': NadaStempel.awas,
        'overdue': NadaStempel.gagal,
        'expired': NadaStempel.gagal,
        'dibatalkan': NadaStempel.gagal,
        'nonaktif': NadaStempel.netral,
      };
      lain.forEach((kode, nada) {
        final s = StempelSidik.keputusan(kode);
        expect(s.nada, nada, reason: kode);
        expect(s.nada, StatusTampil.dariKode(kode).nada, reason: kode);
      });
    });

    test(
      'ejaan lain dari PASS/FAIL = kode asing: netral, tidak pernah hijau',
      () {
        for (final k in ['pass', 'Pass', 'fail', 'Fail', 'LULUS?', ' PASS']) {
          final s = StempelSidik.keputusan(k);
          expect(s.nada, NadaStempel.netral, reason: '"$k"');
          expect(s.adalahFail, isFalse, reason: '"$k"');
          expect(s.status!.mentah, k, reason: 'ditampilkan apa adanya');
        }
      },
    );
  });

  testWidgets('kurangi gerak: statis, tanpa animasi', (tester) async {
    await tester.pumpWidget(
      aplikasiUji(
        kurangiGerak(
          Wrap(
            children: [
              StempelSidik(StatusTampil.dariKode('FAIL')),
              StempelSidik.keputusan(null),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(StempelSidik), findsNWidgets(2));
  });

  group('semantik dan bahasa', () {
    testWidgets('"Status: kata", tanpa aksi ketuk (bukan tombol)', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(StempelSidik(StatusTampil.dariKode('perlu_revisi'))),
      );
      final data = tester
          .getSemantics(find.byType(StempelSidik))
          .getSemanticsData();
      expect(data.label, 'Status: Perlu revisi');
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      semantik.dispose();
    });

    testWidgets('kata mengikuti bahasa (Inggris)', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          StempelSidik(StatusTampil.dariKode('perlu_revisi')),
          bahasa: 'en',
        ),
      );
      expect(find.text('Needs revision'), findsOneWidget);
      await tester.pumpWidget(
        aplikasiUji(StempelSidik.keputusan(null), bahasa: 'en'),
      );
      expect(find.text('No PASS/FAIL'), findsOneWidget);
    });
  });

  group('tangguh', () {
    testWidgets('320 dp x huruf 1,3: kata panjang membungkus, stempel tumbuh', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StempelSidik(StatusTampil.dariKode('expired')),
            StempelSidik(StatusTampil.dariKode('menunggu_approval')),
            StempelSidik(StatusTampil.dariKode('FAIL')),
            StempelSidik.keputusan(null),
          ],
        ),
      );
    });

    testWidgets('huruf besar: ikon ikut membesar, tinggi di atas 30', (
      tester,
    ) async {
      layarUji(tester, lebar: 200, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          Align(
            alignment: Alignment.topLeft,
            child: StempelSidik(StatusTampil.dariKode('expired')),
          ),
          skala: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(StempelSidik)).height,
        greaterThanOrEqualTo(30),
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).size,
        closeTo(14 * 1.3, 0.01),
      );
    });
  });
}
