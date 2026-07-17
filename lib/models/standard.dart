/// Standar acuan buat dropdown "Standar Acuan" di layar Input Kalibrasi
/// (`GET /api/standards`, `docs/kontrak-api.md` §4). Wajib dikirim
/// (`standard_id`) di `POST /api/calibrations` — ketidakpastiannya jadi
/// komponen Type B terbesar di perhitungan GUM backend.
class Standard {
  const Standard({
    required this.id,
    required this.nama,
    required this.merk,
    required this.serialNumber,
    required this.masihBerlaku,
    required this.ketidakpastian,
    required this.satuanKetidakpastian,
    required this.faktorCakupan,
  });

  final int id;
  final String nama;
  final String merk;
  final String serialNumber;

  /// Standar yang `false` ditolak `422` kalau dipakai — jangan ditampilin
  /// bisa dipilih (bukan disembunyikan dari list, cuma dinonaktifkan;
  /// teknisi yang nyari standar biasa dia pakai jangan ngira datanya ilang).
  final bool masihBerlaku;

  final double ketidakpastian;
  final String satuanKetidakpastian;
  final double faktorCakupan;

  factory Standard.fromJson(Map<String, dynamic> json) {
    return Standard(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String,
      merk: json['merk'] as String? ?? '',
      serialNumber: json['serial_number'] as String? ?? '',
      masihBerlaku: json['masih_berlaku'] as bool? ?? false,
      ketidakpastian: (json['ketidakpastian'] as num).toDouble(),
      satuanKetidakpastian: json['satuan_ketidakpastian'] as String? ?? '',
      faktorCakupan: (json['faktor_cakupan'] as num?)?.toDouble() ?? 2,
    );
  }
}
