import '../models/undangan_pelanggan.dart';
import 'api_client.dart';
import 'auth_service.dart' show AuthException;

/// Undang anggota perusahaan pelanggan ke app SIDIK Pelanggan.
///
/// Galat 422 (email sudah anggota aktif, batas anggota) dan 403 dilempar
/// sebagai `AuthException` oleh `ApiClient` dengan pesan ASLI server — layar
/// menampilkannya apa adanya.
abstract class UndanganPelangganService {
  Future<UndanganPelanggan> undang(
    String token,
    int customerId, {
    required String email,
    required PeranUndangan peran,
  });
}

class ApiUndanganPelangganService implements UndanganPelangganService {
  ApiUndanganPelangganService(this._api);

  final ApiClient _api;

  @override
  Future<UndanganPelanggan> undang(
    String token,
    int customerId, {
    required String email,
    required PeranUndangan peran,
  }) async {
    // POST tanpa `client_request_id` TIDAK diulang otomatis oleh ApiClient —
    // undangan baru ke email yang sama membatalkan kode lama, jadi mengulang
    // diam-diam akan mematikan kode yang baru saja ditampilkan.
    final json = await _api.post(
      '/customers/$customerId/undangan',
      token: token,
      body: {'email': email, 'peran': peran.kirim},
    );
    return UndanganPelanggan.fromJson(json);
  }
}

/// Data tiruan buat test dan mode mock.
class MockUndanganPelangganService implements UndanganPelangganService {
  MockUndanganPelangganService({
    this.kode = 'K7M2QX9P',
    this.galat,
    this.jeda = Duration.zero,
  });

  /// `null` meniru server lama yang belum mengirim kode.
  final String? kode;
  final AuthException? galat;
  final Duration jeda;

  int jumlahPanggilan = 0;
  final List<({int customerId, String email, PeranUndangan peran})> riwayat =
      [];

  @override
  Future<UndanganPelanggan> undang(
    String token,
    int customerId, {
    required String email,
    required PeranUndangan peran,
  }) async {
    jumlahPanggilan++;
    riwayat.add((customerId: customerId, email: email, peran: peran));
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (galat != null) throw galat!;

    return UndanganPelanggan(
      id: jumlahPanggilan,
      email: email,
      peran: peran.kirim,
      berlakuSampai: DateTime.now().add(const Duration(days: 7)),
      kode: kode,
    );
  }
}
