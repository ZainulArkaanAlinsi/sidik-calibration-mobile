import '../models/logo_organisasi.dart';
import 'api_client.dart';

/// Logo kop sertifikat — **admin doang** (`POST`/`DELETE /api/organization/logo`).
///
/// `logo_url` ikut di `GET /organization`, jadi tidak ada endpoint baca
/// sendiri. Logo disimpan di disk publik server (identitas yang memang
/// dipajang), beda dari tanda tangan yang privat.
abstract class LogoOrganisasiService {
  Future<LogoOrganisasi> ambil(String token);

  /// PNG atau JPG, maks 2 MB. WEBP/GIF ditolak `422` — dompdf tidak bisa
  /// mencetaknya. Pesan `422`-nya sudah menyebut alasan; tampilkan apa adanya.
  /// Logo lama otomatis terhapus di server.
  Future<LogoOrganisasi> unggah(String token, String filePath);

  /// Idempoten di server: aman dipanggil walau logonya belum ada. Kop
  /// kembali ke logo bawaan.
  Future<void> hapus(String token);
}

class ApiLogoOrganisasiService implements LogoOrganisasiService {
  ApiLogoOrganisasiService(this._api);

  final ApiClient _api;

  static const _path = '/organization/logo';

  @override
  Future<LogoOrganisasi> ambil(String token) async {
    final json = await _api.get('/organization', token: token);
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return LogoOrganisasi.fromJson(data);
  }

  @override
  Future<LogoOrganisasi> unggah(String token, String filePath) async {
    final json = await _api.unggahFile(
      _path,
      field: 'logo',
      filePath: filePath,
      token: token,
    );
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    return LogoOrganisasi.fromJson(data);
  }

  @override
  Future<void> hapus(String token) => _api.delete(_path, token: token);
}

/// Versi in-memory buat mode mock & widget test. Perubahannya benar-benar
/// disimpan, jadi test bisa memastikan hapus mengembalikan keadaan "belum ada".
class MockLogoOrganisasiService implements LogoOrganisasiService {
  MockLogoOrganisasiService({this.gagal = false, String? urlAwal})
    : _url = urlAwal;

  final bool gagal;
  String? _url;

  /// Path berkas terakhir yang diunggah (untuk assert di test).
  String? berkasTerakhir;
  int jumlahAmbil = 0;

  @override
  Future<LogoOrganisasi> ambil(String token) async {
    jumlahAmbil++;
    if (gagal) throw Exception('server nggak nyaut');
    return LogoOrganisasi(url: _url);
  }

  @override
  Future<LogoOrganisasi> unggah(String token, String filePath) async {
    if (gagal) throw Exception('server nggak nyaut');
    berkasTerakhir = filePath;
    _url = 'https://contoh.test/storage/logo-organisasi/1/logo.png';
    return LogoOrganisasi(url: _url);
  }

  @override
  Future<void> hapus(String token) async {
    if (gagal) throw Exception('server nggak nyaut');
    _url = null;
  }
}
