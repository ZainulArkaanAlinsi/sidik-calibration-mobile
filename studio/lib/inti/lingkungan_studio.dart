import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidik_calibration/core/config/app_config.dart';
import 'package:sidik_calibration/services/simpanan_alamat_server.dart';

/// Versi Studio = `version:` di `studio/pubspec.yaml`, APA ADANYA.
///
/// Ditulis tangan karena membaca versi saat jalan butuh `package_info_plus`
/// sebagai dependensi langsung Studio (dependensi baru = izin pemilik).
/// Supaya tidak basi diam-diam, test "versiStudio = version di pubspec.yaml
/// Studio" (`test/klien_studio_test.dart`) membaca pubspec dan gagal bila
/// keduanya beda — naikkan keduanya bersamaan. Test itu membaca
/// `pubspec.yaml` relatif ke direktori kerja, jadi jalankan dari `studio/`.
const String versiStudio = '0.1.0+1';

/// Nilai header `X-Klien` (FR-STU-003). Server memakainya untuk log dan
/// penolakan versi usang (`426 klien_kedaluwarsa`), BUKAN untuk izin.
const String namaKlienStudio = 'sidik-studio';

/// Header identitas yang menempel di SETIAP request Studio — dipasang lewat
/// penimpaan `apiClientProvider` (`inti/penimpaan.dart`). App lapangan tidak
/// mengirimnya.
const Map<String, String> headerKlienStudio = {
  'X-Klien': namaKlienStudio,
  'X-Versi-Klien': versiStudio,
};

/// Alamat API yang dituju (`--dart-define=API_BASE_URL`, lewat `AppConfig`
/// paket bersama) — atau, HANYA di build `APP_ENV=dev`, alamat yang disimpan
/// lewat isian "Alamat server" di layar masuk ([alamatServerDevProvider]).
/// Provider supaya bilah status & layar masuk menyebut server yang SAMA
/// dengan yang ditembak `ApiClient`, dan test bisa mengarahkannya ke server
/// lokal.
final alamatServerStudioProvider = Provider<String>((ref) {
  if (!ref.watch(isianServerDevStudioProvider)) return AppConfig.apiBaseUrl;
  return ref.watch(alamatServerDevProvider) ?? AppConfig.apiBaseUrl;
});

// ─────────────────────────────────────────── alamat server (build dev saja)

/// Kunci SharedPreferences alamat server dev Studio.
const kunciAlamatServerDev = 'studio.dev.alamat_server';

/// Isian "Alamat server" tampil — dan nilai tersimpan DIPAKAI — hanya di
/// build `APP_ENV=dev`. Build rilis mengabaikan nilai tersimpan sama sekali:
/// sisa pengujian di perangkat tidak boleh membelokkan Studio produksi ke
/// laptop pengembang. Provider supaya test bisa menimpanya.
final isianServerDevStudioProvider = Provider<bool>(
  (ref) => appEnvStudio == 'dev',
);

/// Tempat alamat dev disimpan (paket bersama — Studio tidak memakai
/// `shared_preferences` langsung).
final simpananAlamatServerDevProvider = Provider<SimpananAlamatServer>(
  (ref) => const PrefsSimpananAlamatServer(kunciAlamatServerDev),
);

/// Alamat dev yang dibaca dari disk SEBELUM frame pertama ([main]), supaya
/// request pertama (pemeriksaan token tersimpan) sudah menuju server itu.
final alamatServerDevAwalProvider = Provider<String?>((ref) => null);

/// Alamat server pilihan pengembang; `null` = bawaan build.
final alamatServerDevProvider = NotifierProvider<AlamatServerDev, String?>(
  AlamatServerDev.new,
);

class AlamatServerDev extends Notifier<String?> {
  @override
  String? build() => ref.watch(isianServerDevStudioProvider)
      ? ref.watch(alamatServerDevAwalProvider)
      : null;

  /// Simpan & pakai SEKARANG (`ApiClient` dibangun ulang). Melempar
  /// [FormatException] bila bukan alamat http(s) yang sah.
  Future<void> simpan(String mentah) async {
    final alamat = normalisasiAlamatServer(mentah);
    if (alamat == null) {
      throw FormatException('Alamat server tidak sah', mentah);
    }
    await ref.read(simpananAlamatServerDevProvider).simpan(alamat);
    state = alamat;
  }

  /// Kembali ke `API_BASE_URL` build.
  Future<void> pakaiBawaan() async {
    await ref.read(simpananAlamatServerDevProvider).hapus();
    state = null;
  }
}

/// `http(s)://host[:port][/jalur]` tanpa garis miring akhir; selain itu
/// `null`.
String? normalisasiAlamatServer(String mentah) {
  var teks = mentah.trim();
  while (teks.endsWith('/')) {
    teks = teks.substring(0, teks.length - 1);
  }
  final uri = Uri.tryParse(teks);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  if (uri.hasQuery || uri.hasFragment) return null;
  return teks;
}

/// Dibaca `main()` sebelum `runApp`. [dev] bawaan = build `APP_ENV=dev`;
/// selain dev selalu `null` — nilai tersimpan tidak pernah dibaca.
/// Penyimpanan yang rusak tidak menghalangi Studio terbuka.
Future<String?> bacaAlamatServerDevAwal({
  SimpananAlamatServer simpanan = const PrefsSimpananAlamatServer(
    kunciAlamatServerDev,
  ),
  bool dev = appEnvStudio == 'dev',
}) async {
  if (!dev) return null;
  try {
    final tersimpan = await simpanan.baca();
    return tersimpan == null ? null : normalisasiAlamatServer(tersimpan);
  } catch (e) {
    debugPrint('Alamat server dev tidak terbaca: $e');
    return null;
  }
}

/// `host:port` dari [alamat] untuk ditampilkan; alamat utuh bila tak terurai.
String hostServer(String alamat) {
  final uri = Uri.tryParse(alamat);
  return (uri == null || uri.authority.isEmpty) ? alamat : uri.authority;
}

/// `--dart-define=APP_ENV=...` APA ADANYA.
///
/// Sengaja tidak memakai `AppConfig.env` paket bersama: di sana nilai kosong
/// dianggap `dev` (bawaan app lapangan), sedangkan petunjuk akun uji Studio
/// cuma boleh muncul kalau build-nya MEMANG dinyatakan dev. Build Studio tanpa
/// `APP_ENV` = tanpa petunjuk.
const String appEnvStudio = String.fromEnvironment('APP_ENV');

/// Tampilkan petunjuk akun uji di layar masuk? Provider supaya test bisa
/// menimpanya — konstanta kompilasi tidak bisa diubah dari test.
final petunjukDevStudioProvider = Provider<bool>(
  (ref) => appEnvStudio == 'dev',
);

/// Mode tema Studio. Terang bawaan (keputusan desain S1), gelap tersedia.
///
/// Belum disimpan ke disk — pilihan kembali ke terang tiap Studio dibuka.
/// Sengaja: belum ada keputusan tema per akun atau per perangkat.
final modeTemaStudioProvider = NotifierProvider<ModeTemaStudio, ThemeMode>(
  ModeTemaStudio.new,
);

class ModeTemaStudio extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void balik() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}
