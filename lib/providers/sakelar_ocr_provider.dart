import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sakelar OCR lokal. DUA sakelar yang TERPISAH, dua-duanya bawaan MATI.
///
/// - [kumpulkanContohSel]: simpan potongan sel yang dikonfirmasi teknisi di
///   review foto (JPEG abu-abu + nilai akhir) ke folder privat app. Hanya
///   lokal — tidak ada unggah/ekspor (menunggu Gerbang 0 privasi).
/// - [pakaiModelDigit]: pakai pengenal digit sendiri. BELUM ADA modelnya dan
///   belum ada runtime-nya; sakelar ini belum dibaca kode mana pun selain
///   untuk memastikan dia mati. Menyalakannya tidak boleh mengubah warna sel
///   sebelum modelnya divalidasi.
///
/// Dinyalakan lewat `--dart-define=KUMPULKAN_CONTOH_SEL=true` /
/// `PAKAI_MODEL_DIGIT=true` (tanpa UI), atau di-override di test.
class SakelarOcr {
  const SakelarOcr({
    this.kumpulkanContohSel = false,
    this.pakaiModelDigit = false,
  });

  final bool kumpulkanContohSel;
  final bool pakaiModelDigit;
}

final sakelarOcrProvider = Provider<SakelarOcr>(
  (ref) => const SakelarOcr(
    kumpulkanContohSel: bool.fromEnvironment('KUMPULKAN_CONTOH_SEL'),
    pakaiModelDigit: bool.fromEnvironment('PAKAI_MODEL_DIGIT'),
  ),
);
