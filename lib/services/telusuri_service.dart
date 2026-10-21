import '../core/utils/parse_list.dart';
import '../models/revisi_sertifikat.dart' show StatusDokumen;
import '../models/telusuri_sertifikat.dart';
import 'api_client.dart';

/// Pencarian nomor sertifikat di server (`GET /sertifikat/telusuri?q=`).
/// Tidak pernah memfilter di klien: nomor `-R<n>` dan batas organisasi/teknisi
/// ditegakkan server.
abstract class TelusuriService {
  Future<List<TelusuriSertifikat>> cari(String token, String q);
}

class ApiTelusuriService implements TelusuriService {
  ApiTelusuriService(this._api);

  final ApiClient _api;

  @override
  Future<List<TelusuriSertifikat>> cari(String token, String q) async {
    final json = await _api.get(
      '/sertifikat/telusuri?q=${Uri.encodeQueryComponent(q.trim())}',
      token: token,
    );
    return parseListAman(
      json['data'] as List<dynamic>? ?? const [],
      TelusuriSertifikat.fromJson,
    );
  }
}

class MockTelusuriService implements TelusuriService {
  @override
  Future<List<TelusuriSertifikat>> cari(String token, String q) async => [
    TelusuriSertifikat(
      id: 1,
      nomor: '012-CAL-524',
      perusahaan: 'PT Tirta Mandiri Laboratorium',
      alat: 'Timbangan Analitik',
      serialNumber: 'C3349',
      status: 'terbit',
      statusDokumen: StatusDokumen.berlaku,
      tahapPaket: 'sertifikat_terbit',
      pdfUrl: 'https://contoh/sertifikat.pdf',
    ),
  ];
}
