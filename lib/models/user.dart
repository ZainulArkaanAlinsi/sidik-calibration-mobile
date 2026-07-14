/// Role user. Nilainya persis kayak yang dikirim API
/// (lihat `docs/kontrak-api.md`): `admin` / `teknisi` / `viewer`.
enum UserRole {
  admin,
  teknisi,
  viewer;

  /// Role asing dari backend nggak bikin app crash — dianggap `viewer`
  /// (paling nggak berbahaya: read-only).
  static UserRole fromApi(String value) => switch (value) {
    'admin' => UserRole.admin,
    'teknisi' => UserRole.teknisi,
    _ => UserRole.viewer,
  };

  bool get isAdmin => this == UserRole.admin;

  /// Boleh input alat & kalibrasi. Viewer read-only.
  bool get bisaInput => this == UserRole.admin || this == UserRole.teknisi;

  String get label => switch (this) {
    UserRole.admin => 'Admin',
    UserRole.teknisi => 'Teknisi',
    UserRole.viewer => 'Viewer',
  };
}

/// Status akun.
///
/// `pending` = udah daftar sendiri lewat layar Register, **tapi belum
/// disetujui admin**. Akun pending nggak boleh masuk app: role & hak aksesnya
/// ditentukan admin, bukan diisi sendiri waktu daftar. Ini yang bikin orang
/// luar nggak bisa bikin akun terus ngintip data kalibrasi pelanggan.
enum UserStatus {
  aktif,
  pending,
  nonaktif;

  static UserStatus fromApi(String value) => switch (value) {
    'aktif' => UserStatus.aktif,
    'pending' => UserStatus.pending,
    _ => UserStatus.nonaktif,
  };
}

class User {
  const User({
    required this.id,
    required this.nama,
    required this.email,
    required this.employeeId,
    required this.role,
    required this.status,
    required this.organizationId,
    this.department,
  });

  final int id;
  final String nama;
  final String email;

  /// Nomor pegawai, mis. `ASM-0001`. Bisa dipakai buat login (selain email).
  final String employeeId;

  final UserRole role;
  final UserStatus status;

  /// **Bisa null.** Backend bilang (14 Jul) tabel `organizations` belum ada,
  /// jadi akun hasil register organisasinya masih kosong. Kalau ini dipaksa
  /// non-null, app-nya crash waktu parsing — bukan sekadar nampilin strip.
  final int? organizationId;

  final String? department;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      nama: json['nama'] as String,
      email: json['email'] as String,
      employeeId: json['employee_id'] as String,
      role: UserRole.fromApi(json['role'] as String),
      // Backend lama yang belum ngirim `status` dianggap aktif — biar app
      // nggak ngunci semua orang gara-gara satu field belum ada.
      status: UserStatus.fromApi(json['status'] as String? ?? 'aktif'),
      organizationId: json['organization_id'] as int?,
      department: json['department'] as String?,
    );
  }
}
