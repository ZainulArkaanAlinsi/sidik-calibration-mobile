import 'user.dart';

/// Akun teknisi dari `/api/technicians` (`TechnicianResource` di server).
///
/// Sengaja BUKAN [User]: resource ini tidak membawa `role` maupun
/// `organization_id` (rolenya dipaksa `teknisi` di server), jadi `User.fromJson`
/// akan melempar `TypeError` di sini — dan `parseListAman` menelannya diam-diam.
class Teknisi {
  const Teknisi({
    required this.id,
    required this.nama,
    required this.employeeId,
    required this.email,
    required this.status,
    this.department,
    this.jumlahKalibrasi,
  });

  final int id;
  final String nama;

  /// Nomor pegawai (mis. `SDK-0001`) — dipakai teknisi untuk login.
  final String employeeId;
  final String email;
  final UserStatus status;
  final String? department;

  /// Hanya ada kalau server menghitungnya (`GET`), tidak di jawaban `POST`.
  final int? jumlahKalibrasi;

  factory Teknisi.fromJson(Map<String, dynamic> json) {
    return Teknisi(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      employeeId: json['employee_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: UserStatus.fromApi(json['status'] as String? ?? ''),
      department: json['department'] as String?,
      jumlahKalibrasi: (json['jumlah_kalibrasi'] as num?)?.toInt(),
    );
  }
}
