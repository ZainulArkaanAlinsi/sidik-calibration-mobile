import '../models/dashboard_summary.dart';
import 'api_client.dart';

abstract class DashboardService {
  Future<DashboardSummary> ambilRingkasan(String token);
}

/// Nembak `GET /api/dashboard`. **Belum dipakai** — endpoint-nya belum ada di
/// backend. Ditulis sekarang biar hari Kamis (23 Jul, "connect ke API asli")
/// tinggal ganti satu baris di `dashboardServiceProvider`.
class ApiDashboardService implements DashboardService {
  ApiDashboardService(this._api);

  final ApiClient _api;

  @override
  Future<DashboardSummary> ambilRingkasan(String token) async {
    final json = await _api.get('/dashboard', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;

    return DashboardSummary.fromJson(data);
  }
}

/// Data tiruan buat ngerjain layar duluan — sesuai task 21 Jul yang emang
/// minta "belum connect data asli".
class MockDashboardService implements DashboardService {
  MockDashboardService({
    this.kosong = false,
    this.gagal = false,
    this.jeda = const Duration(milliseconds: 600),
  });

  /// Buat nguji state `empty` (akun baru, belum ada alat sama sekali).
  final bool kosong;

  /// Buat nguji state `error` + tombol coba lagi.
  final bool gagal;

  /// Jeda palsu biar skeleton loading beneran keliatan waktu dipakai manual.
  /// Di test dibikin `Duration.zero` — kalau nggak, timer-nya masih
  /// menggantung waktu test kelar dan Flutter nganggep itu error.
  final Duration jeda;

  @override
  Future<DashboardSummary> ambilRingkasan(String token) async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);

    if (gagal) throw Exception('server nggak nyaut');

    if (kosong) {
      return const DashboardSummary(
        totalAlat: 0,
        alatOverdue: 0,
        kalibrasiDraft: 0,
        menungguApproval: 0,
        sertifikatBulanIni: 0,
      );
    }

    return const DashboardSummary(
      totalAlat: 42,
      alatOverdue: 3,
      kalibrasiDraft: 2,
      menungguApproval: 5,
      sertifikatBulanIni: 12,
    );
  }
}
