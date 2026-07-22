import 'calibration_draft.dart';

/// Satu pembacaan pH — nilai pH + suhu larutan saat itu. Suhunya boleh kosong:
/// backend nganggep `suhu` opsional (dokumentasi kondisi baca), yang wajib
/// cuma angka pH-nya.
class PhReading {
  const PhReading({required this.ph, this.suhu});

  final double ph;
  final double? suhu;
}

/// Satu titik buffer (pH 4 / 7 / 10) — verifikasi *sebelum* alat
/// diadjust ("as found") dan *sesudah* diadjust ("as left"), masing-masing
/// sampai 5 pengulangan. Ini pola standar metrologi pH Meter: alat dikalibrasi
/// ulang di tempat pakai larutan buffer, jadi ada dua state yang dicatat.
///
/// Dua-duanya dikirim ke API — tapi cuma [sesudahAdjustment] yang ikut
/// dihitung GUM di backend dan masuk sertifikat. [sebelumAdjustment] murni
/// dokumentasi kondisi alat waktu diterima, disimpan buat audit trail.
class PhBufferPoint {
  PhBufferPoint({
    required this.label,
    required this.titikUkur,
    this.titikUkurSebelum,
    this.standardId,
  }) : sebelumAdjustment = List.generate(5, (_) => null),
       sesudahAdjustment = List.generate(5, (_) => null);

  /// "4", "7", atau "10" — label tampilan, bukan nilai acuan (lihat
  /// [titikUkur]).
  final String label;

  /// Nilai acuan buffer yang **udah terkoreksi suhu** (mis. 4.009244572) —
  /// ini yang jadi `titik_ukur` waktu dikirim.
  ///
  /// Bukan angka bulat 4/7/10, dan bukan juga nilai mentah sertifikat buffer.
  /// Nilai buffer geser ikut suhu larutan; koreksinya udah dihitung di
  /// worksheet, teknisi nyalin angka jadinya.
  final double titikUkur;

  /// Nilai acuan versi "as found". Bisa beda tipis dari [titikUkur] karena
  /// suhu larutan waktu pembacaan sebelum adjustment nggak persis sama.
  /// `null` = nggak dicatat (pembacaan sebelum tetap kekirim tanpa acuan).
  final double? titikUkurSebelum;

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
    required this.points,
  });

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

  /// Koreksi & U95% dari sertifikat thermohygro-nya sendiri — dibaca dari
  /// worksheet, bukan dihitung mobile. Backend butuh ini buat nurunin U95%
  /// kondisi lingkungan.
  double? suhuKoreksi;
  double? kelembabanKoreksi;
  double? suhuUStd;
  double? kelembabanUStd;

  String? nomorOrder;
  DateTime? tanggalTerima;

  final List<PhBufferPoint> points;

  /// Kategori pH Meter di lampiran akreditasi PT Sidik — "Instrumen
  /// Analitik" (`data-kemampuan-kalibrasi.json`), bukan hasil tebakan.
  static const kategori = 'instrumen-analitik';

  /// Buffer standar yang selalu dipakai satu sesi pH.
  static const labelTitik = ['4', '7', '10'];

  /// Minimum pengulangan per titik yang diterima backend buat pH.
  static const minPengulangan = 3;

  /// Terjemahin ke [CalibrationDraft] generik buat dikirim ke
  /// `POST /api/calibrations`.
  CalibrationDraft toGenericDraft({
    required String clientRequestId,
    LokasiKalibrasi lokasi = LokasiKalibrasi.lab,
    bool simpanSebagaiDraft = false,
    bool adaScanKamera = false,
  }) {
    return CalibrationDraft(
      adaScanKamera: adaScanKamera,
      equipmentId: equipmentId,
      kategori: kategori,
      standardId: standardId,
      tanggalKalibrasi: tanggalKalibrasi,
      lokasi: lokasi,
      clientRequestId: clientRequestId,
      simpanSebagaiDraft: simpanSebagaiDraft,
      nomorOrder: nomorOrder,
      tanggalTerima: tanggalTerima,
      lingkungan: KondisiLingkunganDraft(
        // Kondisi lingkungan divalidasi lengkap di form sebelum sampai sini.
        suhuAwal: suhuAwal ?? 0,
        suhuAkhir: suhuAkhir ?? 0,
        kelembabanAwal: kelembabanAwal ?? 0,
        kelembabanAkhir: kelembabanAkhir ?? 0,
        suhuKoreksi: suhuKoreksi,
        kelembabanKoreksi: kelembabanKoreksi,
        suhuUStd: suhuUStd,
        kelembabanUStd: kelembabanUStd,
        thermohygro: thermohygroId,
      ),
      measurements: [
        for (final titik in points)
          MeasurementPoint(
            titikUkur: titik.titikUkur,
            satuan: 'pH',
            standardId: titik.standardId,
            pembacaan: _nilai(titik.sesudahAdjustment),
            suhu: _suhu(titik.sesudahAdjustment),
            titikUkurSebelum: titik.titikUkurSebelum,
            pembacaanSebelum: _nilai(titik.sebelumAdjustment),
            suhuSebelum: _suhu(titik.sebelumAdjustment),
          ),
      ],
    );
  }

  /// Baris yang angka pH-nya keisi. Baris kosong dibuang, bukan dikirim
  /// sebagai `0` — nol itu pembacaan yang sah di skala pH.
  static List<double> _nilai(List<PhReading?> baris) =>
      baris.whereType<PhReading>().map((r) => r.ph).toList();

  /// Suhu larutan sejajar index sama [_nilai].
  ///
  /// Kalau ada **satu aja** baris yang suhunya belum keisi, seluruh deret suhu
  /// dibuang. `suhu` itu opsional di backend, tapi kalau dikirim dia harus
  /// sejajar index sama `pembacaan` — deret yang bolong bikin suhu nempel ke
  /// baris yang salah, dan itu lebih buruk daripada nggak ngirim suhu sama
  /// sekali (angkanya kelihatan wajar, cuma ketuker).
  static List<double> _suhu(List<PhReading?> baris) {
    final terisi = baris.whereType<PhReading>().toList();
    if (terisi.isEmpty || terisi.any((r) => r.suhu == null)) return const [];
    return terisi.map((r) => r.suhu!).toList();
  }
}
