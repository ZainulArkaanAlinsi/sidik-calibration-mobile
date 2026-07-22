/// Versi ringkas alat buat picker di layar Input Kalibrasi
/// (`GET /api/equipments`, `docs/kontrak-api.md` §3). Bukan model penuh buat
/// CRUD Alat (itu punya layarnya sendiri).
///
/// Field identitas (merk, model, rentang, resolusi, pemilik) **udah dikirim
/// server di endpoint yang sama** — dulu dibuang di sini, jadi worksheet pH
/// nampilin kolom Identitas Alat & Customer kosong padahal datanya udah
/// nyampe. Nampungnya nggak nambah request sama sekali.
class EquipmentLookup {
  const EquipmentLookup({
    required this.id,
    required this.namaAlat,
    required this.serialNumber,
    required this.kategori,
    required this.status,
    this.merk = '',
    this.model = '',
    this.rangeMin,
    this.rangeMax,
    this.satuan = '',
    this.resolusi,
    this.pelangganNama = '',
    this.lokasi = '',
  });

  final int id;
  final String namaAlat;
  final String serialNumber;
  final String kategori;

  /// `aktif` / `overdue` / `nonaktif`.
  final String status;

  /// Kolom **Merk** & **Type** di worksheet.
  final String merk;
  final String model;

  /// Kolom **Rentang Ukur** (`0–14 pH`) & **Kapasitas Max.**.
  /// Bisa `null` — sebagian alat batasnya bukan angka.
  final double? rangeMin;
  final double? rangeMax;
  final String satuan;

  /// Kolom **Resolusi Alat** (`0,01 pH`).
  final double? resolusi;

  /// Kolom **Nama Customer**. Alamatnya nggak ikut di endpoint ini — lihat
  /// `docs/permintaan-endpoint.md` §5b.
  final String pelangganNama;

  final String lokasi;

  /// Teks siap tempel buat kolom Rentang Ukur. `null` kalau batasnya nggak
  /// kekirim — layar nampilin strip, bukan `0–0` yang kebaca kayak alat rusak.
  String? get rentangTeks {
    if (rangeMin == null || rangeMax == null) return null;

    final min = _ringkas(rangeMin!);
    final max = _ringkas(rangeMax!);
    return satuan.isEmpty ? '$min–$max' : '$min–$max $satuan';
  }

  String? get resolusiTeks {
    if (resolusi == null) return null;
    return satuan.isEmpty ? _ringkas(resolusi!) : '${_ringkas(resolusi!)} $satuan';
  }

  /// Buang nol di ekor: `14.0` → `14`, tapi `0.01` tetap `0.01`.
  static String _ringkas(double v) {
    final s = v.toStringAsFixed(4);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }

  factory EquipmentLookup.fromJson(Map<String, dynamic> json) {
    final pelanggan = json['pelanggan'] as Map<String, dynamic>?;

    return EquipmentLookup(
      id: (json['id'] as num).toInt(),
      namaAlat: json['nama_alat'] as String,
      serialNumber: json['serial_number'] as String? ?? '',
      kategori: json['kategori'] as String? ?? '',
      status: json['status'] as String? ?? 'aktif',
      merk: json['merk'] as String? ?? '',
      model: json['model'] as String? ?? '',
      rangeMin: (json['range_min'] as num?)?.toDouble(),
      rangeMax: (json['range_max'] as num?)?.toDouble(),
      satuan: json['satuan'] as String? ?? '',
      resolusi: (json['resolusi'] as num?)?.toDouble(),
      pelangganNama: pelanggan?['nama'] as String? ?? '',
      lokasi: json['lokasi'] as String? ?? '',
    );
  }
}
