import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:sidik_calibration/services/ocr_angka/keputusan_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin_bawaan.dart';
import 'package:sidik_calibration/services/ocr_angka/sesi_inferensi_tflite.dart';
import 'package:sidik_calibration/services/ocr_angka/sumber_model_ocr.dart';
import 'package:sidik_calibration/services/ocr_angka/ukur_ocr.dart';

/// Uji **DI PERANGKAT** untuk mesin angka TFLite: satu-satunya tempat yang bisa
/// membuktikan LiteRT 1.4.0 (lewat `tflite_flutter` 0.12.1) memuat dan
/// menjalankan `assets/models/ocr_angka_en.tflite` di Android.
///
/// ## STATUS: TIDAK TERBUKTI (13 Nov 2026)
///
/// Belum pernah dijalankan di tablet/HP. Di mesin pengembangan, rantai yang sama
/// (praproses Dart + penataan NHWC Dart + model ASLI lewat ai-edge-litert Python
/// + dekoder Dart) cocok dengan golden rig: lihat `docs/ocr-angka-onnx.md`
/// bagian 6. Yang BELUM dibuktikan: runtime Android, kernel ARM, XNNPACK,
/// latensi, memori.
///
/// ## Yang diperiksa
///
///  1. model dimuat dari ASET APK (bukan folder adb) lewat gerbang rilis:
///     sha256 dipatok + bukti SINTETIS hanya karena tes ini menyalakannya;
///  2. kontrak tensor lolos (`[1,48,320,3]` -> `[1,40,438]`, float32);
///  3. sel "yakin" (skor rig >= 0,995): teks IDENTIK dengan rig, selisih skor
///     `jalur` <= 0,01, dan menjadi usulan;
///  4. sel "ditahan" (skor rig <= 0,90) dan "kosong": TIDAK menjadi usulan
///     (teksnya boleh beda dari rig; yang dijaga keputusannya);
///  5. panggilan bersamaan menghasilkan bacaan yang sama dengan berurutan;
///  6. latensi per sel dicetak (median/p95; putaran pertama dipisah karena
///     memuat kernel). TIDAK diadili di sini: ambangnya milik pemilik.
///
/// ## Menjalankan di tablet
///
/// ```
/// flutter test integration_test/ocr_tflite_hp_test.dart -d <id-perangkat>
/// ```
///
/// (`adb devices` / `flutter devices` untuk id.) Tidak perlu `adb push`: model
/// dan 21 crop uji ikut APK debug-nya. Tanpa perangkat Android tes ini SKIP.
/// Catat keluaran `OCR-TFLITE:` ke laporan; itulah satu-satunya bukti
/// latensi/paritas di perangkat.
///
/// ## Golden
///
/// `integration_test/fixtures/ocr_tflite/golden.json` = keluaran rig
/// (`pred_B_en_tflite_f32_uji.csv`, SINTETIS) pada crop uji yang sama. Crop
/// berasal dari `sidik-ocr-eval\data\uji`, dikodekan ulang lossless.
const _dir = 'integration_test/fixtures/ocr_tflite';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TFLite asli: termuat, cocok dengan golden rig, konkuren aman, latensi',
    (tester) async {
      // 1-2. Gerbang rilis penuh dengan aset APK.
      final muat = await muatMesinAngka(
        sumber: SumberAsetOcr(rootBundle),
        buatSesi: SesiInferensiTflite.dariByte,
        izinkanSintetis: true,
        sha256Dipercaya: sha256ModelDipercaya,
      );
      expect(
        muat.mesin,
        isNotNull,
        reason:
            'mesin tidak termuat: ${muat.ditolak}. runtimeGagalDimuat = '
            'LiteRT/tflite_flutter gagal di perangkat ini (lihat logcat).',
      );
      final mesin = muat.mesin!;
      addTearDown(mesin.tutup);

      final golden =
          (jsonDecode(await rootBundle.loadString('$_dir/golden.json'))
                  as Map<String, dynamic>)['sel']
              as List;
      final labels = {
        for (final l in bacaLabelsCsv(
          await rootBundle.loadString('$_dir/labels.csv'),
        ))
          l.file: l,
      };

      final crops = <String, img.Image>{};
      for (final g in golden.cast<Map<String, dynamic>>()) {
        final berkas = g['file'] as String;
        final data = await rootBundle.load('$_dir/$berkas');
        crops[berkas] = img.decodeImage(data.buffer.asUint8List())!;
      }
      expect(crops.length, golden.length);

      Future<HasilSelAngka> baca(Map<String, dynamic> g) {
        final berkas = g['file'] as String;
        return mesin.baca(
          crops[berkas]!,
          labels[berkas]!.aturan()!,
          ambang: 0.990,
        );
      }

      // 3-4. Putaran pertama (dingin), sekaligus perbandingan dengan rig.
      final jam = Stopwatch();
      final pertama = <double>[];
      final hasil = <String, HasilSelAngka>{};
      var yakin = 0;
      for (final g in golden.cast<Map<String, dynamic>>()) {
        final berkas = g['file'] as String;
        jam
          ..reset()
          ..start();
        final h = await baca(g);
        pertama.add(jam.elapsedMicroseconds / 1000);
        hasil[berkas] = h;

        final kelas = g['kelas'] as String;
        final rig = g['pred_rig'] as String;
        final jalurRig = (g['jalur_rig'] as num).toDouble();

        switch (kelas) {
          case 'yakin':
            yakin++;
            expect(h.bacaanMentah, rig, reason: '$berkas: teks beda dari rig');
            expect(
              (h.jalur - jalurRig).abs(),
              lessThanOrEqualTo(0.01),
              reason: '$berkas: skor ${h.jalur} vs rig $jalurRig',
            );
            expect(h.usulan, rig, reason: '$berkas: harusnya jadi usulan');
          case 'ditahan' || 'kosong':
            expect(
              h.usulan,
              isNull,
              reason:
                  '$berkas ($kelas): tidak boleh jadi usulan, tetapi '
                  '"${h.bacaanMentah}" skor ${h.jalur}',
            );
        }
      }
      expect(yakin, greaterThanOrEqualTo(10));

      // 5. Konkuren: hasil sama dengan berurutan (pekerja melayani berurutan).
      final semua = golden.cast<Map<String, dynamic>>();
      final serentak = await Future.wait([for (final g in semua) baca(g)]);
      for (final (i, g) in semua.indexed) {
        final berkas = g['file'] as String;
        expect(
          serentak[i].bacaanMentah,
          hasil[berkas]!.bacaanMentah,
          reason: '$berkas: konkuren beda dari berurutan',
        );
        expect(serentak[i].jalur, closeTo(hasil[berkas]!.jalur, 1e-6));
      }

      // 6. Latensi: dua putaran berikutnya (hangat).
      final hangat = <double>[];
      for (var putaran = 0; putaran < 2; putaran++) {
        for (final g in semua) {
          jam
            ..reset()
            ..start();
          await baca(g);
          hangat.add(jam.elapsedMicroseconds / 1000);
        }
      }

      String ms(List<double> v, double q) {
        final s = [...v]..sort();
        return s[((s.length - 1) * q).round()].toStringAsFixed(1);
      }

      // ignore: avoid_print
      print(
        'OCR-TFLITE: ${semua.length} sel | yakin $yakin cocok rig | '
        'putaran 1 (dingin) median ${ms(pertama, 0.5)} ms p95 ${ms(pertama, 0.95)} ms, '
        'maks ${ms(pertama, 1)} ms | '
        'hangat median ${ms(hangat, 0.5)} ms p95 ${ms(hangat, 0.95)} ms '
        '(per sel: pagar tinta + praproses + inferensi + dekode; sel kosong '
        'tanpa tinta tidak menjalankan model) | '
        'threads ${SesiInferensiTflite.threadBawaan()} | '
        '${Platform.operatingSystemVersion}',
      );
    },
    skip: !Platform.isAndroid,
  );
}
