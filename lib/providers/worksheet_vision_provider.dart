import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../services/photo_source.dart';
import '../services/worksheet_vision.dart';
import 'auth_provider.dart';

/// Sumber foto buat alur scan, DIPILIH SESUAI PLATFORM.
///
/// Dulu selalu `KameraSumberFoto` tanpa syarat. Di macOS & Windows itu bikin
/// tombol "foto tabel" pasti gagal: `image_picker` nggak punya implementasi
/// kamera di sana sama sekali, dan app macOS-nya juga nggak punya entitlement
/// kamera. Tombolnya kelihatan normal, ditekan, lalu error — tiap kali.
///
/// Sekarang desktop pilih BERKAS gambar ([BerkasSumberFoto]); HP tetap kamera
/// beneran, termasuk di build `USE_MOCK`, biar izin & alur ambil fotonya tetap
/// keuji di perangkat aslinya.
///
/// Di test di-override pakai [MockSumberFoto] biar kameranya nggak kepanggil.
final sumberFotoProvider = Provider<SumberFoto>((ref) {
  if (Platform.isAndroid || Platform.isIOS) return const KameraSumberFoto();
  return const BerkasSumberFoto();
});

/// Ekstraksi tabel worksheet lewat **AI Vision di backend**. Menggantikan OCR
/// on-device (ML Kit) yang dulu sering meleset di lapangan.
///
/// Di `USE_MOCK` / test pakai [MockWorksheetVisionService] supaya alur foto →
/// pra-isi tetap bisa diuji tanpa backend maupun kamera sungguhan.
final worksheetVisionProvider = Provider<WorksheetVisionService>((ref) {
  if (AppConfig.useMock) return MockWorksheetVisionService();
  return ApiWorksheetVisionService(
    ref.watch(apiClientProvider),
    () => ref.read(tokenStorageProvider).read(),
  );
});
