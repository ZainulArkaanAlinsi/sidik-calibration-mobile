import '../models/autoclave_hasil.dart';
import 'api_client.dart';

/// Olah data Autoklaf lewat `POST /api/calibrations/autoclave/preview`.
///
/// Endpoint terpisah dari `/calibrations/preview` karena bentuk data Autoklaf
/// (3 disk suhu × titik waktu + 1 titik tekanan berkonversi satuan) nggak muat
/// di model "titik ukur + pengulangan" alat lain. Tabel kalibrator & CMC ada di
/// server; payload cuma data ukur teknisi.
abstract class AutoclaveService {
  /// [payload] = data ukur mentah (lihat `AutoclaveInputScreen._payload`).
  Future<AutoclaveHasil> pratinjau(String token, Map<String, dynamic> payload);
}

class ApiAutoclaveService implements AutoclaveService {
  ApiAutoclaveService(this._api);

  final ApiClient _api;

  @override
  Future<AutoclaveHasil> pratinjau(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final json = await _api.post(
      '/calibrations/autoclave/preview',
      token: token,
      body: payload,
    );
    return AutoclaveHasil.fromJson(json);
  }
}
