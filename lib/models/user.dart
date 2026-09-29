/// Role user. Nilainya persis kayak yang dikirim API
/// (lihat `docs/kontrak-api.md`): `admin` / `teknisi` / `viewer` /
/// `super_admin`.
enum UserRole {
  admin,
  teknisi,
  viewer,

  /// Baca semua, tulis nol — sama persis dengan izinnya di server
  /// (`EnsureUserHasRole::lolosBacaSuperAdmin`). Dulu jatuh ke `viewer` dan
  /// berlabel "Viewer", jadi super admin yang login lewat HP melihat dirinya
  /// sebagai viewer.
  superAdmin;

  /// Role asing dari backend nggak bikin app crash — dianggap `viewer`
  /// (paling nggak berbahaya: read-only).
  static UserRole fromApi(String value) => switch (value) {
    'admin' => UserRole.admin,
    'teknisi' => UserRole.teknisi,
    'super_admin' => UserRole.superAdmin,
    _ => UserRole.viewer,
  };

  /// Role yang boleh DIBERIKAN admin ke orang lain — sejajar `User::roles()`
  /// di server. `superAdmin` sengaja tidak ada: satu-satunya pintunya
  /// `php artisan akun:super-admin`, dan server menolak yang lewat sini.
  static const bisaDiberikan = [admin, teknisi, viewer];

  /// Nilai persis yang dikirim ke API. BUKAN `name`: `superAdmin.name` itu
  /// `superAdmin`, sedangkan server mengenal `super_admin`.
  String get api => switch (this) {
    UserRole.superAdmin => 'super_admin',
    _ => name,
  };

  bool get isAdmin => this == UserRole.admin;

  /// Pengesah sertifikat (keputusan 26 Sep §1). Baca semua; tulisnya cuma
  /// pengesahan, pengembalian dari pengesahan, dan penugasan.
  bool get isSuperAdmin => this == UserRole.superAdmin;

  /// Boleh input alat & kalibrasi. Viewer & super admin read-only.
  bool get bisaInput => this == UserRole.admin || this == UserRole.teknisi;

  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.teknisi => 'Teknisi',
    UserRole.viewer => 'Viewer',
    UserRole.superAdmin => 'Super Admin',
  };
}

/// Status akun.
///
/// `pending` = **belum disetujui admin**, jadi nggak boleh masuk app.
///
/// Statusnya nggak lahir dari pendaftaran mandiri lagi: layar Register dan
/// `POST /register` dicabut 18 Sep 2026, akun sekarang dibuat admin di panel.
/// Nilai ini tetap ada karena baris lama di server masih bisa memakainya, dan
/// jalur setuju/tolaknya masih jalan.
enum UserStatus {
  aktif,
  pending,
  nonaktif;

  static UserStatus fromApi(String value) => switch (value) {
    'aktif' => UserStatus.aktif,
    'pending' => UserStatus.pending,
    _ => UserStatus.nonaktif,
  };

  String get label => switch (this) {
    UserStatus.aktif => 'Aktif',
    UserStatus.pending => 'Pending',
    UserStatus.nonaktif => 'Nonaktif',
  };
}

class User {
  const User({
    required this.id,
    required this.nama,
    required this.email,
    required this.employeeId,
    this.kodeTeknisi,
    required this.role,
    required this.status,
    required this.organizationId,
    this.department,
  });

  final int id;
  final String nama;
  final String email;

  /// Nomor pegawai, mis. `SDK-0001`. Bisa dipakai buat login (selain email).
  final String employeeId;

  /// "Technician ID" yang tercetak di lembar kerja & sertifikat — inisial
  /// (`JO`), bukan `SDK-0001`.
  ///
  /// Datang dari backend (`User::kodeTeknisi()`), BUKAN dipotong dari nama di
  /// sini: yang dibekukan ke snapshot sertifikat juga lewat fungsi itu, dan dua
  /// tempat yang sama-sama "motong dua huruf pertama" cepat atau lambat beda —
  /// mis. buat akun yang `kode_teknisi`-nya diisi manual admin.
  final String? kodeTeknisi;

  final UserRole role;
  final UserStatus status;

  /// **Bisa null.** Backend bilang (14 Jul) tabel `organizations` belum ada,
  /// jadi akun lama organisasinya masih kosong. Kalau ini dipaksa non-null,
  /// app-nya crash waktu parsing — bukan sekadar nampilin strip.
  final int? organizationId;

  final String? department;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      nama: json['nama'] as String,
      email: json['email'] as String,
      // `as String?`, bukan `as String`. Kolomnya `nullable` di DB —
      // migrasi 2026_07_14_110000 sengaja bikin begitu buat baris lama — dan
      // `UserResource` meneruskannya apa adanya tanpa `?? ''`.
      //
      // Cast keras di sini bikin akun seperti itu HILANG DIAM-DIAM dari layar
      // admin: `TypeError`-nya ditelan `parseListAman` (`catch (_)`), barisnya
      // dilewat, dan tidak ada error di mana pun. Admin tidak bisa approve
      // atau reset password akun yang tidak pernah dia lihat. Di jalur login
      // akibatnya beda tapi sama buruknya — `TypeError` yang muncul sebagai
      // pesan gagal generik.
      //
      // Dijadikan string kosong, bukan `String?`: satu-satunya layar yang
      // peduli sudah menanganinya (`technician_list_screen` menampilkan
      // `teknisiTanpaEmployeeId` kalau kosong), jadi tipe non-null di sini
      // menghindari perubahan yang merembet ke belasan pemanggil tanpa
      // menambah satu pun perlindungan.
      employeeId: json['employee_id'] as String? ?? '',
      kodeTeknisi: json['kode_teknisi'] as String?,
      role: UserRole.fromApi(json['role'] as String),
      // Backend lama yang belum ngirim `status` dianggap aktif — biar app
      // nggak ngunci semua orang gara-gara satu field belum ada.
      status: UserStatus.fromApi(json['status'] as String? ?? 'aktif'),
      organizationId: json['organization_id'] as int?,
      department: json['department'] as String?,
    );
  }
}
