import 'package:package_info_plus/package_info_plus.dart';

import '../models/versi_aplikasi.dart';
import 'api_client.dart';

/// Sumber jawaban "aplikasimu ketinggalan atau tidak".
///
/// Dua sisi pertanyaannya dipegang di sini sekaligus, dan itu disengaja:
/// versi yang TERPASANG cuma bisa dibaca dari paket aplikasi, versi TERBARU
/// cuma bisa ditanyakan ke server, dan yang berguna itu hasil membandingkan
/// keduanya. Dipisah ke dua tempat, pemanggilnya harus tahu urutan &
/// aturannya — dan aturan perbandingan versi itu yang paling gampang salah
/// (lihat [bandingkanVersi]).
abstract class VersiService {
  /// Versi yang sedang terpasang di HP ini, mis. `1.0.58`.
  Future<String> versiTerpasang();

  /// Nomor build yang terpasang, mis. `58`. Dipakai buat ditampilkan, bukan
  /// buat membandingkan — yang dibandingkan nama versinya.
  Future<String> buildTerpasang();

  /// Versi terbaru yang terbit. `null` = belum bisa tahu (server/GitHub tidak
  /// terjawab, atau belum ada rilis). Bukan error.
  Future<VersiAplikasi?> versiTerbaru();
}

class ApiVersiService implements VersiService {
  ApiVersiService(this._api);

  final ApiClient _api;

  PackageInfo? _paket;

  Future<PackageInfo> _info() async => _paket ??= await PackageInfo.fromPlatform();

  @override
  Future<String> versiTerpasang() async => (await _info()).version;

  @override
  Future<String> buildTerpasang() async => (await _info()).buildNumber;

  @override
  Future<VersiAplikasi?> versiTerbaru() async {
    try {
      // TANPA token — endpoint-nya publik, dan itu disengaja: layar yang paling
      // butuh tahu "aplikasimu ketinggalan" justru layar login, yang belum
      // punya token sama sekali.
      final json = await _api.get('/app/versi-terbaru');

      return VersiAplikasi.fromJson(json);
    } catch (_) {
      // Gagal mengecek versi TIDAK BOLEH kelihatan sebagai error di layar.
      // Ini pemeriksaan latar yang jalan tiap aplikasi dibuka; kalau dia
      // melempar, yang rusak justru pembukaan aplikasinya — persis kebalikan
      // dari gunanya. Teknisi di lapangan sering tanpa sinyal, dan itu keadaan
      // yang sah, bukan kesalahan.
      return null;
    }
  }
}

/// Versi terpasang yang dipatok — dipakai test & mode demo.
class MockVersiService implements VersiService {
  MockVersiService({
    this.terpasang = '1.0.10',
    this.build = '10',
    this.terbaru,
    this.gagal = false,
  });

  final String terpasang;
  final String build;

  /// `null` = server menjawab "tidak tersedia".
  final VersiAplikasi? terbaru;

  /// Beda dari [terbaru] yang null: yang ini melempar, buat memastikan
  /// pemanggilnya benar-benar menelan kegagalan dan bukan cuma kebetulan
  /// menerima null.
  final bool gagal;

  @override
  Future<String> versiTerpasang() async => terpasang;

  @override
  Future<String> buildTerpasang() async => build;

  @override
  Future<VersiAplikasi?> versiTerbaru() async {
    if (gagal) throw Exception('server nggak nyaut');

    return terbaru;
  }
}
