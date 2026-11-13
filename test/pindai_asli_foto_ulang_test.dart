import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/pindai_formulir_asli_flow.dart';
import 'package:sidik_calibration/services/jalankan_pindai.dart'
    show GagalPindai;
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';

/// Foto lembar kerja yang GAGAL karena fotonya: alasan lama tetap tampil,
/// ditambah tombol "Foto ulang" yang membuka kamera lagi; halaman terpotong
/// diberi penjelasan sendiri. Foto sintetis + mesin baca tiruan: yang diuji
/// adalah penyambungan alurnya.

/// Mesin yang gagal/berhasil menurut urutan: elemen non-null dilempar,
/// null = lolos (satu sel gagal dibaca → layar review terbuka).
class _MesinBerurutan extends JalankanPindaiAsli {
  _MesinBerurutan(this.urutan)
    : super(halaman: MockPembacaHalaman(const []), pembaca: MockPembacaSel());

  final List<Object?> urutan;
  int panggilan = 0;

  @override
  Future<HasilBacaAsli> baca(
    img.Image foto, {
    required WorksheetTemplate template,
    Uint8List? jpegAsli,
  }) async {
    final langkah = urutan[panggilan.clamp(0, urutan.length - 1)];
    panggilan++;
    if (langkah != null) throw langkah;

    const kunci = 'sesudah_adjustment|1|1|pembacaan';

    return HasilBacaAsli(
      kodeTerbaca: 'SIDIK-FM-CAL-0509',
      sel: [
        for (final s in template.selAsli)
          if (s.kunci == kunci)
            (sel: s, bacaan: (teks: null, keyakinan: null, didalamKotak: true)),
      ],
      gagalDibaca: const {kunci},
    );
  }
}

/// Sumber foto yang menulis berkas BARU tiap kali (alur menghapus berkas
/// begitu terbaca, jadi berkas yang sama tak bisa dipakai dua kali).
class _SumberSegar extends MockSumberFoto {
  _SumberSegar(this.dir, this.bita);

  final Directory dir;
  final List<int> bita;

  @override
  Future<File?> ambil({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    double? rasioKertas,
  }) async {
    jumlahAmbil++;
    rasioKertasTerakhir = rasioKertas;

    return File('${dir.path}/foto-$jumlahAmbil.png')..writeAsBytesSync(bita);
  }
}

void main() {
  late WorksheetTemplate template;
  late Directory dir;
  late List<int> pngSintetis;

  setUpAll(() {
    template = WorksheetTemplate.fromJson(
      jsonDecode(
            File(
              'test/assets/template-asli-ph_meter-0509.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    dir = Directory.systemTemp.createTempSync('foto-ulang');
    pngSintetis = img.encodePng(img.Image(width: 64, height: 48));
  });

  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows: berkas masih dipegang; folder temp OS.
    }
  });

  LembarKerjaState buatState() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerja()),
    clientRequestId: 'uuid-test',
  );

  Finder dialogUlang() => find.byKey(const ValueKey('dialog-foto-ulang'));
  Finder tombolUlang() => find.byKey(const ValueKey('foto-ulang'));

  /// Tekan "foto" dan tunggu sampai alur berhenti di dialog, snackbar, atau
  /// layar review. Isolate decode = IO sungguhan → beri waktu nyata.
  Future<void> tunggu(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (dialogUlang().evaluate().isNotEmpty ||
          find.byType(SnackBar).evaluate().isNotEmpty ||
          find.byType(TextField).evaluate().isNotEmpty) {
        return;
      }
    }
  }

  Future<({_SumberSegar sumber, Future<int> hasil})> mulai(
    WidgetTester tester, {
    required JalankanPindaiAsli mesin,
    List<int>? bita,
  }) async {
    final sumber = _SumberSegar(dir, bita ?? pngSintetis);
    final isian = buatState();
    late Future<int> hasil;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sumberFotoProvider.overrideWithValue(sumber)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('id'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () {
                  hasil = pindaiFormulirAsli(
                    context: context,
                    ref: ref,
                    isian: isian,
                    template: template,
                    mesin: mesin,
                  );
                },
                child: const Text('foto'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('foto'));
    await tunggu(tester);

    return (sumber: sumber, hasil: hasil);
  }

  group('galat mutu: alasan lama + tombol "Foto ulang"', () {
    testWidgets('buram: alasan tampil, Foto ulang membuka kamera LAGI dan '
        'mengulang seluruh alur', (tester) async {
      final mesin = _MesinBerurutan([
        const PindaiAsliGagal(
          GagalPindaiAsli.mutu,
          mutu: GagalPindai.mutuBuram,
        ),
        null,
      ]);
      final r = await mulai(tester, mesin: mesin);

      expect(dialogUlang(), findsOneWidget);
      expect(
        find.text('Fotonya buram. Tahan HP lebih diam, lalu foto ulang.'),
        findsOneWidget,
        reason: 'pesan alasan yang sudah ada tetap dipakai',
      );
      expect(tombolUlang(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pesan-halaman-terpotong')),
        findsNothing,
        reason: 'buram bukan halaman terpotong',
      );
      expect(r.sumber.jumlahAmbil, 1);

      await tester.tap(tombolUlang());
      await tester.pump();
      await tunggu(tester);

      expect(r.sumber.jumlahAmbil, 2, reason: 'kamera dibuka lagi');
      expect(mesin.panggilan, 2, reason: 'seluruh alur baca diulang');
      expect(dialogUlang(), findsNothing);
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'percobaan kedua lolos → layar review (tinjauan teknisi)',
      );
    });

    testWidgets('gagal lagi di percobaan kedua: dialog muncul lagi; Tutup '
        'mengembalikan 0 tanpa membuka kamera lagi', (tester) async {
      const buram = PindaiAsliGagal(
        GagalPindaiAsli.mutu,
        mutu: GagalPindai.mutuGelap,
      );
      final mesin = _MesinBerurutan([buram, buram]);
      final r = await mulai(tester, mesin: mesin);

      await tester.tap(tombolUlang());
      await tester.pump();
      await tunggu(tester);
      expect(dialogUlang(), findsOneWidget);
      expect(r.sumber.jumlahAmbil, 2);
      expect(find.textContaining('Terlalu gelap'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('foto-ulang-tutup')));
      await tester.pumpAndSettle();

      expect(await r.hasil, 0);
      expect(r.sumber.jumlahAmbil, 2, reason: 'ditutup = tidak ada foto lagi');
      expect(dialogUlang(), findsNothing);
    });

    for (final (mutu, potongan) in [
      (GagalPindai.mutuSilau, 'Terlalu terang'),
      (GagalPindai.mutuPantulan, 'pantulan cahaya'),
      (GagalPindai.mutuMiring, 'terlalu miring'),
      (GagalPindai.mutuKejauhan, 'kejauhan'),
    ]) {
      testWidgets('mutu $mutu: alasan lama + Foto ulang', (tester) async {
        await mulai(
          tester,
          mesin: _MesinBerurutan([
            PindaiAsliGagal(GagalPindaiAsli.mutu, mutu: mutu),
          ]),
        );

        expect(find.textContaining(potongan), findsOneWidget);
        expect(tombolUlang(), findsOneWidget);
      });
    }
  });

  group('halaman terpotong', () {
    testWidgets('jangkar kurang: alasan lama + pesan "halaman terpotong"', (
      tester,
    ) async {
      await mulai(
        tester,
        mesin: _MesinBerurutan([
          const PindaiAsliGagal(GagalPindaiAsli.jangkarKurang, jumlah: 3),
        ]),
      );

      expect(
        find.textContaining('terlalu sedikit (3)'),
        findsOneWidget,
        reason: 'alasan yang sudah ada',
      );
      final terpotong = find.byKey(const ValueKey('pesan-halaman-terpotong'));
      expect(terpotong, findsOneWidget);
      expect(
        tester.widget<Text>(terpotong).data,
        allOf(contains('Halaman terpotong'), contains('SELURUH halaman')),
      );
      expect(tombolUlang(), findsOneWidget);
    });

    testWidgets(
      'jangkar tidak menyebar: pesan "halaman terpotong" juga muncul',
      (tester) async {
        await mulai(
          tester,
          mesin: _MesinBerurutan([
            const PindaiAsliGagal(GagalPindaiAsli.jangkarTidakMenyebar),
          ]),
        );

        expect(find.textContaining('menumpuk di satu sisi'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('pesan-halaman-terpotong')),
          findsOneWidget,
        );
        expect(tombolUlang(), findsOneWidget);
      },
    );
  });

  group('kapan "Foto ulang" ditawarkan', () {
    for (final sebab in [
      GagalPindaiAsli.fotoTerbalik,
      GagalPindaiAsli.kodeTidakTerbaca,
      GagalPindaiAsli.revisiTidakTerbaca,
      GagalPindaiAsli.pembacaMati,
    ]) {
      testWidgets('$sebab (fotonya yang salah): dialog + Foto ulang', (
        tester,
      ) async {
        await mulai(tester, mesin: _MesinBerurutan([PindaiAsliGagal(sebab)]));

        expect(tombolUlang(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('pesan-halaman-terpotong')),
          findsNothing,
        );
      });
    }

    for (final sebab in [
      GagalPindaiAsli.belumSiap,
      GagalPindaiAsli.geometriBelumLengkap,
      GagalPindaiAsli.formulirLain,
      GagalPindaiAsli.revisiBeda,
    ]) {
      testWidgets(
        '$sebab (bukan salah foto): snackbar saja, tanpa Foto ulang',
        (tester) async {
          final r = await mulai(
            tester,
            mesin: _MesinBerurutan([
              PindaiAsliGagal(sebab, terbaca: 'SIDIK-FM-CAL-0510'),
            ]),
          );

          expect(find.byType(SnackBar), findsOneWidget);
          expect(dialogUlang(), findsNothing);
          expect(tombolUlang(), findsNothing);
          expect(await r.hasil, 0);
          expect(r.sumber.jumlahAmbil, 1);
        },
      );
    }

    testWidgets('galat tak terduga (bug): snackbar umum, tanpa Foto ulang', (
      tester,
    ) async {
      await mulai(
        tester,
        mesin: _MesinBerurutan([StateError('/data/rahasia.jpg')]),
      );

      expect(find.textContaining('Foto gagal diproses'), findsOneWidget);
      expect(tombolUlang(), findsNothing);
    });

    testWidgets('berkas bukan citra (tak terbaca): Foto ulang ditawarkan', (
      tester,
    ) async {
      final mesin = _MesinBerurutan([null]);
      final r = await mulai(
        tester,
        mesin: mesin,
        bita: [1, 2, 3, 4, 5, 6, 7, 8],
      );

      expect(find.textContaining('Foto tidak bisa dibaca'), findsOneWidget);
      expect(tombolUlang(), findsOneWidget);
      expect(mesin.panggilan, 0, reason: 'mesin tak disentuh');
      expect(r.sumber.jumlahAmbil, 1);
    });
  });

  group('kamera tahu bentuk halaman', () {
    testWidgets('rasio lebar÷tinggi halaman templat diteruskan ke kamera', (
      tester,
    ) async {
      final halaman = template.halamanPt;
      expect(halaman, isNotNull, reason: 'templat uji memuat ukuran halaman');

      final r = await mulai(
        tester,
        mesin: _MesinBerurutan([
          const PindaiAsliGagal(GagalPindaiAsli.pembacaMati),
        ]),
      );

      expect(
        r.sumber.rasioKertasTerakhir,
        closeTo(halaman!.w / halaman.h, 1e-9),
      );
    });
  });

  group('fotoUlangMembantu', () {
    test(
      'tiap sebab diputuskan eksplisit (salah foto = ya, salah lembar = tidak)',
      () {
        final ya = {
          for (final s in GagalPindaiAsli.values)
            if (fotoUlangMembantu(s)) s,
        };

        expect(ya, {
          GagalPindaiAsli.mutu,
          GagalPindaiAsli.jangkarKurang,
          GagalPindaiAsli.jangkarTidakMenyebar,
          GagalPindaiAsli.fotoTerbalik,
          GagalPindaiAsli.kodeTidakTerbaca,
          GagalPindaiAsli.revisiTidakTerbaca,
          GagalPindaiAsli.pembacaMati,
        });
      },
    );

    test('halaman terpotong hanya untuk dua sebab jangkar', () {
      final ya = {
        for (final s in GagalPindaiAsli.values)
          if (sebabHalamanTerpotong(s)) s,
      };

      expect(ya, {
        GagalPindaiAsli.jangkarKurang,
        GagalPindaiAsli.jangkarTidakMenyebar,
      });
    });
  });
}
