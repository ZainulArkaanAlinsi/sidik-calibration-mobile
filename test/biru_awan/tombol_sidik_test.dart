// TombolSidik (utama 56; tegas, sekunder, teks, bahaya 48; pil).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_sidik.dart';

import '../support/uji_biru_awan.dart';

Type _jenis(RagamTombolSidik r) => switch (r) {
  RagamTombolSidik.sekunder => OutlinedButton,
  RagamTombolSidik.teks => TextButton,
  _ => FilledButton,
};

ButtonStyle _gaya(WidgetTester tester, RagamTombolSidik r, {String? label}) {
  final f = label == null
      ? find.byType(_jenis(r))
      : find.widgetWithText(_jenis(r), label);
  return switch (r) {
    RagamTombolSidik.sekunder => tester.widget<OutlinedButton>(f).style!,
    RagamTombolSidik.teks => tester.widget<TextButton>(f).style!,
    _ => tester.widget<FilledButton>(f).style!,
  };
}

void main() {
  setUpAll(muatFontUji);

  group('ukuran dan bentuk', () {
    for (final r in RagamTombolSidik.values) {
      testWidgets('${r.name}: tinggi ${r == RagamTombolSidik.utama ? 56 : 48}, '
          'pil', (tester) async {
        layarUji(tester, lebar: 360, tinggi: 640);
        await tester.pumpWidget(
          aplikasiUji(
            Padding(
              padding: const EdgeInsets.all(16),
              child: TombolSidik(label: 'Simpan', onPressed: () {}, ragam: r),
            ),
          ),
        );
        final ukuran = tester.getSize(find.byType(_jenis(r)));
        expect(ukuran.height, r == RagamTombolSidik.utama ? 56 : 48);
        if (r == RagamTombolSidik.utama) {
          expect(ukuran.width, 360 - 32, reason: 'utama selebar induk');
        } else {
          expect(ukuran.width, lessThan(200), reason: '$r tidak penuh');
        }
        final bentuk = _gaya(tester, r).shape!.resolve({})!;
        expect(
          (bentuk as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(BentukBiruAwan.pil),
        );
      });
    }

    testWidgets('lebarPenuh mengganti bawaan ragam', (tester) async {
      layarUji(tester, lebar: 360, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TombolSidik(
                  label: 'Ringkasan',
                  onPressed: () {},
                  ragam: RagamTombolSidik.tegas,
                  lebarPenuh: true,
                ),
                TombolSidik(
                  label: 'Kecil',
                  onPressed: () {},
                  lebarPenuh: false,
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FilledButton).first).width, 360 - 32);
      expect(
        tester.getSize(find.byType(FilledButton).last).width,
        lessThan(200),
      );
    });
  });

  group('warna dari tema', () {
    for (final gelap in [false, true]) {
      testWidgets('isi dan tinta tiap ragam (${gelap ? 'gelap' : 'terang'})', (
        tester,
      ) async {
        await tester.pumpWidget(
          aplikasiUji(
            Column(
              children: [
                for (final r in RagamTombolSidik.values)
                  TombolSidik(label: r.name, onPressed: () {}, ragam: r),
              ],
            ),
            gelap: gelap,
          ),
        );
        final ctx = tester.element(find.byType(Scaffold));
        final m = SidikMaterial.of(ctx);
        final s = Theme.of(ctx).colorScheme;
        Color? isi(RagamTombolSidik r) =>
            _gaya(tester, r, label: r.name).backgroundColor!.resolve({});
        Color? tinta(RagamTombolSidik r) =>
            _gaya(tester, r, label: r.name).foregroundColor!.resolve({});

        expect(isi(RagamTombolSidik.utama), s.primary);
        expect(tinta(RagamTombolSidik.utama), s.onPrimary);
        expect(isi(RagamTombolSidik.tegas), m.tinta);
        expect(tinta(RagamTombolSidik.tegas), m.kertas);
        expect(isi(RagamTombolSidik.sekunder), m.kertas);
        expect(tinta(RagamTombolSidik.sekunder), m.tinta);
        expect(
          _gaya(
            tester,
            RagamTombolSidik.sekunder,
            label: 'sekunder',
          ).side!.resolve({})!.color,
          m.garisTegas,
          reason: 'tepi sekunder = tepi kontrol 3:1, bukan #C5D5E6',
        );
        expect(isi(RagamTombolSidik.teks), Colors.transparent);
        expect(tinta(RagamTombolSidik.teks), m.biruTinta);
        expect(isi(RagamTombolSidik.bahaya), s.error);
        expect(tinta(RagamTombolSidik.bahaya), s.onError);
      });

      testWidgets('kontras teks >= 4,5:1: aktif dan mati, semua ragam '
          '(${gelap ? 'gelap' : 'terang'})', (tester) async {
        for (final aktif in [true, false]) {
          await tester.pumpWidget(
            aplikasiUji(
              Column(
                children: [
                  for (final r in RagamTombolSidik.values)
                    TombolSidik(
                      label: r.name,
                      onPressed: aktif ? () {} : null,
                      ragam: r,
                    ),
                ],
              ),
              gelap: gelap,
            ),
          );
          await tester.pumpAndSettle();
          for (final r in RagamTombolSidik.values) {
            expect(
              pelanggaranKontrasTeks(tester, find.byType(_jenis(r)).first),
              isEmpty,
              reason: '${r.name} ${aktif ? 'aktif' : 'mati'}',
            );
          }
        }
      });
    }

    testWidgets('mati: isi, tinta, dan tepi dari token tombol mati '
        '(terang dan gelap)', (tester) async {
      for (final gelap in [false, true]) {
        await tester.pumpWidget(
          aplikasiUji(
            Column(
              children: [
                for (final r in RagamTombolSidik.values)
                  TombolSidik(label: r.name, onPressed: null, ragam: r),
              ],
            ),
            gelap: gelap,
          ),
        );
        final ctx = tester.element(find.byType(Scaffold));
        final m = SidikMaterial.of(ctx);
        final w = WarnaBiruAwan.of(ctx);
        for (final r in RagamTombolSidik.values) {
          final gaya = _gaya(tester, r, label: r.name);
          final isi = switch (r) {
            RagamTombolSidik.sekunder => m.kertas,
            RagamTombolSidik.teks => Colors.transparent,
            _ => w.isiTombolMati,
          };
          expect(gaya.backgroundColor!.resolve({}), isi, reason: r.name);
          expect(
            gaya.foregroundColor!.resolve({}),
            w.tintaTombolMati,
            reason: r.name,
          );
          expect(
            gaya.side!.resolve({}),
            r == RagamTombolSidik.sekunder
                ? BorderSide(color: m.kertasTepi, width: AppUkuran.garis)
                : BorderSide.none,
            reason: '${r.name}: tepi mati',
          );
        }
      }
    });

    testWidgets('tepi sekunder yang TAMPIL (Material) mengikuti keadaan: '
        'aktif = garisTegas, mati = kertasTepi', (tester) async {
      for (final aktif in [true, false]) {
        await tester.pumpWidget(
          aplikasiUji(
            TombolSidik(
              label: 'Sekunder',
              ragam: RagamTombolSidik.sekunder,
              onPressed: aktif ? () {} : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final m = SidikMaterial.of(tester.element(find.byType(Scaffold)));
        final bahan = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(OutlinedButton),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(
          (bahan.shape! as RoundedRectangleBorder).side.color,
          aktif ? m.garisTegas : m.kertasTepi,
          reason: 'tema OutlinedButton tidak boleh menimpa tepi mati',
        );
      }
    });
  });

  // Cincin fokus papan ketik. Digambar di LUAR tombol: di dalam bentuk, cincin
  // navy di atas isi navy (tegas) tidak terlihat (1,00:1), dan di atas isi
  // utama/bahaya cuma 1,6 sampai 3,0:1. Di luar dan terpisah 2 dp, yang
  // bersebelahan dengan cincin adalah latar halaman, bukan isi tombol.
  group('cincin fokus: di luar isi, kontras >= 3:1 terhadap latar', () {
    const ambang = 3.0;
    const jarak = UkuranKomponenBiruAwan.jarakCincinFokus;

    for (final gelap in [false, true]) {
      for (final r in RagamTombolSidik.values) {
        testWidgets('${r.name} (${gelap ? 'gelap' : 'terang'})', (
          tester,
        ) async {
          await tester.pumpWidget(
            aplikasiUji(
              Padding(
                padding: const EdgeInsets.all(24),
                child: TombolSidik(
                  label: 'Simpan',
                  onPressed: () {},
                  ragam: r,
                  lebarPenuh: false,
                ),
              ),
              gelap: gelap,
            ),
          );
          expect(
            find.byKey(kunciCincinFokusTombol),
            findsNothing,
            reason: 'tanpa fokus tidak ada cincin',
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(find.byKey(kunciCincinFokusTombol), findsOneWidget);

          // Geometri: cincin menyelimuti tombol dengan ruang `jarak` di antara
          // tepi tombol dan sisi dalam cincin; isi tombol tidak ikut tertimpa.
          final tombol = tester.getRect(find.byType(_jenis(r)));
          final cincin = tester.getRect(find.byKey(kunciCincinFokusTombol));
          expect(
            cincin.deflate(AppUkuran.garisTebal),
            tombol.inflate(jarak),
            reason: 'sisi dalam cincin harus $jarak dp di luar tepi tombol',
          );
          final hias = tester.widget<DecoratedBox>(
            find.descendant(
              of: find.byKey(kunciCincinFokusTombol),
              matching: find.byType(DecoratedBox),
            ),
          );
          final dekor = hias.decoration as BoxDecoration;
          final garis = dekor.border!.top;
          expect(garis.width, AppUkuran.garisTebal);
          expect(dekor.borderRadius, BorderRadius.circular(BentukBiruAwan.pil));

          // Warna: dari token, dan >= 3:1 terhadap latar halaman (meja) maupun
          // kartu (kertas), tempat tombol bisa duduk.
          final ctx = tester.element(find.byType(Scaffold));
          final m = SidikMaterial.of(ctx);
          final latar = <String, Color>{
            'meja': m.meja,
            'kertas': m.kertas,
            'scaffold': Theme.of(ctx).scaffoldBackgroundColor,
          };
          latar.forEach((nama, warna) {
            expect(
              rasioKontras(garis.color, warna),
              greaterThanOrEqualTo(ambang),
              reason: 'cincin/$nama ${r.name}',
            );
          });
          expect(garis.color, m.tinta, reason: 'cincin = token tinta');
        });
      }
    }

    testWidgets('mati atau sibuk: tidak bisa difokuskan, tanpa cincin', (
      tester,
    ) async {
      for (final (mati, sibuk) in [(true, false), (false, true)]) {
        await tester.pumpWidget(
          aplikasiUji(
            TombolSidik(
              key: ValueKey('$mati-$sibuk'),
              label: 'Simpan',
              onPressed: mati ? null : () {},
              sibuk: sibuk,
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(find.byKey(kunciCincinFokusTombol), findsNothing);
      }
    });

    testWidgets('cincin tidak mengubah ukuran tombol', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          Padding(
            padding: const EdgeInsets.all(24),
            child: TombolSidik(label: 'Simpan', onPressed: () {}),
          ),
        ),
      );
      final sebelum = tester.getSize(find.byType(FilledButton));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.byKey(kunciCincinFokusTombol), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)), sebelum);
    });
  });

  group('perilaku', () {
    testWidgets('ketuk memanggil onPressed (semua ragam); ikon opsional', (
      tester,
    ) async {
      for (final r in RagamTombolSidik.values) {
        var n = 0;
        await tester.pumpWidget(
          aplikasiUji(
            TombolSidik(
              label: 'Kirim ${r.name}',
              ikon: Icons.send,
              onPressed: () => n++,
              ragam: r,
            ),
          ),
        );
        expect(find.byIcon(Icons.send), findsOneWidget);
        await tester.tap(find.text('Kirim ${r.name}'));
        expect(n, 1, reason: r.name);
      }
    });

    testWidgets('mati: ketukan diabaikan; alasan tampil DI ATAS tombol', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          const TombolSidik(
            label: 'Kirim ke admin',
            onPressed: null,
            alasanMati: 'Isi 2 sel wajib dulu.',
          ),
        ),
      );
      final alasan = tester.getRect(find.text('Isi 2 sel wajib dulu.'));
      final tombol = tester.getRect(find.byType(FilledButton));
      expect(alasan.bottom, lessThanOrEqualTo(tombol.top));
      await tester.tap(find.text('Kirim ke admin'), warnIfMissed: false);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'tidak ada callback yang bisa terpanggil',
      );
      // Pembaca layar: tetap tombol, tetapi mati dan tanpa aksi ketuk.
      final data = tester
          .getSemantics(find.byType(FilledButton))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(semantikAktif(data), isFalse, reason: 'mati, bukan tanpa keadaan');
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      semantik.dispose();
    });

    testWidgets('aktif: alasan tidak tampil', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          TombolSidik(
            label: 'Kirim',
            onPressed: () {},
            alasanMati: 'Isi 2 sel wajib dulu.',
          ),
        ),
      );
      expect(find.text('Isi 2 sel wajib dulu.'), findsNothing);
    });

    testWidgets('sibuk: pemutar, ketukan ditolak, pembaca layar diberi tahu', (
      tester,
    ) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          TombolSidik(label: 'Simpan', onPressed: () => n++, sibuk: true),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Simpan'), warnIfMissed: false);
      expect(n, 0);
      final data = tester
          .getSemantics(find.byType(FilledButton))
          .getSemanticsData();
      expect(data.label, 'Simpan, sedang diproses');
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      semantik.dispose();
    });

    testWidgets('kurangi gerak: pemutar diam (busur tetap)', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          kurangiGerak(
            TombolSidik(label: 'Simpan', onPressed: () {}, sibuk: true),
          ),
        ),
      );
      final p = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(p.value, isNotNull, reason: 'tanpa value = berputar terus');
    });

    testWidgets('bahasa Inggris: keterangan sibuk ikut bahasa', (tester) async {
      final semantik = tester.ensureSemantics();
      await tester.pumpWidget(
        aplikasiUji(
          TombolSidik(label: 'Save', onPressed: () {}, sibuk: true),
          bahasa: 'en',
        ),
      );
      expect(
        tester.getSemantics(find.byType(FilledButton)).getSemanticsData().label,
        'Save, in progress',
      );
      semantik.dispose();
    });

    testWidgets('semantik: label dan aksi ketuk di satu node', (tester) async {
      final semantik = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          TombolSidik(
            label: 'Simpan draf',
            ragam: RagamTombolSidik.sekunder,
            onPressed: () => n++,
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byType(OutlinedButton))
          .getSemanticsData();
      expect(data.label, 'Simpan draf');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      tester.semantics.tap(find.semantics.byLabel('Simpan draf'));
      expect(n, 1);
      semantik.dispose();
    });
  });

  group('tangguh', () {
    testWidgets('320 dp x huruf 1,3: label panjang membungkus, tombol tumbuh', (
      tester,
    ) async {
      await periksaSkala13(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in RagamTombolSidik.values) ...[
              TombolSidik(
                label:
                    'Kirim lembar kerja ke admin untuk diperiksa dan disetujui',
                ikon: Icons.send,
                onPressed: () {},
                ragam: r,
                lebarPenuh: true,
              ),
              TombolSidik(
                label: 'Sibuk',
                onPressed: () {},
                ragam: r,
                sibuk: true,
                lebarPenuh: true,
              ),
              TombolSidik(
                label: 'Mati',
                onPressed: null,
                ragam: r,
                alasanMati: 'Isi 2 sel wajib dulu sebelum mengirim.',
                lebarPenuh: true,
              ),
            ],
          ],
        ),
        tinggi: 3000,
      );
    });

    testWidgets('tinggi tumbuh melebihi minimum bila label membungkus', (
      tester,
    ) async {
      layarUji(tester, lebar: 320, tinggi: 640);
      await tester.pumpWidget(
        aplikasiUji(
          Padding(
            padding: const EdgeInsets.all(16),
            child: TombolSidik(
              label:
                  'Kirim lembar kerja ke admin untuk diperiksa dan disetujui',
              onPressed: () {},
            ),
          ),
          skala: 1.3,
        ),
      );
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThan(56));
    });

    for (final gelap in [false, true]) {
      testWidgets('pedoman: sasaran >= 48 dp dan berlabel '
          '(${gelap ? 'gelap' : 'terang'})', (tester) async {
        final semantik = tester.ensureSemantics();
        await tester.pumpWidget(
          aplikasiUji(
            Column(
              children: [
                for (final r in RagamTombolSidik.values)
                  TombolSidik(
                    label: 'Aksi ${r.name}',
                    onPressed: () {},
                    ragam: r,
                  ),
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
