import '../models/user.dart';
import 'auth_service.dart';

/// Auth palsu buat kerja duluan sebelum endpoint auth dari backend jadi.
/// Response-nya sengaja dibikin **persis sama bentuknya** dengan yang
/// dijanjiin di `docs/kontrak-api.md` dan diparse lewat `User.fromJson` —
/// jadi kalau kontraknya ditepati, ganti ke API asli nggak bakal ngagetin.
///
/// HAPUS file ini begitu `ApiAuthService` jalan.
class MockAuthService implements AuthService {
  /// Akun tes. Password semuanya `password123`.
  static final List<Map<String, dynamic>> _akun = [
    {
      'id': 1,
      'nama': 'Budi Santoso',
      'email': 'admin@pt-sidik.com',
      'employee_id': 'ASM-0001',
      'role': 'admin',
      'status': 'aktif',
      'department': 'Quality Control',
      'organization_id': 1,
    },
    {
      'id': 2,
      'nama': 'Andi Pratama',
      'email': 'teknisi@pt-sidik.com',
      'employee_id': 'ASM-0002',
      'role': 'teknisi',
      'status': 'aktif',
      'department': 'Kalibrasi',
      'organization_id': 1,
    },
    {
      'id': 3,
      'nama': 'Citra Dewi',
      'email': 'viewer@pt-sidik.com',
      'employee_id': 'ASM-0003',
      'role': 'viewer',
      'status': 'aktif',
      'department': 'Manajemen',
      'organization_id': 1,
    },
    // Akun yang udah daftar tapi belum di-approve admin — buat nguji bahwa
    // akun pending beneran ditolak masuk.
    {
      'id': 4,
      'nama': 'Dewi Lestari',
      'email': 'pending@pt-sidik.com',
      'employee_id': 'ASM-0004',
      'role': 'teknisi',
      'status': 'pending',
      'department': 'Kalibrasi',
      'organization_id': 1,
    },
  ];

  static const _password = 'password123';

  /// Jeda palsu — biar state `loading` di UI beneran keuji, bukan cuma teori.
  static const _jeda = Duration(milliseconds: 600);

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(_jeda);

    final key = identifier.trim().toLowerCase();
    final json = _akun.where((u) {
      return (u['email'] as String).toLowerCase() == key ||
          (u['employee_id'] as String).toLowerCase() == key;
    }).firstOrNull;

    // Password per-akun: seed pakai default `_password`, tapi bisa diubah lewat
    // resetPassword / dipilih sendiri waktu register.
    final expected = (json?['password'] as String?) ?? _password;
    if (json == null || password != expected) {
      throw const AuthException('ID pegawai / email atau password salah.');
    }

    final user = User.fromJson(json);

    // Akun pending ditolak di sini. Kalau ini cuma disembunyiin di UI,
    // orang masih bisa nembak API langsung — makanya backend WAJIB nolak juga.
    if (user.status == UserStatus.pending) {
      throw const AuthException(
        'Akun kamu belum disetujui admin. Tunggu konfirmasi dulu ya.',
      );
    }
    if (user.status == UserStatus.nonaktif) {
      throw const AuthException('Akun kamu dinonaktifkan. Hubungi admin.');
    }

    return AuthSession(token: 'mock-token-${json['id']}', user: user);
  }

  @override
  Future<void> register(RegisterData data) async {
    await Future<void>.delayed(_jeda);

    final emailKepakai = _akun.any(
      (u) =>
          (u['email'] as String).toLowerCase() == data.email.trim().toLowerCase(),
    );
    if (emailKepakai) {
      throw const AuthException('Email ini sudah terdaftar.');
    }

    final idKepakai = _akun.any(
      (u) =>
          (u['employee_id'] as String).toLowerCase() ==
          data.employeeId.trim().toLowerCase(),
    );
    if (idKepakai) {
      throw const AuthException('ID pegawai ini sudah terdaftar.');
    }

    // Akun baru selalu `pending` + role default `teknisi`. Role sebenarnya
    // ditentukan admin waktu nyetujuin — user nggak bisa milih role sendiri.
    _akun.add({
      'id': _akun.length + 1,
      'nama': data.nama.trim(),
      'email': data.email.trim(),
      'employee_id': data.employeeId.trim(),
      'role': 'teknisi',
      'status': 'pending',
      'department': data.department,
      'organization_id': 1,
      'password': data.password,
    });
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await Future<void>.delayed(_jeda);

    if (_cariAkun(email) == null) {
      throw const AuthException('Email ini nggak terdaftar.');
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await Future<void>.delayed(_jeda);

    final akun = _cariAkun(email);
    if (akun == null) {
      throw const AuthException('Email ini nggak terdaftar.');
    }
    // Password beneran keganti — habis ini login pakai password baru bakal
    // sukses, yang lama ditolak. Bukan sekadar layar "berhasil".
    akun['password'] = newPassword;
  }

  Map<String, dynamic>? _cariAkun(String email) {
    final key = email.trim().toLowerCase();
    return _akun
        .where((u) => (u['email'] as String).toLowerCase() == key)
        .firstOrNull;
  }

  @override
  Future<User> me(String token) async {
    await Future<void>.delayed(_jeda);

    final json = _akun.firstWhere(
      (u) => token == 'mock-token-${u['id']}',
      orElse: () => throw const AuthException('Sesi kamu sudah berakhir.'),
    );

    return User.fromJson(json);
  }

  @override
  Future<void> logout(String token) async {
    await Future<void>.delayed(_jeda);
  }

  /// Pura-puranya user ini lagi login di 3 perangkat (HP lama, HP baru, tablet
  /// lab) — biar angka "sesi dicabut" di UI ada yang diuji, bukan cuma 0.
  @override
  Future<int> logoutAll(String token) async {
    await Future<void>.delayed(_jeda);

    if (gagalLogoutAll) {
      throw const AuthException('Server nggak nyaut. Coba lagi sebentar.');
    }

    return 3;
  }

  /// Dipakai test buat nguji yang paling penting: **kalau nyabut sesi gagal,
  /// user nggak boleh dikeluarin diam-diam** — dia bakal ngira HP-nya yang
  /// ilang udah aman padahal belum.
  bool gagalLogoutAll = false;
}
