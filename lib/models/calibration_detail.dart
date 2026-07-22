import 'calibration_history_item.dart';

/// Standar acuan ringkas — dipakai di level sesi dan bisa di-override per
/// titik ukur (mis. pH: buffer 4/7/10 masing-masing sertifikatnya sendiri).
class StandardRef {
  const StandardRef({required this.id, required this.nama, this.noSertifikat});

  final int id;
  final String nama;
  final String? noSertifikat;

  factory StandardRef.fromJson(Map<String, dynamic> json) {
    return StandardRef(
      id: (json['id'] as num).toInt(),
      nama: json['nama'] as String? ?? '—',
      noSertifikat: json['no_sertifikat'] as String?,
    );
  }
}

/// Satu komponen Type B — angka udah dikonversi ke ketidakpastian BAKU (u),
/// bukan diperluas (U), dan `keterangan` udah diformat siap-tampil oleh
/// backend (`GumCalculator::komponenTypeB()` / `hitungDariKemampuan()`).
class UncertaintyComponent {
  const UncertaintyComponent({
    required this.sumber,
    required this.keterangan,
    required this.nilai,
    this.distribusi,
  });

  final String sumber;
  final String keterangan;
  final String? distribusi;
  final double nilai;

  factory UncertaintyComponent.fromJson(Map<String, dynamic> json) {
    return UncertaintyComponent(
      sumber: json['sumber'] as String? ?? '—',
      keterangan: json['keterangan'] as String? ?? '',
      distribusi: json['distribusi'] as String?,
      nilai: (json['nilai'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Tahap pembacaan — alat pH dibaca dua kali: waktu diterima ("as found") dan
/// setelah diadjust ("as left"). Cuma [sesudahAdjustment] yang ikut hitungan
/// GUM dan masuk sertifikat.
enum TahapPembacaan {
  sebelumAdjustment,
  sesudahAdjustment;

  static TahapPembacaan fromJson(String? value) =>
      value == 'sebelum_adjustment'
      ? TahapPembacaan.sebelumAdjustment
      : TahapPembacaan.sesudahAdjustment;
}

/// Satu pembacaan mentah (`pembacaan_mentah` di response) — baris asli yang
/// diinput teknisi, sebelum diringkas jadi rata-rata di [MeasurementResult].
/// Cuma ikut di response detail sesi (`GET /api/calibrations/{id}`), nggak di
/// daftar (`GET /api/calibrations`).
class RawMeasurement {
  const RawMeasurement({
    required this.id,
    required this.titikKe,
    required this.pembacaanKe,
    required this.pembacaan,
    required this.inputSource,
    required this.isVerified,
    this.tahap = TahapPembacaan.sesudahAdjustment,
    this.suhu,
  });

  final int id;
  final int titikKe;
  final int pembacaanKe;
  final double pembacaan;

  /// Default `sesudah_adjustment` — alat non-pH cuma punya satu tahap, dan
  /// backend nandain barisnya sebagai tahap yang disertifikasi.
  final TahapPembacaan tahap;

  /// Suhu larutan waktu baris ini dibaca (khusus pH). Null buat alat lain.
  final double? suhu;

  /// `manual` / `ocr`.
  final String inputSource;

  /// Pembacaan hasil OCR yang belum dikonfirmasi teknisi — sesi nggak bisa
  /// di-approve selama masih ada yang `false` (`CalibrationController::approve()`).
  final bool isVerified;

  factory RawMeasurement.fromJson(Map<String, dynamic> json) {
    return RawMeasurement(
      id: (json['id'] as num).toInt(),
      titikKe: (json['titik_ke'] as num).toInt(),
      pembacaanKe: (json['pembacaan_ke'] as num).toInt(),
      pembacaan: (json['pembacaan'] as num).toDouble(),
      tahap: TahapPembacaan.fromJson(json['tahap'] as String?),
      suhu: (json['suhu'] as num?)?.toDouble(),
      inputSource: json['input_source'] as String? ?? 'manual',
      isVerified: json['is_verified'] as bool? ?? true,
    );
  }
}

/// Ringkasan satu titik **sebelum adjustment** (`titik_sebelum`) — sengaja
/// jauh lebih tipis dari [MeasurementResult]: nggak ada ketidakpastian,
/// toleransi, atau keputusan PASS/FAIL, karena kondisi as-found memang nggak
/// disertifikasi. Cuma dokumentasi "alatnya datang dalam keadaan seperti apa".
class MeasurementBefore {
  const MeasurementBefore({
    required this.titikKe,
    required this.titikUkur,
    required this.rataRata,
    required this.koreksi,
    required this.standarDeviasi,
    required this.jumlahPengulangan,
  });

  final int titikKe;
  final double titikUkur;
  final double rataRata;
  final double koreksi;
  final double standarDeviasi;
  final int jumlahPengulangan;

  factory MeasurementBefore.fromJson(Map<String, dynamic> json) {
    return MeasurementBefore(
      titikKe: (json['titik_ke'] as num?)?.toInt() ?? 0,
      titikUkur: (json['titik_ukur'] as num?)?.toDouble() ?? 0,
      rataRata: (json['rata_rata'] as num?)?.toDouble() ?? 0,
      koreksi: (json['koreksi'] as num?)?.toDouble() ?? 0,
      standarDeviasi: (json['standar_deviasi'] as num?)?.toDouble() ?? 0,
      jumlahPengulangan: (json['jumlah_pengulangan'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Satu besaran lingkungan (suhu ATAU kelembaban) — dibaca awal & akhir sesi,
/// dikoreksi pakai sertifikat thermohygro, plus U95% yang diturunkan backend
/// dari `2·√((U_TH/2)² + (|awal−akhir|/2)²)`.
class BesaranLingkungan {
  const BesaranLingkungan({
    required this.awal,
    required this.akhir,
    required this.rataRata,
    required this.satuan,
    this.koreksi,
    this.nilaiTerkoreksi,
    this.u95,
  });

  final double awal;
  final double akhir;
  final double rataRata;
  final String satuan;
  final double? koreksi;
  final double? nilaiTerkoreksi;
  final double? u95;

  factory BesaranLingkungan.fromJson(Map<String, dynamic> json) {
    return BesaranLingkungan(
      awal: (json['awal'] as num?)?.toDouble() ?? 0,
      akhir: (json['akhir'] as num?)?.toDouble() ?? 0,
      rataRata: (json['rata_rata'] as num?)?.toDouble() ?? 0,
      satuan: json['satuan'] as String? ?? '',
      koreksi: (json['koreksi'] as num?)?.toDouble(),
      nilaiTerkoreksi: (json['nilai_terkoreksi'] as num?)?.toDouble(),
      u95: (json['u95'] as num?)?.toDouble(),
    );
  }
}

/// Blok `kondisi_lingkungan` di response detail. Cuma keisi buat sesi yang
/// ngirim kondisi lingkungan lengkap (awal/akhir) — sesi lama yang cuma kirim
/// satu angka tetap balik lewat `suhu_ruang`/`kelembaban` di level atas.
class KondisiLingkungan {
  const KondisiLingkungan({this.suhu, this.kelembaban, this.thermohygro});

  final BesaranLingkungan? suhu;
  final BesaranLingkungan? kelembaban;
  final String? thermohygro;

  factory KondisiLingkungan.fromJson(Map<String, dynamic> json) {
    final suhu = json['suhu'] as Map<String, dynamic>?;
    final kelembaban = json['kelembaban'] as Map<String, dynamic>?;

    return KondisiLingkungan(
      suhu: suhu == null ? null : BesaranLingkungan.fromJson(suhu),
      kelembaban: kelembaban == null
          ? null
          : BesaranLingkungan.fromJson(kelembaban),
      thermohygro: json['thermohygro'] as String?,
    );
  }
}

/// Hasil kalkulasi GUM buat satu titik ukur (`titik` di respons `GET
/// /api/calibrations/{id}`, `docs/kontrak-api.md` §4) — bentuknya dikunci ke
/// `CalibrationResource::toArray()` di backend, bukan tebakan.
///
/// **Mobile nggak ngitung ulang apa pun di sini** — cuma nampilin apa yang
/// dibalikin backend.
class MeasurementResult {
  const MeasurementResult({
    required this.titikKe,
    required this.titikUkur,
    required this.rataRata,
    required this.error,
    required this.koreksi,
    required this.standarDeviasi,
    required this.jumlahPengulangan,
    required this.typeA,
    required this.typeB,
    this.typeBComponents = const [],
    required this.ketidakpastianGabungan,
    required this.faktorCakupanK,
    required this.ketidakpastianDiperluas,
    required this.toleransi,
    required this.keputusan,
    this.standarAcuan,
    this.metode,
  });

  final int titikKe;
  final double titikUkur;
  final double rataRata;
  final double error;
  final double koreksi;
  final double standarDeviasi;
  final int jumlahPengulangan;
  final double typeA;
  final double typeB;
  final List<UncertaintyComponent> typeBComponents;
  final double ketidakpastianGabungan;
  final double faktorCakupanK;
  final double ketidakpastianDiperluas;
  final double toleransi;

  /// `PASS` / `FAIL` per titik — satu titik `FAIL` bikin seluruh sesi `FAIL`
  /// (`CalibrationController::isiUlangPengukuran()`).
  final Keputusan keputusan;

  /// Cuma keisi kalau titik ini pakai standar BEDA dari standar default sesi
  /// (mis. pH: buffer 4/7/10 masing-masing sertifikatnya sendiri).
  final StandardRef? standarAcuan;

  /// Instruksi kerja yang dipakai (mis. "SIDIK-IK-CAL-0506") — dicetak di
  /// sertifikat, jadi ditampilin apa adanya.
  final String? metode;

  factory MeasurementResult.fromJson(Map<String, dynamic> json) {
    final komponen = json['type_b_components'] as List<dynamic>? ?? const [];
    final standar = json['standar_acuan'] as Map<String, dynamic>?;

    return MeasurementResult(
      titikKe: (json['titik_ke'] as num?)?.toInt() ?? 0,
      titikUkur: (json['titik_ukur'] as num?)?.toDouble() ?? 0,
      rataRata: (json['rata_rata'] as num?)?.toDouble() ?? 0,
      error: (json['error'] as num?)?.toDouble() ?? 0,
      koreksi: (json['koreksi'] as num?)?.toDouble() ?? 0,
      standarDeviasi: (json['standar_deviasi'] as num?)?.toDouble() ?? 0,
      jumlahPengulangan: (json['jumlah_pengulangan'] as num?)?.toInt() ?? 0,
      typeA: (json['type_a'] as num?)?.toDouble() ?? 0,
      typeB: (json['type_b'] as num?)?.toDouble() ?? 0,
      typeBComponents: komponen
          .cast<Map<String, dynamic>>()
          .map(UncertaintyComponent.fromJson)
          .toList(),
      ketidakpastianGabungan:
          (json['ketidakpastian_gabungan'] as num?)?.toDouble() ?? 0,
      faktorCakupanK: (json['faktor_cakupan_k'] as num?)?.toDouble() ?? 0,
      ketidakpastianDiperluas:
          (json['ketidakpastian_diperluas'] as num?)?.toDouble() ?? 0,
      toleransi: (json['toleransi'] as num?)?.toDouble() ?? 0,
      keputusan: json['keputusan'] == 'FAIL' ? Keputusan.fail : Keputusan.pass,
      standarAcuan: standar == null ? null : StandardRef.fromJson(standar),
      metode: json['metode'] as String?,
    );
  }
}

/// Ringkasan sertifikat sesi ini — embed langsung di respons detail sesi
/// (`CalibrationResource::toArray()`), beda dari `Certificate` penuh yang
/// dibalikin `GET /api/certificates/{id}` (§5). `pdfUrl` cuma keisi kalau
/// `status == 'terbit'`.
class CertificateRef {
  const CertificateRef({
    required this.id,
    required this.nomor,
    required this.status,
    this.pdfUrl,
  });

  final int id;
  final String nomor;
  final String status;
  final String? pdfUrl;

  factory CertificateRef.fromJson(Map<String, dynamic> json) {
    return CertificateRef(
      id: (json['id'] as num).toInt(),
      nomor: json['nomor'] as String? ?? '—',
      status: json['status'] as String? ?? 'menunggu_generate',
      pdfUrl: json['pdf_url'] as String?,
    );
  }
}

/// Respons penuh `GET /api/calibrations/{id}` (`docs/kontrak-api.md` §4) —
/// termasuk field bonus (`nomor_sesi`, `standar_acuan`, `suhu_ruang`,
/// `kelembaban`, `lokasi`, `sertifikat`, `titik`) yang dibutuhin buat
/// nampilin worksheet & tabel ketidakpastian di layar detail.
class CalibrationDetail {
  const CalibrationDetail({
    required this.id,
    required this.namaAlat,
    required this.namaTeknisi,
    required this.tanggalKalibrasi,
    required this.status,
    this.keputusan,
    this.certificateId,
    this.catatanRevisi,
    this.nomorSesi,
    this.standarAcuan,
    this.suhuRuang,
    this.kelembaban,
    this.lokasi,
    this.sertifikat,
    this.kondisiLingkungan,
    this.titik = const [],
    this.titikSebelum = const [],
    this.pembacaanMentah = const [],
    this.perluVerifikasi = false,
  });

  final int id;
  final String namaAlat;
  final String namaTeknisi;
  final DateTime tanggalKalibrasi;
  final CalibrationStatus status;
  final Keputusan? keputusan;
  final int? certificateId;
  final String? catatanRevisi;

  final String? nomorSesi;
  final StandardRef? standarAcuan;
  final double? suhuRuang;
  final double? kelembaban;
  final String? lokasi;
  final CertificateRef? sertifikat;

  /// Rincian awal/akhir + U95% lingkungan. Null buat sesi yang cuma ngirim
  /// satu angka suhu/kelembaban — pakai [suhuRuang]/[kelembaban] buat itu.
  final KondisiLingkungan? kondisiLingkungan;

  /// Kosong kalau sesi belum lewat kalkulasi backend (`draft` yang belum
  /// pernah disubmit).
  final List<MeasurementResult> titik;

  /// Ringkasan as-found per titik. Kosong kalau sesi ini nggak nyatet
  /// pembacaan sebelum adjustment (alat non-pH umumnya nggak).
  final List<MeasurementBefore> titikSebelum;

  /// Baris pembacaan asli per titik — cuma ikut di respons detail (bukan
  /// daftar). Dikelompokkan manual per `titikKe` + `tahap` di UI.
  final List<RawMeasurement> pembacaanMentah;

  /// Masih ada pembacaan OCR yang belum dikonfirmasi teknisi — selama `true`,
  /// sesi ini ditolak backend waktu di-approve.
  final bool perluVerifikasi;

  /// STDEV terbesar antar titik — kolom **MAX STDEV** di worksheet asli
  /// (`DATA HASIL KALIBRASI`), dihitung di sini karena backend nggak
  /// ngirimnya: dia cuma turunan `max()` dari `standar_deviasi` tiap titik,
  /// bukan besaran baru yang butuh data mentah.
  ///
  /// Dipisah sebelum/sesudah adjustment karena di worksheet emang dua tabel
  /// terpisah dengan MAX STDEV masing-masing — nyampur keduanya bikin angka
  /// as-found yang jelek (mis. 0,144) kebawa ke tabel as-left yang udah rapi
  /// (0,005), padahal yang disertifikasi cuma yang as-left.
  ///
  /// `null` kalau titiknya belum dihitung backend — bukan `0`, biar layar bisa
  /// bedain "belum ada data" dari "sebarannya nol".
  double? get maxStdev => _maks(titik.map((t) => t.standarDeviasi));

  double? get maxStdevSebelum =>
      _maks(titikSebelum.map((t) => t.standarDeviasi));

  static double? _maks(Iterable<double> nilai) =>
      nilai.isEmpty ? null : nilai.reduce((a, b) => a > b ? a : b);

  factory CalibrationDetail.fromJson(Map<String, dynamic> json) {
    final hasil = json['hasil'] as Map<String, dynamic>?;
    final equipment = json['equipment'] as Map<String, dynamic>?;
    final teknisi = json['teknisi'] as Map<String, dynamic>?;
    final standar = json['standar_acuan'] as Map<String, dynamic>?;
    final sertifikat = json['sertifikat'] as Map<String, dynamic>?;
    final lingkungan = json['kondisi_lingkungan'] as Map<String, dynamic>?;
    final titikJson = json['titik'] as List<dynamic>? ?? const [];
    final sebelumJson = json['titik_sebelum'] as List<dynamic>? ?? const [];
    final pembacaanJson = json['pembacaan_mentah'] as List<dynamic>? ?? const [];

    return CalibrationDetail(
      id: (json['id'] as num).toInt(),
      namaAlat: equipment?['nama_alat'] as String? ?? '—',
      namaTeknisi: teknisi?['nama'] as String? ?? '—',
      tanggalKalibrasi: DateTime.parse(json['tanggal_kalibrasi'] as String),
      status: CalibrationStatusJson.fromJson(json['status'] as String),
      keputusan: switch (hasil?['keputusan']) {
        'PASS' => Keputusan.pass,
        'FAIL' => Keputusan.fail,
        _ => null,
      },
      certificateId: (json['certificate_id'] as num?)?.toInt(),
      catatanRevisi: json['catatan_revisi'] as String?,
      nomorSesi: json['nomor_sesi'] as String?,
      standarAcuan: standar == null ? null : StandardRef.fromJson(standar),
      suhuRuang: (json['suhu_ruang'] as num?)?.toDouble(),
      kelembaban: (json['kelembaban'] as num?)?.toDouble(),
      lokasi: json['lokasi'] as String?,
      sertifikat: sertifikat == null ? null : CertificateRef.fromJson(sertifikat),
      kondisiLingkungan: lingkungan == null
          ? null
          : KondisiLingkungan.fromJson(lingkungan),
      titik: titikJson
          .cast<Map<String, dynamic>>()
          .map(MeasurementResult.fromJson)
          .toList(),
      titikSebelum: sebelumJson
          .cast<Map<String, dynamic>>()
          .map(MeasurementBefore.fromJson)
          .toList(),
      pembacaanMentah: pembacaanJson
          .cast<Map<String, dynamic>>()
          .map(RawMeasurement.fromJson)
          .toList(),
      perluVerifikasi: json['perlu_verifikasi'] as bool? ?? false,
    );
  }
}
