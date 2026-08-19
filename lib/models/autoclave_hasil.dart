/// Hasil `POST /api/calibrations/autoclave/preview` — olah data Autoklaf TANPA
/// nyimpen sesi.
///
/// **Mobile nggak ngitung apa pun.** Rata-rata disk, koreksi, Kestabilan/
/// Keseragaman/Variasi, konversi satuan tekanan, dan U95 semua datang dari
/// backend (`AutoclaveCalculator`, diadu persis ke `Master Olah Data_Autoclave
/// .xlsm`). Layar cuma nampilin.
///
/// Bentuk Autoklaf beda dari alat lain: satu sesi = DUA besaran (Suhu &
/// Tekanan), jadi hasilnya juga dua blok terpisah — bukan daftar titik.
class AutoclaveHasil {
  const AutoclaveHasil({required this.setPoint, this.suhu, this.tekanan});

  final double? setPoint;
  final AutoclaveSuhu? suhu;
  final AutoclaveTekanan? tekanan;

  factory AutoclaveHasil.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;
    final suhu = data['suhu'];
    final tekanan = data['tekanan'];

    return AutoclaveHasil(
      setPoint: _d(data['set_point']),
      suhu: suhu is Map<String, dynamic> && suhu.isNotEmpty
          ? AutoclaveSuhu.fromJson(suhu)
          : null,
      tekanan: tekanan is Map<String, dynamic> && tekanan.isNotEmpty
          ? AutoclaveTekanan.fromJson(tekanan)
          : null,
    );
  }
}

/// Section A (sebaran suhu per sensor) + B (kinerja autoklaf) sertifikat.
class AutoclaveSuhu {
  const AutoclaveSuhu({
    required this.indikatorRata,
    required this.sensor,
    required this.kestabilan,
    required this.keseragaman,
    required this.variasi,
    required this.uc,
    required this.k,
    required this.uBentangan,
    required this.cmc,
    required this.u95,
  });

  final double? indikatorRata;
  final List<AutoclaveSensor> sensor;

  /// Kestabilan Suhu (SS) = ½·max(ΔT antar titik waktu).
  final double? kestabilan;

  /// Keseragaman Suhu (KS) = |simpangan sensor terbesar vs Indikator|.
  final double? keseragaman;

  /// Variasi Keseluruhan (VK) = Tmax − Tmin seluruh sensor.
  final double? variasi;

  final double? uc;
  final double? k;
  final double? uBentangan;
  final double? cmc;

  /// U95 sesi yang dilaporkan = max(hitung, CMC). Satu angka untuk semua sensor.
  final double? u95;

  factory AutoclaveSuhu.fromJson(Map<String, dynamic> json) => AutoclaveSuhu(
        indikatorRata: _d(json['indikator_rata']),
        sensor: (json['sensor'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AutoclaveSensor.fromJson)
            .toList(),
        kestabilan: _d(json['kestabilan']),
        keseragaman: _d(json['keseragaman']),
        variasi: _d(json['variasi']),
        uc: _d(json['uc']),
        k: _d(json['k']),
        uBentangan: _d(json['u_bentangan']),
        cmc: _d(json['cmc']),
        u95: _d(json['u95']),
      );
}

/// Satu disk sensor suhu (Section A sertifikat).
class AutoclaveSensor {
  const AutoclaveSensor({
    required this.no,
    required this.rata,
    required this.koreksiStandar,
    required this.standarTerkoreksi,
    required this.koreksi,
    required this.deltaT,
  });

  final int no;
  final double? rata;
  final double? koreksiStandar;
  final double? standarTerkoreksi;

  /// Selisih standar-terkoreksi ke rata-rata Indikator autoklaf.
  final double? koreksi;
  final double? deltaT;

  factory AutoclaveSensor.fromJson(Map<String, dynamic> json) =>
      AutoclaveSensor(
        no: (json['no'] as num?)?.toInt() ?? 0,
        rata: _d(json['rata']),
        koreksiStandar: _d(json['koreksi_standar']),
        standarTerkoreksi: _d(json['standar_terkoreksi']),
        koreksi: _d(json['koreksi']),
        deltaT: _d(json['delta_t']),
      );
}

/// Section C (tekanan) sertifikat. Nilai yang DITAMPILKAN pakai [satuan] alat
/// ([standarTerkoreksi]/[koreksi]/[u95]), bukan yang `*Bar` (itu buat audit).
class AutoclaveTekanan {
  const AutoclaveTekanan({
    required this.satuan,
    required this.uutSetting,
    required this.standarTerkoreksi,
    required this.koreksi,
    required this.u95,
    required this.k,
    required this.uc,
    required this.cmcBar,
    required this.u95Bar,
  });

  final String satuan;
  final double? uutSetting;
  final double? standarTerkoreksi;
  final double? koreksi;
  final double? u95;
  final double? k;
  final double? uc;
  final double? cmcBar;
  final double? u95Bar;

  factory AutoclaveTekanan.fromJson(Map<String, dynamic> json) =>
      AutoclaveTekanan(
        satuan: json['satuan'] as String? ?? 'Bar',
        uutSetting: _d(json['uut_setting']),
        standarTerkoreksi: _d(json['standar_terkoreksi']),
        koreksi: _d(json['koreksi']),
        u95: _d(json['u95']),
        k: _d(json['k']),
        uc: _d(json['uc']),
        cmcBar: _d(json['cmc_bar']),
        u95Bar: _d(json['u95_bar']),
      );
}

double? _d(dynamic v) => (v as num?)?.toDouble();
