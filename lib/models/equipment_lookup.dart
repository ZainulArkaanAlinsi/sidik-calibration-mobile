/// Versi ringkas alat — dipakai picker "Alat" di layar Input Kalibrasi, dan
/// jadi sumber kolom yang **keisi otomatis** di lembar kerja
/// (`GET /api/equipments`, `docs/kontrak-api.md` §3).
///
/// Bagian "EQUIPMENT IDENTITY" & "OWNER" di lembar kerja nggak diketik teknisi:
/// begitu alatnya dipilih, tujuh kolomnya keisi dari sini dan jadi read-only.
/// Makanya model ini bawa lebih dari sekadar nama & serial — semua yang
/// dicetak di formulirnya ada di sini, biar layar nggak perlu nembak endpoint
/// kedua (dan `/api/customers` itu admin-only, teknisi bakal kena 403).
class EquipmentLookup {
  const EquipmentLookup({
    required this.id,
    required this.namaAlat,
    required this.serialNumber,
    required this.kategori,
    required this.status,
    this.merk = '',
    this.model = '',
    this.satuan = '',
    this.rangeMin,
    this.rangeMax,
    this.resolusi,
    this.pelangganNama = '',
    this.pelangganAlamat = '',
  });

  final int id;
  final String namaAlat;
  final String serialNumber;
  final String kategori;

  /// `aktif` / `overdue` / `nonaktif`.
  final String status;

  final String merk;
  final String model;
  final String satuan;
  final double? rangeMin;
  final double? rangeMax;
  final double? resolusi;

  /// Bagian OWNER di lembar kerja — dua-duanya read-only.
  final String pelangganNama;
  final String pelangganAlamat;

  /// Kolom "Range/Resolution" di lembar kerja, mis. `0-14 pH / 0.01 pH`.
  /// String kosong kalau datanya belum diisi admin — biar kelihatan kurang,
  /// bukan diisi tebakan.
  String get rangeResolusi {
    final rentang = (rangeMin == null && rangeMax == null)
        ? null
        : '${_angka(rangeMin ?? 0)}-${_angka(rangeMax ?? 0)}';
    final res = resolusi == null ? null : _angka(resolusi!);

    final bagian = [
      if (rentang != null) satuan.isEmpty ? rentang : '$rentang $satuan',
      if (res != null) satuan.isEmpty ? res : '$res $satuan',
    ];

    return bagian.join(' / ');
  }

  /// Buang `.0` yang nggak berarti: `14.0` → `14`, tapi `0.01` tetap `0.01`.
  static String _angka(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  factory EquipmentLookup.fromJson(Map<String, dynamic> json) {
    final pelanggan = json['pelanggan'] as Map<String, dynamic>? ?? const {};

    return EquipmentLookup(
      id: (json['id'] as num).toInt(),
      namaAlat: json['nama_alat'] as String,
      serialNumber: json['serial_number'] as String? ?? '',
      kategori: json['kategori'] as String? ?? '',
      status: json['status'] as String? ?? 'aktif',
      merk: json['merk'] as String? ?? '',
      model: json['model'] as String? ?? '',
      satuan: json['satuan'] as String? ?? '',
      rangeMin: (json['range_min'] as num?)?.toDouble(),
      rangeMax: (json['range_max'] as num?)?.toDouble(),
      resolusi: (json['resolusi'] as num?)?.toDouble(),
      pelangganNama: pelanggan['nama'] as String? ?? '',
      pelangganAlamat: pelanggan['alamat'] as String? ?? '',
    );
  }
}
