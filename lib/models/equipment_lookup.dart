/// Versi ringkas alat — dipakai picker "Alat" di layar Input Kalibrasi, dan
/// jadi sumber kolom yang **keisi otomatis** di lembar kerja
/// (`GET /api/equipments`, `docs/kontrak-api.md` §3). Bukan model penuh buat
/// CRUD Alat (itu punya layarnya sendiri).
///
/// Bagian "EQUIPMENT IDENTITY" & "OWNER" di lembar kerja nggak diketik teknisi:
/// begitu alatnya dipilih, kolomnya keisi dari sini dan jadi read-only. Field
/// identitas (merk, model, rentang, resolusi, pemilik) **udah dikirim server di
/// endpoint yang sama** — dulu dibuang di sini, jadi worksheet nampilin kolom
/// Identitas Alat & Customer kosong padahal datanya udah nyampe. Nampungnya
/// nggak nambah request sama sekali.
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
    this.lokasi = '',
  });

  /// Kesetaraan pakai `id`, BUKAN identitas objek.
  ///
  /// `DropdownButtonFormField` ngecek nilainya lawan daftar item; kalau
  /// daftarnya ke-refresh, instance-nya baru semua. Tanpa `==` ini, alat yang
  /// udah dipilih teknisi mendadak nggak cocok sama item mana pun — dropdown
  /// balik ke hint "Pilih alat" dan Flutter ngelempar error, padahal pilihannya
  /// masih utuh di state. Ketahuan 11 Agt 2026 waktu bentuk lembar mulai
  /// diambil ulang tiap ganti alat.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is EquipmentLookup && other.id == id);

  @override
  int get hashCode => id.hashCode;

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

  /// Bagian OWNER di lembar kerja — dua-duanya read-only.
  final String pelangganNama;

  /// Ikut di `GET /api/equipments` sejak `pelanggan.alamat` ditambahin ke
  /// `EquipmentResource`. Sebelumnya mobile kepaksa nembak `/api/customers`
  /// cuma buat satu baris — dan itu endpoint admin, teknisi bakal kena 403.
  final String pelangganAlamat;

  final String lokasi;

  /// Teks siap tempel buat kolom Rentang Ukur. `null` kalau batasnya nggak
  /// kekirim — layar nampilin strip, bukan `0–0` yang kebaca kayak alat rusak.
  String? get rentangTeks {
    if (rangeMin == null || rangeMax == null) return null;

    final min = _ringkas(rangeMin!);
    final max = _ringkas(rangeMax!);
    return satuan.isEmpty ? '$min–$max' : '$min–$max $satuan';
  }

  /// Kolom **Kapasitas Max.** — batas atas alatnya. Di sheet PERHITUNGAN dia
  /// baris sendiri (`4 mg/L`), bukan rentang.
  String? get kapasitasTeks {
    if (rangeMax == null) return null;
    return satuan.isEmpty ? _ringkas(rangeMax!) : '${_ringkas(rangeMax!)} $satuan';
  }

  String? get resolusiTeks {
    if (resolusi == null) return null;
    return satuan.isEmpty ? _ringkas(resolusi!) : '${_ringkas(resolusi!)} $satuan';
  }

  /// Kolom "2. Range/Resolution" di **lembar kerja**.
  ///
  /// Isinya TIGA angka yang di sheet PERHITUNGAN jadi baris sendiri-sendiri:
  /// Rentang Ukur, Kapasitas Max., dan Resolusi Alat. Dulu Kapasitas Max. nggak
  /// ikut sama sekali, jadi teknisi nggak pernah lihat batas atas alatnya di
  /// lembar kerjanya — padahal itu yang nentuin titik mana yang boleh dipakai.
  ///
  /// Dikasih label pendek biar kebaca sebagai tiga hal, bukan deretan angka:
  /// `0–4 mg/L · maks 4 mg/L · res 0,01 mg/L`.
  ///
  /// String kosong kalau semuanya belum diisi admin — biar kelihatan kurang,
  /// bukan diisi tebakan.
  String get rangeResolusi => [
    rentangTeks,
    if (kapasitasTeks != null) 'maks $kapasitasTeks',
    if (resolusiTeks != null) 'res $resolusiTeks',
  ].whereType<String>().join(' · ');

  /// Buang nol di ekor: `14.0` → `14`, tapi `0.01` tetap `0,01`.
  ///
  /// Desimalnya KOMA, ngikut lembar kerjanya sendiri (titik ukur ditulis `1,74`
  /// / `1,83`) dan sheet PERHITUNGAN (`0,01 mg/L`). Sebelum ini kolom Range/
  /// Resolution nulis `0.01` pakai titik — satu-satunya angka bertitik di
  /// tengah lembar yang semuanya berkoma.
  static String _ringkas(double v) {
    final s = v.toStringAsFixed(4);
    final rapi = s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
    return rapi.replaceAll('.', ',');
  }

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
      lokasi: json['lokasi'] as String? ?? '',
    );
  }
}
