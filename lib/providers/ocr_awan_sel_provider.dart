import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../models/izin.dart';
import '../services/ocr_awan_sel_service.dart';
import '../services/saran_ocr_awan.dart';
import 'auth_provider.dart';
import 'izin_provider.dart';
import 'ocr_awan_provider.dart';
import 'sakelar_ocr_provider.dart';

/// Klien `POST /api/ocr/sel-awan` (kontrak 22B). Mode mock memakai servis
/// palsu yang bawaannya menjawab "awan belum aktif", jadi layar jatuh ke jalur
/// manual seperti saat server mematikan fiturnya.
final ocrAwanSelServiceProvider = Provider<OcrAwanSelService>((ref) {
  if (AppConfig.useMock) return MockOcrAwanSelService();

  return ApiOcrAwanSelService(ref.watch(apiClientProvider));
});

/// Penjalur usulan awan: pecah per 20 sel, jeda sesuai limiter 4 per menit,
/// berhenti pada galat pertama. Tidak pernah melempar.
///
/// Gerbang [PenjalurSaranAwan.nyala] dibaca SAAT DIPANGGIL (bukan saat
/// provider dibuat), jadi sakelar klien atau fitur yang dimatikan Super Admin
/// langsung berlaku. Mati = tanpa baca token dan tanpa jaringan.
final penjalurSaranAwanProvider = Provider<PenjalurSaranAwan>((ref) {
  return PenjalurSaranAwan(
    service: ref.watch(ocrAwanSelServiceProvider),
    bacaToken: () => ref.read(tokenStorageProvider).read(),
    nyala: () => ocrAwanBolehDitawarkan(
      sakelar: ref.read(sakelarOcrProvider),
      izin: ref.read(izinProvider).value ?? Izin.kosong,
    ),
  );
});
