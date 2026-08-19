import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/photo_source.dart';

/// Sumber foto buat alur pindai, DIPILIH SESUAI PLATFORM.
///
/// Dulu selalu `KameraSumberFoto` tanpa syarat. Di macOS & Windows itu bikin
/// tombol foto pasti gagal: `image_picker` nggak punya implementasi kamera di
/// sana sama sekali, dan app macOS-nya juga nggak punya entitlement kamera.
/// Tombolnya kelihatan normal, ditekan, lalu error — tiap kali.
///
/// Sekarang desktop pilih BERKAS gambar ([BerkasSumberFoto]); HP tetap kamera
/// beneran, termasuk di build `USE_MOCK`, biar izin & alur ambil fotonya tetap
/// keuji di perangkat aslinya.
///
/// Di test di-override pakai [MockSumberFoto] biar kameranya nggak kepanggil.
///
/// Berkasnya sendiri: dulu numpang di `worksheet_vision_provider.dart` — file
/// jalur AI Vision, yang bakal dicabut. Kamera nggak boleh mati gara-gara
/// jalur lain dihapus, jadi providernya berdiri sendiri.
final sumberFotoProvider = Provider<SumberFoto>((ref) {
  if (Platform.isAndroid || Platform.isIOS) return const KameraSumberFoto();

  return const BerkasSumberFoto();
});
