import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ocr_angka/sesi_inferensi.dart' show BuatSesiCtc;
import '../services/ocr_angka/sesi_inferensi_tflite.dart'
    show PabrikSesiTfliteBersama;

/// Sakelar OCR lokal. Bawaan MATI, kecuali [ocrAwanSel] di
/// [sakelarOcrProvider] (menyala sejak 26 Nov 2026).
///
/// - [kumpulkanContohSel]: simpan potongan sel yang dikonfirmasi teknisi di
///   review foto (JPEG abu-abu + nilai akhir) ke folder privat app. Hanya
///   lokal — tidak ada unggah/ekspor (menunggu Gerbang 0 privasi).
/// - [pakaiModelDigit]: pakai pengenal digit sendiri. BELUM ADA modelnya;
///   sakelar ini belum dibaca kode mana pun selain untuk memastikan dia mati
///   (pembaca dan adaptornya dihapus 13 Nov 2026 karena tak terpasang ke alur
///   mana pun). Menyalakannya tidak boleh mengubah warna sel sebelum modelnya
///   divalidasi.
/// - [pakaiMesinAngkaOnnx]: sel angka bertemplat dibaca `PembacaSelOnnx`
///   (PP-OCR en dalam TFLite + gerbang format, `lib/services/ocr_angka/`), ML
///   Kit jadi cadangan. Bukti akurasinya masih SINTETIS, jadi ini sakelar
///   developer. Mati = jalur ML Kit murni seperti sebelumnya, dan model TIDAK
///   dibuka ([buatSesiOcrAngkaProvider] `null`). Nama field dipertahankan dari
///   masa ONNX supaya tes dan skrip lama tetap jalan; runtime-nya kini TFLite.
///
/// - [ocrAwanSel]: tawarkan OCR awan atas POTONGAN sel angka
///   (`POST /api/ocr/sel-awan`, kontrak 22B: HP memotong sendiri sel angka lalu
///   mengunggah potongannya lewat backend; app tidak memegang kunci atau URL
///   Google dan tidak mengirim foto utuh). Hasilnya usulan yang wajib
///   dikonfirmasi manusia per sel. Ini hanya sakelar sisi klien: server punya
///   sakelar sendiri (`GOOGLE_VISION_AKTIF`, `ocr_cloud_sel`) dan menang bila
///   mati. Bawaan provider MENYALA sejak keputusan pemilik 26 Nov 2026
///   (`--dart-define=OCR_AWAN_SEL=false` mematikannya); pertanyaan kontrak
///   pelanggan dan ISO/IEC 17025 §4.2 di AGENTS.md masih terbuka. Konstruktor
///   `const SakelarOcr()` tetap mati. Lihat `ocrAwanBolehDitawarkan`.
///
/// Layar diagnostik `Ukur OCR` bukan sakelar di kelas ini: lihat
/// [tampilkanUkurOcrAktif] (const).
///
/// Dinyalakan lewat `--dart-define=KUMPULKAN_CONTOH_SEL=true` /
/// `PAKAI_MODEL_DIGIT=true` / `PAKAI_MESIN_ANGKA=true` (tanpa UI; nama lama
/// `PAKAI_MESIN_ANGKA_ONNX=true` tetap diterima), atau di-override di test.
/// `OCR_AWAN_SEL` kebalikannya: menyala kecuali diberi `=false`.
class SakelarOcr {
  const SakelarOcr({
    this.kumpulkanContohSel = false,
    this.pakaiModelDigit = false,
    this.pakaiMesinAngkaOnnx = false,
    this.ocrAwanSel = false,
  });

  final bool kumpulkanContohSel;
  final bool pakaiModelDigit;
  final bool pakaiMesinAngkaOnnx;
  final bool ocrAwanSel;
}

/// Layar diagnostik `Ukur OCR` tampil? Selalu di build debug; di rilis hanya
/// bila dibangun dengan `--dart-define=TAMPILKAN_UKUR_OCR=true`. Const: di
/// rilis biasa seluruh cabang yang memakainya dibuang kompilator.
const tampilkanUkurOcrAktif =
    kDebugMode || bool.fromEnvironment('TAMPILKAN_UKUR_OCR');

final sakelarOcrProvider = Provider<SakelarOcr>(
  (ref) => const SakelarOcr(
    kumpulkanContohSel: bool.fromEnvironment('KUMPULKAN_CONTOH_SEL'),
    pakaiModelDigit: bool.fromEnvironment('PAKAI_MODEL_DIGIT'),
    pakaiMesinAngkaOnnx:
        bool.fromEnvironment('PAKAI_MESIN_ANGKA') ||
        bool.fromEnvironment('PAKAI_MESIN_ANGKA_ONNX'),
    // Satu-satunya sakelar yang bawaannya MENYALA: pemilik memutuskan 26 Nov
    // 2026 (di chat) agar tombol usulan awan ikut di APK rilis. Server tetap
    // gerbangnya (`GOOGLE_VISION_AKTIF` + `ocr_cloud_sel`); build yang harus
    // mematikannya memakai `--dart-define=OCR_AWAN_SEL=false`.
    ocrAwanSel: bool.fromEnvironment('OCR_AWAN_SEL', defaultValue: true),
  ),
);

/// Pabrik sesi inferensi mesin angka: TFLite lewat `tflite_flutter`/LiteRT yang
/// sudah ada di APK HANYA bila sakelar [SakelarOcr.pakaiMesinAngkaOnnx]
/// menyala; mati (bawaan) = `null`, jadi tidak ada yang bisa membuka model dan
/// `PembacaSelOnnx` jatuh ke ML Kit. Gagal memuat runtime/model juga berakhir
/// di ML Kit, tanpa crash. Test dan layar ukur bisa meng-override-nya dengan
/// sesi tiruan.
///
/// Model dimuat SEKALI per proses ([PabrikSesiTfliteBersama]), bukan per foto,
/// dan dilepas saat provider dibuang.
final buatSesiOcrAngkaProvider = Provider<BuatSesiCtc?>(
  (ref) => ref.watch(pabrikSesiOcrAngkaProvider)?.buat,
);

/// Pabrik di balik [buatSesiOcrAngkaProvider]; `null` bila sakelar mati. Dibaca
/// juga untuk `menyerah`: sesudah runtime gagal dimuat berulang kali, pemanggil
/// berhenti membaca aset model sama sekali (`muatMesinAngkaBawaan`).
final pabrikSesiOcrAngkaProvider = Provider<PabrikSesiTfliteBersama?>((ref) {
  if (!ref.watch(sakelarOcrProvider).pakaiMesinAngkaOnnx) return null;

  final pabrik = PabrikSesiTfliteBersama();
  ref.onDispose(pabrik.lepas);

  return pabrik;
});
