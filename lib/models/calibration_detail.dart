import 'calibration_history_item.dart';

/// Satu komponen Type B (`docs/kontrak-api.md` §4: "Type B beserta rincian
/// komponennya") — mis. ketidakpastian standar acuan, resolusi alat,
/// pengaruh suhu. Backend yang ngitung & jumlahin, mobile cuma nampilin
/// rinciannya di tabel ketidakpastian.
class UncertaintyComponent {
  const UncertaintyComponent({required this.nama, required this.nilai});

  final String nama;
  final double nilai;

  factory UncertaintyComponent.fromJson(Map<String, dynamic> json) {
    return UncertaintyComponent(
      nama: json['nama'] as String? ?? '—',
      nilai: (json['nilai'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Hasil kalkulasi GUM buat satu titik ukur — persis field bonus yang
/// disebut `docs/kontrak-api.md` §4 di response `GET /api/calibrations/{id}`
/// (`titik`: "error, koreksi, Type A, Type B beserta rincian komponennya, U,
/// keputusan per titik"). Bentuk JSON belum dikonfirmasi backend — lihat
/// proposal di `docs/kontrak-api.md`.
///
/// **Mobile nggak ngitung ulang apa pun di sini** — cuma nampilin apa yang
/// dibalikin backend, sama kayak seluruh app ini.
class MeasurementResult {
  const MeasurementResult({
    required this.titikUkur,
    required this.satuan,
    required this.pembacaan,
    this.rataRata,
    this.error,
    this.koreksi,
    this.typeA,
    this.typeB,
    this.typeBKomponen = const [],
    this.ketidakpastianGabungan,
    this.faktorCakupanK,
    this.ketidakpastianDiperluas,
    this.keputusan,
  });

  final double titikUkur;
  final String satuan;
  final List<double> pembacaan;

  final double? rataRata;
  final double? error;
  final double? koreksi;
  final double? typeA;
  final double? typeB;
  final List<UncertaintyComponent> typeBKomponen;
  final double? ketidakpastianGabungan;
  final double? faktorCakupanK;
  final double? ketidakpastianDiperluas;

  /// `PASS` / `FAIL` — `null` kalau sesi belum dihitung backend (belum
  /// `disetujui`/`menunggu_approval` yang udah lewat kalkulasi).
  final Keputusan? keputusan;

  factory MeasurementResult.fromJson(Map<String, dynamic> json) {
    final komponen = json['type_b_komponen'] as List<dynamic>? ?? const [];

    return MeasurementResult(
      titikUkur: (json['titik_ukur'] as num?)?.toDouble() ?? 0,
      satuan: json['satuan'] as String? ?? '',
      pembacaan: (json['pembacaan'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      rataRata: (json['rata_rata'] as num?)?.toDouble(),
      error: (json['error'] as num?)?.toDouble(),
      koreksi: (json['koreksi'] as num?)?.toDouble(),
      typeA: (json['type_a'] as num?)?.toDouble(),
      typeB: (json['type_b'] as num?)?.toDouble(),
      typeBKomponen: komponen
          .cast<Map<String, dynamic>>()
          .map(UncertaintyComponent.fromJson)
          .toList(),
      ketidakpastianGabungan:
          (json['ketidakpastian_gabungan'] as num?)?.toDouble(),
      faktorCakupanK: (json['faktor_cakupan_k'] as num?)?.toDouble(),
      ketidakpastianDiperluas:
          (json['ketidakpastian_diperluas'] as num?)?.toDouble(),
      keputusan: switch (json['keputusan']) {
        'PASS' => Keputusan.pass,
        'FAIL' => Keputusan.fail,
        _ => null,
      },
    );
  }
}

/// Respons penuh `GET /api/calibrations/{id}` (`docs/kontrak-api.md` §4) —
/// termasuk field bonus (`nomor_sesi`, `standar_acuan`, `suhu_ruang`,
/// `kelembaban`, `lokasi`, `titik`) yang dibutuhin buat nampilin worksheet &
/// tabel ketidakpastian di layar detail.
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
    this.titik = const [],
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
  final String? standarAcuan;
  final double? suhuRuang;
  final double? kelembaban;
  final String? lokasi;

  /// Kosong kalau sesi belum lewat kalkulasi backend (`draft` /
  /// `menunggu_approval` yang masih di antrean).
  final List<MeasurementResult> titik;

  factory CalibrationDetail.fromJson(Map<String, dynamic> json) {
    final hasil = json['hasil'] as Map<String, dynamic>?;
    final equipment = json['equipment'] as Map<String, dynamic>?;
    final teknisi = json['teknisi'] as Map<String, dynamic>?;
    final titikJson = json['titik'] as List<dynamic>? ?? const [];

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
      standarAcuan: json['standar_acuan'] as String?,
      suhuRuang: (json['suhu_ruang'] as num?)?.toDouble(),
      kelembaban: (json['kelembaban'] as num?)?.toDouble(),
      lokasi: json['lokasi'] as String?,
      titik: titikJson
          .cast<Map<String, dynamic>>()
          .map(MeasurementResult.fromJson)
          .toList(),
    );
  }
}
