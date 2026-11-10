import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/sumber_foto_provider.dart';
import 'package:sidik_calibration/providers/contoh_sel_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/foto_review_screen.dart';
import 'package:sidik_calibration/screens/calibration/grid_sensor_state.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_grid.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_matriks.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_qr.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/penampung_contoh_sel.dart';
import 'package:sidik_calibration/services/simpanan_contoh_sel.dart';

TeksTerbaca kata(String teks, double x, double y, [double? skor]) => (
  teks: teks,
  kotak: Rect.fromLTWH(x, y, teks.length * 12, 24),
  keyakinan: skor,
);

// Two anchored rows permit real cell crops. Only the first has readings.
List<TeksTerbaca> foto(String label, String labelLain) => [
  for (var r = 0; r < 3; r++) kata('X${r + 1}', 420 + r * 180, 60),
  kata(label, 50, 200),
  kata(labelLain, 50, 260),
  kata('121,70', 420, 200, 0.97),
  kata('122,20', 600, 200),
  kata('123,90', 780, 200, 0.40),
];

Future<MockSumberFoto> pasang(
  WidgetTester tester,
  Widget child,
  List<TeksTerbaca> teks, {
  PenampungContohSel? penampung,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final dir = Directory.systemTemp.createTempSync('review-payload');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File('${dir.path}/foto.png')
    ..writeAsBytesSync(img.encodePng(img.Image(width: 1200, height: 600)));
  final sumber = MockSumberFoto(file: file);
  final penampungLokal =
      penampung ??
      PenampungContohSel(SimpananContohSel(Directory('${dir.path}/contoh')));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sumberFotoProvider.overrideWithValue(sumber),
        penampungContohSelProvider.overrideWith((_) async => penampungLokal),
        pabrikPembacaPindaiProvider.overrideWithValue((
          halaman: () => MockPembacaHalaman(teks),
          sel: MockPembacaSel.new,
          qr: MockPembacaQr.new,
        )),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  return sumber;
}

Future<void> bukaReview(WidgetTester tester, Key tombol) async {
  await tester.ensureVisible(find.byKey(tombol));
  await tester.tap(find.byKey(tombol));
  // Image I/O and isolates use real time; never substitute a mapper mock.
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(FotoReviewScreen).evaluate().isNotEmpty) break;
  }
  expect(find.byType(FotoReviewScreen), findsOneWidget);
  await tester.pumpAndSettle();
}

Future<void> koreksiDanSetujui(
  WidgetTester tester, {
  String rawTinggi = '121,70',
}) async {
  final masuk = find.widgetWithText(FilledButton, 'Masukkan ke lembar');
  expect(tester.widget<FilledButton>(masuk).onPressed, isNull);
  // High confidence is still handwriting; red starts empty.
  expect(find.byType(Image), findsNWidgets(3));
  final merah = find.byWidgetPredicate(
    (w) => w is TextField && w.controller!.text.isEmpty,
  );
  await tester.enterText(merah, '123,40');
  final tinggi = find.byWidgetPredicate(
    (w) => w is TextField && w.controller!.text == rawTinggi,
  );
  await tester.enterText(tinggi, '121,10');
  await tester.pump();
  expect(
    tester.widget<FilledButton>(masuk).onPressed,
    isNull,
    reason: 'Null confidence must be individually checked too.',
  );
  final cek = find.byWidgetPredicate(
    (w) =>
        w is IconButton &&
        w.key is ValueKey &&
        '${(w.key as ValueKey).value}'.startsWith('cek-'),
  );
  final belum = cek
      .evaluate()
      .map((e) => e.widget as IconButton)
      .where((w) => (w.icon as Icon).icon == Icons.check_circle_outline)
      .toList();
  expect(belum, hasLength(1));
  await tester.tap(find.byKey(belum.single.key!));
  await tester.pump();
  expect(tester.widget<FilledButton>(masuk).onPressed, isNotNull);
  await tester.tap(masuk);
  await tester.pumpAndSettle();
  expect(
    find.byType(FotoReviewScreen),
    findsNothing,
    reason:
        'Submitting must actually close the review, not hit another overlay.',
  );
}

void main() {
  GridSensorState gridBaru() => GridSensorState(
    bentuk: GridSensorBentuk.fromJson({
      'jumlah_sensor_saran': 1,
      'pengulangan': [1, 2, 3],
      'baris_indikator': true,
      'baris_suhu_ruang': false,
    })!,
  );

  for (final batal in [false, true]) {
    testWidgets(
      'Grid widget camera flow -> per-cell review -> payload; cancel=$batal',
      (tester) async {
        final grid = gridBaru();
        addTearDown(grid.dispose);
        final sebelum = jsonEncode(
          grid.payload(satuan: 'C', pakaiChannel: false),
        );
        final sumber = await pasang(
          tester,
          LembarKerjaGrid(
            state: grid,
            satuanSuhu: 'C',
            onBerubah: () {},
            pemilik: 'uji',
            pindaiAktif: true,
          ),
          foto('7', '3'),
        );
        await bukaReview(tester, const Key('grid_foto_1'));
        expect(
          jsonEncode(grid.payload(satuan: 'C', pakaiChannel: false)),
          sebelum,
        );
        expect(sumber.maxWidthTerakhir, 4200);
        expect(sumber.maxHeightTerakhir, 4200);
        if (batal) {
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(
            jsonEncode(grid.payload(satuan: 'C', pakaiChannel: false)),
            sebelum,
          );
          return;
        }
        await koreksiDanSetujui(tester);
        final sp = grid.payload(satuan: 'C', pakaiChannel: false).first;
        final sensor = (sp['sensor_grid'] as List).single as Map;
        expect(sensor['no'], 7);
        expect(sensor['pembacaan'], [121.10, 122.20, 123.40]);
        final ocr = sensor['ocr'] as List;
        expect((ocr[0] as Map)['raw_text'], '121,70');
        expect((ocr[0] as Map)['confidence'], 0.97);
        expect((ocr[1] as Map).containsKey('confidence'), isFalse);
        expect((ocr[2] as Map)['raw_text'], '123,90');
        expect((ocr[2] as Map)['confidence'], 0.40);
        // Existing manual values survive a later photo application as well.
        final ctl = grid.setPoint.first.sensor.first.pembacaanCtl.first;
        ctl.text = '119,25';
        grid.setPoint.first.terapkanHasilFoto([
          (
            titikUkur: 7.0,
            repeatNo: 1,
            fieldId: 'pembacaan',
            teks: '999',
            keyakinan: 0.99,
          ),
        ]);
        expect(ctl.text, '119,25');
      },
    );
  }

  LembarKerjaState matriksBaru() => LembarKerjaState(
    clientRequestId: 'uji-review',
    bentuk: LembarKerja.fromJson({
      'judul': 'Autoclave',
      'satuan': 'C',
      'bagian': [
        {
          'kode': 'hasil',
          'judul': 'Result',
          'field': [],
          'matriks': {
            'judul_kolom': 'Readings',
            'titik_waktu': [1, 2, 3],
            'baris': [
              {'kode': 'disk_1', 'label': 'Disk A', 'kode_data': 'suhu.disk.0'},
              {'kode': 'disk_2', 'label': 'Disk B', 'kode_data': 'suhu.disk.1'},
            ],
          },
        },
      ],
    }),
  );

  for (final batal in [false, true]) {
    testWidgets(
      'Autoclave widget camera flow -> per-cell review -> payload; cancel=$batal',
      (tester) async {
        final isian = matriksBaru();
        addTearDown(isian.dispose);
        final matriks = isian.bentuk.bagian.single.matriks!;
        final sebelum = jsonEncode(isian.salinanLokal());
        await pasang(
          tester,
          LembarKerjaMatriks(
            matriks: matriks,
            isian: isian,
            onBerubah: () {},
            pindaiAktif: true,
          ),
          foto('Disk A', 'Disk B'),
        );
        await bukaReview(tester, const Key('matriks_foto'));
        expect(jsonEncode(isian.salinanLokal()), sebelum);
        if (batal) {
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(jsonEncode(isian.salinanLokal()), sebelum);
          return;
        }
        await koreksiDanSetujui(tester);
        final payload = isian.payloadMatriks(matriks, null);
        expect(payload['suhu']['disk'][0], [121.10, 122.20, 123.40]);
        final ocr = payload['ocr']['suhu']['disk'][0] as List;
        expect((ocr[0] as Map)['raw_text'], '121,70');
        expect((ocr[1] as Map).containsKey('confidence'), isFalse);
        expect((ocr[2] as Map)['raw_text'], '123,90');
        expect(isian.adaIsianDariFoto, isTrue);
      },
    );
  }
  for (final jalurGrid in [true, false]) {
    for (final batalB in [true, false]) {
      testWidgets(
        'crop A survives reviewed B on filled cells: grid=$jalurGrid cancel=$batalB',
        (tester) async {
          final folder = Directory.systemTemp.createTempSync('crop-a-b');
          addTearDown(() => folder.deleteSync(recursive: true));
          final simpanan = SimpananContohSel(folder);
          final penampung = PenampungContohSel(simpanan);
          final grid = jalurGrid ? gridBaru() : null;
          final isian = jalurGrid ? null : matriksBaru();
          if (grid != null) addTearDown(grid.dispose);
          if (isian != null) addTearDown(isian.dispose);
          final teks = jalurGrid ? foto('7', '3') : foto('Disk A', 'Disk B');
          final child = grid != null
              ? LembarKerjaGrid(
                  state: grid,
                  satuanSuhu: 'C',
                  onBerubah: () {},
                  pemilik: 'uji',
                  pindaiAktif: true,
                )
              : LembarKerjaMatriks(
                  matriks: isian!.bentuk.bagian.single.matriks!,
                  isian: isian,
                  onBerubah: () {},
                  pindaiAktif: true,
                );
          final sumber = await pasang(
            tester,
            child,
            teks,
            penampung: penampung,
          );
          final tombol = Key(jalurGrid ? 'grid_foto_1' : 'matriks_foto');
          final pemilik = jalurGrid ? 'uji' : isian!.clientRequestId;

          // A has black pixels and original OCR 121,70. Accept it fully.
          await bukaReview(tester, tombol);
          expect(penampung.jumlahMilik(pemilik), 0);
          await koreksiDanSetujui(tester);
          expect(penampung.jumlahMilik(pemilik), 3);
          expect(find.byType(SnackBar), findsOneWidget);

          // B addresses the same cells but is visually distinct (white).
          // Its OCR is also distinct, so both crop and metadata prove provenance.
          sumber.file!.writeAsBytesSync(
            img.encodePng(
              img.fill(
                img.Image(width: 1200, height: 600),
                color: img.ColorRgb8(255, 255, 255),
              ),
            ),
          );
          teks[5] = kata('991,70', 420, 200, 0.97);
          await bukaReview(tester, tombol);
          expect(
            find.byType(SnackBar),
            findsNothing,
            reason:
                'A previous photo result must not cover the review actions.',
          );
          expect(penampung.jumlahMilik(pemilik), 3);
          if (batalB) {
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
          } else {
            // Accepted B cannot replace values/crops on already filled cells.
            await koreksiDanSetujui(tester, rawTinggi: '991,70');
          }
          expect(penampung.jumlahMilik(pemilik), 3);

          // Exercise the real collector and file store, not just payload snapshots.
          final hasil = await tester.runAsync(
            () => penampung.serahkan(
              lembar: jalurGrid ? 'enclosure' : 'autoclave',
              pemilik: pemilik,
            ),
          );
          expect(hasil!.tersimpan, 3);
          final isi = (await tester.runAsync(simpanan.baca))!;
          expect(isi.contoh.map((c) => c.label).toSet(), {
            '121,10',
            '122,20',
            '123,40',
          });
          expect(isi.contoh.map((c) => c.bacaanOcr).toSet(), {
            '121,70',
            '122,20',
            '123,90',
          });
          for (final contoh in isi.contoh) {
            final citra = img.decodePng(
              File('${folder.path}/${contoh.berkas}').readAsBytesSync(),
            )!;
            expect(
              citra.getPixel(0, 0).r,
              0,
              reason: 'Stored pixels must come from accepted A, never white B.',
            );
          }
        },
      );
    }
  }
}
