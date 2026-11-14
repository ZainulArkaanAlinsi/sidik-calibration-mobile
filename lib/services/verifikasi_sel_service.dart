import 'api_client.dart';

/// Konfirmasi pembacaan hasil kamera PER BARIS
/// (`POST /api/calibrations/{id}/measurements/verify` dengan
/// `measurement_ids`).
///
/// Sengaja terpisah dari `HistoryService.verifikasiPembacaan`, yang mengirim
/// badan kosong (= "semua yang belum dicek"). Jalur lembar kerja TIDAK boleh
/// memakai bentuk massal itu: "tanpa terima semua" adalah aturan keras, dan
/// satu-satunya yang boleh dikonfirmasi ke server adalah baris yang sel-selnya
/// sudah dicek teknisi. Daftar [measurementIds] yang kosong ditolak di sini
/// (server memperlakukan daftar kosong sebagai "semua").
abstract class VerifikasiSelService {
  Future<void> verifikasi(String token, int sesiId, List<int> measurementIds);
}

class ApiVerifikasiSelService implements VerifikasiSelService {
  ApiVerifikasiSelService(this._api);

  final ApiClient _api;

  @override
  Future<void> verifikasi(
    String token,
    int sesiId,
    List<int> measurementIds,
  ) async {
    if (measurementIds.isEmpty) {
      throw ArgumentError.value(
        measurementIds,
        'measurementIds',
        'tidak boleh kosong: server menafsirkan daftar kosong sebagai "semua"',
      );
    }

    await _api.post(
      '/calibrations/$sesiId/measurements/verify',
      body: <String, dynamic>{'measurement_ids': measurementIds},
      token: token,
    );
  }
}

/// Tiruan untuk test dan mode mock: mencatat tiap panggilan.
class MockVerifikasiSelService implements VerifikasiSelService {
  MockVerifikasiSelService({this.gagal = false});

  final bool gagal;

  /// (sesi, daftar id) per panggilan.
  final List<({int sesiId, List<int> ids})> panggilan = [];

  @override
  Future<void> verifikasi(
    String token,
    int sesiId,
    List<int> measurementIds,
  ) async {
    if (measurementIds.isEmpty) {
      throw ArgumentError.value(measurementIds, 'measurementIds');
    }
    if (gagal) throw Exception('server nggak nyaut');

    panggilan.add((sesiId: sesiId, ids: List.of(measurementIds)));
  }
}
