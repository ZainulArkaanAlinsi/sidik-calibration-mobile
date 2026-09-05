import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/simpanan_pelanggan.dart';

/// Berkas sendiri, bukan ikut nebeng di `master_data_provider.dart`.
///
/// Yang memakainya ada dua dan letaknya berjauhan: `customerLookupProvider`
/// (yang mengisi simpanannya) dan `AuthController` (yang membuangnya waktu
/// logout). Ditaruh di `master_data_provider.dart`, jalur logout jadi
/// mengimpor berkas yang mengimpor `auth_provider.dart` — lingkaran yang
/// Dart-nya sendiri masih terima, tapi yang bikin urutan inisialisasi susah
/// dibaca dan gampang salah waktu ada yang menambah provider di situ.
final simpananPelangganProvider = Provider<SimpananPelanggan>(
  (ref) => const SimpananPelanggan(),
);
