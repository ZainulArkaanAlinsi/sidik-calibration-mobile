import '../models/teknisi.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;

/// Buat akun teknisi (`POST /api/technicians`) — admin & super admin.
///
/// Hanya `POST`. Daftar, ubah, nonaktifkan, dan reset sandi akun sudah punya
/// jalannya lewat `UserService` (`/users*`, layar Data Teknisi); `GET`,
/// `PUT`, `DELETE /technicians/{id}` sengaja belum dipakai di sini.
///
/// Role dipaksa `teknisi` oleh server dan TIDAK dikirim dari sini: layar ini
/// bukan jalan pintas membuat akun admin. Status tidak dikirim juga — akun
/// buatan admin langsung `aktif` (bukan antrean persetujuan).
abstract class TechnicianService {
  /// [password] adalah sandi AWAL (min 8 karakter). Tidak pernah dibalikkan
  /// server, tidak disimpan di sini, dan admin menyampaikannya langsung ke
  /// orangnya (`docs/kontrak-api.md`). Ganti sandi akun yang sudah ada lewat
  /// `UserService.resetPassword`, bukan dari sini.
  Future<Teknisi> buat(
    String token, {
    required String nama,
    required String employeeId,
    required String email,
    required String password,
    String? department,
  });
}

class ApiTechnicianService implements TechnicianService {
  ApiTechnicianService(this._api);

  final ApiClient _api;

  @override
  Future<Teknisi> buat(
    String token, {
    required String nama,
    required String employeeId,
    required String email,
    required String password,
    String? department,
  }) async {
    // `POST` ini TIDAK diulang otomatis oleh `ApiClient` (tanpa
    // `client_request_id`), jadi sinyal putus-nyambung tidak melahirkan dua
    // akun kembar — kalau jawabannya hilang, admin yang memutuskan lewat
    // layar Data Teknisi.
    final json = await _api.post(
      '/technicians',
      token: token,
      body: {
        'nama': nama,
        'employee_id': employeeId,
        'email': email,
        'password': password,
        // `?x` = elemen null-aware: departemen kosong tidak dikirim, bukan
        // dikirim sebagai string kosong.
        'department': ?department,
      },
    );
    final data = (json['data'] ?? json) as Map<String, dynamic>;

    return Teknisi.fromJson(data);
  }
}

/// Versi in-memory buat mode mock & widget test.
///
/// Meniru dua penolakan `422` yang nyata di server (ID pegawai dan email
/// harus unik se-sistem) supaya penanganan galatnya per kolom bisa diuji.
class MockTechnicianService implements TechnicianService {
  MockTechnicianService({this.gagal = false});

  final bool gagal;

  int _idBerikut = 100;

  final List<Teknisi> dibuat = [];

  /// Sandi terakhir yang DITERIMA service ini. Hanya untuk test (membuktikan
  /// sandi sampai ke service tanpa pernah tampil di layar).
  String? passwordTerakhir;

  final _employeeIdTerpakai = <String>{'SDK-0001', 'SDK-0002'};
  final _emailTerpakai = <String>{'budi@pt-sidik.com', 'eko@gmial.com'};

  @override
  Future<Teknisi> buat(
    String token, {
    required String nama,
    required String employeeId,
    required String email,
    required String password,
    String? department,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');

    final salah = <String, List<String>>{
      if (_employeeIdTerpakai.contains(employeeId))
        'employee_id': ['ID pegawai ini sudah terdaftar.'],
      if (_emailTerpakai.contains(email.toLowerCase()))
        'email': ['Email ini sudah terdaftar.'],
      if (password.length < 8) 'password': ['Password minimal 8 karakter.'],
    };
    if (salah.isNotEmpty) {
      throw ApiException(
        salah.values.first.first,
        status: 422,
        body: {'message': salah.values.first.first, 'errors': salah},
      );
    }

    passwordTerakhir = password;
    _employeeIdTerpakai.add(employeeId);
    _emailTerpakai.add(email.toLowerCase());

    final baru = Teknisi(
      id: _idBerikut++,
      nama: nama,
      employeeId: employeeId,
      email: email,
      status: UserStatus.aktif,
      department: department,
    );
    dibuat.add(baru);

    return baru;
  }
}
