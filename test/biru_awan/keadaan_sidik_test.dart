// KeadaanSidik (L2): memuat (kerangka berdenyut terbatas, spinner > 400 ms),
// kosong (kartu putih bergaris + satu aksi) dan galat (kartu merah muda + Coba lagi):
// ukuran, warna, Semantics, kurangi gerak, tanpa animasi tak berujung pada
// kerangka, sasaran 48, 320 dp x huruf 1,3.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/token_umpan_balik_biru_awan.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/hero_langit.dart';
import 'package:sidik_calibration/widgets/biru_awan/keadaan_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_sidik.dart';

import '../support/uji_lanjut_biru_awan.dart';

Widget _p(Widget w) => Padding(padding: const EdgeInsets.all(16), child: w);

/// Opasitas tiap baris kerangka, dari atas.
List<double> _opasitas(WidgetTester tester) => [
  for (final o in tester.widgetList<Opacity>(
    find.descendant(
      of: find.byType(KeadaanMemuat),
      matching: find.byType(Opacity),
    ),
  ))
    o.opacity,
];

void main() {
  setUpAll(muatFontUji);

  group('memuat: kerangka', () {
    testWidgets(
      'baris 64, sudut 12, ubin 40/10, batang 12 (60 %) dan 10 (40 %)',
      (tester) async {
        await pasang(
          tester,
          _p(const KeadaanMemuat.kerangka(baris: 3)),
          bergulir: false,
        );
        expect(find.byType(Opacity), findsNWidgets(3));
        final baris = find.descendant(
          of: find.byType(KeadaanMemuat),
          matching: find.byType(Opacity),
        );
        for (var i = 0; i < 3; i++) {
          final r = tester.getRect(baris.at(i));
          expect(r.height, 64, reason: 'baris $i');
          expect(r.width, 392 - 32);
          if (i > 0) {
            expect(r.top - tester.getRect(baris.at(i - 1)).bottom, 12);
          }
        }
        final kotak = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: baris.first,
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .toList();
        expect(kotak.first.borderRadius, BorderRadius.circular(12));
        expect(kotak.first.color, bahan(tester).kertas);
        expect(
          kotak.map((d) => d.borderRadius),
          contains(BorderRadius.circular(10)),
        );
        expect(
          kotak.map((d) => d.borderRadius),
          contains(BorderRadius.circular(6)),
        );
        expect(
          kotak.map((d) => d.borderRadius),
          contains(BorderRadius.circular(5)),
        );
        final batang = tester
            .widgetList<FractionallySizedBox>(
              find.descendant(
                of: baris.first,
                matching: find.byType(FractionallySizedBox),
              ),
            )
            .toList();
        expect(batang.map((b) => b.widthFactor), [0.6, 0.4]);
      },
    );

    testWidgets(
      'berdenyut: baris pertama redup dulu, baris kedua menyusul 150 ms',
      (tester) async {
        await pasang(
          tester,
          _p(const KeadaanMemuat.kerangka(baris: 2)),
          bergulir: false,
        );
        expect(_opasitas(tester), [1.0, 1.0], reason: 'mulai penuh');
        await tester.pump(
          const Duration(milliseconds: 300),
        ); // seperempat siklus
        final a = _opasitas(tester);
        expect(a[0], lessThan(0.9), reason: 'baris 0 sudah meredup');
        expect(a[1], greaterThan(a[0]), reason: 'baris 1 bergeser 150 ms');
        expect(a[0], greaterThanOrEqualTo(0.45 - 0.001));
        await tester.pump(const Duration(milliseconds: 300)); // setengah siklus
        expect(
          _opasitas(tester)[0],
          closeTo(0.45, 0.02),
          reason: 'puncak redup',
        );
      },
    );

    testWidgets('berhenti setelah 5 siklus: tidak berulang, bisa disettle', (
      tester,
    ) async {
      await pasang(
        tester,
        _p(const KeadaanMemuat.kerangka(baris: 3)),
        bergulir: false,
      );
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle(); // gagal (timeout) bila ada repeat()
      expect(tester.hasRunningAnimations, isFalse);
      expect(_opasitas(tester), everyElement(1.0));
    });

    testWidgets('kurangi gerak: diam sejak awal, tanpa animasi', (
      tester,
    ) async {
      await pasang(
        tester,
        kurangiGerak(_p(const KeadaanMemuat.kerangka(baris: 3))),
        bergulir: false,
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(milliseconds: 600));
      expect(_opasitas(tester), everyElement(1.0));
    });

    testWidgets('dilepas di tengah denyut: tanpa galat', (tester) async {
      await pasang(tester, _p(const KeadaanMemuat.kerangka()), bergulir: false);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });
  });

  group('memuat: spinner hanya bila menunggu > 400 ms', () {
    testWidgets('tidak ada di 399 ms, ada di 401 ms; 36 primer di rel kabut', (
      tester,
    ) async {
      await pasang(tester, _p(const KeadaanMemuat.spinner()), bergulir: false);
      await tester.pump(const Duration(milliseconds: 399));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 2));
      final spin = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spin.strokeWidth, 4);
      expect(spin.color, skemaWarna(tester).primary);
      expect(spin.backgroundColor, bahan(tester).biruTipis);
      expect(spin.value, isNull, reason: 'berputar');
      expect(
        tester.getSize(
          find
              .ancestor(
                of: find.byType(CircularProgressIndicator),
                matching: find.byType(SizedBox),
              )
              .first,
        ),
        const Size(36, 36),
      );
    });

    testWidgets('ruang 36 dipesan sejak awal: tata letak tidak melompat', (
      tester,
    ) async {
      await pasang(tester, _p(const KeadaanMemuat.spinner()), bergulir: false);
      final awal = tester.getSize(find.byType(KeadaanMemuat));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getSize(find.byType(KeadaanMemuat)), awal);
      expect(awal.height, 36);
    });

    testWidgets('kurangi gerak: busur diam (value tetap)', (tester) async {
      await pasang(
        tester,
        kurangiGerak(_p(const KeadaanMemuat.spinner())),
        bergulir: false,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        0.25,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('dilepas sebelum 400 ms: timer dibatalkan', (tester) async {
      await pasang(tester, _p(const KeadaanMemuat.spinner()), bergulir: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Semantics: live region "Memuat" ada sejak awal, label bisa diganti',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pasang(
          tester,
          _p(const KeadaanMemuat.spinner()),
          bergulir: false,
        );
        var d = tester
            .getSemantics(find.bySemanticsLabel('Memuat'))
            .getSemanticsData();
        expect(d.flagsCollection.isLiveRegion, isTrue);
        await tester.pumpWidget(
          aplikasiUji(
            _p(const KeadaanMemuat.kerangka(label: 'Memuat antrean')),
            bergulir: false,
          ),
        );
        d = tester
            .getSemantics(find.bySemanticsLabel('Memuat antrean'))
            .getSemanticsData();
        expect(d.flagsCollection.isLiveRegion, isTrue);
        handle.dispose();
      },
    );
  });

  group('kosong', () {
    testWidgets('kartu putih bergaris sudut 16, min 200, motif skala, judul '
        '20/600', (tester) async {
      var n = 0;
      await pasang(
        tester,
        _p(
          KeadaanKosong(
            judul: 'Belum ada draf',
            isi:
                'Lembar kerja yang kamu simpan lewat Simpan draf menunggu di sini.',
            aksi: 'Mulai kalibrasi',
            onAksi: () => n++,
          ),
        ),
        bergulir: false,
      );
      final r = tester.getRect(find.byType(KeadaanKosong));
      expect(r.height, greaterThanOrEqualTo(200));
      expect(UkuranUmpanBalikBiruAwan.keadaanMin, 200, reason: 'dulu 260');
      expect(r.width, 392 - 32);
      final d =
          tester
                  .widgetList<DecoratedBox>(
                    find.descendant(
                      of: find.byType(KeadaanKosong),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .first
                  .decoration
              as BoxDecoration;
      // REVISI 16 Nov: bukan blok langit penuh; kartu putih + garis halus.
      expect(d.color, bahan(tester).kertas);
      expect(d.color, isNot(warnaLanjut(tester).isiHero));
      expect(d.border!.top.color, bahan(tester).kertasTepi);
      expect(d.borderRadius, BorderRadius.circular(16));
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is PelukisMotifSkala,
        ),
        findsOneWidget,
      );
      final judul = tester.widget<Text>(find.text('Belum ada draf')).style!;
      expect(judul.fontSize, 20);
      expect(judul.fontWeight, FontWeight.w600);
      expect(judul.color, bahan(tester).tinta);
      expect(
        tester.getSize(find.byType(TombolSidik)).height,
        48,
        reason: 'satu aksi navy, sasaran 48',
      );
      expect(
        tester.widget<TombolSidik>(find.byType(TombolSidik)).ragam,
        RagamTombolSidik.tegas,
      );
      await tester.tap(find.text('Mulai kalibrasi'));
      expect(n, 1);
    });

    testWidgets('tanpa aksi: tanpa tombol', (tester) async {
      await pasang(
        tester,
        _p(const KeadaanKosong(judul: 'Kosong', isi: 'Tidak ada apa pun.')),
        bergulir: false,
      );
      expect(find.byType(TombolSidik), findsNothing);
    });

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('kontras teks di atas kartu putih >= 4,5 ($nama)', (
        tester,
      ) async {
        await pasang(
          tester,
          _p(
            KeadaanKosong(
              judul: 'Belum ada draf',
              isi: 'Lembar kerja menunggu di sini.',
              aksi: 'Mulai kalibrasi',
              onAksi: () {},
            ),
          ),
          bergulir: false,
          gelap: gelap,
        );
        expect(
          pelanggaranKontrasTeks(tester, find.byType(KeadaanKosong)),
          isEmpty,
        );
      });
    }

    testWidgets('Semantics: satu simpul "judul. isi" dan tombol berlabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pasang(
        tester,
        _p(
          KeadaanKosong(
            judul: 'Belum ada draf',
            isi: 'Menunggu di sini.',
            aksi: 'Mulai kalibrasi',
            onAksi: () {},
          ),
        ),
        bergulir: false,
      );
      expect(
        find.bySemanticsLabel('Belum ada draf. Menunggu di sini.'),
        findsOneWidget,
      );
      final tombol = tester
          .getSemantics(find.bySemanticsLabel('Mulai kalibrasi'))
          .getSemanticsData();
      expect(tombol.flagsCollection.isButton, isTrue);
      expect(tombol.hasAction(SemanticsAction.tap), isTrue);
      await periksaPedomanSentuh(tester);
      handle.dispose();
    });
  });

  group('galat', () {
    testWidgets('kartu merah muda 16, ubin ikon 48/12, pesan apa adanya', (
      tester,
    ) async {
      var n = 0;
      const server = 'Server mengembalikan 503: antrean sedang dipindah.';
      await pasang(
        tester,
        _p(
          KeadaanGalat(
            judul: 'Gagal memuat antrean',
            isi: server,
            aksi: 'Coba lagi',
            onAksi: () => n++,
          ),
        ),
        bergulir: false,
      );
      final r = tester.getRect(find.byType(KeadaanGalat));
      expect(r.height, greaterThanOrEqualTo(200));
      final dekor = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(KeadaanGalat),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(dekor.first.color, warna(tester).isi(IsiBiruAwan.koralTipis));
      expect(dekor.first.borderRadius, BorderRadius.circular(16));
      final ubin = dekor.firstWhere(
        (d) => d.borderRadius == BorderRadius.circular(12),
      );
      expect(ubin.color, warna(tester).isi(IsiBiruAwan.koral));
      expect(
        tester.getSize(
          find
              .ancestor(
                of: find.byIcon(Icons.warning_amber_rounded),
                matching: find.byType(SizedBox),
              )
              .first,
        ),
        const Size(48, 48),
      );
      expect(find.text(server), findsOneWidget, reason: 'pesan server utuh');
      expect(
        tester.widget<TombolSidik>(find.byType(TombolSidik)).ragam,
        RagamTombolSidik.tegas,
      );
      expect(tester.getSize(find.byType(TombolSidik)).height, 48);
      await tester.tap(find.text('Coba lagi'));
      expect(n, 1);
    });

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('kontras teks di atas koral tipis >= 4,5 ($nama)', (
        tester,
      ) async {
        await pasang(
          tester,
          _p(
            KeadaanGalat(
              judul: 'Gagal memuat antrean',
              isi: 'Periksa koneksi lalu coba lagi.',
              aksi: 'Coba lagi',
              onAksi: () {},
            ),
          ),
          bergulir: false,
          gelap: gelap,
        );
        expect(
          pelanggaranKontrasTeks(tester, find.byType(KeadaanGalat)),
          isEmpty,
        );
      });
    }

    testWidgets('Semantics: live region "judul. isi", tombol berlabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pasang(
        tester,
        _p(
          KeadaanGalat(
            judul: 'Gagal memuat antrean',
            isi: 'Periksa koneksi.',
            aksi: 'Coba lagi',
            onAksi: () {},
          ),
        ),
        bergulir: false,
      );
      final teks = tester
          .getSemantics(
            find.bySemanticsLabel('Gagal memuat antrean. Periksa koneksi.'),
          )
          .getSemanticsData();
      expect(teks.flagsCollection.isLiveRegion, isTrue);
      expect(teks.flagsCollection.isButton, isFalse);
      final tombol = tester
          .getSemantics(find.bySemanticsLabel('Coba lagi'))
          .getSemanticsData();
      expect(tombol.flagsCollection.isButton, isTrue);
      expect(semantikAktif(tombol), isTrue);
      await periksaPedomanSentuh(tester);
      handle.dispose();
    });

    testWidgets('tanpa aksi: tanpa tombol', (tester) async {
      await pasang(
        tester,
        _p(const KeadaanGalat(judul: 'Galat', isi: 'Tidak ada tombol.')),
        bergulir: false,
      );
      expect(find.byType(TombolSidik), findsNothing);
    });
  });

  group('statis, 320 dp x huruf 1,3', () {
    testWidgets('kosong dan galat tidak menganimasikan apa pun', (
      tester,
    ) async {
      await pasang(
        tester,
        _p(
          Column(
            children: [
              KeadaanKosong(
                judul: 'Belum ada draf',
                isi: 'Menunggu.',
                aksi: 'Mulai',
                onAksi: () {},
              ),
              KeadaanGalat(
                judul: 'Gagal',
                isi: 'Coba lagi nanti.',
                aksi: 'Coba lagi',
                onAksi: () {},
              ),
            ],
          ),
        ),
        bergulir: false,
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.hasRunningAnimations, isFalse);
    });

    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('semua keadaan tanpa luapan ($nama)', (tester) async {
        await periksaSkala13Satu(tester, gelap);
      });
    }
  });
}

/// Semua keadaan di 320 dp x huruf 1,3 pada satu tema (teks panjang).
Future<void> periksaSkala13Satu(WidgetTester tester, bool gelap) async {
  layarUji(tester, lebar: 320, tinggi: 2400);
  await tester.pumpWidget(
    aplikasiUji(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            KeadaanKosong(
              judul: 'Belum ada lembar kerja yang tersimpan',
              isi:
                  'Lembar kerja yang kamu simpan lewat Simpan draf menunggu di '
                  'sini sampai dikirim untuk approval.',
              aksi: 'Mulai kalibrasi baru',
              onAksi: () {},
            ),
            const SizedBox(height: 12),
            KeadaanGalat(
              judul: 'Gagal memuat antrean approval',
              isi:
                  'Server menolak permintaan karena token sudah habis. '
                  'Masuk lagi lalu coba lagi.',
              aksi: 'Coba lagi',
              onAksi: () {},
            ),
            const SizedBox(height: 12),
            const KeadaanMemuat.kerangka(baris: 3),
            const SizedBox(height: 12),
            const KeadaanMemuat.spinner(),
          ],
        ),
      ),
      bergulir: false,
      gelap: gelap,
      skala: 1.3,
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
  for (final f in [find.byType(KeadaanKosong), find.byType(KeadaanGalat)]) {
    final r = tester.getRect(f);
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(320));
  }
  for (final t
      in tester.widgetList<TombolSidik>(find.byType(TombolSidik)).indexed) {
    expect(
      tester.getSize(find.byType(TombolSidik).at(t.$1)).height,
      greaterThanOrEqualTo(48),
    );
  }
}
