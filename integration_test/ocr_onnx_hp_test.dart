import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin_bawaan.dart';
import 'package:sidik_calibration/services/ocr_angka/sesi_inferensi.dart';
import 'package:sidik_calibration/services/ocr_angka/ukur_ocr.dart';
import 'package:sidik_calibration/services/ocr_angka/ukur_ocr_jalankan.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/pembaca_sel_onnx.dart';

/// Uji **DI PERANGKAT** untuk mesin angka (inferensi NYATA di tablet) — satu-
/// satunya tempat dua hal ini bisa dibuktikan:
///
///  1. model dimuat oleh runtime yang dipilih dan menjawab tanpa galat;
///  2. teks dari tablet sama dengan teks rig Python pada crop yang sama
///     (paritas praproses Dart + runtime Android), dan latensinya per sel.
///
/// ## STATUS: TIDAK TERBUKTI (12 Nov 2026)
///
/// Belum ada runtime inferensi di app (keputusan dependensi menunggu pemilik,
/// lihat `docs/ocr-angka-onnx.md`), jadi [buatSesiUji] masih `null` dan tes
/// di bawah SKIP. Begitu runtime dipilih, isi [buatSesiUji] dengan adaptor
/// `SesiInferensiCtc`-nya dan jalankan.
///
/// ## Persiapan di tablet (adb)
///
/// ```
/// adb shell mkdir -p /sdcard/Android/data/com.ptsidik.kalibrasi/files/ocr-ukur
/// adb push ocr_angka_en.onnx ocr_angka_en.meta.json labels.csv crop \
///   /sdcard/Android/data/com.ptsidik.kalibrasi/files/ocr-ukur/
/// # opsional, untuk paritas: prediksi rig pada crop yang sama
/// adb push pred_rig.csv /sdcard/Android/data/com.ptsidik.kalibrasi/files/ocr-ukur/
/// ```
///
/// `labels.csv` dan `crop/` dari rig `sidik-ocr-eval\data\uji` (SINTETIS) atau
/// dari foto nyata; `pred_rig.csv` = `hasil\pred_B_en_uji.csv` (kolom `file,pred,konf`).
///
/// ## Menjalankan
///
/// ```
/// flutter test integration_test/ocr_onnx_hp_test.dart -d <id-perangkat> \
///   --dart-define=PAKAI_MESIN_ANGKA_ONNX=true
/// ```
///
/// Folder lain: `--dart-define=OCR_UKUR_DIR=/path`. Jumlah sel: `--dart-define=OCR_UKUR_N=200`.
///
/// Keluaran (ringkasan akurasi, cakupan, latensi) dicetak ke log dan `hasil.csv`
/// ditulis di folder itu. Tes GAGAL hanya untuk kerusakan struktural (mesin tidak
/// termuat, galat per sel, paritas di bawah 95%); angka akurasi tidak diadili
/// di sini.
BuatSesiCtc? get buatSesiUji =>
    null; // TODO: isi dengan adaptor runtime terpilih.

const _dirEnv = String.fromEnvironment('OCR_UKUR_DIR');
const _nEnv = int.fromEnvironment('OCR_UKUR_N', defaultValue: 200);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mesin angka termuat, membaca crop tanpa galat, dan cocok dengan rig',
    (tester) async {
      final folder = _dirEnv.isNotEmpty
          ? Directory(_dirEnv)
          : await folderOcrUkur();
      expect(
        File('${folder.path}/labels.csv').existsSync(),
        isTrue,
        reason: 'labels.csv tidak ada di ${folder.path} (lihat persiapan adb)',
      );

      final muat = await muatMesinAngka(
        sumber: await sumberModelBawaan(),
        buatSesi: buatSesiUji,
        izinkanSintetis: true,
      );
      expect(
        muat.mesin,
        isNotNull,
        reason: 'mesin tidak termuat: ${muat.ditolak}',
      );

      final labels = bacaLabelsCsv(
        File('${folder.path}/labels.csv').readAsStringSync(),
      );
      final onnx = PembacaSelOnnx(
        cadangan: _TanpaCadangan(),
        muatMesin: () async => muat.mesin,
      );

      final hasil = await jalankanUkurFolder(
        folder: folder,
        labels: labels,
        batas: _nEnv,
        baca: pembacaUkurMesinAngka(onnx),
      );

      File('${folder.path}/hasil.csv').writeAsStringSync(hasilCsv(hasil));
      final r = ringkasUkur(hasil);
      // ignore: avoid_print
      print(
        'OCR-ONNX: ${r.jumlah} sel | cakupan ${persenAtauStrip(r.cakupan)} | '
        'akurasi terjawab ${persenAtauStrip(r.akurasiTerjawab)} | '
        'isi-palsu ${persenAtauStrip(r.isiPalsuPersen)} | '
        'latensi median ${r.latensiMedian.toStringAsFixed(1)} ms '
        'p95 ${r.latensiP95.toStringAsFixed(1)} ms',
      );

      expect(hasil, isNotEmpty);
      expect(
        hasil.where((h) => h.status.startsWith('galat')),
        isEmpty,
        reason: 'ada sel yang galat saat dibaca',
      );

      final berkasRig = File('${folder.path}/pred_rig.csv');
      if (berkasRig.existsSync()) {
        final rig = <String, String>{
          for (final baris in bacaLabelsCsv(
            berkasRig.readAsStringSync().replaceFirst('file,pred', 'file,teks'),
          ))
            baris.file: baris.teks,
        };
        final dibanding = [
          for (final h in hasil)
            if (rig.containsKey(h.label.file)) h,
        ];
        final sama = dibanding.where((h) => h.teks == rig[h.label.file]).length;
        // ignore: avoid_print
        print('OCR-ONNX paritas dengan rig: $sama / ${dibanding.length}');
        expect(dibanding, isNotEmpty);
        expect(
          sama / dibanding.length,
          greaterThanOrEqualTo(0.95),
          reason:
              'teks tablet berbeda dari rig: periksa praproses/runtime '
              '(Dart + ORT laptop memberi 96,8% pada 600 crop sintetis)',
        );
      }
    },
    skip: buatSesiUji == null,
  );
}

/// Pengukuran mesin angka tidak boleh diam-diam jatuh ke ML Kit.
class _TanpaCadangan implements PembacaSel {
  @override
  Future<BacaanSel> baca(img.Image potongan) =>
      throw StateError('tanpa cadangan: pengukuran khusus mesin angka');

  @override
  Future<void> tutup() async {}
}
