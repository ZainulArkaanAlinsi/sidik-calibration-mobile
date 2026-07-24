/// Lokasi pengerjaan kalibrasi (`docs/kontrak-api.md` §4) — `lab` (default
/// backend kalau nggak dikirim) atau `onsite` (di tempat pelanggan).
enum LokasiKalibrasi {
  lab,
  onsite;

  String toApi() => switch (this) {
    LokasiKalibrasi.lab => 'lab',
    LokasiKalibrasi.onsite => 'onsite',
  };
}

/// Kondisi lingkungan versi LENGKAP — dibaca dua kali (awal & akhir sesi),
/// plus koreksi & U95% dari sertifikat thermohygro yang dipakai mantau ruangan.
///
/// Beda dari jalur ringkas (`CalibrationDraft.suhuRuang`/`kelembaban`, satu
/// angka) yang dipakai alat non-pH: di sini backend yang ngerata-ratain DAN
/// nurunin U95% lingkungannya sendiri —
/// `2·√((U_TH/2)² + (|awal−akhir|/2)²)`.
///
/// Makanya rata-ratanya sengaja **nggak** ikut dikirim. Kalau mobile kirim
/// rata-rata juga, ada dua sumber buat angka yang sama dan nggak ada yang tahu
/// mana yang menang waktu keduanya beda.
class KondisiLingkunganDraft {
  const KondisiLingkunganDraft({
    required this.suhuAwal,
    required this.suhuAkhir,
    required this.kelembabanAwal,
    required this.kelembabanAkhir,
    this.suhuKoreksi,
    this.kelembabanKoreksi,
    this.suhuUStd,
    this.kelembabanUStd,
    this.thermohygro,
  });

  final double suhuAwal;
  final double suhuAkhir;
  final double kelembabanAwal;
  final double kelembabanAkhir;

  /// Koreksi dari sertifikat kalibrasi thermohygro-nya sendiri (mis. −0.43 °C)
  /// — alat pemantau ruangan juga punya simpangan, dan nilai terkoreksinya yang
  /// masuk sertifikat.
  final double? suhuKoreksi;
  final double? kelembabanKoreksi;

  /// U95% dari sertifikat thermohygro. Ini yang jadi suku `U_TH` di rumus U95%
  /// lingkungan — bukan sebaran pembacaan.
  final double? suhuUStd;
  final double? kelembabanUStd;

  /// Label unit pemantau ruangan yang dipakai (mis. "TH-3").
  final String? thermohygro;

  Map<String, dynamic> toJson() => {
    'suhu_ruang_awal': suhuAwal,
    'suhu_ruang_akhir': suhuAkhir,
    'kelembaban_awal': kelembabanAwal,
    'kelembaban_akhir': kelembabanAkhir,
    if (suhuKoreksi != null) 'suhu_ruang_koreksi': suhuKoreksi,
    if (kelembabanKoreksi != null) 'kelembaban_koreksi': kelembabanKoreksi,
    if (suhuUStd != null) 'suhu_ruang_u_std': suhuUStd,
    if (kelembabanUStd != null) 'kelembaban_u_std': kelembabanUStd,
    if (thermohygro != null && thermohygro!.trim().isNotEmpty)
      'thermohygro': thermohygro!.trim(),
  };
}

/// Satu titik ukur — nilai acuan (`titikUkur`) + pembacaan berulang.
///
/// Alat biasa: min. 2 pembacaan (Type A itu standar deviasi antar-pengulangan,
/// satu angka nggak ada sebaran yang bisa dihitung). pH: min. 3.
class MeasurementPoint {
  const MeasurementPoint({
    required this.titikUkur,
    required this.satuan,
    required this.pembacaan,
    this.suhu = const [],
    this.standardId,
    this.titikUkurSebelum,
    this.pembacaanSebelum = const [],
    this.suhuSebelum = const [],
  });

  /// Nilai acuan titik ini — untuk pH, ini nilai buffer yang **udah terkoreksi
  /// suhu** (mis. 4.009244572, bukan 4 bulat atau 3.99 mentah dari sertifikat).
  ///
  /// Nilai buffer pH geser ikut suhu larutan — pH 10 bergeser 0,1 dari 20 °C ke
  /// 30 °C, separuh toleransi alatnya. Koreksinya udah dihitung di worksheet,
  /// jadi teknisi nyalin angka jadinya, bukan angka mentah sertifikat.
  final double titikUkur;

  final String satuan;
  final List<double> pembacaan;

  /// Suhu larutan **per baris pembacaan** — khusus pH, sejajar index sama
  /// [pembacaan]. Opsional (dokumentasi kondisi baca), backend nggak nurunin
  /// [titikUkur] dari sini.
  ///
  /// Bukan suhu ruang. Di sesi asli 012-CAL-524 ruangannya 21,4 °C tapi
  /// larutannya 22,1–22,2 °C dan beda tiap titik.
  final List<double> suhu;

  /// Override standar acuan khusus titik ini — sebagian kategori alat (mis.
  /// pH: buffer 4/7/10) butuh standar BEDA per titik, bukan satu standar
  /// buat seluruh sesi. `null` berarti titik ini ikut `standard_id` sesi.
  final int? standardId;

  /// Nilai acuan versi "as found" — bisa beda tipis dari [titikUkur] karena
  /// suhu larutannya beda waktu pembacaan sebelum adjustment diambil.
  final double? titikUkurSebelum;

  /// Pembacaan "as found" (sebelum alat di-adjustment) — dokumentasi kondisi
  /// alat, TIDAK ikut hitungan GUM backend. Kosong = tidak dicatat.
  final List<double> pembacaanSebelum;

  /// Suhu larutan per baris [pembacaanSebelum], sejajar index.
  final List<double> suhuSebelum;

  Map<String, dynamic> toJson() => {
    'titik_ukur': titikUkur,
    'satuan': satuan,
    'pembacaan': pembacaan,
    if (suhu.isNotEmpty) 'suhu': suhu,
    if (standardId != null) 'standard_id': standardId,
    if (titikUkurSebelum != null) 'titik_ukur_sebelum': titikUkurSebelum,
    if (pembacaanSebelum.isNotEmpty) 'pembacaan_sebelum': pembacaanSebelum,
    if (suhuSebelum.isNotEmpty) 'suhu_sebelum': suhuSebelum,
  };
}

/// Body `POST`/`PUT /api/calibrations` (`docs/kontrak-api.md` §4).
/// `standardId` wajib — komponen Type B terbesar di perhitungan GUM backend,
/// tanpa dia `422`.
class CalibrationDraft {
  const CalibrationDraft({
    required this.equipmentId,
    required this.kategori,
    required this.standardId,
    required this.tanggalKalibrasi,
    required this.measurements,
    required this.clientRequestId,
    this.suhuRuang,
    this.kelembaban,
    this.lingkungan,
    this.lokasi = LokasiKalibrasi.lab,
    this.simpanSebagaiDraft = false,
    this.adaScanKamera = false,
    this.nomorOrder,
    this.tanggalTerima,
  });

  final int equipmentId;
  final String kategori;
  final int standardId;
  final DateTime tanggalKalibrasi;
  final List<MeasurementPoint> measurements;
  final LokasiKalibrasi lokasi;

  /// Kondisi lingkungan ringkas — satu angka, jalur alat non-pH. Diabaikan
  /// kalau [lingkungan] keisi.
  final double? suhuRuang;
  final double? kelembaban;

  /// Kondisi lingkungan lengkap (awal/akhir + koreksi + U95% thermohygro).
  /// Kalau ada, ini yang dikirim dan [suhuRuang]/[kelembaban] nggak ikut —
  /// backend yang ngerata-ratain, jadi ngirim dua-duanya cuma bikin dua sumber
  /// buat angka yang sama.
  final KondisiLingkunganDraft? lingkungan;

  /// Nomor order dari customer (mis. "2405.13.A") — opsional, murni catatan.
  final String? nomorOrder;

  /// Tanggal alat DITERIMA dari customer — beda dari [tanggalKalibrasi].
  final DateTime? tanggalTerima;

  /// UUID yang di-generate SEKALI per sesi form (bukan per tap tombol) —
  /// kalau submit di-retry (mis. sinyal putus pas nunggu respons) dengan key
  /// yang sama, backend balikin sesi yang udah ada, bukan bikin dobel.
  final String clientRequestId;

  /// `true` → kirim `status: "draft"` ("simpan dulu, lanjut nanti").
  /// `false` → nggak dikirim sama sekali, sesi langsung masuk antrean
  /// `menunggu_approval` (perilaku default backend).
  final bool simpanSebagaiDraft;

  /// `true` kalau ada **minimal satu** angka yang datang dari scan kamera.
  ///
  /// Dikirim sebagai `input_method: "ocr"`. Backend cuma makai ini buat
  /// statistik, bukan buat logic yang beda (`docs/kontrak-api.md` §4) — tapi
  /// tetap dikirim jujur: ini yang bikin lab bisa ngukur seberapa sering scan
  /// dipakai dan seberapa sering hasilnya dikoreksi teknisi.
  final bool adaScanKamera;

  Map<String, dynamic> toJson() => {
    'equipment_id': equipmentId,
    'kategori': kategori,
    'input_method': adaScanKamera ? 'ocr' : 'manual',
    'standard_id': standardId,
    'tanggal_kalibrasi': tanggalKalibrasi.toUtc().toIso8601String(),
    if (lingkungan != null)
      ...lingkungan!.toJson()
    else ...{
      if (suhuRuang != null) 'suhu_ruang': suhuRuang,
      if (kelembaban != null) 'kelembaban': kelembaban,
    },
    'lokasi': lokasi.toApi(),
    'client_request_id': clientRequestId,
    'measurements': measurements.map((m) => m.toJson()).toList(),
    if (simpanSebagaiDraft) 'status': 'draft',
    if (nomorOrder != null && nomorOrder!.trim().isNotEmpty)
      'nomor_order': nomorOrder!.trim(),
    if (tanggalTerima != null)
      'tanggal_terima': tanggalTerima!.toUtc().toIso8601String(),
  };
}
