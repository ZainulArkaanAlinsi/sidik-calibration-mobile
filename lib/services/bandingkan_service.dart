import '../models/bandingkan.dart';
import 'api_client.dart';

/// `GET /api/calibrations/{id}/bandingkan` — asli teknisi lawan sekarang.
/// Admin & super admin saja (teknisi 403, lab lain 404).
abstract class BandingkanService {
  Future<Bandingkan> ambil(String token, int calibrationId);
}

class ApiBandingkanService implements BandingkanService {
  ApiBandingkanService(this._api);

  final ApiClient _api;

  @override
  Future<Bandingkan> ambil(String token, int calibrationId) async {
    final json = await _api.get(
      '/calibrations/$calibrationId/bandingkan',
      token: token,
    );
    return Bandingkan.dariJson(json);
  }
}

/// Tiruan untuk mode mock & test.
class MockBandingkanService implements BandingkanService {
  MockBandingkanService({this.hasil, this.gagal = false});

  final Bandingkan? hasil;
  final bool gagal;

  @override
  Future<Bandingkan> ambil(String token, int calibrationId) async {
    if (gagal) throw Exception('server nggak nyaut');
    return hasil ??
        Bandingkan(
          sesiId: calibrationId,
          status: 'menunggu_approval',
          adaAsli: false,
          jenis: 'pembacaan',
          totalSel: 0,
          jumlahBerubah: 0,
          sel: const [],
        );
  }
}
