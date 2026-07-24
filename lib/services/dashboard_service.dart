import '../models/dashboard_summary.dart';
import 'api_client.dart';

abstract class DashboardService {
  Future<DashboardSummary> ambilRingkasan(String token);
}

/// Nembak `GET /api/dashboard` (live 14 Jul).
///
/// Isi responsnya beda per role, tapi **mobile nggak ngirim role** — backend
/// yang mutusin dari token: teknisi cuma diitungin kalibrasi miliknya sendiri,
/// admin & viewer lintas-teknisi.
///
/// Cakupan angkanya **nggak seragam**, dan ini penting buat yang baca layarnya:
/// angka sesi (`kalibrasi_*`, `menunggu_approval`, `grafik_pekerjaan`) buat
/// teknisi disaring jadi miliknya sendiri, tapi angka alat & sertifikat
/// (`total_alat`, `alat_overdue`, `total_sertifikat`, `sertifikat_bulan_ini`)
/// **selalu se-lab**. Jadi "Kalibrasi selesai: 2" bareng "Total sertifikat: 15"
/// itu wajar, bukan data ngaco.
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

/// Data tiruan. Sekarang cuma dipakai **test** — buat maksa tiap state
/// dashboard (kosong, gagal, normal) tanpa perlu `php artisan serve` nyala.
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
        kalibrasiSelesai: 0,
        menungguApproval: 0,
        sertifikatBulanIni: 0,
        totalSertifikat: 0,
        // Kosong, bukan deret nol: state "belum ada apa-apa" nggak boleh
        // nampilin grafik sama sekali.
        grafikPekerjaan: [],
      );
    }

    // Dibangun lewat `fromJson` pakai nama field yang PERSIS kayak server,
    // bukan lewat constructor. Waktu mock-nya ngisi `TitikTren` langsung,
    // salah nama field di parser (`periode` vs `bulan`) nggak kelihatan sama
    // sekali dari test — mock-nya ngelewatin parser yang mau diuji.
    return DashboardSummary.fromJson(const {
      'total_alat': 42,
      'alat_overdue': 3,
      'kalibrasi_draft': 2,
      'kalibrasi_selesai': 18,
      'menunggu_approval': 5,
      'sertifikat_bulan_ini': 12,
      'total_sertifikat': 137,
      'grafik_pekerjaan': [
        {'bulan': '2026-02', 'label': 'Feb 2026', 'masuk': 8, 'selesai': 7},
        {'bulan': '2026-03', 'label': 'Mar 2026', 'masuk': 12, 'selesai': 11},
        {'bulan': '2026-04', 'label': 'Apr 2026', 'masuk': 6, 'selesai': 6},
        {'bulan': '2026-05', 'label': 'May 2026', 'masuk': 14, 'selesai': 10},
        {'bulan': '2026-06', 'label': 'Jun 2026', 'masuk': 9, 'selesai': 9},
        {'bulan': '2026-07', 'label': 'Jul 2026', 'masuk': 5, 'selesai': 2},
      ],
    });
  }
}
