/// Satu titik ukur — target (`titikUkur`) + pembacaan berulang (min. 2, Type
/// A itu standar deviasi antar-pengulangan, satu angka nggak ada sebaran
/// yang bisa dihitung — `docs/kontrak-api.md` §4).
class MeasurementPoint {
  const MeasurementPoint({
    required this.titikUkur,
    required this.satuan,
    required this.pembacaan,
  });

  final double titikUkur;
  final String satuan;
  final List<double> pembacaan;

  Map<String, dynamic> toJson() => {
    'titik_ukur': titikUkur,
    'satuan': satuan,
    'pembacaan': pembacaan,
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
    this.simpanSebagaiDraft = false,
  });

  final int equipmentId;
  final String kategori;
  final int standardId;
  final DateTime tanggalKalibrasi;
  final double suhuRuang;
  final double kelembaban;
  final List<MeasurementPoint> measurements;

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
    'measurements': measurements.map((m) => m.toJson()).toList(),
    if (simpanSebagaiDraft) 'status': 'draft',
  };
}
