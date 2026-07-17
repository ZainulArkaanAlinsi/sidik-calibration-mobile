import '../models/calibration_history_item.dart';
import 'api_client.dart';

abstract class HistoryService {
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token);
}

/// Nembak `GET /api/calibrations?mine=true` (`docs/kontrak-api.md` §4).
///
/// `mine=true` cuma efektif buat admin & viewer yang mau nyaring punya
/// sendiri — teknisi **selalu** dapat sesi miliknya doang, apa pun query-nya.
/// Belum dipakai di [historyProvider]: endpoint kalibrasinya sendiri belum
/// live di backend (minggu 4), jadi provider masih nunjuk ke
/// [MockHistoryService] sampai itu jalan.
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
}

/// Data tiruan buat layar Riwayat & test — dipakai sampai
/// `GET /api/calibrations` beneran live.
class MockHistoryService implements HistoryService {
  MockHistoryService({
    this.kosong = false,
    this.gagal = false,
    // Nol secara default: ini yang dipasang [historyServiceProvider] buat
    // app beneran (belum ada backend), jadi nggak boleh nunda apa-apa waktu
    // MainShell nge-build 5 tab sekaligus lewat IndexedStack. Test yang mau
    // ngetes state loading eksplisit ngasih durasi sendiri.
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
}
