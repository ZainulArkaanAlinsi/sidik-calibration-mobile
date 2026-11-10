import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';
import 'package:sidik_calibration/widgets/dekorasi_isian_wajib.dart';

/// Konvensi warna isian (lihat `dekorasi_isian_wajib.dart`).
///
/// Yang dikunci: warna tiap keadaan di tema terang DAN gelap, tanda `*` supaya
/// warna bukan satu-satunya penanda, kontras teks, legenda, dan bahwa di luar
/// `WarnaIsianScope` (layar baca-saja) isian tampil biasa.
void main() {
  Widget bungkus(Widget anak, {Brightness tema = Brightness.light}) =>
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('id'),
          theme: ThemeData(brightness: tema),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: anak)),
        ),
      );

  /// Satu TextField yang dekorasinya murni dari helper.
  Widget kotak({
    required bool wajib,
    required bool terisi,
    bool otomatis = false,
    bool scope = true,
  }) {
    final isi = Builder(
      builder: (context) => TextField(
        decoration: dekorasiIsian(
          context,
          wajib: wajib,
          terisi: terisi,
          otomatis: otomatis,
          base: const InputDecoration(
            labelText: 'Suhu',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );

    return scope ? WarnaIsianScope(child: isi) : isi;
  }

  InputDecoration dekorasiTerpasang(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).decoration!;

  double kontras(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final terang = la > lb ? la : lb;
    final gelap = la > lb ? lb : la;

    return (terang + 0.05) / (gelap + 0.05);
  }

  group('warna per keadaan (tema terang)', () {
    testWidgets('wajib & kosong: oranye lembut + tepi tegas + tanda *', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(kotak(wajib: true, terisi: false)));

      final d = dekorasiTerpasang(tester);
      final p = PaletIsian.untuk(Brightness.light, StatusIsian.wajibKosong)!;

      expect(d.filled, isTrue);
      expect(d.fillColor, p.latar);
      expect((d.enabledBorder as OutlineInputBorder).borderSide.color, p.tepi);
      expect(
        (d.enabledBorder as OutlineInputBorder).borderSide.width,
        greaterThanOrEqualTo(2),
        reason: 'tepi tegas, bukan garis tipis',
      );
      expect(d.labelText, 'Suhu *');
    });

    testWidgets('wajib & terisi: hijau sangat lembut', (tester) async {
      await tester.pumpWidget(bungkus(kotak(wajib: true, terisi: true)));

      final d = dekorasiTerpasang(tester);
      final p = PaletIsian.untuk(Brightness.light, StatusIsian.wajibTerisi)!;

      expect(d.fillColor, p.latar);
      expect(d.labelText, 'Suhu *');
      expect(p.latar.g, greaterThan(p.latar.r), reason: 'condong hijau');
    });

    testWidgets('opsional: netral, tanpa warna dan tanpa bintang', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(kotak(wajib: false, terisi: false)));

      final d = dekorasiTerpasang(tester);
      expect(d.filled, isNull);
      expect(d.fillColor, isNull);
      expect(d.enabledBorder, isNull);
      expect(d.labelText, 'Suhu');

      // Opsional yang terisi pun tetap netral.
      await tester.pumpWidget(bungkus(kotak(wajib: false, terisi: true)));
      expect(dekorasiTerpasang(tester).fillColor, isNull);
    });

    testWidgets('otomatis: abu kebiruan, tanpa bintang wajib', (tester) async {
      await tester.pumpWidget(
        bungkus(kotak(wajib: false, terisi: false, otomatis: true)),
      );

      final d = dekorasiTerpasang(tester);
      final p = PaletIsian.untuk(Brightness.light, StatusIsian.otomatis)!;

      expect(d.fillColor, p.latar);
      expect(d.labelText, 'Suhu');
      expect(p.latar.b, greaterThan(p.latar.r), reason: 'condong biru');
    });

    testWidgets('keempat keadaan saling beda warna latar', (tester) async {
      final latar = {
        for (final s in StatusIsian.values)
          if (PaletIsian.untuk(Brightness.light, s) case final p?) p.latar,
      };
      expect(latar, hasLength(3));
    });
  });

  group('tema gelap', () {
    testWidgets('memakai token gelap untuk tiap keadaan', (tester) async {
      Future<InputDecoration> ambil(
        bool wajib,
        bool terisi, {
        bool otomatis = false,
      }) async {
        await tester.pumpWidget(
          bungkus(
            kotak(wajib: wajib, terisi: terisi, otomatis: otomatis),
            tema: Brightness.dark,
          ),
        );

        return dekorasiTerpasang(tester);
      }

      expect(
        (await ambil(true, false)).fillColor,
        PaletIsian.untuk(Brightness.dark, StatusIsian.wajibKosong)!.latar,
      );
      expect(
        (await ambil(true, true)).fillColor,
        PaletIsian.untuk(Brightness.dark, StatusIsian.wajibTerisi)!.latar,
      );
      expect((await ambil(false, false)).fillColor, isNull);
      expect(
        (await ambil(false, false, otomatis: true)).fillColor,
        PaletIsian.untuk(Brightness.dark, StatusIsian.otomatis)!.latar,
      );

      expect(
        PaletIsian.untuk(Brightness.dark, StatusIsian.wajibKosong)!.latar,
        isNot(
          PaletIsian.untuk(Brightness.light, StatusIsian.wajibKosong)!.latar,
        ),
      );
    });

    test('kontras teks vs latar >= 4,5 di kedua tema, semua keadaan', () {
      for (final tema in Brightness.values) {
        final teks = ThemeData(brightness: tema).colorScheme.onSurface;
        for (final s in StatusIsian.values) {
          final p = PaletIsian.untuk(tema, s);
          if (p == null) continue;
          expect(
            kontras(teks, p.latar),
            greaterThanOrEqualTo(4.5),
            reason: '$s di $tema',
          );
        }
      }
    });
  });

  testWidgets('di luar WarnaIsianScope (layar baca-saja) tampil biasa', (
    tester,
  ) async {
    await tester.pumpWidget(
      bungkus(kotak(wajib: true, terisi: false, scope: false)),
    );

    final d = dekorasiTerpasang(tester);
    expect(d.fillColor, isNull);
    expect(d.enabledBorder, isNull);
    expect(d.labelText, 'Suhu', reason: 'tanpa bintang juga');
  });

  group('baris centang (standar tercetak)', () {
    Widget centang({required bool scope, required bool nilai}) {
      final isi = Builder(
        builder: (context) => bungkusKotakIsian(
          context,
          wajib: true,
          terisi: nilai,
          anak: CheckboxListTile(
            value: nilai,
            onChanged: (_) {},
            title: const Text('Buffer 7'),
          ),
        ),
      );

      return scope ? WarnaIsianScope(child: isi) : isi;
    }

    Color? latarKotak(WidgetTester tester) => tester
        .widgetList<Material>(
          find.ancestor(
            of: find.byType(CheckboxListTile),
            matching: find.byType(Material),
          ),
        )
        .map((m) => m.color)
        .firstWhere(
          (c) =>
              PaletIsian.untuk(
                    Brightness.light,
                    StatusIsian.wajibKosong,
                  )!.latar ==
                  c ||
              PaletIsian.untuk(
                    Brightness.light,
                    StatusIsian.wajibTerisi,
                  )!.latar ==
                  c,
          orElse: () => null,
        );

    testWidgets('tercentang hijau, tidak tercentang oranye (tanpa assertion)', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(centang(scope: true, nilai: true)));
      expect(tester.takeException(), isNull);
      expect(
        latarKotak(tester),
        PaletIsian.untuk(Brightness.light, StatusIsian.wajibTerisi)!.latar,
      );

      await tester.pumpWidget(bungkus(centang(scope: true, nilai: false)));
      expect(tester.takeException(), isNull);
      expect(
        latarKotak(tester),
        PaletIsian.untuk(Brightness.light, StatusIsian.wajibKosong)!.latar,
      );
    });

    testWidgets('tanpa scope: tidak diwarnai', (tester) async {
      await tester.pumpWidget(bungkus(centang(scope: false, nilai: false)));
      expect(latarKotak(tester), isNull);
    });
  });

  group('legenda', () {
    testWidgets('baris ringkas tampil + info membuka penjelasan (id)', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(const LegendaWarnaIsian()));

      expect(find.text('Wajib'), findsOneWidget);
      expect(find.text('Terisi'), findsOneWidget);
      expect(find.text('Opsional'), findsOneWidget);
      expect(find.text('Otomatis'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('tombol-legenda-warna-isian')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Arti warna isian'), findsOneWidget);
      expect(find.textContaining('Wajib, masih kosong'), findsOneWidget);
      expect(find.textContaining('Wajib, sudah terisi'), findsOneWidget);
      expect(find.textContaining('Opsional (tanpa warna)'), findsOneWidget);
      expect(find.textContaining('Otomatis (abu kebiruan)'), findsOneWidget);
    });

    testWidgets('teks bahasa Inggris juga ada', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: LegendaWarnaIsian()),
          ),
        ),
      );

      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Automatic'), findsOneWidget);
    });
  });

  group('terpasang di tabel (kolom suhu wajib)', () {
    LembarKerja conductivity({required bool suhuWajib}) =>
        LembarKerja.fromJson({
          'kode_dokumen': 'SIDIK-IK-CAL-0507_Rev.6',
          'judul': 'Calibration Worksheet - Conductivity Meter',
          'untuk': 'teknisi',
          'jumlah_pengulangan': 2,
          'satuan': null,
          'satuan_campuran': true,
          'suhu_wajib': suhuWajib,
          'satuan_suhu': '°C',
          'bagian': [
            {
              'kode': 'hasil',
              'judul': 'CALIBRATION RESULT',
              'tabel': [
                {
                  'tahap': 'sesudah_adjustment',
                  'judul': 'After adjustment Reading',
                  'kolom': [
                    {'kode': 'pembacaan', 'label': 'nilai', 'tipe': 'angka'},
                    {'kode': 'suhu', 'label': '°C', 'tipe': 'angka'},
                  ],
                  'pengulangan': [1, 2],
                  'baris': [
                    {
                      'titik_ukur': 25,
                      'label': '25',
                      'satuan': 'µS/cm',
                      'resolusi': 0.1,
                      'desimal': 1,
                    },
                  ],
                },
              ],
            },
          ],
        });

    Future<LembarKerjaState> pasang(
      WidgetTester tester, {
      required bool suhuWajib,
      bool scope = true,
      Brightness tema = Brightness.light,
    }) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final bentuk = conductivity(suhuWajib: suhuWajib);
      final isian = LembarKerjaState(
        bentuk: bentuk,
        clientRequestId: 'tes-warna',
      );
      addTearDown(isian.dispose);

      final tabel = LembarKerjaTabel(
        tabel: bentuk.bagian.first.tabel.first,
        isian: isian,
        onBerubah: () {},
        pindaiAktif: false,
      );

      await tester.pumpWidget(
        bungkus(scope ? WarnaIsianScope(child: tabel) : tabel, tema: tema),
      );
      await tester.pump();

      return isian;
    }

    InputDecoration dekorasiSel(WidgetTester tester, TextEditingController c) =>
        tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (w) => w is TextField && identical(w.controller, c),
              ),
            )
            .decoration!;

    testWidgets('suhu kosong kuning -> diketik jadi hijau; pembacaan netral', (
      tester,
    ) async {
      final isian = await pasang(tester, suhuWajib: true);
      final suhu = isian.titik[25]!.kotak('sesudah_adjustment', 'suhu', 0);
      final baca = isian.titik[25]!.kotak('sesudah_adjustment', 'pembacaan', 0);

      final kosong = PaletIsian.untuk(
        Brightness.light,
        StatusIsian.wajibKosong,
      )!;
      final terisi = PaletIsian.untuk(
        Brightness.light,
        StatusIsian.wajibTerisi,
      )!;

      expect(dekorasiSel(tester, suhu).fillColor, kosong.latar);
      expect(
        dekorasiSel(tester, suhu).hintText,
        '*',
        reason: 'sel tanpa label membawa tanda * di hint',
      );
      expect(
        dekorasiSel(tester, baca).fillColor,
        isNull,
        reason: 'pembacaan tidak punya gerbang wajib -> netral',
      );

      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && identical(w.controller, suhu),
        ),
        '25',
      );
      await tester.pump();

      expect(dekorasiSel(tester, suhu).fillColor, terisi.latar);
    });

    testWidgets('lembar tanpa suhu_wajib: semua sel netral', (tester) async {
      final isian = await pasang(tester, suhuWajib: false);
      final suhu = isian.titik[25]!.kotak('sesudah_adjustment', 'suhu', 0);

      expect(dekorasiSel(tester, suhu).fillColor, isNull);
    });

    testWidgets('tema gelap memakai token gelap di sel suhu', (tester) async {
      final isian = await pasang(
        tester,
        suhuWajib: true,
        tema: Brightness.dark,
      );
      final suhu = isian.titik[25]!.kotak('sesudah_adjustment', 'suhu', 0);

      expect(
        dekorasiSel(tester, suhu).fillColor,
        PaletIsian.untuk(Brightness.dark, StatusIsian.wajibKosong)!.latar,
      );
    });

    testWidgets('tanpa scope (baca-saja): sel suhu tampil biasa', (
      tester,
    ) async {
      final isian = await pasang(tester, suhuWajib: true, scope: false);
      final suhu = isian.titik[25]!.kotak('sesudah_adjustment', 'suhu', 0);

      expect(dekorasiSel(tester, suhu).fillColor, isNull);
      expect(dekorasiSel(tester, suhu).hintText, isNull);
    });
  });
}
