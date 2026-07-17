import '../models/user.dart';

/// Hasil login: token + user yang login.
class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final User user;
}

/// Data yang diisi user di layar Register.
class RegisterData {
  const RegisterData({
    required this.nama,
    required this.employeeId,
    required this.department,
    required this.email,
    required this.password,
  });

  final String nama;
  final String employeeId;
  final String department;
  final String email;
  final String password;
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
/// `authServiceProvider`.
abstract class AuthService {
  /// [identifier] bisa **Employee ID** (mis. `ASM-0001`) **atau email** —
  /// teknisi di lapangan hafal nomor pegawainya, bukan emailnya. Backend yang
  /// nentuin itu ID atau email (lihat `docs/kontrak-api.md`).
  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  /// Daftar akun baru. **Nggak langsung bisa login** — akunnya berstatus
  /// `pending` sampai admin nyetujuin & ngasih role.
  Future<void> register(RegisterData data);

  /// Minta link reset password dikirim ke email.
  ///
  /// Lempar [AuthException] kalau emailnya nggak terdaftar — ini permintaan
  /// eksplisit di catatan harian (state "error email nggak terdaftar").
  ///
  /// Catatan keamanan yang perlu diomongin sama backend: bilang "email nggak
  /// terdaftar" itu ngebocorin email mana yang punya akun (user enumeration).
  /// Praktik yang lebih aman: selalu jawab "kalau emailnya terdaftar, link
  /// udah dikirim". Sementara ini ngikutin catatan harian dulu.
  Future<void> requestPasswordReset(String email);

  /// Set password baru buat akun [email].
  ///
  /// Di alur produksi, kepemilikan email diverifikasi lewat token yang dikirim
  /// ke email, dan halaman "atur password baru" dibuka dari link di email itu.
  /// Di mock (nggak ada infra email) langkah verifikasi di-skip — ini
  /// nyimulasiin halaman tersebut biar reset-nya beneran kepakai, bukan cuma
  /// numpuk di layar "link terkirim".
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  });

  /// Validasi token yang tersimpan waktu app dibuka (splash).
  Future<User> me(String token);

  Future<void> logout(String token);

  /// Cabut **semua** sesi user ini di semua perangkat — termasuk yang lagi
  /// dipakai sekarang. Balikin jumlah sesi yang kecabut (`sesi_dicabut`).
  ///
  /// Kenapa ini perlu ada: token Sanctum **nggak kadaluarsa sendiri**. Jadi
  /// kalau HP teknisi ilang atau dicuri, sesinya di HP itu hidup selamanya —
  /// dan nggak ada cara nyabutnya selain nonaktifin akunnya (kelewat keras,
  /// orangnya jadi nggak bisa kerja). Ini jalan keluarnya.
  Future<int> logoutAll(String token);
}
