import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/providers/sakelar_ocr_provider.dart';
import 'package:sidik_calibration/screens/settings/ukur_ocr_screen.dart';
import 'package:sidik_calibration/services/ocr_angka/aturan_format_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/ukur_ocr.dart';
import 'package:sidik_calibration/services/ocr_angka/ukur_ocr_jalankan.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';

/// Layar diagnostik `Ukur OCR`: logika ukur (CSV, ringkasan, hasil.csv) dan
/// penjalannya. Tanpa ML Kit dan tanpa ONNX nyata.
void main() {
  group('labels.csv', () {
    test('kolom file,teks wajib; kutip, BOM, CRLF, kolom opsional', () {
      final l = bacaLabelsCsv(
        '﻿file,teks,kondisi,jenis,sumber,format,desimal,sep,bertanda\r\n'
        'crop/000000.png,,bersih,kosong_batal,font,,-1,,0\r\n'
        'crop/000001.png,"0,54",noise,isi,font,d2,2,",",0\r\n'
        'crop/000002.png,-0.20,bersih,isi,font,d2,2,.,1\r\n',
      );

      expect(l.map((e) => e.file), [
        'crop/000000.png',
        'crop/000001.png',
        'crop/000002.png',
      ]);
      expect(l.map((e) => e.teks), ['', '0,54', '-0.20']);
      expect(l.map((e) => e.berisi), [false, true, true]);
      expect(l[1].desimal, 2);
      expect(l[1].bertanda, isFalse);
      expect(l[2].bertanda, isTrue);
      expect(l[0].desimal, -1);
    });

    test(
      'tanpa kolom desimal: disimpulkan dari label; format.sel kosong dari asumsi',
      () {
        final l = bacaLabelsCsv(
          'file,teks\na.png,"12,345"\nb.png,\nc.png,610\n',
        );

        expect(l[0].aturan()!.desimal, 3);
        expect(l[2].aturan()!.desimal, 0);
        expect(l[1].aturan()!.desimal, 2, reason: 'asumsi sel kosong');
        expect(l[1].aturan(desimalSelKosong: 1)!.desimal, 1);
        expect(l[1].aturan()!.bolehNegatif, isFalse);
        expect(l[1].aturan(bertandaSelKosong: true)!.bolehNegatif, isTrue);
        expect(
          l[0].aturan()!.bolehNegatif,
          isTrue,
          reason: 'sel berisi: default rig',
        );
      },
    );

    test('desimal di luar yang diukur -> tanpa aturan', () {
      final l = bacaLabelsCsv('file,teks,desimal\na.png,"1,23456",5\n');
      expect(l.single.aturan(), isNull);
    });

    test('tanpa kolom file/teks -> FormatException', () {
      expect(() => bacaLabelsCsv('nama,nilai\na,b\n'), throwsFormatException);
    });

    test(
      'file kosong -> daftar kosong',
      () => expect(bacaLabelsCsv(''), isEmpty),
    );
  });

  group('ringkasan', () {
    HasilUkurSel h(
      String label,
      String teks, {
      bool dijawab = true,
      double ms = 10,
    }) => HasilUkurSel(
      label: LabelUkur(file: 'x', teks: label),
      teks: teks,
      keyakinan: dijawab ? 0.995 : null,
      dijawab: dijawab,
      status: dijawab ? 'usulanKeyakinanTinggi' : 'perluCek',
      milidetik: ms,
    );

    test('cakupan, akurasi terjawab, exact, isi-palsu, latensi', () {
      final r = ringkasUkur([
        h('1,50', '1.50'), // dijawab benar (koma = titik)
        h('2,00', '2,01'), // dijawab salah
        h('3,00', '3,00', dijawab: false), // benar tapi tidak dijawab
        h('4,00', '', dijawab: false), // tidak terbaca
        h('', '7', ms: 30), // kosong tapi dijawab: isi-palsu
        h('', '', dijawab: false, ms: 50),
      ]);

      expect(r.jumlah, 6);
      expect(r.berisi, 4);
      expect(r.kosong, 2);
      expect(r.dijawabBerisi, 2);
      expect(r.cakupan, 0.5);
      expect(r.benarDijawab, 1);
      expect(r.akurasiTerjawab, 0.5);
      expect(r.exact, 0.5, reason: '1,50 dan 3,00 benar dari 4');
      expect(r.isiPalsu, 1);
      expect(r.isiPalsuPersen, 0.5);
      expect(r.latensiMedian, closeTo(10, 1e-9));
      expect(r.latensiP95, greaterThan(30));
    });

    test('tanpa sel berisi: rasio null, bukan pembagian nol', () {
      final r = ringkasUkur([h('', '', dijawab: false)]);

      expect(r.cakupan, isNull);
      expect(r.akurasiTerjawab, isNull);
      expect(r.exact, isNull);
      expect(persenAtauStrip(r.cakupan), '—');
      expect(persenAtauStrip(0.9234), '92.3%');
    });
  });

  group('hasil.csv', () {
    test(
      'tiga kolom pertama = file,teks,keyakinan (format CSV ML Kit rig)',
      () {
        final csv = hasilCsv([
          HasilUkurSel(
            label: const LabelUkur(file: 'crop/1.png', teks: '7,5'),
            teks: '7,5',
            keyakinan: 0.99123456,
            dijawab: true,
            status: 'usulanKeyakinanTinggi',
            milidetik: 12.34,
          ),
          HasilUkurSel(
            label: const LabelUkur(file: 'crop/2.png', teks: ''),
            teks: '1,2',
            keyakinan: null,
            dijawab: false,
            status: 'kosong',
            milidetik: 3,
          ),
        ]);

        final baris = csv.trim().split('\n');
        expect(baris.first, 'file,teks,keyakinan,status,ms');
        expect(
          baris[1],
          'crop/1.png,"7,5",0.991235,usulanKeyakinanTinggi,12.3',
        );
        expect(baris[2], 'crop/2.png,"1,2",,kosong,3.0');

        // Dibaca balik dengan pembaca yang sama: teks bertanda koma utuh.
        final balik = bacaLabelsCsv(csv);
        expect(balik[0].teks, '7,5');
        expect(balik[1].teks, '1,2');
      },
    );
  });

  group('jalankanUkurFolder', () {
    late Directory d;

    setUp(() {
      d = Directory.systemTemp.createTempSync('ukur_ocr_');
      for (final nama in ['a.png', 'b.png']) {
        final i = img.Image(width: 40, height: 20)
          ..clear(img.ColorRgb8(255, 255, 255));
        File('${d.path}/$nama').writeAsBytesSync(img.encodePng(i));
      }
      File('${d.path}/rusak.png').writeAsBytesSync([1, 2, 3]);
    });

    tearDown(() => d.deleteSync(recursive: true));

    const a = LabelUkur(file: 'a.png', teks: '1,00');
    const b = LabelUkur(file: 'b.png', teks: '');
    const rusak = LabelUkur(file: 'rusak.png', teks: '5');
    const hilang = LabelUkur(file: 'tidak_ada.png', teks: '5');

    test('membaca tiap crop, mengukur waktu, melapor progres', () async {
      final progres = <int>[];
      final hasil = await jalankanUkurFolder(
        folder: d,
        labels: const [a, b],
        baca: (crop, label) async {
          expect(crop.width, 40);

          return (
            teks: label.teks,
            keyakinan: 0.995,
            dijawab: label.berisi,
            status: 'ok',
          );
        },
        progres: (s, t) => progres.add(s),
      );

      expect(hasil.map((e) => e.teks), ['1,00', '']);
      expect(hasil.every((e) => e.milidetik >= 0), isTrue);
      expect(progres, [1, 2]);
    });

    test(
      'batas menghentikan di N sel; dibatalkan berhenti di tengah',
      () async {
        var n = 0;
        final hasil = await jalankanUkurFolder(
          folder: d,
          labels: const [a, b, a, b],
          batas: 3,
          dibatalkan: () => n >= 2,
          baca: (crop, label) async {
            n++;

            return (teks: '', keyakinan: null, dijawab: false, status: 'ok');
          },
        );

        expect(hasil.length, 2);
      },
    );

    test(
      'berkas rusak/hilang dan galat pembaca tidak menghentikan sel lain',
      () async {
        final hasil = await jalankanUkurFolder(
          folder: d,
          labels: const [rusak, hilang, a],
          baca: (crop, label) async => throw Exception('ML Kit mati'),
        );

        expect(hasil.map((e) => e.status), [
          'galat-baca-berkas',
          'galat-baca-berkas',
          'galat',
        ]);
        expect(hasil.every((e) => !e.dijawab), isTrue);
      },
    );

    test(
      'StateError (mesin tidak aktif) menghentikan seluruh pengukuran',
      () async {
        expect(
          jalankanUkurFolder(
            folder: d,
            labels: const [a, b],
            baca: (_, _) async => throw StateError('mesin tidak aktif'),
          ),
          throwsStateError,
        );
      },
    );

    test('adaptor ML Kit: teks disaring ke 0-9 . , - ; tanpa skor', () async {
      final baca = pembacaUkurMlKit(_MlKitPalsu('O 12,5 kg'));
      final h = await baca(img.Image(width: 4, height: 4), a);

      expect(h.teks, '12,5');
      expect(h.keyakinan, isNull);
      expect(h.dijawab, isTrue);

      final kosong = await pembacaUkurMlKit(_MlKitPalsu(null))(
        img.Image(width: 4, height: 4),
        a,
      );
      expect(kosong.dijawab, isFalse);
    });
  });

  group('layar', () {
    // IO berkas sungguhan jalan di luar FakeAsync: selang-seling tunggu nyata
    // dan pump sampai tombol Mulai aktif lagi.
    Future<void> tunggu(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        final tombol = tester.widget<FilledButton>(
          find.byKey(const ValueKey('ukur-ocr-mulai')),
        );
        if (tombol.onPressed != null) return;
      }
    }

    Future<void> pasang(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: UkurOcrScreen())),
      );
      await tester.pump();
    }

    testWidgets('folder tanpa labels.csv -> pesan jelas, tidak crash', (
      tester,
    ) async {
      await pasang(tester);

      await tester.enterText(
        find.byType(TextField).first,
        '${Directory.systemTemp.path}/ukur_ocr_tidak_ada',
      );
      await tester.tap(find.byKey(const ValueKey('ukur-ocr-mulai')));
      await tunggu(tester);

      expect(find.textContaining('labels.csv tidak ada'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('ukur-ocr-mulai')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'mesin angka tanpa runtime -> berhenti dengan pesan, TIDAK diam-diam memakai ML Kit',
      (tester) async {
        final d = Directory.systemTemp.createTempSync('ukur_ocr_layar_');
        addTearDown(() => d.deleteSync(recursive: true));
        File(
          '${d.path}/labels.csv',
        ).writeAsStringSync('file,teks\na.png,"1,00"\n');
        final i = img.Image(width: 40, height: 20)
          ..clear(img.ColorRgb8(255, 255, 255));
        File('${d.path}/a.png').writeAsBytesSync(img.encodePng(i));

        await pasang(tester);
        await tester.enterText(find.byType(TextField).first, d.path);
        await tester.tap(find.text('Mesin angka'));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('ukur-ocr-mulai')));
        await tunggu(tester);

        expect(find.textContaining('Mesin angka tidak aktif'), findsOneWidget);
        expect(
          File('${d.path}/hasil.csv').existsSync(),
          isFalse,
          reason: 'tidak ada hasil palsu',
        );
      },
    );

    test(
      'layar hanya tampil di debug atau lewat flag: bawaan build test = debug',
      () {
        expect(
          tampilkanUkurOcrAktif,
          isTrue,
          reason: 'flutter test berjalan sebagai debug',
        );
      },
    );

    test('SakelarOcr bawaan tidak menyalakan mesin angka', () {
      expect(const SakelarOcr().pakaiMesinAngkaOnnx, isFalse);
      expect(AturanFormatSel(desimal: 1, bolehNegatif: false).desimal, 1);
    });
  });
}

class _MlKitPalsu implements PembacaSel {
  _MlKitPalsu(this.teks);

  final String? teks;

  @override
  Future<BacaanSel> baca(img.Image potongan) async =>
      (teks: teks, keyakinan: null, didalamKotak: true);

  @override
  Future<void> tutup() async {}
}
