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

/// Satu titik ukur — target (`titikUkur`) + pembacaan berulang (min. 2, Type
/// A itu standar deviasi antar-pengulangan, satu angka nggak ada sebaran
/// yang bisa dihitung — `docs/kontrak-api.md` §4).
class MeasurementPoint {
  const MeasurementPoint({
    required this.satuan,
    required this.pembacaan,
    this.titikUkur,
    this.suhuLarutan = const [],
    this.standardId,
    this.pembacaanSebelum = const [],
  }) : assert(
         titikUkur != null || suhuLarutan.length > 0,
         'Kirim salah satu: titikUkur (alat biasa) atau suhuLarutan (pH). '
         'Tanpa dua-duanya backend nggak punya acuan buat ngitung error.',
       );

  /// Nilai acuan titik ini. **Null buat pH** — di sana nilai acuannya nggak
  /// tetap, dia geser ikut suhu larutan, jadi backend yang nurunin dari kurva
  /// sertifikat lewat [suhuLarutan].
  final double? titikUkur;

  final String satuan;
  final List<double> pembacaan;

  /// Suhu larutan **per baris pembacaan** — khusus pH.
  ///
  /// Bukan suhu ruang. Di sesi asli 012-CAL-524 ruangannya 21,4 °C tapi
  /// larutannya 22,1–22,2 °C dan beda tiap titik. Bedanya penting: nilai
  /// buffer pH geser ikut suhu — pH 10 bergeser 0,1 dari 20 °C ke 30 °C,
  /// separuh toleransi alatnya. Salah pakai suhu ruang di sini bikin
  /// nilai acuannya meleset.
  ///
  /// Panjangnya **wajib sama** dengan [pembacaan] — kalau nggak, backend
  /// nolak 422.
  final List<double> suhuLarutan;

  /// Override standar acuan khusus titik ini — sebagian kategori alat (mis.
  /// pH: buffer 4/7/10) butuh standar BEDA per titik, bukan satu standar
  /// buat seluruh sesi. `null` berarti titik ini ikut `standard_id` sesi.
  final int? standardId;

  /// Pembacaan "as found" (sebelum alat di-adjustment) — dokumentasi kondisi
  /// alat doang, TIDAK ikut hitungan GUM backend. Kosong = tidak dicatat.
  final List<double> pembacaanSebelum;

  Map<String, dynamic> toJson() => {
    // Dikirim salah satu, nggak pernah dua-duanya:
    //   alat biasa -> titik_ukur (jalur lama, nggak berubah)
    //   pH         -> suhu_larutan, backend yang nurunin titik_ukur-nya
    //                 dari kurva sertifikat buffer
    if (titikUkur != null) 'titik_ukur': titikUkur,
    if (suhuLarutan.isNotEmpty) 'suhu_larutan': suhuLarutan,
    'satuan': satuan,
    'pembacaan': pembacaan,
    if (standardId != null) 'standard_id': standardId,
    if (pembacaanSebelum.isNotEmpty) 'pembacaan_sebelum': pembacaanSebelum,
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
    required this.suhuRuang,
    required this.kelembaban,
    required this.measurements,
    required this.clientRequestId,
    this.lokasi = LokasiKalibrasi.lab,
    this.simpanSebagaiDraft = false,
    this.nomorOrder,
    this.tanggalTerima,
  });

  final int equipmentId;
  final String kategori;
  final int standardId;
  final DateTime tanggalKalibrasi;
  final double suhuRuang;
  final double kelembaban;
  final List<MeasurementPoint> measurements;
  final LokasiKalibrasi lokasi;

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

  Map<String, dynamic> toJson() => {
    'equipment_id': equipmentId,
    'kategori': kategori,
    'input_method': 'manual',
    'standard_id': standardId,
    'tanggal_kalibrasi': tanggalKalibrasi.toUtc().toIso8601String(),
    'suhu_ruang': suhuRuang,
    'kelembaban': kelembaban,
    'lokasi': lokasi.toApi(),
    'client_request_id': clientRequestId,
    'measurements': measurements.map((m) => m.toJson()).toList(),
    if (simpanSebagaiDraft) 'status': 'draft',
    if (nomorOrder != null && nomorOrder!.trim().isNotEmpty) 'nomor_order': nomorOrder!.trim(),
    if (tanggalTerima != null) 'tanggal_terima': tanggalTerima!.toUtc().toIso8601String(),
  };
}
