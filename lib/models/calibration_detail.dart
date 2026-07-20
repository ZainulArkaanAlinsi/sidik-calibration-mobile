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
  });

  final int id;
  final int titikKe;
  final int pembacaanKe;
  final double pembacaan;

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
      inputSource: json['input_source'] as String? ?? 'manual',
      isVerified: json['is_verified'] as bool? ?? true,
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
    this.titik = const [],
    this.pembacaanMentah = const [],
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

  /// Kosong kalau sesi belum lewat kalkulasi backend (`draft` yang belum
  /// pernah disubmit).
  final List<MeasurementResult> titik;

  /// Baris pembacaan asli per titik — cuma ikut di respons detail (bukan
  /// daftar). Dikelompokkan manual per `titikKe` di UI kalau dibutuhin.
  final List<RawMeasurement> pembacaanMentah;

  factory CalibrationDetail.fromJson(Map<String, dynamic> json) {
    final hasil = json['hasil'] as Map<String, dynamic>?;
    final equipment = json['equipment'] as Map<String, dynamic>?;
    final teknisi = json['teknisi'] as Map<String, dynamic>?;
    final standar = json['standar_acuan'] as Map<String, dynamic>?;
    final sertifikat = json['sertifikat'] as Map<String, dynamic>?;
    final titikJson = json['titik'] as List<dynamic>? ?? const [];
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
      titik: titikJson
          .cast<Map<String, dynamic>>()
          .map(MeasurementResult.fromJson)
          .toList(),
      pembacaanMentah: pembacaanJson
          .cast<Map<String, dynamic>>()
          .map(RawMeasurement.fromJson)
          .toList(),
    );
  }
}
