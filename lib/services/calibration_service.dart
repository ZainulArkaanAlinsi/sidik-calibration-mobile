import '../models/calibration_draft.dart';
import 'api_client.dart';

abstract class CalibrationService {
  /// Balikin `id` sesi yang baru dibikin.
  Future<int> buatSesi(String token, CalibrationDraft draft);
}

/// Nembak `POST /api/calibrations` — live sejak 14 Jul
/// (`docs/kontrak-api.md` §4).
class ApiCalibrationService implements CalibrationService {
  ApiCalibrationService(this._api);

  final ApiClient _api;

  @override
  Future<int> buatSesi(String token, CalibrationDraft draft) async {
    final json = await _api.post(
      '/calibrations',
      token: token,
      body: draft.toJson(),
    );
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }
}

/// Data tiruan buat test.
class MockCalibrationService implements CalibrationService {
  MockCalibrationService({this.gagal = false});

  final bool gagal;

  @override
  Future<int> buatSesi(String token, CalibrationDraft draft) async {
    if (gagal) throw Exception('server nggak nyaut');
    return 999;
  }
}
