import '../models/user.dart';
import 'api_client.dart';

/// Kelola akun (Data Teknisi) — admin doang.
///
/// Beda dari CRUD master data lain: **nggak ada `simpan()` dan `hapus()`.**
/// Backend sengaja nggak nyediain `POST /users` maupun `DELETE /users/{id}` —
/// akun lahir dari orang yang daftar sendiri lewat `POST /register` dengan
/// status `pending`, lalu admin nyetujui sambil nentuin role-nya. Nonaktifin
/// akun lewat [tolak], bukan dihapus, biar sesi kalibrasi lama tetap punya
/// jejak siapa tekniknya.
abstract class UserService {
  /// [status] opsional: `pending` / `aktif` / `nonaktif`.
  Future<List<User>> daftar(String token, {String? status});

  /// Setujui akun pending sekaligus tetapkan rolenya. Role ditentukan admin
  /// di sini, bukan diambil dari apa yang diisi pendaftar.
  Future<User> setujui(String token, int id, UserRole role);

  /// Menonaktifkan akun dan mencabut token yang mungkin masih dipegang.
  Future<User> tolak(String token, int id);

  Future<void> resetPassword(String token, int id);
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

    return data.cast<Map<String, dynamic>>().map(User.fromJson).toList();
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
  Future<void> resetPassword(String token, int id) async {
    await _api.post('/users/$id/reset-password', token: token, body: {});
  }
}
