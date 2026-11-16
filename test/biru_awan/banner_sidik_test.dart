// BannerSidik (L2, REVISI 16 Nov 2026): tanpa koneksi navy 48 sudut 12,
// pembaruan biru muda 56 + tombol navy, peringatan krem sudut 16; Semantics (live region), tombol, kontras,
// cincin fokus, sasaran 48, kurangi gerak (statis), 320 dp x huruf 1,3.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/core/theme/palet_lab.dart';
import 'package:sidik_calibration/widgets/biru_awan/banner_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/toast_sidik.dart';

import '../support/uji_lanjut_biru_awan.dart';

const _koneksi = 'Tanpa koneksi. Data terakhir 08.42';
const _versi = 'Versi baru tersedia';
const _standar = 'Standar acuan Buffer pH 10,01 berakhir dalam 12 hari.';

Widget _p(Widget banner) =>
    Padding(padding: const EdgeInsets.all(16), child: banner);

BoxDecoration _dekor(WidgetTester tester) =>
    tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(BannerSidik),
                matching: find.byType(DecoratedBox),
              ),
            )
            .first
            .decoration
        as BoxDecoration;

Future<void> _fokuskan(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    if (find.byKey(kunciCincinFokusUmpanBalik).evaluate().isNotEmpty) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
}

void main() {
  setUpAll(muatFontUji);

  group('tanpa koneksi', () {
    testWidgets(
      'bilah navy 48 sudut 12, ikon wifi coret 18, teks 14/600 putih',
      (tester) async {
        await pasang(
          tester,
          _p(const BannerSidik.tanpaKoneksi(teks: _koneksi)),
          bergulir: false,
        );
        final r = tester.getRect(find.byType(BannerSidik));
        expect(r.height, 48);
        expect(r.width, 392 - 32);
        final d = _dekor(tester);
        expect(d.color, bahan(tester).tinta);
        expect(d.borderRadius, BorderRadius.circular(12));
        final ikon = tester.widget<Icon>(find.byIcon(Icons.wifi_off_rounded));
        expect(ikon.size, 18);
        expect(ikon.color, bahan(tester).kertas);
        final teks = tester.widget<Text>(find.text(_koneksi)).style!;
        expect(teks.fontSize, 14);
        expect(teks.fontWeight, FontWeight.w600);
        expect(teks.color, bahan(tester).kertas);
        expect(
          tester.getRect(find.byIcon(Icons.wifi_off_rounded)).left - r.left,
          16,
        );
        expect(find.byType(PilAksiSidik), findsNothing);
        expect(find.byType(TombolTutupSidik), findsNothing);
      },
    );

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('kontras teks >= 4,5 ($nama)', (tester) async {
        await pasang(
          tester,
          _p(const BannerSidik.tanpaKoneksi(teks: _koneksi)),
          bergulir: false,
          gelap: gelap,
        );
        expect(
          pelanggaranKontrasTeks(tester, find.byType(BannerSidik)),
          isEmpty,
        );
      });
    }

    testWidgets('live region berlabel teks; tanpa simpul tombol', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pasang(
        tester,
        _p(const BannerSidik.tanpaKoneksi(teks: _koneksi)),
        bergulir: false,
      );
      final d = tester
          .getSemantics(find.bySemanticsLabel(_koneksi))
          .getSemanticsData();
      expect(d.flagsCollection.isLiveRegion, isTrue);
      expect(d.flagsCollection.isButton, isFalse);
      expect(
        find.bySemanticsLabel(RegExp('wifi', caseSensitive: false)),
        findsNothing,
      );
      handle.dispose();
    });
  });

  group('pembaruan', () {
    testWidgets(
      'kotak biru muda 56 sudut 12, teks navy 14/600, tombol Pasang',
      (tester) async {
        var n = 0;
        await pasang(
          tester,
          _p(
            BannerSidik.pembaruan(
              teks: _versi,
              aksi: 'Pasang',
              onAksi: () => n++,
            ),
          ),
          bergulir: false,
        );
        final r = tester.getRect(find.byType(BannerSidik));
        expect(r.height, 56, reason: 'sasaran 48 + 4 + 4');
        final d = _dekor(tester);
        // Bukan bidang langit penuh lagi (REVISI 16 Nov): kabut yang tenang.
        expect(d.color, bahan(tester).biruTipis);
        expect(d.color, isNot(warnaLanjut(tester).isiHero));
        expect(d.borderRadius, BorderRadius.circular(12));
        final teks = tester.widget<Text>(find.text(_versi)).style!;
        expect(teks.fontSize, 14);
        expect(teks.fontWeight, FontWeight.w600);
        expect(teks.color, bahan(tester).tinta);
        expect(
          tester.getSize(find.byType(PilAksiSidik)).height,
          greaterThanOrEqualTo(48),
        );
        final pil = tester.getSize(
          find
              .descendant(
                of: find.byType(PilAksiSidik),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(pil.height, 40, reason: 'gambar 40');
        expect(
          isiKotak(tester, find.byType(PilAksiSidik)),
          bahan(tester).tinta,
          reason: 'tombol navy',
        );
        expect(
          tester.widget<Text>(find.text('Pasang')).style!.color,
          bahan(tester).kertas,
        );
        await tester.tap(find.text('Pasang'));
        expect(n, 1);
        // Ketuk di tepi sasaran 48 (di luar pil 40) juga memasang.
        final sasaran = tester.getRect(find.byType(PilAksiSidik));
        await tester.tapAt(sasaran.topCenter + const Offset(0, 1.5));
        expect(n, 2);
      },
    );

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('kontras teks dan tombol >= 4,5; cincin >= 3:1 ($nama)', (
        tester,
      ) async {
        await pasang(
          tester,
          _p(
            BannerSidik.pembaruan(teks: _versi, aksi: 'Pasang', onAksi: () {}),
          ),
          bergulir: false,
          gelap: gelap,
        );
        expect(
          pelanggaranKontrasTeks(tester, find.byType(BannerSidik)),
          isEmpty,
          reason: 'teks banner ($nama)',
        );
        await _fokuskan(tester);
        final cincinFinder = find.byKey(kunciCincinFokusUmpanBalik);
        expect(cincinFinder, findsOneWidget);
        final cincin = tester.getRect(cincinFinder);
        final sasaran = tester.getRect(find.byType(PilAksiSidik));
        expect(
          sasaran.inflate(0.01).contains(cincin.topLeft) &&
              sasaran.inflate(0.01).contains(cincin.bottomRight),
          isTrue,
          reason: 'cincin di dalam sasaran 48',
        );
        final bentuk =
            (tester
                            .widget<DecoratedBox>(
                              find.descendant(
                                of: cincinFinder,
                                matching: find.byType(DecoratedBox),
                              ),
                            )
                            .decoration
                        as ShapeDecoration)
                    .shape
                as OutlinedBorder;
        expect(bentuk.side.width, AppUkuran.garisTebal);
        expect(
          rasioKontras(bentuk.side.color, bahan(tester).biruTipis),
          greaterThanOrEqualTo(ambangBukanTeks),
          reason: 'cincin/kabut ($nama)',
        );
      });
    }

    testWidgets('Semantics: tombol berlabel, aktif, bisa diketuk; pedoman 48', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pasang(
        tester,
        _p(BannerSidik.pembaruan(teks: _versi, aksi: 'Pasang', onAksi: () {})),
        bergulir: false,
      );
      final d = tester
          .getSemantics(find.bySemanticsLabel('Pasang'))
          .getSemanticsData();
      expect(d.flagsCollection.isButton, isTrue);
      expect(d.hasAction(SemanticsAction.tap), isTrue);
      expect(semantikAktif(d), isTrue);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(_versi))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      await periksaPedomanSentuh(tester);
      handle.dispose();
    });
  });

  group('peringatan data', () {
    testWidgets('kartu krem radius 16, min 56, ikon segitiga amber', (
      tester,
    ) async {
      await pasang(
        tester,
        _p(const BannerSidik.peringatan(teks: _standar)),
        bergulir: false,
      );
      final r = tester.getRect(find.byType(BannerSidik));
      expect(r.height, greaterThanOrEqualTo(56));
      final d = _dekor(tester);
      expect(d.color, PaletLab.kuningTipis);
      expect(d.borderRadius, BorderRadius.circular(16));
      final ikon = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );
      expect(ikon.color, PaletLab.kuningTinta);
      expect(ikon.size, 18);
      final teks = tester.widget<Text>(find.text(_standar)).style!;
      expect(teks.fontSize, 14);
      expect(teks.height, closeTo(20 / 14, 0.001));
      expect(
        find.byType(TombolTutupSidik),
        findsNothing,
        reason: 'tutup opsional',
      );
    });

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('kontras teks >= 4,5 dan ikon >= 3 ($nama)', (tester) async {
        await pasang(
          tester,
          _p(const BannerSidik.peringatan(teks: _standar)),
          bergulir: false,
          gelap: gelap,
        );
        expect(
          pelanggaranKontrasTeks(tester, find.byType(BannerSidik)),
          isEmpty,
        );
        final d = _dekor(tester);
        final ikon = tester.widget<Icon>(
          find.byIcon(Icons.warning_amber_rounded),
        );
        expect(
          rasioKontras(ikon.color!, d.color!),
          greaterThanOrEqualTo(ambangBukanTeks),
        );
      });
    }

    testWidgets('dengan onTutup: tombol tutup 48 memanggilnya', (tester) async {
      var n = 0;
      await pasang(
        tester,
        _p(BannerSidik.peringatan(teks: _standar, onTutup: () => n++)),
        bergulir: false,
      );
      expect(tester.getSize(find.byType(TombolTutupSidik)), const Size(48, 48));
      await tester.tap(find.byType(TombolTutupSidik));
      expect(n, 1);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Tutup'), findsOneWidget);
      handle.dispose();
    });
  });

  group('statis dan 320 dp x huruf 1,3', () {
    testWidgets('banner tidak menganimasikan apa pun (kurangi gerak sama)', (
      tester,
    ) async {
      await pasang(
        tester,
        kurangiGerak(
          _p(
            BannerSidik.pembaruan(teks: _versi, aksi: 'Pasang', onAksi: () {}),
          ),
        ),
        bergulir: false,
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('ketiganya tanpa luapan, tumbuh mengikuti teks ($nama)', (
        tester,
      ) async {
        await pasang(
          tester,
          _p(
            Column(
              children: [
                const BannerSidik.tanpaKoneksi(
                  teks:
                      'Tanpa koneksi. Data terakhir 08.42, perubahan disimpan di HP.',
                ),
                const SizedBox(height: 8),
                BannerSidik.pembaruan(
                  teks: 'Versi baru tersedia untuk dipasang sekarang juga',
                  aksi: 'Pasang',
                  onAksi: () {},
                ),
                const SizedBox(height: 8),
                BannerSidik.peringatan(teks: _standar * 2, onTutup: () {}),
              ],
            ),
          ),
          bergulir: false,
          gelap: gelap,
          skala: 1.3,
          lebar: 320,
        );
        expect(tester.takeException(), isNull);
        for (final e
            in tester
                .widgetList<BannerSidik>(find.byType(BannerSidik))
                .indexed) {
          final r = tester.getRect(find.byType(BannerSidik).at(e.$1));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(320));
          expect(
            r.height,
            greaterThanOrEqualTo(
              e.$2.ragam == RagamBannerSidik.tanpaKoneksi ? 48 : 56,
            ),
          );
        }
        expect(
          tester.getSize(find.byType(PilAksiSidik)).height,
          greaterThanOrEqualTo(48),
        );
      });
    }
  });
}
