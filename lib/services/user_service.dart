import '../models/user.dart';
import '../core/utils/parse_list.dart';
import 'api_client.dart';

/// Kelola akun (Data Teknisi) — admin doang.
///
/// Beda dari CRUD master data lain: **nggak ada `simpan()` dan `hapus()`.**
/// `/users` sengaja nggak nyediain `POST` maupun `DELETE` — akun lahir dari
/// orang yang daftar sendiri lewat `POST /register` dengan status `pending`,
/// lalu admin nyetujui sambil nentuin role-nya. Nonaktifin akun lewat [tolak],
/// bukan dihapus, biar sesi kalibrasi lama tetap punya jejak siapa tekniknya.
///
/// Sejak 20 Jul backend punya `/api/technicians` yang **memang** ada create &
/// delete-nya, khusus akun role `teknisi`. Service ini belum makai itu.
abstract class UserService {
  /// [status] opsional: `pending` / `aktif` / `nonaktif`.
  Future<List<User>> daftar(String token, {String? status});

  /// Setujui akun pending sekaligus tetapkan rolenya. Role ditentukan admin
  /// di sini, bukan diambil dari apa yang diisi pendaftar.
  Future<User> setujui(String token, int id, UserRole role);

  /// Menonaktifkan akun dan mencabut token yang mungkin masih dipegang.
  Future<User> tolak(String token, int id);

  /// [passwordBaru] wajib diisi & minimal 8 karakter — backend nolak `422`
  /// kalau kosong. Backend **nggak ngirim email apa pun**: password barunya
  /// dikasih tahu admin ke orangnya langsung.
  Future<void> resetPassword(String token, int id, String passwordBaru);
}

/// Nembak `GET /api/users`, `POST /api/users/{id}/approve|reject|reset-password`.
class ApiUserService implements UserService {
  ApiUserService(this._api);

  final ApiClient _api;

  @override
  Future<List<User>> daftar(String token, {String? status}) async {
    final path = status == null || status.isEmpty
        ? '/users'
        : '/users?status=${Uri.encodeQueryComponent(status)}';
    final json = await _api.get(path, token: token);
    final data = (json['data'] as List<dynamic>? ?? const []);

    return parseListAman(data, User.fromJson);
  }

  @override
  Future<User> setujui(String token, int id, UserRole role) async {
    final json = await _api.post(
      '/users/$id/approve',
      token: token,
      body: {'role': role.name},
    );
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return User.fromJson(result);
  }

  @override
  Future<User> tolak(String token, int id) async {
    final json = await _api.post('/users/$id/reject', token: token, body: {});
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return User.fromJson(result);
  }

  @override
  Future<void> resetPassword(String token, int id, String passwordBaru) async {
    // Body-nya sempat dikirim kosong — backend mewajibkan `password`, jadi
    // aksi ini SELALU gagal 422 dan nggak pernah ada yang kereset.
    await _api.post(
      '/users/$id/reset-password',
      token: token,
      body: {'password': passwordBaru},
    );
  }
}
