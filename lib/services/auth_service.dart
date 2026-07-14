import '../models/user.dart';

/// Hasil login: token + user yang login.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final User user;
}

/// Error yang pesannya layak ditampilin ke user apa adanya.
/// Beda dari exception teknis (timeout, parsing) yang mesti disembunyiin.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Kontrak auth. UI & provider ngomongnya ke sini, bukan ke implementasi —
/// jadi ganti dari mock ke API asli cukup ganti satu baris di
/// `authServiceProvider`, layar Login nggak perlu disentuh sama sekali.
abstract class AuthService {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  /// Validasi token yang tersimpan waktu app dibuka (splash).
  Future<User> me(String token);

  Future<void> logout(String token);
}
