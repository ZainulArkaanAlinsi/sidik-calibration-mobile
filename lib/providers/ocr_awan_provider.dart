import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/izin.dart';
import 'izin_provider.dart';
import 'sakelar_ocr_provider.dart';

/// Boleh nggak OCR awan atas potongan sel DITAWARKAN ke teknisi?
///
/// Ya hanya bila SEMUA ini benar:
///  1. sakelar klien [SakelarOcr.ocrAwanSel] menyala (bawaan provider MENYALA sejak 26 Nov 2026; konstruktor `const SakelarOcr()` MATI);
///  2. backend sudah menjawab matriks izin ([Izin.adaJawaban]) — selama izin
///     belum sampai atau gagal diambil, fitur yang memakai biaya dan data
///     pelanggan tidak ditawarkan (gagal tertutup);
///  3. Super Admin tidak mematikan `ocr_cloud_sel` maupun `pindai_lembar`
///     ([Izin.fiturNonaktif]).
///
/// Ini hanya menyembunyikan tombol. Server tetap penegak: bila tombol sampai
/// tertekan saat fitur mati, jawabannya `503 fitur_dimatikan`
/// ([JenisGalatOcrAwan.fiturMati]), dan server juga punya sakelar sendiri
/// (`GOOGLE_VISION_AKTIF`) yang menang atas klien.
///
/// Fungsi murni, tanpa provider turunan: `izinProvider` sengaja dibaca
/// langsung oleh layar (lihat catatan `setState() called during build` di
/// `izin_provider.dart`).
bool ocrAwanBolehDitawarkan({required SakelarOcr sakelar, required Izin izin}) {
  if (!sakelar.ocrAwanSel) return false;
  if (!izin.adaJawaban) return false;
  if (izin.fiturMati(KodeFitur.ocrCloudSel)) return false;
  if (izin.fiturMati(KodeFitur.pindaiLembar)) return false;

  return true;
}

extension OcrAwanRef on WidgetRef {
  /// Jalan pintas layar: tombol OCR awan boleh tampil? Dibaca dengan `watch`,
  /// jadi tombol ikut hilang bila izin ditarik ulang dan fitur sudah mati.
  bool get ocrAwanTersedia => ocrAwanBolehDitawarkan(
    sakelar: watch(sakelarOcrProvider),
    izin: watch(izinProvider).value ?? Izin.kosong,
  );
}
