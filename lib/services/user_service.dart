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

  /// Betulin data akun (`PUT /api/users/{id}`, admin-only).
  ///
  /// Kenapa ini penting: reset password jalannya lewat **email**, sedangkan
  /// login pakai **ID pegawai**. Orang yang salah ketik emailnya waktu daftar
  /// (`eko@gmial.com`) kekunci selamanya kalau nggak ada yang bisa mbenerin —
  /// dia nggak bisa nerima link reset, dan nggak ada jalan lain masuk.
  ///
  /// Field yang `null` **nggak ikut dikirim**, jadi ngubah satu kolom nggak
  /// diam-diam nimpa kolom lain yang nggak disentuh admin.
  ///
  /// `status` sengaja NGGAK ada di sini walaupun backend nerima: menonaktifkan
  /// akun udah punya jalannya sendiri lewat [tolak], dan dua pintu ke hal yang
  /// sama cuma bikin ragu mana yang bener.
  Future<User> ubah(
    String token,
    int id, {
    String? nama,
    String? email,
    String? employeeId,
    String? department,
    UserRole? role,
  });
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

  @override
  Future<User> ubah(
    String token,
    int id, {
    String? nama,
    String? email,
    String? employeeId,
    String? department,
    UserRole? role,
  }) async {
    // `?nilai` = elemen null-aware: kalau null, kuncinya nggak ikut kekirim
    // sama sekali. Itu yang bikin ngubah satu kolom nggak nimpa kolom lain.
    //
    // Catatan buat `department`: string KOSONG tetap kekirim (itu cara admin
    // ngosongin departemen yang salah isi). Yang dilewat cuma `null`, artinya
    // "jangan sentuh kolom ini".
    final body = <String, dynamic>{
      'nama': ?nama,
      'email': ?email,
      'employee_id': ?employeeId,
      'department': ?department,
      'role': ?role?.name,
    };

    final json = await _api.put('/users/$id', token: token, body: body);
    final result = (json['data'] ?? json) as Map<String, dynamic>;
    return User.fromJson(result);
  }
}

/// Versi in-memory buat mode mock & widget test.
///
/// Perubahannya beneran disimpen, bukan cuma dibalikin — jadi test bisa
/// mastiin `PUT` yang cuma ngirim sebagian kolom nggak nimpa kolom lain.
class MockUserService implements UserService {
  MockUserService({this.gagal = false});

  final bool gagal;

  final List<User> _data = [
    const User(
      id: 1,
      nama: 'Budi Santoso',
      email: 'budi@pt-sidik.com',
      employeeId: 'ASM-0001',
      role: UserRole.admin,
      status: UserStatus.aktif,
      organizationId: 1,
      department: 'Kalibrasi',
    ),
    const User(
      id: 2,
      nama: 'Eko Prasetyo',
      // Sengaja salah ketik: ini persis kasus yang bikin fitur edit perlu ada.
      // Orangnya nggak bisa nerima link reset password, dan login pakai ID
      // pegawai — jadi tanpa admin yang mbenerin, dia kekunci selamanya.
      email: 'eko@gmial.com',
      employeeId: 'ASM-0002',
      role: UserRole.teknisi,
      status: UserStatus.pending,
      organizationId: 1,
    ),
  ];

  @override
  Future<List<User>> daftar(String token, {String? status}) async {
    if (gagal) throw Exception('server nggak nyaut');
    if (status == null || status.isEmpty) return List.unmodifiable(_data);

    return _data.where((u) => u.status.name == status).toList();
  }

  @override
  Future<User> setujui(String token, int id, UserRole role) async {
    if (gagal) throw Exception('server nggak nyaut');
    return _ganti(id, (u) => _salin(u, role: role, status: UserStatus.aktif));
  }

  @override
  Future<User> tolak(String token, int id) async {
    if (gagal) throw Exception('server nggak nyaut');
    return _ganti(id, (u) => _salin(u, status: UserStatus.nonaktif));
  }

  @override
  Future<void> resetPassword(String token, int id, String passwordBaru) async {
    if (gagal) throw Exception('server nggak nyaut');
  }

  @override
  Future<User> ubah(
    String token,
    int id, {
    String? nama,
    String? email,
    String? employeeId,
    String? department,
    UserRole? role,
  }) async {
    if (gagal) throw Exception('server nggak nyaut');

    return _ganti(
      id,
      (u) => _salin(
        u,
        nama: nama,
        email: email,
        employeeId: employeeId,
        department: department,
        role: role,
      ),
    );
  }

  User _ganti(int id, User Function(User lama) ubah) {
    final i = _data.indexWhere((u) => u.id == id);
    if (i < 0) throw Exception('akun $id nggak ada');

    final baru = ubah(_data[i]);
    _data[i] = baru;
    return baru;
  }

  /// Yang `null` dibiarin apa adanya — meniru perilaku `PUT` di backend, di
  /// mana kolom yang nggak dikirim nggak disentuh.
  User _salin(
    User u, {
    String? nama,
    String? email,
    String? employeeId,
    String? department,
    UserRole? role,
    UserStatus? status,
  }) {
    return User(
      id: u.id,
      nama: nama ?? u.nama,
      email: email ?? u.email,
      employeeId: employeeId ?? u.employeeId,
      role: role ?? u.role,
      status: status ?? u.status,
      organizationId: u.organizationId,
      department: department ?? u.department,
    );
  }
}
