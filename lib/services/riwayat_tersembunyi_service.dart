import 'api_client.dart';
import 'auth_service.dart';
import 'mock_store.dart';

/// Sembunyikan sesi dari Riwayat akun yang login — dan tampilkan lagi
/// (keputusan pemilik 8 Okt 2026).
///
/// `POST /api/calibrations/{id}/sembunyikan` · `DELETE` di alamat yang sama.
/// Dua-duanya menjawab `{"data": {"id": .., "tersembunyi": bool}}`.
///
/// **Cuma tampilan, per akun.** Sesi, pembacaan, dan sertifikatnya tetap utuh
/// di server; akun lain tetap melihatnya. Makanya namanya "sembunyikan", bukan
/// "hapus" — nilai yang sudah diisi teknisi tidak pernah dihapus (ISO/IEC 17025
/// klausul 7.5.2).
///
/// Service sendiri, bukan metode baru di `HistoryService`: beberapa test
/// memalsukan `HistoryService` lewat `implements`, dan menambah anggota di
/// sana memecahkan semuanya tanpa ada yang berubah perilakunya.
abstract class RiwayatTersembunyiService {
  /// Memulangkan nilai `tersembunyi` menurut SERVER — biasanya `true`.
  Future<bool> sembunyikan(String token, int sesiId);

  /// Memulangkan nilai `tersembunyi` menurut SERVER — biasanya `false`.
  Future<bool> tampilkanLagi(String token, int sesiId);
}

class ApiRiwayatTersembunyiService implements RiwayatTersembunyiService {
  ApiRiwayatTersembunyiService(this._api);

  final ApiClient _api;

  @override
  Future<bool> sembunyikan(String token, int sesiId) async {
    final json = await _api.post(
      '/calibrations/$sesiId/sembunyikan',
      body: const <String, dynamic>{},
      token: token,
    );
    return _baca(json, cadangan: true);
  }

  @override
  Future<bool> tampilkanLagi(String token, int sesiId) async {
    final json = await _api.delete(
      '/calibrations/$sesiId/sembunyikan',
      token: token,
    );
    return _baca(json, cadangan: false);
  }

  /// Jawaban 2xx tanpa kunci `tersembunyi` (bentuk yang belum disepakati)
  /// dianggap berhasil sesuai yang diminta — servernya sudah bilang "oke".
  /// Kalau kuncinya ADA, nilai server yang menang.
  bool _baca(Map<String, dynamic> json, {required bool cadangan}) {
    final data = json['data'];
    final isi = data is Map<String, dynamic> ? data : json;
    final nilai = isi['tersembunyi'];
    return nilai is bool ? nilai : cadangan;
  }
}

/// Build mock & test. Penandanya ditaruh di [MockStore] supaya
/// `MockHistoryService` ikut memulangkan `tersembunyi: true` sesudah daftar
/// ditarik ulang — persis yang dilakukan server asli.
class MockRiwayatTersembunyiService implements RiwayatTersembunyiService {
  MockRiwayatTersembunyiService({
    this.gagal = false,
    this.statusGagal,
    this.jeda = Duration.zero,
  });

  /// Lempar galat jaringan umum.
  final bool gagal;

  /// Lempar [ApiException] dengan status ini (mis. 403 buat super admin,
  /// 404 buat sesi yang bukan miliknya). Diperiksa sebelum [gagal].
  final int? statusGagal;

  final Duration jeda;

  /// Jejak panggilan, urut: `(sesiId, tersembunyi)`. Dipakai test buat
  /// mastiin tombolnya beneran nembak service, bukan cuma ngubah layar.
  final List<(int, bool)> panggilan = [];

  @override
  Future<bool> sembunyikan(String token, int sesiId) =>
      _atur(sesiId, tersembunyi: true);

  @override
  Future<bool> tampilkanLagi(String token, int sesiId) =>
      _atur(sesiId, tersembunyi: false);

  Future<bool> _atur(int sesiId, {required bool tersembunyi}) async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    panggilan.add((sesiId, tersembunyi));

    final status = statusGagal;
    if (status != null) {
      throw ApiException(
        status == 403
            ? 'Akun ini tidak bisa menyembunyikan riwayat.'
            : 'Sesi kalibrasi tidak ditemukan.',
        status: status,
      );
    }
    if (gagal) throw Exception('server nggak nyaut');

    MockStore.instance.aturTersembunyi(sesiId, tersembunyi: tersembunyi);
    return tersembunyi;
  }
}
