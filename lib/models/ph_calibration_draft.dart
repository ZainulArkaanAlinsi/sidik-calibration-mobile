import 'calibration_draft.dart';

/// Satu pembacaan pH — nilai pH + suhu larutan saat itu (pengaruh suhu
/// signifikan buat buffer pH, lihat sheet "Nilai koefisien Sensitifitas"
/// di master worksheet aslinya).
class PhReading {
  const PhReading({required this.ph, required this.suhu});

  final double ph;
  final double suhu;
}

/// Satu titik buffer (pH 4 / 7 / 10) — verifikasi *sebelum* alat
/// diadjust ("as found") dan *sesudah* diadjust ("as left"), masing-masing
/// 5 pengulangan. Ini pola standar metrologi pH Meter: alat dikalibrasi
/// ulang di tempat pakai larutan buffer, jadi ada dua state yang dicatat.
///
/// **Cuma `sesudahAdjustment` yang dikirim ke API** sebagai hasil kalibrasi
/// final (`docs/kontrak-api.md` §4 belum punya field buat state "as found" —
/// ini salah satu gap yang perlu dibahas sama tim backend). `sebelumAdjustment`
/// tetap ditangkep di form biar nggak ada data yang ilang dari alur kerja
/// teknisi di lapangan, cuma belum ada tempatnya di kontrak API sekarang.
class PhBufferPoint {
  PhBufferPoint({
    required this.label,
    required this.nilaiStandar,
    this.standardId,
  }) : sebelumAdjustment = List.generate(5, (_) => null),
       sesudahAdjustment = List.generate(5, (_) => null);

  /// "4", "7", atau "10" — label tampilan, bukan nilai pasti (nilai pasti
  /// sertifikat buffer beda tipis per batch, lihat [nilaiStandar]).
  final String label;

  /// Nilai pasti dari sertifikat buffer yang dipakai (mis. 3.99, bukan 4
  /// bulat) — ini yang jadi `titik_ukur` waktu dikirim ke API.
  final double nilaiStandar;

  /// Standar buffer yang dipakai KHUSUS titik ini (mis. "pH Buffer Solution
  /// 4"). Beda dari `standardId` sesi (yang dipakai buat Termometer &
  /// Sensor Std. — kondisi lingkungan) — buffer 4/7/10 masing-masing punya
  /// sertifikat sendiri (lihat `SERTIFIKAT.csv` di master worksheet: 3
  /// larutan buffer beda serial number). `null` sampai teknisi milih.
  int? standardId;

  final List<PhReading?> sebelumAdjustment;
  final List<PhReading?> sesudahAdjustment;
}

/// Draft kalibrasi pH Meter — struktur lengkap ngikutin master worksheet
/// asli (`Master Olah Data_pH for trial.xlsm`), bukan cuma subset generik.
///
/// Backend yang ngitung GUM & keputusan PASS/FAIL (`Aturan Bisnis Inti.md`:
/// "mobile cuma menampilkan hasil, tidak menghitung ulang apa pun") — kelas
/// ini cuma nampung data mentah & nerjemahin ke bentuk [CalibrationDraft]
/// yang API-nya udah live.
class PhCalibrationDraft {
  PhCalibrationDraft({
    required this.equipmentId,
    required this.standardId,
    required this.tanggalKalibrasi,
    required this.thermohygroId,
  }) : points = [
         PhBufferPoint(label: '4', nilaiStandar: 4.0),
         PhBufferPoint(label: '7', nilaiStandar: 7.0),
         PhBufferPoint(label: '10', nilaiStandar: 10.0),
       ];

  final int equipmentId;

  /// Standar acuan sesi — Termometer & Sensor Std., dipakai buat Type B
  /// kondisi lingkungan (suhu ruang/kelembaban). **Bukan** standar buffer,
  /// itu per titik lewat [PhBufferPoint.standardId].
  final int standardId;
  final DateTime tanggalKalibrasi;
  final String thermohygroId;

  double? suhuAwal;
  double? suhuAkhir;
  double? kelembabanAwal;
  double? kelembabanAkhir;

  final List<PhBufferPoint> points;

  /// Kategori pH Meter di lampiran akreditasi PT Sidik — "Instrumen
  /// Analitik" (`data-kemampuan-kalibrasi.json`), bukan hasil tebakan.
  static const kategori = 'instrumen-analitik';

  /// Terjemahin ke [CalibrationDraft] generik buat dikirim ke
  /// `POST /api/calibrations` yang udah live. Suhu/kelembaban dirata-rata
  /// dari awal-akhir (sama kayak kolom "Average" di master worksheet);
  /// tiap titik buffer kirim 5 pembacaan *sesudah* adjustment plus standar
  /// buffernya sendiri-sendiri.
  CalibrationDraft toGenericDraft({
    required String clientRequestId,
    LokasiKalibrasi lokasi = LokasiKalibrasi.lab,
    bool simpanSebagaiDraft = false,
  }) {
    final suhuRuang = ((suhuAwal ?? 0) + (suhuAkhir ?? 0)) / 2;
    final kelembaban = ((kelembabanAwal ?? 0) + (kelembabanAkhir ?? 0)) / 2;

    return CalibrationDraft(
      equipmentId: equipmentId,
      kategori: kategori,
      standardId: standardId,
      tanggalKalibrasi: tanggalKalibrasi,
      suhuRuang: suhuRuang,
      kelembaban: kelembaban,
      lokasi: lokasi,
      clientRequestId: clientRequestId,
      simpanSebagaiDraft: simpanSebagaiDraft,
      measurements: [
        for (final titik in points)
          MeasurementPoint(
            titikUkur: titik.nilaiStandar,
            satuan: 'pH',
            standardId: titik.standardId,
            pembacaan: titik.sesudahAdjustment
                .whereType<PhReading>()
                .map((r) => r.ph)
                .toList(),
          ),
      ],
    );
  }
}
