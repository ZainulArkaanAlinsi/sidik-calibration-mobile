/// Ruangan lab tempat sesi dikerjain (`GET /api/rooms`) — jadi "Calibration
/// Location" di sertifikat. Kosong buat sesi onsite.
class Room {
  const Room({
    required this.id,
    required this.nama,
    required this.kode,
    required this.aktif,
    this.lokasi,
    this.suhuMin,
    this.suhuMax,
    this.kelembabanMin,
    this.kelembabanMax,
  });

  final int id;
  final String nama;
  final String kode;
  final bool aktif;
  final String? lokasi;

  /// Rentang kondisi yang dijaga di ruangan ini. Dipakai layar cuma buat
  /// **nunjukin** ke teknisi kalau pembacaannya di luar rentang — bukan buat
  /// nolak isian. Yang mutusin sah/nggaknya tetap admin waktu memeriksa.
  final double? suhuMin;
  final double? suhuMax;
  final double? kelembabanMin;
  final double? kelembabanMax;

  String get label => kode.isEmpty ? nama : '$kode — $nama';

  /// `null` kalau rentangnya nggak diatur — bukan berarti lolos, berarti
  /// nggak ada yang bisa dibandingin.
  bool? suhuDiLuarRentang(double? suhu) {
    if (suhu == null || suhuMin == null || suhuMax == null) return null;
    return suhu < suhuMin! || suhu > suhuMax!;
  }

  bool? kelembabanDiLuarRentang(double? kelembaban) {
    if (kelembaban == null || kelembabanMin == null || kelembabanMax == null) {
      return null;
    }
    return kelembaban < kelembabanMin! || kelembaban > kelembabanMax!;
  }

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: (json['id'] as num).toInt(),
    nama: json['nama'] as String? ?? '',
    kode: json['kode'] as String? ?? '',
    aktif: json['aktif'] as bool? ?? true,
    lokasi: json['lokasi'] as String?,
    suhuMin: (json['suhu_min'] as num?)?.toDouble(),
    suhuMax: (json['suhu_max'] as num?)?.toDouble(),
    kelembabanMin: (json['kelembaban_min'] as num?)?.toDouble(),
    kelembabanMax: (json['kelembaban_max'] as num?)?.toDouble(),
  );
}
