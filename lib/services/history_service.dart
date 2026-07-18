import '../models/calibration_detail.dart';
import '../models/calibration_history_item.dart';
import 'api_client.dart';

abstract class HistoryService {
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token);

  /// `GET /api/calibrations/{id}` — versi lengkap satu sesi, termasuk
  /// breakdown per titik ukur (`docs/kontrak-api.md` §4).
  Future<CalibrationDetail> ambilDetail(String token, int id);
}

/// Nembak `GET /api/calibrations?mine=true` (live sejak 14 Jul,
/// `docs/kontrak-api.md` §4).
///
/// `mine=true` cuma efektif buat admin & viewer yang mau nyaring punya
/// sendiri — teknisi **selalu** dapat sesi miliknya doang, apa pun query-nya.
class ApiHistoryService implements HistoryService {
  ApiHistoryService(this._api);

  final ApiClient _api;

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async {
    final json = await _api.get('/calibrations?mine=true', token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return data
        .cast<Map<String, dynamic>>()
        .map(CalibrationHistoryItem.fromJson)
        .toList();
  }

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    final json = await _api.get('/calibrations/$id', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return CalibrationDetail.fromJson(data);
  }
}

/// Data tiruan — sekarang cuma dipakai **test**, sama kayak
/// `MockDashboardService` (`GET /api/calibrations` udah live).
class MockHistoryService implements HistoryService {
  MockHistoryService({
    this.kosong = false,
    this.gagal = false,
    this.jeda = Duration.zero,
  });

  final bool kosong;
  final bool gagal;
  final Duration jeda;

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);

    if (gagal) throw Exception('server nggak nyaut');
    if (kosong) return const [];

    final sekarang = DateTime.now();

    return [
      CalibrationHistoryItem(
        id: 1,
        namaAlat: 'Jangka Sorong Mitutoyo',
        namaTeknisi: 'Andi',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 1)),
        status: CalibrationStatus.disetujui,
        keputusan: Keputusan.pass,
        nomorSertifikat: 'CAL/2026/07/0001',
      ),
      CalibrationHistoryItem(
        id: 2,
        namaAlat: 'Timbangan Digital Ohaus',
        namaTeknisi: 'Andi',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 3)),
        status: CalibrationStatus.disetujui,
        keputusan: Keputusan.fail,
        nomorSertifikat: 'CAL/2026/07/0004',
      ),
      CalibrationHistoryItem(
        id: 3,
        namaAlat: 'Termometer Digital Fluke',
        namaTeknisi: 'Sari',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 5)),
        status: CalibrationStatus.menungguApproval,
      ),
      CalibrationHistoryItem(
        id: 4,
        namaAlat: 'Multimeter Fluke 87V',
        namaTeknisi: 'Andi',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 6)),
        status: CalibrationStatus.perluRevisi,
      ),
      CalibrationHistoryItem(
        id: 5,
        namaAlat: 'Pressure Gauge WIKA',
        namaTeknisi: 'Sari',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 9)),
        status: CalibrationStatus.draft,
      ),
    ];
  }

  /// Titik contoh angkanya diambil dari `PERHITUNGAN.csv` master worksheet
  /// pH (`Project-PT-Sidik/Master Olah Data_pH for trial_CSV`) — biar layar
  /// detail bisa dites pakai angka yang realistis, bukan asal-asalan.
  static const _titikContoh = [
    MeasurementResult(
      titikUkur: 4.009244572,
      satuan: 'pH',
      pembacaan: [4, 4, 4, 4, 4],
      rataRata: 4,
      error: -0.009244572,
      koreksi: 0.009244572,
      typeA: 0,
      typeB: 0.01171610510631313,
      typeBKomponen: [
        UncertaintyComponent(nama: 'Standar buffer pH 4', nilai: 0.01),
        UncertaintyComponent(nama: 'Resolusi alat', nilai: 0.005),
      ],
      ketidakpastianGabungan: 0.01171610510631313,
      faktorCakupanK: 1.9706589608358136,
      ketidakpastianDiperluas: 0.02343221021262627,
      keputusan: Keputusan.pass,
    ),
    MeasurementResult(
      titikUkur: 6.9889072,
      satuan: 'pH',
      pembacaan: [7.01, 7.01, 7, 7, 7],
      rataRata: 7.004,
      error: 0.0150928,
      koreksi: -0.0150928,
      typeA: 0.005477225575051544,
      typeB: 0.01047,
      typeBKomponen: [
        UncertaintyComponent(nama: 'Standar buffer pH 7', nilai: 0.01),
        UncertaintyComponent(nama: 'Resolusi alat', nilai: 0.005),
      ],
      ketidakpastianGabungan: 0.010714869473539,
      faktorCakupanK: 1.9706589608358136,
      ketidakpastianDiperluas: 0.02110894987572546,
      keputusan: Keputusan.pass,
    ),
    MeasurementResult(
      titikUkur: 9.9788769,
      satuan: 'pH',
      pembacaan: [10.11, 10.11, 10.11, 10.11, 10.11],
      rataRata: 10.11,
      error: 0.1311231,
      koreksi: -0.1311231,
      typeA: 0,
      typeB: 0.0157,
      typeBKomponen: [
        UncertaintyComponent(nama: 'Standar buffer pH 10', nilai: 0.012),
        UncertaintyComponent(nama: 'Resolusi alat', nilai: 0.005),
      ],
      ketidakpastianGabungan: 0.0157,
      faktorCakupanK: 1.9706589608358136,
      ketidakpastianDiperluas: 0.031,
      keputusan: Keputusan.fail,
    ),
  ];

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (gagal) throw Exception('server nggak nyaut');

    final riwayat = await ambilRiwayat(token);
    final item = riwayat.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Sesi kalibrasi nggak ketemu.'),
    );

    final sudahDihitung =
        item.status == CalibrationStatus.disetujui ||
        item.status == CalibrationStatus.menungguApproval;

    return CalibrationDetail(
      id: item.id,
      namaAlat: item.namaAlat,
      namaTeknisi: item.namaTeknisi,
      tanggalKalibrasi: item.tanggalKalibrasi,
      status: item.status,
      keputusan: item.keputusan,
      certificateId: item.certificateId,
      catatanRevisi: item.catatanRevisi,
      nomorSesi:
          'KAL/2026/07/${item.id.toString().padLeft(4, '0')}',
      standarAcuan: 'Gauge Block Set Grade 0',
      suhuRuang: 21.4,
      kelembaban: 54.5,
      lokasi: 'Lab. Uji A',
      titik: sudahDihitung ? _titikContoh : const [],
    );
  }
}
