/// Role user. Nilainya persis kayak yang dikirim API
/// (lihat `docs/kontrak-api.md`): `admin` / `teknisi` / `viewer`.
enum UserRole {
  admin,
  teknisi,
  viewer;

  /// Role asing dari backend nggak bikin app crash — dianggap `viewer`
  /// (paling nggak berbahaya: read-only), tapi tetap kelihatan di log.
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

class User {
  const User({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    required this.organizationId,
  });

  final int id;
  final String nama;
  final String email;
  final UserRole role;
  final int organizationId;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      nama: json['nama'] as String,
      email: json['email'] as String,
      role: UserRole.fromApi(json['role'] as String),
      organizationId: json['organization_id'] as int,
    );
  }
}
