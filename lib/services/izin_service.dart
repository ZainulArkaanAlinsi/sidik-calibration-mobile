import '../models/izin.dart';
import 'api_client.dart';

/// Matriks peran — `GET /api/me/permissions`.
abstract class IzinService {
  Future<Izin> ambil(String token);
}

class ApiIzinService implements IzinService {
  ApiIzinService(this._api);

  final ApiClient _api;

  @override
  Future<Izin> ambil(String token) async {
    try {
      final json = await _api.get('/me/permissions', token: token);
      return Izin.fromJson(json);
    } catch (_) {
      // Gagal ambil izin **nggak boleh** bikin app mati atau ngunci semua
      // tombol. Balikin kosong; tiap pemanggil punya cadangan aturan peran
      // lama, jadi paling buruk perilakunya sama kayak sebelum matriks peran
      // dipasang.
      //
      // Ditelan di sini, bukan di layar: kalau tiap layar harus nanganin ini
      // sendiri, cepat atau lambat ada yang lupa dan tombolnya ilang tanpa
      // penjelasan.
      return Izin.kosong;
    }
  }
}

class MockIzinService implements IzinService {
  MockIzinService({this.izin = Izin.kosong});

  final Izin izin;

  @override
  Future<Izin> ambil(String token) async => izin;
}
