import '../models/calibration_detail.dart';
import '../models/calibration_history_item.dart';
import 'api_client.dart';

abstract class HistoryService {
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token);

  /// Antrean approval admin: **semua kiriman dari semua teknisi**, bukan cuma
  /// punya sendiri (`GET /api/calibrations?status=menunggu_approval`).
  ///
  /// Beda dari [ambilRiwayat] yang pakai `mine=true`. Teknisi yang nembak ini
  /// tetap cuma dapat sesi miliknya — penyaringnya di controller backend,
  /// bukan di query param dari mobile.
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(String token);

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
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async {
    final json = await _api.get(
      '/calibrations?status=menunggu_approval',
      token: token,
    );
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
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async {
    final semua = await ambilRiwayat(token);
    return semua
        .where((s) => s.status == CalibrationStatus.menungguApproval)
        .toList();
  }

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
        certificateId: 901,
      ),
      CalibrationHistoryItem(
        id: 2,
        namaAlat: 'Timbangan Digital Ohaus',
        namaTeknisi: 'Andi',
        tanggalKalibrasi: sekarang.subtract(const Duration(days: 3)),
        status: CalibrationStatus.disetujui,
        keputusan: Keputusan.fail,
        nomorSertifikat: 'CAL/2026/07/0004',
        certificateId: 902,
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
  /// detail bisa dites pakai angka yang realistis, bukan asal-asalan. Bentuk
  /// field-nya dikunci ke `CalibrationResource::toArray()` backend
  /// (`sidik-calibration-api`, commit `06af54e`).
  static const _titikContoh = [
    MeasurementResult(
      titikKe: 1,
      titikUkur: 4.009244572,
      rataRata: 4,
      error: -0.009244572,
      koreksi: 0.009244572,
      standarDeviasi: 0,
      jumlahPengulangan: 5,
      typeA: 0,
      typeB: 0.01171610510631313,
      typeBComponents: [
        UncertaintyComponent(
          sumber: 'ketidakpastian_standar',
          keterangan: 'Sertifikat standar pH Buffer Solution 4 (U=0.02 pH, k=2)',
          distribusi: 'normal',
          nilai: 0.01,
        ),
        UncertaintyComponent(
          sumber: 'resolusi_alat',
          keterangan: 'Resolusi alat 0.01 pH',
          distribusi: 'persegi',
          nilai: 0.005,
        ),
      ],
      ketidakpastianGabungan: 0.01171610510631313,
      faktorCakupanK: 1.9706589608358136,
      ketidakpastianDiperluas: 0.02343221021262627,
      toleransi: 0.05,
      keputusan: Keputusan.pass,
      standarAcuan: StandardRef(id: 2, nama: 'pH Buffer Solution 4', noSertifikat: 'HC32513535'),
    ),
    MeasurementResult(
      titikKe: 2,
      titikUkur: 6.9889072,
      rataRata: 7.004,
      error: 0.0150928,
      koreksi: -0.0150928,
      standarDeviasi: 0.005477225575051544,
      jumlahPengulangan: 5,
      typeA: 0.005477225575051544,
      typeB: 0.01047,
      typeBComponents: [
        UncertaintyComponent(
          sumber: 'ketidakpastian_standar',
          keterangan: 'Sertifikat standar pH Buffer Solution 7 (U=0.02 pH, k=2)',
          distribusi: 'normal',
          nilai: 0.01,
        ),
        UncertaintyComponent(
          sumber: 'resolusi_alat',
          keterangan: 'Resolusi alat 0.01 pH',
          distribusi: 'persegi',
          nilai: 0.005,
        ),
      ],
      ketidakpastianGabungan: 0.010714869473539,
      faktorCakupanK: 1.9706589608358136,
      ketidakpastianDiperluas: 0.02110894987572546,
      toleransi: 0.05,
      keputusan: Keputusan.pass,
      standarAcuan: StandardRef(id: 3, nama: 'pH Buffer Solution 7', noSertifikat: 'HC46341939'),
    ),
    MeasurementResult(
      titikKe: 3,
      titikUkur: 9.9788769,
      rataRata: 10.11,
      error: 0.1311231,
      koreksi: -0.1311231,
      standarDeviasi: 0,
      jumlahPengulangan: 5,
      typeA: 0,
      typeB: 0.0157,
      typeBComponents: [
        UncertaintyComponent(
          sumber: 'ketidakpastian_standar',
          keterangan: 'Sertifikat standar pH Buffer Solution 10 (U=0.024 pH, k=2)',
          distribusi: 'normal',
          nilai: 0.012,
        ),
        UncertaintyComponent(
          sumber: 'resolusi_alat',
          keterangan: 'Resolusi alat 0.01 pH',
          distribusi: 'persegi',
          nilai: 0.005,
        ),
      ],
      ketidakpastianGabungan: 0.0157,
      faktorCakupanK: 1.9706589608358136,
      ketidakpastianDiperluas: 0.031,
      toleransi: 0.05,
      keputusan: Keputusan.fail,
      standarAcuan: StandardRef(id: 4, nama: 'pH Buffer Solution 10', noSertifikat: 'HC45400338'),
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
      nomorSesi: 'KAL/2026/07/${item.id.toString().padLeft(4, '0')}',
      standarAcuan: const StandardRef(id: 1, nama: 'Gauge Block Set Grade 0'),
      suhuRuang: 21.4,
      kelembaban: 54.5,
      lokasi: 'lab',
      sertifikat: item.certificateId == null
          ? null
          : CertificateRef(
              id: item.certificateId!,
              nomor: item.nomorSertifikat ?? 'CAL/2026/07/0000',
              status: 'terbit',
              pdfUrl: 'https://contoh.sidik.co.id/certificates/${item.certificateId}/download',
            ),
      titik: sudahDihitung ? _titikContoh : const [],
    );
  }
}
