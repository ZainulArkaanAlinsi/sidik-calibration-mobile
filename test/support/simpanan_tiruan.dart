import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pasang SharedPreferences tiruan buat test yang menyentuh jalur pelanggan.
///
/// Sejak daftar pelanggan disalin ke HP (`SimpananPelanggan`), dua jalur biasa
/// ikut menyentuh disk: **membuka pemilih pelanggan** (nyimpen salinannya) dan
/// **logout** (mbuangnya).
///
/// Di test, channel plugin-nya nggak ada yang jawab — dan `SharedPreferences
/// .getInstance()` di situ nggak gagal, dia **menggantung**. Jadi yang muncul
/// bukan error yang menjelaskan apa-apa, tapi `pumpAndSettle timed out` di test
/// yang isinya kelihatan nggak ada hubungannya sama penyimpanan sama sekali.
/// Jebakan yang sama pernah kena di `localeProvider`, dan catatannya masih ada
/// di `lewati_onboarding.dart`.
///
/// Panggil di awal `main()` test yang membuka pemilih pelanggan atau logout.
void pasangSimpananTiruan() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
}
