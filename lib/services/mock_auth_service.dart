import '../models/user.dart';
import 'auth_service.dart';

/// Auth palsu buat kerja duluan sebelum endpoint `/api/login` dari backend
/// jadi. Response-nya sengaja dibikin **persis sama bentuknya** dengan yang
/// dijanjiin di `docs/kontrak-api.md`, termasuk lewat `User.fromJson` —
/// jadi kalau kontraknya ditepati, ganti ke API asli nggak bakal ngagetin.
///
/// HAPUS file ini begitu `ApiAuthService` jalan.
class MockAuthService implements AuthService {
  /// Akun tes. Password semuanya `password123`.
  static const _akun = <String, Map<String, dynamic>>{
    'admin@asmo.test': {
      'id': 1,
      'nama': 'Budi Santoso',
      'email': 'admin@asmo.test',
      'role': 'admin',
      'organization_id': 1,
    },
    'teknisi@asmo.test': {
      'id': 2,
      'nama': 'Andi Pratama',
      'email': 'teknisi@asmo.test',
      'role': 'teknisi',
      'organization_id': 1,
    },
    'viewer@asmo.test': {
      'id': 3,
      'nama': 'Citra Dewi',
      'email': 'viewer@asmo.test',
      'role': 'viewer',
      'organization_id': 1,
    },
  };

  static const _password = 'password123';

  /// Jeda palsu — biar state `loading` di UI beneran keuji, bukan cuma teori.
  static const _jeda = Duration(milliseconds: 600);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_jeda);

    final json = _akun[email.trim().toLowerCase()];
    if (json == null || password != _password) {
      throw const AuthException('Email atau password salah.');
    }

    return AuthSession(
      token: 'mock-token-${json['id']}',
      user: User.fromJson(json),
    );
  }

  @override
  Future<User> me(String token) async {
    await Future<void>.delayed(_jeda);

    final json = _akun.values.firstWhere(
      (u) => token == 'mock-token-${u['id']}',
      orElse: () => throw const AuthException('Sesi kamu sudah berakhir.'),
    );

    return User.fromJson(json);
  }

  @override
  Future<void> logout(String token) async {
    await Future<void>.delayed(_jeda);
  }
}
