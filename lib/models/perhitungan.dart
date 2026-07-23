/// Lembar PERHITUNGAN — tampilan sisi ADMIN dari satu sesi kalibrasi
/// (`GET /api/calibrations/{id}/perhitungan`).
///
/// Bentuknya ngikutin sheet "PERHITUNGAN" di `Master Olah Data_pH.xlsm` yang
/// selama ini dipakai lab. **Semua angkanya udah jadi di respons** — nggak ada
/// satu pun yang dihitung di sini. Ikut menghitung di mobile cepat atau lambat
/// bikin angkanya beda dari sertifikat, dan bedanya nggak akan ketahuan sampai
/// ada yang ngebandingin dua dokumen.
library;

import '../core/utils/parse_list.dart';

class IdentitasAlat {
  const IdentitasAlat({
    this.namaAlat,
    this.merk,
    this.type,
    this.noSeri,
    this.rentangUkur,
    this.kapasitasMax,
    this.resolusi,
    this.satuan,
  });

  final String? namaAlat;
  final String? merk;
  final String? type;
  final String? noSeri;
  final String? rentangUkur;
  final double? kapasitasMax;
  final double? resolusi;
  final String? satuan;

  factory IdentitasAlat.fromJson(Map<String, dynamic> json) => IdentitasAlat(
    namaAlat: json['nama_alat'] as String?,
    merk: json['merk'] as String?,
    type: json['type'] as String?,
    noSeri: json['no_seri'] as String?,
    rentangUkur: json['rentang_ukur'] as String?,
    kapasitasMax: (json['kapasitas_max'] as num?)?.toDouble(),
    resolusi: (json['resolusi'] as num?)?.toDouble(),
    satuan: json['satuan'] as String?,
  );
}

class IdentitasCustomer {
  const IdentitasCustomer({
    this.nama,
    this.alamat,
    this.tanggalTerima,
    this.tanggalKalibrasi,
  });

  final String? nama;
  final String? alamat;
  final String? tanggalTerima;
  final String? tanggalKalibrasi;

  factory IdentitasCustomer.fromJson(Map<String, dynamic> json) =>
      IdentitasCustomer(
        nama: json['nama'] as String?,
        alamat: json['alamat'] as String?,
        tanggalTerima: json['tanggal_terima'] as String?,
        tanggalKalibrasi: json['tanggal_kalibrasi'] as String?,
      );
}

/// Satu baris blok "PERHITUNGAN KONDISI LINGKUNGAN" (Suhu Ruangan /
/// Kelembaban).
///
/// `null` di sini artinya **belum bisa dihitung**, bukan nol:
/// - `correction`/`u95StdTh` kosong = thermohygro-nya belum dipilih admin,
///   atau standar itu belum diisi `parameter_kondisi`-nya
/// - `delta` kosong = cuma satu dari dua pembacaan (awal/akhir) yang dicatat
class BarisKondisi {
  const BarisKondisi({
    required this.satuan,
    this.awal,
    this.akhir,
    this.average,
    this.indexedValue,
    this.correction,
    this.delta,
    this.u95StdTh,
    this.u95Sertifikat,
    this.nilaiTerkoreksi,
  });

  final String satuan;
  final double? awal;
  final double? akhir;
  final double? average;
  final double? indexedValue;
  final double? correction;

  /// |Akhir − Awal| — seberapa jauh ruangan bergeser selama kerja.
  final double? delta;

  final double? u95StdTh;

  /// akar(U95%_stdTH² + Δ²) — ini yang dicetak di sertifikat.
  final double? u95Sertifikat;

  /// Average + Correction. Ini yang jadi "Env. Condition" di sertifikat.
  final double? nilaiTerkoreksi;

  static BarisKondisi? fromJson(Object? raw) {
    if (raw is! Map) return null;
    double? n(String k) => (raw[k] as num?)?.toDouble();

    return BarisKondisi(
      satuan: raw['satuan'] as String? ?? '',
      awal: n('awal'),
      akhir: n('akhir'),
      average: n('average'),
      indexedValue: n('indexed_value'),
      correction: n('correction'),
      delta: n('delta'),
      u95StdTh: n('u95_std_th'),
      u95Sertifikat: n('u95_sertifikat'),
      nilaiTerkoreksi: n('nilai_terkoreksi'),
    );
  }
}

class KondisiLingkungan {
  const KondisiLingkungan({
    this.suhu,
    this.kelembaban,
    this.thermohygro,
    this.thermohygroSerial,
  });

  final BarisKondisi? suhu;
  final BarisKondisi? kelembaban;

  /// "Thermohygro Used". Kosong = admin belum milih, dan itu sebabnya kolom
  /// Correction & U95% di dua baris di atas ikut kosong.
  final String? thermohygro;
  final String? thermohygroSerial;

  bool get thermohygroBelumDipilih => thermohygro == null;

  factory KondisiLingkungan.fromJson(Map<String, dynamic> json) =>
      KondisiLingkungan(
        suhu: BarisKondisi.fromJson(json['suhu']),
        kelembaban: BarisKondisi.fromJson(json['kelembaban']),
        thermohygro: json['thermohygro'] as String?,
        thermohygroSerial: json['thermohygro_serial'] as String?,
      );
}

/// Satu pembacaan (Repeat n) di tabel hasil.
class PembacaanPerhitungan {
  const PembacaanPerhitungan({
    required this.repeat,
    required this.nilai,
    this.suhu,
  });

  final int repeat;
  final double nilai;
  final double? suhu;

  factory PembacaanPerhitungan.fromJson(Map<String, dynamic> json) =>
      PembacaanPerhitungan(
        repeat: (json['repeat'] as num).toInt(),
        nilai: (json['nilai'] as num).toDouble(),
        suhu: (json['suhu'] as num?)?.toDouble(),
      );
}

/// Satu titik (kolom) di tabel hasil, lengkap dengan penutupnya.
class TitikPerhitungan {
  const TitikPerhitungan({
    required this.titikKe,
    required this.pembacaan,
    this.standard,
    this.standardNominal,
    this.standardDariSuhu = false,
    this.satuan,
    this.average,
    this.averageSuhu,
    this.correction,
    this.stdev,
  });

  final int titikKe;
  final List<PembacaanPerhitungan> pembacaan;

  /// **Bukan nilai nominal (4,00)**, tapi nilai buffer pada suhu larutan saat
  /// itu (4,0092252 di 22,2 °C) — dihitung backend dari persamaan di
  /// sertifikat buffer.
  final double? standard;

  /// Nilai nominal yang diketik teknisi. Dipakai cuma buat nunjukin bedanya.
  final double? standardNominal;

  /// `false` = standarnya nggak punya kurva suhu (atau suhu larutan nggak
  /// dicatat), jadi `standard` jatuh ke nilai nominal.
  final bool standardDariSuhu;

  final String? satuan;
  final double? average;
  final double? averageSuhu;

  /// **Di lembar ini Correction = Average − Standard.** Di SERTIFIKAT tandanya
  /// kebalikan (Standard − Average). Dua-duanya bener, jangan dipakai silang.
  final double? correction;

  final double? stdev;

  factory TitikPerhitungan.fromJson(Map<String, dynamic> json) =>
      TitikPerhitungan(
        titikKe: (json['titik_ke'] as num).toInt(),
        standard: (json['standard'] as num?)?.toDouble(),
        standardNominal: (json['standard_nominal'] as num?)?.toDouble(),
        standardDariSuhu: json['standard_dari_suhu'] as bool? ?? false,
        satuan: json['satuan'] as String?,
        average: (json['average'] as num?)?.toDouble(),
        averageSuhu: (json['average_suhu'] as num?)?.toDouble(),
        correction: (json['correction'] as num?)?.toDouble(),
        stdev: (json['stdev'] as num?)?.toDouble(),
        pembacaan: parseListAman((json['pembacaan'] as List<dynamic>? ?? const []), PembacaanPerhitungan.fromJson),
      );
}

/// Satu tabel hasil (Before / After adjustment).
class TabelPerhitungan {
  const TabelPerhitungan({
    required this.tahap,
    required this.judul,
    required this.titik,
    this.maxStdev,
  });

  final String tahap;
  final String judul;
  final List<TitikPerhitungan> titik;

  /// Penanda cepat titik mana yang pembacaannya paling nggak stabil.
  final double? maxStdev;

  /// Nomor Repeat terbanyak di antara semua titik — dipakai buat nentuin
  /// berapa baris tabelnya, tanpa nebak 5.
  int get jumlahPengulangan => titik.fold(
    0,
    (maks, t) => t.pembacaan.length > maks ? t.pembacaan.length : maks,
  );

  factory TabelPerhitungan.fromJson(Map<String, dynamic> json) =>
      TabelPerhitungan(
        tahap: json['tahap'] as String? ?? '',
        judul: json['judul'] as String? ?? '',
        maxStdev: (json['max_stdev'] as num?)?.toDouble(),
        titik: parseListAman((json['titik'] as List<dynamic>? ?? const []), TitikPerhitungan.fromJson),
      );
}

class Perhitungan {
  const Perhitungan({
    required this.identitasAlat,
    required this.identitasCustomer,
    required this.kondisiLingkungan,
    required this.hasil,
    this.nomorSesi,
  });

  final String? nomorSesi;
  final IdentitasAlat identitasAlat;
  final IdentitasCustomer identitasCustomer;
  final KondisiLingkungan kondisiLingkungan;
  final List<TabelPerhitungan> hasil;

  factory Perhitungan.fromJson(Map<String, dynamic> json) => Perhitungan(
    nomorSesi: json['nomor_sesi'] as String?,
    identitasAlat: IdentitasAlat.fromJson(
      json['identitas_alat'] as Map<String, dynamic>? ?? const {},
    ),
    identitasCustomer: IdentitasCustomer.fromJson(
      json['identitas_customer'] as Map<String, dynamic>? ?? const {},
    ),
    kondisiLingkungan: KondisiLingkungan.fromJson(
      json['kondisi_lingkungan'] as Map<String, dynamic>? ?? const {},
    ),
    hasil: parseListAman((json['hasil'] as List<dynamic>? ?? const []), TabelPerhitungan.fromJson),
  );
}
