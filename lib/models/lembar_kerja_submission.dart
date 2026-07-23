import 'calibration_draft.dart' show LokasiKalibrasi;

/// Satu baris tabel hasil siap kirim: satu titik ukur dengan pembacaan
/// Repeat 1..n untuk **dua tahap** sekaligus (before & after adjustment).
///
/// Sel kosong disimpen sebagai `null` di list, **bukan dibuang**. Itu bukan
/// detail teknis: kalau Repeat 2 kosong lalu dibuang, Repeat 3 naik jadi
/// Repeat 2 dan seluruh nomor pengulangannya geser — angka yang nyampe
/// sertifikat jadi ngaku-ngaku diambil di urutan yang salah. Backend yang
/// nyaring null-nya waktu ngitung.
class TitikLembarKerja {
  TitikLembarKerja({
    required this.titikUkur,
    required this.jumlahPengulangan,
    this.standardId,
    this.satuan,
  }) : pembacaan = List<double?>.filled(jumlahPengulangan, null),
       suhu = List<double?>.filled(jumlahPengulangan, null),
       pembacaanSebelum = List<double?>.filled(jumlahPengulangan, null),
       suhuSebelum = List<double?>.filled(jumlahPengulangan, null);

  final double titikUkur;
  final int jumlahPengulangan;

  /// Standar buffer khusus titik ini (pH butuh buffer 4/7/10 yang beda-beda).
  /// `null` = ikut `standard_id` sesi.
  int? standardId;

  final String? satuan;

  /// After adjustment — ini yang dihitung backend.
  final List<double?> pembacaan;
  final List<double?> suhu;

  /// Before adjustment (as-found) — dokumentasi kondisi alat, nggak ikut GUM.
  final List<double?> pembacaanSebelum;
  final List<double?> suhuSebelum;

  /// Baris yang sama sekali belum disentuh. Dipakai buat mutusin baris ini
  /// perlu ikut dikirim apa nggak — bukan buat nahan tombol kirim.
  bool get kosongSemua =>
      pembacaan.every((n) => n == null) &&
      suhu.every((n) => n == null) &&
      pembacaanSebelum.every((n) => n == null) &&
      suhuSebelum.every((n) => n == null);

  Map<String, dynamic> toJson() => {
    'titik_ukur': titikUkur,
    if (satuan != null) 'satuan': satuan,
    if (standardId != null) 'standard_id': standardId,
    // Empat list ini SELALU dikirim penuh sepanjang jumlah pengulangan,
    // termasuk null-nya. Lihat docblock kelas.
    'pembacaan': pembacaan,
    'suhu': suhu,
    'pembacaan_sebelum': pembacaanSebelum,
    'suhu_sebelum': suhuSebelum,
  };
}

/// Satu baris "Usage Check": standar mana yang dicentang teknisi.
class StandarDicek {
  const StandarDicek({
    required this.standardId,
    required this.dipakai,
    this.keterangan,
  });

  final int standardId;
  final bool dipakai;
  final String? keterangan;

  Map<String, dynamic> toJson() => {
    'standard_id': standardId,
    'dipakai': dipakai,
    if (keterangan != null && keterangan!.trim().isNotEmpty)
      'keterangan': keterangan!.trim(),
  };
}

/// Body `POST /api/calibrations` & `PUT /api/calibrations/{id}` dari layar
/// lembar kerja.
///
/// Beda dari `CalibrationDraft` yang lama: di sini **nggak ada satu pun field
/// yang wajib** selain alat, dan semua yang kosong dikirim sebagai null.
/// Tombol kirim di layar nggak pernah dikunci — penjagaannya ada di penerbitan
/// sertifikat (validasi admin), bukan di formulirnya.
class LembarKerjaSubmission {
  const LembarKerjaSubmission({
    required this.equipmentId,
    required this.clientRequestId,
    required this.simpanSebagaiDraft,
    this.standardId,
    this.roomId,
    this.lokasi = LokasiKalibrasi.lab,
    this.tanggalKalibrasi,
    this.tanggalTerima,
    this.suhuAwal,
    this.suhuAkhir,
    this.kelembabanAwal,
    this.kelembabanAkhir,
    this.catatanTeknisi,
    this.standarDicek = const [],
    this.measurements = const [],
    this.sertakanMeasurements = true,
  });

  final int equipmentId;

  /// UUID yang dibikin **sekali per submit**. Kalau sinyal putus pas nunggu
  /// respons dan mobile retry dengan UUID yang sama, backend balikin sesi yang
  /// udah ada — bukan bikin sesi dobel buat satu kejadian kalibrasi.
  final String clientRequestId;

  /// `true` → `status: "draft"` (tersimpan, belum masuk antrean admin, tanggal
  /// boleh kosong). `false` → `menunggu_approval`.
  final bool simpanSebagaiDraft;

  final int? standardId;
  final int? roomId;
  final LokasiKalibrasi lokasi;
  final DateTime? tanggalKalibrasi;
  final DateTime? tanggalTerima;
  final double? suhuAwal;
  final double? suhuAkhir;
  final double? kelembabanAwal;
  final double? kelembabanAkhir;
  final String? catatanTeknisi;
  final List<StandarDicek> standarDicek;
  final List<TitikLembarKerja> measurements;

  /// `false` → kunci `measurements` **nggak ikut dikirim sama sekali**, dan
  /// backend cuma memperbarui bagian header tanpa ngehapus pengukuran yang
  /// udah kecatat. Dipakai waktu teknisi cuma ngerapiin identitas/kondisi
  /// lingkungan di draft yang tabelnya udah keisi.
  final bool sertakanMeasurements;

  static String _tanggal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'equipment_id': equipmentId,
    'client_request_id': clientRequestId,
    'input_method': 'manual',
    'lokasi': lokasi.toApi(),
    'status': simpanSebagaiDraft ? 'draft' : 'menunggu_approval',

    // Tanggal dikirim sebagai tanggal lokal (YYYY-MM-DD), bukan ISO UTC.
    // Kalibrasi jam 8 pagi WIB kalau dikonversi ke UTC mundur ke hari
    // sebelumnya — dan backend punya aturan `before_or_equal:today`, jadi
    // tanggal hari ini bisa lolos/ketolak tergantung jam. Ini tanggal
    // kalender, bukan titik waktu.
    'tanggal_kalibrasi': tanggalKalibrasi == null
        ? null
        : _tanggal(tanggalKalibrasi!),
    'tanggal_terima': tanggalTerima == null ? null : _tanggal(tanggalTerima!),

    // Semua di bawah ini boleh null — itu bentuk sahnya "belum diisi di
    // lapangan", bukan error. Sengaja dikirim eksplisit (bukan dihilangkan
    // kuncinya) supaya PUT bisa MENGOSONGKAN kolom yang tadinya keisi.
    'standard_id': standardId,
    'room_id': roomId,
    'suhu_awal': suhuAwal,
    'suhu_akhir': suhuAkhir,
    'kelembaban_awal': kelembabanAwal,
    'kelembaban_akhir': kelembabanAkhir,
    'catatan_teknisi': catatanTeknisi?.trim(),

    'standar_dicek': standarDicek.map((s) => s.toJson()).toList(),

    if (sertakanMeasurements)
      'measurements': measurements.map((m) => m.toJson()).toList(),
  };
}
