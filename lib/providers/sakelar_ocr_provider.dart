import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ocr_angka/sesi_inferensi.dart' show BuatSesiCtc;

/// Sakelar OCR lokal. Semuanya bawaan MATI.
///
/// - [kumpulkanContohSel]: simpan potongan sel yang dikonfirmasi teknisi di
///   review foto (JPEG abu-abu + nilai akhir) ke folder privat app. Hanya
///   lokal — tidak ada unggah/ekspor (menunggu Gerbang 0 privasi).
/// - [pakaiModelDigit]: pakai pengenal digit sendiri. BELUM ADA modelnya dan
///   belum ada runtime-nya; sakelar ini belum dibaca kode mana pun selain
///   untuk memastikan dia mati. Menyalakannya tidak boleh mengubah warna sel
///   sebelum modelnya divalidasi.
/// - [pakaiMesinAngkaOnnx]: sel angka bertemplat dibaca `PembacaSelOnnx`
///   (PP-OCR en + gerbang format, `lib/services/ocr_angka/`), ML Kit jadi
///   cadangan. Bukti akurasinya masih SINTETIS, jadi ini sakelar developer.
///   Mati = jalur ML Kit murni seperti sebelumnya.
///
/// Layar diagnostik `Ukur OCR` bukan sakelar di kelas ini: lihat
/// [tampilkanUkurOcrAktif] (const).
///
/// Dinyalakan lewat `--dart-define=KUMPULKAN_CONTOH_SEL=true` /
/// `PAKAI_MODEL_DIGIT=true` / `PAKAI_MESIN_ANGKA_ONNX=true` (tanpa UI), atau
/// di-override di test.
class SakelarOcr {
  const SakelarOcr({
    this.kumpulkanContohSel = false,
    this.pakaiModelDigit = false,
    this.pakaiMesinAngkaOnnx = false,
  });

  final bool kumpulkanContohSel;
  final bool pakaiModelDigit;
  final bool pakaiMesinAngkaOnnx;
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
    pakaiMesinAngkaOnnx: bool.fromEnvironment('PAKAI_MESIN_ANGKA_ONNX'),
  ),
);

/// Pabrik sesi inferensi mesin angka. `null` = build ini tidak membawa runtime
/// (kondisi sekarang): `PembacaSelOnnx` jatuh ke ML Kit. Diisi (override) saat
/// runtime ONNX/LiteRT dipilih, lihat `docs/ocr-angka-onnx.md`.
final buatSesiOcrAngkaProvider = Provider<BuatSesiCtc?>((ref) => null);
