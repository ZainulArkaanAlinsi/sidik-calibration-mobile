import '../models/user.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Auth beneran — nembak `sidik-calibration-api` (Laravel + Sanctum).
///
/// Bentuk request/response-nya ngikutin `docs/kontrak-api.md`. Kalau backend
/// ngubah bentuknya, yang diubah cuma file ini — layar & provider nggak kena.
class ApiAuthService implements AuthService {
  ApiAuthService(this._api);

  final ApiClient _api;

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final json = await _api.post(
      '/login',
      body: {'identifier': identifier.trim(), 'password': password},
    );

    final data = json['data'] as Map<String, dynamic>;

    return AuthSession(
      token: data['token'] as String,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<void> register(RegisterData data) async {
    await _api.post(
      '/register',
      body: {
        'nama': data.nama.trim(),
        'employee_id': data.employeeId.trim(),
        'department': data.department,
        'email': data.email.trim(),
        'password': data.password,
        // Sengaja NGGAK ngirim `role` — role ditentukan admin waktu approve.
        // Backend juga ngabaikan field ini kalau dikirim (udah dites).
      },
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _api.post('/forgot-password', body: {'email': email.trim()});
  }

  @override
  Future<User> me(String token) async {
    final json = await _api.get('/me', token: token);

    // `/me` bisa balikin user langsung atau dibungkus `data` — dua-duanya
    // diterima biar nggak rewel kalau backend beda dikit.
    final raw = json['data'] ?? json;

    return User.fromJson(raw as Map<String, dynamic>);
  }

  @override
  Future<void> logout(String token) async {
    await _api.post('/logout', token: token);
  }
}
