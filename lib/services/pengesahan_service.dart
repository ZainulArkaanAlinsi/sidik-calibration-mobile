import '../models/pengesahan.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Gerbang pengesahan sertifikat (keputusan 26 Sep 2026).
///
/// Empat pintu, dan pemiliknya beda:
/// - `antrean` — dibaca admin (lihat punyanya masih mengantre) & super admin;
/// - `sahkan` / `kembalikan` — SUPER ADMIN saja (grup `role:super_admin` di
///   server). `sahkan` satu-satunya jalan yang melahirkan nomor sertifikat;
/// - `tarik` — ADMIN menarik pengajuannya sendiri selama belum disahkan.
abstract class PengesahanService {
  Future<List<ItemPengesahan>> antrean(String token, {String? cari});

  /// Melempar [PengesahanButuhKonfirmasi] kalau server menahan sekali untuk
  /// peringatan pemisahan wewenang. Kirim ulang dengan [abaikanPeringatan].
  Future<String> sahkan(
    String token,
    int sesiId, {
    bool abaikanPeringatan = false,
    String? berlakuSampai,
  });

  Future<String> kembalikan(String token, int sesiId, String alasan);

  Future<String> tarik(String token, int sesiId, String alasan);
}

class ApiPengesahanService implements PengesahanService {
  ApiPengesahanService(this._api);

  final ApiClient _api;

  @override
  Future<List<ItemPengesahan>> antrean(String token, {String? cari}) async {
    final q = (cari == null || cari.trim().isEmpty)
        ? ''
        : '?q=${Uri.encodeQueryComponent(cari.trim())}';
    final json = await _api.get('/pengesahan/antrean$q', token: token);
    final data = json['data'] as List<dynamic>? ?? const [];
    return [
      for (final d in data.whereType<Map<String, dynamic>>())
        ItemPengesahan.fromJson(d),
    ];
  }

  @override
  Future<String> sahkan(
    String token,
    int sesiId, {
    bool abaikanPeringatan = false,
    String? berlakuSampai,
  }) async {
    try {
      final json = await _api.post(
        '/calibrations/$sesiId/sahkan',
        token: token,
        body: {
          if (abaikanPeringatan) 'abaikan_peringatan': true,
          'berlaku_sampai': ?berlakuSampai,
        },
      );
      return json['message'] as String? ?? '';
    } on ApiException catch (e) {
      if (e.status == 422 && e.butuhKonfirmasi) {
        throw PengesahanButuhKonfirmasi(
          e.message,
          TemuanWewenang.dariBody(e.body),
        );
      }
      rethrow;
    }
  }

  @override
  Future<String> kembalikan(String token, int sesiId, String alasan) async {
    final json = await _api.post(
      '/calibrations/$sesiId/kembalikan-dari-pengesahan',
      token: token,
      body: {'alasan': alasan},
    );
    return json['message'] as String? ?? '';
  }

  @override
  Future<String> tarik(String token, int sesiId, String alasan) async {
    final json = await _api.post(
      '/calibrations/$sesiId/tarik-pengajuan',
      token: token,
      body: {'alasan': alasan},
    );
    return json['message'] as String? ?? '';
  }
}

/// Mock untuk `--dart-define=USE_MOCK=true` & test widget.
class MockPengesahanService implements PengesahanService {
  MockPengesahanService({List<ItemPengesahan>? awal})
    : _antrean = List.of(awal ?? _contoh);

  final List<ItemPengesahan> _antrean;

  static final _contoh = [
    ItemPengesahan(
      id: 412,
      nomorSesi: 'KAL/2026/09/0412',
      status: 'menunggu_pengesahan',
      keputusan: 'PASS',
      alatNama: 'Timbangan Analitik',
      alatMerk: 'Ohaus PX224',
      alatSerial: 'C3349',
      pelanggan: 'PT Tirta Mandiri Laboratorium',
      teknisiNama: 'Rizky Pratama',
      teknisiKode: 'RZP',
      diperiksaOleh: 'Hendra Wijaya',
      diajukanOleh: 'Hendra Wijaya',
      diajukanPada: DateTime(2026, 9, 26, 10, 12),
      menungguHari: 2,
    ),
    ItemPengesahan(
      id: 415,
      nomorSesi: 'KAL/2026/09/0415',
      status: 'menunggu_pengesahan',
      keputusan: 'FAIL',
      alatNama: 'pH Meter',
      alatMerk: 'Hanna HI2211',
      alatSerial: 'HI2211-0419',
      pelanggan: 'CV Anugerah Kimia Utama',
      teknisiNama: 'Rizky Pratama',
      teknisiKode: 'RZP',
      diperiksaOleh: 'Hendra Wijaya',
      diajukanOleh: 'Hendra Wijaya',
      diajukanPada: DateTime(2026, 9, 27, 14, 40),
      menungguHari: 1,
      catatanPengajuan: 'Alat FAIL, pelanggan sudah ditelepon.',
    ),
  ];

  @override
  Future<List<ItemPengesahan>> antrean(String token, {String? cari}) async {
    final q = cari?.trim().toLowerCase() ?? '';
    return _antrean
        .where(
          (i) =>
              q.isEmpty ||
              i.nomorSesi.toLowerCase().contains(q) ||
              i.alatNama.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Future<String> sahkan(
    String token,
    int sesiId, {
    bool abaikanPeringatan = false,
    String? berlakuSampai,
  }) async {
    _antrean.removeWhere((i) => i.id == sesiId);
    return 'Disahkan. Sertifikatnya sedang dicetak.';
  }

  @override
  Future<String> kembalikan(String token, int sesiId, String alasan) async {
    _antrean.removeWhere((i) => i.id == sesiId);
    return 'Pengajuan dikembalikan ke admin.';
  }

  @override
  Future<String> tarik(String token, int sesiId, String alasan) async {
    _antrean.removeWhere((i) => i.id == sesiId);
    return 'Pengajuan ditarik.';
  }
}
