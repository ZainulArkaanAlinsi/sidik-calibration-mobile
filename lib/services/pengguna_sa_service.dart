import '../models/user.dart';
import 'api_client.dart';
import 'auth_service.dart' show ApiException;

/// Satu halaman hasil daftar berpaginasi Laravel (`{data, links, meta}`).
class HalamanHasil<T> {
  const HalamanHasil({
    required this.items,
    this.halaman = 1,
    this.halamanTerakhir = 1,
  });

  final List<T> items;
  final int halaman;
  final int halamanTerakhir;

  bool get adaLagi => halaman < halamanTerakhir;

  /// `meta.current_page` / `meta.last_page`. Server tanpa `meta` dianggap
  /// satu halaman penuh (bukan galat): daftarnya tetap tampil.
  static (int, int) bacaMeta(Map<String, dynamic> json) {
    final meta = json['meta'];
    if (meta is! Map) return (1, 1);
    final sekarang = (meta['current_page'] as num?)?.toInt() ?? 1;
    final terakhir = (meta['last_page'] as num?)?.toInt() ?? sekarang;
    return (sekarang, terakhir < sekarang ? sekarang : terakhir);
  }
}

/// Kelola akun internal lab dari aplikasi (kontrak
/// `docs/perintah-frontend-super-admin.md` §4). TIDAK ADA hapus: akun hanya
/// dinonaktifkan, karena riwayat sertifikat & audit menempel di akun.
///
/// Galat 4xx dilempar sebagai `ApiException` (badan asli server: `kode`,
/// `errors`) — layar yang memetakannya ke kolom atau kalimat. Sandi tidak
/// pernah dicatat atau dikembalikan.
abstract class PenggunaSaService {
  /// `GET /users` — [peran] `admin|teknisi|viewer`, [status]
  /// `aktif|pending|nonaktif`, [cari] ≤ 100 karakter.
  Future<HalamanHasil<User>> daftar(
    String token, {
    String? peran,
    String? status,
    String? cari,
    int halaman = 1,
  });

  /// `POST /users` — hanya super admin; hanya `role: admin`. Sandi awal
  /// tidak dikembalikan server.
  Future<User> buatAdmin(
    String token, {
    required String nama,
    required String employeeId,
    required String email,
    required String password,
    String? department,
  });

  /// `PUT /users/{id}` — kolom `null` tidak ikut dikirim.
  Future<User> ubah(
    String token,
    int id, {
    String? nama,
    String? email,
    String? employeeId,
    String? department,
    UserRole? role,
  });

  /// `POST /users/{id}/reset-password` — min 8; semua token orang itu dicabut.
  Future<void> setelUlangSandi(String token, int id, String sandiBaru);

  /// `POST /users/{id}/approve` — pendaftar `pending` (baris lama).
  Future<User> setujui(String token, int id, UserRole role);

  /// `POST /users/{id}/reject`.
  Future<User> tolak(String token, int id);

  /// `POST /users/{id}/nonaktifkan` — hanya super admin; [alasan] 3–500.
  Future<User> nonaktifkan(String token, int id, {required String alasan});

  /// `POST /users/{id}/aktifkan` — hanya super admin; [alasan] opsional.
  Future<User> aktifkan(String token, int id, {String? alasan});
}

class ApiPenggunaSaService implements PenggunaSaService {
  ApiPenggunaSaService(this._api);

  final ApiClient _api;

  User _user(Map<String, dynamic> json) =>
      User.fromJson((json['data'] ?? json) as Map<String, dynamic>);

  @override
  Future<HalamanHasil<User>> daftar(
    String token, {
    String? peran,
    String? status,
    String? cari,
    int halaman = 1,
  }) async {
    final query = <String, String>{
      if (peran != null && peran.isNotEmpty) 'role': peran,
      if (status != null && status.isNotEmpty) 'status': status,
      if (cari != null && cari.trim().isNotEmpty) 'search': cari.trim(),
      if (halaman > 1) 'page': '$halaman',
    };
    final qs = query.isEmpty
        ? ''
        : '?${query.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

    final json = await _api.get('/users$qs', token: token);
    final data = json['data'];
    final (sekarang, terakhir) = HalamanHasil.bacaMeta(json);

    return HalamanHasil(
      // Baris cacat TIDAK dilewati diam-diam: admin yang tidak melihat satu
      // akun tidak bisa menyetujui atau menonaktifkannya.
      items: [
        if (data is List)
          for (final e in data)
            if (e is Map) User.fromJson(Map<String, dynamic>.from(e)),
      ],
      halaman: sekarang,
      halamanTerakhir: terakhir,
    );
  }

  @override
  Future<User> buatAdmin(
    String token, {
    required String nama,
    required String employeeId,
    required String email,
    required String password,
    String? department,
  }) async {
    // POST tanpa `client_request_id`: tidak diulang otomatis oleh ApiClient,
    // jadi sinyal putus-nyambung tidak melahirkan dua akun kembar.
    final json = await _api.post(
      '/users',
      token: token,
      body: {
        'role': 'admin',
        'nama': nama,
        'email': email,
        'employee_id': employeeId,
        'password': password,
        'department': ?department,
      },
    );
    return _user(json);
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
    final json = await _api.put(
      '/users/$id',
      token: token,
      body: {
        'nama': ?nama,
        'email': ?email,
        'employee_id': ?employeeId,
        'department': ?department,
        'role': ?role?.api,
      },
    );
    return _user(json);
  }

  @override
  Future<void> setelUlangSandi(String token, int id, String sandiBaru) async {
    await _api.post(
      '/users/$id/reset-password',
      token: token,
      body: {'password': sandiBaru},
    );
  }

  @override
  Future<User> setujui(String token, int id, UserRole role) async {
    final json = await _api.post(
      '/users/$id/approve',
      token: token,
      body: {'role': role.api},
    );
    return _user(json);
  }

  @override
  Future<User> tolak(String token, int id) async {
    final json = await _api.post('/users/$id/reject', token: token, body: {});
    return _user(json);
  }

  @override
  Future<User> nonaktifkan(
    String token,
    int id, {
    required String alasan,
  }) async {
    final json = await _api.post(
      '/users/$id/nonaktifkan',
      token: token,
      body: {'alasan': alasan},
    );
    return _user(json);
  }

  @override
  Future<User> aktifkan(String token, int id, {String? alasan}) async {
    final json = await _api.post(
      '/users/$id/aktifkan',
      token: token,
      body: {'alasan': ?alasan},
    );
    return _user(json);
  }
}

/// Tiruan in-memory buat test dan mode mock. Meniru aturan server seperlunya
/// (kode galat, batas alasan) supaya layar bisa diuji; sandi TIDAK disimpan.
class MockPenggunaSaService implements PenggunaSaService {
  MockPenggunaSaService({
    List<User>? awal,
    this.galat,
    this.ukuranHalaman = 15,
    this.jeda = Duration.zero,
  }) : _data = [...(awal ?? contoh)];

  /// Bila diisi, dilempar oleh SETIAP panggilan (meniru 403/429/jaringan).
  final Object? galat;
  final int ukuranHalaman;
  final Duration jeda;
  final List<User> _data;

  /// Catatan panggilan untuk assert di test (tanpa sandi).
  final List<String> catatan = [];

  static const contoh = <User>[
    User(
      id: 11,
      nama: 'Rina Master Data',
      email: 'rina@lab.test',
      employeeId: 'SDK-0200',
      role: UserRole.admin,
      status: UserStatus.aktif,
      organizationId: 1,
      department: 'Master Data',
    ),
    User(
      id: 21,
      nama: 'Dedi Teknisi',
      email: 'dedi@lab.test',
      employeeId: 'SDK-0021',
      role: UserRole.teknisi,
      status: UserStatus.aktif,
      organizationId: 1,
    ),
    User(
      id: 22,
      nama: 'Eko Prasetyo',
      email: 'eko@lab.test',
      employeeId: 'SDK-0022',
      role: UserRole.teknisi,
      status: UserStatus.pending,
      organizationId: 1,
    ),
    User(
      id: 23,
      nama: 'Lina Wulandari',
      email: 'lina@lab.test',
      employeeId: 'SDK-0023',
      role: UserRole.teknisi,
      status: UserStatus.nonaktif,
      organizationId: 1,
    ),
  ];

  Future<void> _awal(String panggilan) async {
    catatan.add(panggilan);
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (galat != null) throw galat!;
  }

  ApiException _galat422(
    String pesan, {
    String? kode,
    Map<String, dynamic>? errors,
  }) => ApiException(
    pesan,
    status: 422,
    body: {'message': pesan, 'kode': ?kode, 'errors': ?errors},
  );

  User _ganti(int id, User Function(User lama) ubah) {
    final i = _data.indexWhere((u) => u.id == id);
    if (i < 0) {
      throw const ApiException('Data nggak ketemu.', status: 404);
    }
    return _data[i] = ubah(_data[i]);
  }

  User _salin(
    User u, {
    String? nama,
    String? email,
    String? employeeId,
    String? department,
    UserRole? role,
    UserStatus? status,
  }) => User(
    id: u.id,
    nama: nama ?? u.nama,
    email: email ?? u.email,
    employeeId: employeeId ?? u.employeeId,
    role: role ?? u.role,
    status: status ?? u.status,
    organizationId: u.organizationId,
    department: department ?? u.department,
  );

  @override
  Future<HalamanHasil<User>> daftar(
    String token, {
    String? peran,
    String? status,
    String? cari,
    int halaman = 1,
  }) async {
    await _awal('daftar peran=$peran status=$status cari=$cari h=$halaman');
    final kata = (cari ?? '').trim().toLowerCase();
    final cocok = _data.where((u) {
      if (peran != null && u.role.api != peran) return false;
      if (status != null && u.status.name != status) return false;
      if (kata.isEmpty) return true;
      return u.nama.toLowerCase().contains(kata) ||
          u.email.toLowerCase().contains(kata) ||
          u.employeeId.toLowerCase().contains(kata);
    }).toList();

    final terakhir = cocok.isEmpty ? 1 : (cocok.length / ukuranHalaman).ceil();
    final mulai = (halaman - 1) * ukuranHalaman;
    final irisan = cocok.skip(mulai).take(ukuranHalaman).toList();
    return HalamanHasil(
      items: irisan,
      halaman: halaman,
      halamanTerakhir: terakhir,
    );
  }

  @override
  Future<User> buatAdmin(
    String token, {
    required String nama,
    required String employeeId,
    required String email,
    required String password,
    String? department,
  }) async {
    await _awal('buatAdmin $employeeId');
    final errors = <String, dynamic>{
      if (_data.any((u) => u.email == email))
        'email': ['Email ini sudah terdaftar.'],
      if (_data.any((u) => u.employeeId == employeeId))
        'employee_id': ['ID pegawai ini sudah terdaftar.'],
    };
    if (errors.isNotEmpty) {
      throw _galat422('Data yang dikirim nggak valid.', errors: errors);
    }
    final baru = User(
      id: _data.fold<int>(0, (m, u) => u.id > m ? u.id : m) + 1,
      nama: nama,
      email: email,
      employeeId: employeeId,
      role: UserRole.admin,
      status: UserStatus.aktif,
      organizationId: 1,
      department: department,
    );
    _data.add(baru);
    return baru;
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
    await _awal('ubah $id');
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

  @override
  Future<void> setelUlangSandi(String token, int id, String sandiBaru) async {
    // Sandi sengaja TIDAK masuk catatan.
    await _awal('setelUlangSandi $id');
    _ganti(id, (u) => u);
  }

  @override
  Future<User> setujui(String token, int id, UserRole role) async {
    await _awal('setujui $id ${role.api}');
    return _ganti(id, (u) => _salin(u, role: role, status: UserStatus.aktif));
  }

  @override
  Future<User> tolak(String token, int id) async {
    await _awal('tolak $id');
    return _ganti(id, (u) => _salin(u, status: UserStatus.nonaktif));
  }

  @override
  Future<User> nonaktifkan(
    String token,
    int id, {
    required String alasan,
  }) async {
    await _awal('nonaktifkan $id "$alasan"');
    final panjang = alasan.trim().length;
    if (panjang < 3 || panjang > 500) {
      throw _galat422(
        'Alasan harus 3 sampai 500 karakter.',
        errors: {
          'alasan': ['Alasan harus 3 sampai 500 karakter.'],
        },
      );
    }
    final sekarang = _data.firstWhere(
      (u) => u.id == id,
      orElse: () => throw const ApiException('Data nggak ketemu.', status: 404),
    );
    if (sekarang.status == UserStatus.nonaktif) {
      throw _galat422('Akun sudah nonaktif.', kode: 'sudah_nonaktif');
    }
    return _ganti(id, (u) => _salin(u, status: UserStatus.nonaktif));
  }

  @override
  Future<User> aktifkan(String token, int id, {String? alasan}) async {
    await _awal('aktifkan $id');
    final sekarang = _data.firstWhere(
      (u) => u.id == id,
      orElse: () => throw const ApiException('Data nggak ketemu.', status: 404),
    );
    if (sekarang.status == UserStatus.aktif) {
      throw _galat422('Akun sudah aktif.', kode: 'sudah_aktif');
    }
    if (sekarang.status == UserStatus.pending) {
      throw _galat422(
        'Setujui pendaftar lewat Setujui.',
        kode: 'perlu_persetujuan',
      );
    }
    return _ganti(id, (u) => _salin(u, status: UserStatus.aktif));
  }
}
