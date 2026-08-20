import '../models/autoclave_hasil.dart';
import 'api_client.dart';

/// Olah data Autoklaf lewat `POST /api/calibrations/autoclave/preview`.
///
/// Endpoint terpisah dari `/calibrations/preview` karena bentuk data Autoklaf
/// (3 disk suhu × titik waktu + 1 titik tekanan berkonversi satuan) nggak muat
/// di model "titik ukur + pengulangan" alat lain. Tabel kalibrator & CMC ada di
/// server; payload cuma data ukur teknisi.
abstract class AutoclaveService {
  /// [payload] = data ukur mentah, dirakit `LembarKerjaState.payloadMatriks`
  /// dari jalur `kode_data` yang dikirim backend di `bagian.matriks`.
  Future<AutoclaveHasil> pratinjau(String token, Map<String, dynamic> payload);

  /// Simpan sesi Autoklaf (`POST /calibrations/autoclave`). [payload] gabungan
  /// identitas (equipment_id, tanggal, kondisi lingkungan) + data ukur.
  /// Balik id sesi tersimpan.
  Future<int> simpan(String token, Map<String, dynamic> payload);
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

  @override
  Future<int> simpan(String token, Map<String, dynamic> payload) async {
    final json = await _api.post(
      '/calibrations/autoclave',
      token: token,
      body: payload,
    );
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }
}
