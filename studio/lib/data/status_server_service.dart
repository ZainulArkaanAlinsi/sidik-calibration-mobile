import 'package:sidik_calibration/services/api_client.dart';

/// Ringkasan `GET /api/health` untuk bilah status (FR-STU-013).
///
/// Cuma yang ditampilkan Studio. Kunci yang tidak dikirim server (server lama)
/// jadi `null` — ditampilkan "tidak diketahui", bukan ditebak.
class StatusServer {
  const StatusServer({this.realtimeNyala, this.versiApi, this.lingkungan});

  /// `realtime.nyala`: driver siaran bukan `log`/`null`.
  final bool? realtimeNyala;

  /// `deploy.versi`: commit yang berjalan di server.
  final String? versiApi;

  /// `deploy.lingkungan` (`production`, `local`, …).
  final String? lingkungan;

  factory StatusServer.fromJson(Map<String, dynamic> json) {
    final realtime = json['realtime'];
    final deploy = json['deploy'];

    String? teks(Object? nilai) =>
        nilai is String && nilai.trim().isNotEmpty ? nilai.trim() : null;

    return StatusServer(
      realtimeNyala: switch (realtime) {
        {'nyala': final bool nyala} => nyala,
        _ => null,
      },
      versiApi: deploy is Map ? teks(deploy['versi']) : null,
      lingkungan: deploy is Map ? teks(deploy['lingkungan']) : null,
    );
  }
}

/// Sumber [StatusServer]. Pola abstrak + `Api…` + `Mock…` repo mobile.
abstract class LayananStatusServer {
  /// Melempar bila server tidak terjangkau / menjawab galat.
  Future<StatusServer> ambil();
}

/// `GET /api/health` — publik, tanpa token, aman diulang.
class ApiLayananStatusServer implements LayananStatusServer {
  ApiLayananStatusServer(this._api);

  final ApiClient _api;

  @override
  Future<StatusServer> ambil() async =>
      StatusServer.fromJson(await _api.get('/health'));
}

/// Untuk `USE_MOCK=true` dan test.
class MockLayananStatusServer implements LayananStatusServer {
  MockLayananStatusServer({
    this.status = const StatusServer(
      realtimeNyala: false,
      versiApi: 'a1b2c3d4e5f6',
      lingkungan: 'local',
    ),
    this.galat,
  });

  final StatusServer status;

  /// Bila diisi, [ambil] melempar ini (server tak terjangkau).
  final Object? galat;

  int dipanggil = 0;

  @override
  Future<StatusServer> ambil() async {
    dipanggil++;
    final g = galat;
    if (g != null) throw g;
    return status;
  }
}
