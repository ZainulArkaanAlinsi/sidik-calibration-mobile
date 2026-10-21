import '../core/utils/parse_list.dart';
import '../models/calibration_history_item.dart';
import 'api_client.dart';
import 'history_service.dart' show MockHistoryService;

/// Data tab "Kalibrasi" teknisi — dua pertanyaan kecil, bukan seluruh Riwayat.
///
/// Riwayat lama menarik SEMUA halaman (`_semuaHalaman`, sampai 20 × 15 sesi)
/// waktu dibuka. Teknisi cuma butuh dua hal: lembar yang dikembalikan untuk
/// diperbaiki, dan beberapa kiriman terakhirnya. Dua-duanya halaman PERTAMA
/// saja (`ringkas=1`); server sudah menyaring teknisi ke sesi miliknya sendiri
/// (`CalibrationController::index`), apa pun query-nya.
abstract class KalibrasiTeknisiService {
  /// `GET /calibrations?status=perlu_revisi` — lembar lama yang masih
  /// berstatus perlu revisi (jalur Tolak dicabut K-50-01, tapi sesi lama tetap
  /// ada dan tetap bisa dikirim ulang).
  Future<List<CalibrationHistoryItem>> perluRevisi(String token);

  /// `GET /calibrations` halaman pertama, tanpa draf & perlu revisi (yang dua
  /// itu punya bagian sendiri), paling banyak [batas] baris. Baca saja.
  Future<List<CalibrationHistoryItem>> terkirimTerakhir(
    String token, {
    int batas = 10,
  });
}

bool _sudahTerkirim(CalibrationHistoryItem s) =>
    s.status != CalibrationStatus.draft &&
    s.status != CalibrationStatus.perluRevisi;

class ApiKalibrasiTeknisiService implements KalibrasiTeknisiService {
  ApiKalibrasiTeknisiService(this._api);

  final ApiClient _api;

  @override
  Future<List<CalibrationHistoryItem>> perluRevisi(String token) async {
    final json = await _api.get(
      '/calibrations?status=perlu_revisi&ringkas=1&page=1',
      token: token,
    );
    return parseListAman(json['data'], CalibrationHistoryItem.fromJson);
  }

  @override
  Future<List<CalibrationHistoryItem>> terkirimTerakhir(
    String token, {
    int batas = 10,
  }) async {
    final json = await _api.get('/calibrations?ringkas=1&page=1', token: token);
    return parseListAman(
      json['data'],
      CalibrationHistoryItem.fromJson,
    ).where(_sudahTerkirim).take(batas).toList();
  }
}

/// Tiruan untuk mode mock & test: membaca daftar sesi tiruan yang sama dengan
/// [MockHistoryService], jadi angka di layar lain tidak saling membantah.
class MockKalibrasiTeknisiService implements KalibrasiTeknisiService {
  MockKalibrasiTeknisiService({this.sesi, this.gagal = false});

  /// `null` = [MockHistoryService.sesiMock].
  final List<CalibrationHistoryItem>? sesi;
  final bool gagal;

  int panggilRevisi = 0;
  int panggilTerkirim = 0;

  List<CalibrationHistoryItem> get _semua =>
      sesi ?? MockHistoryService.sesiMock();

  @override
  Future<List<CalibrationHistoryItem>> perluRevisi(String token) async {
    panggilRevisi++;
    if (gagal) throw Exception('server nggak nyaut');
    return _semua
        .where((s) => s.status == CalibrationStatus.perluRevisi)
        .toList();
  }

  @override
  Future<List<CalibrationHistoryItem>> terkirimTerakhir(
    String token, {
    int batas = 10,
  }) async {
    panggilTerkirim++;
    if (gagal) throw Exception('server nggak nyaut');
    return _semua.where(_sudahTerkirim).take(batas).toList();
  }
}
