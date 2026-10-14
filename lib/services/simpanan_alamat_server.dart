import 'package:shared_preferences/shared_preferences.dart';

/// Alamat server API pilihan pengembang, disimpan LOKAL di perangkat.
///
/// ## Kenapa ada di paket bersama
///
/// Dipakai Sidik Studio build dev (`studio/lib/inti/lingkungan_studio.dart`):
/// tablet di lab bisa diarahkan ke laptop pengembang lewat Wi-Fi tanpa
/// `adb reverse` dan tanpa build ulang dengan `--dart-define=API_BASE_URL`.
/// Studio tidak bisa memakai `shared_preferences` langsung — paket itu bukan
/// dependensi langsung Studio, dan dependensi baru butuh izin pemilik proyek
/// — jadi pintunya di sini, di paket yang memang sudah memakainya.
///
/// App lapangan TIDAK memakainya: alamatnya tetap dari `AppConfig.apiBaseUrl`.
///
/// Bukan rahasia (alamat server, bukan kredensial), jadi SharedPreferences,
/// bukan penyimpanan aman. Tidak ikut disapu logout — milik perangkat, bukan
/// milik akun.
abstract class SimpananAlamatServer {
  /// `null` = belum pernah disimpan.
  Future<String?> baca();

  Future<void> simpan(String alamat);

  Future<void> hapus();
}

class PrefsSimpananAlamatServer implements SimpananAlamatServer {
  const PrefsSimpananAlamatServer(this.kunci);

  /// Kunci SharedPreferences — per aplikasi pemakai.
  final String kunci;

  @override
  Future<String?> baca() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kunci);
  }

  @override
  Future<void> simpan(String alamat) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kunci, alamat);
  }

  @override
  Future<void> hapus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kunci);
  }
}

/// Dipakai di test — tidak menyentuh SharedPreferences.
class MemoriSimpananAlamatServer implements SimpananAlamatServer {
  MemoriSimpananAlamatServer([this._alamat]);

  String? _alamat;

  @override
  Future<String?> baca() async => _alamat;

  @override
  Future<void> simpan(String alamat) async => _alamat = alamat;

  @override
  Future<void> hapus() async => _alamat = null;
}
