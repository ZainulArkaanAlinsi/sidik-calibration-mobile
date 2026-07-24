/// Kelompok pengukuran (`GET /api/categories`, `docs/kontrak-api.md` §3).
/// `rentangUkur`/`ketidakpastianTerbaik`/`satuan` di sini cuma ringkasan
/// buat dropdown — jangan dipakai buat validasi (satu kategori bisa punya
/// banyak satuan sekaligus, lihat `GET /api/categories/{kode}`).
library;
import '../core/utils/parse_list.dart';

class Category {
  const Category({
    required this.kode,
    required this.nama,
    this.rentangUkur,
    this.ketidakpastianTerbaik,
    this.satuan,
  });

  final String kode;
  final String nama;
  final String? rentangUkur;
  final double? ketidakpastianTerbaik;
  final String? satuan;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      kode: json['kode'] as String,
      nama: json['nama'] as String,
      rentangUkur: json['rentang_ukur'] as String?,
      ketidakpastianTerbaik: (json['ketidakpastian_terbaik'] as num?)
          ?.toDouble(),
      satuan: json['satuan'] as String?,
    );
  }
}

/// Satu rentang kemampuan kalibrasi (CMC) — dari lampiran akreditasi
/// LK-285-IDN. Alat yang `namaAlatKemampuan`-nya nunjuk ke salah satu
/// `namaAlat` di sini bakal dihitung ketidakpastiannya pakai angka CMC resmi
/// ini (`GumCalculator::hitungDariKemampuan()` di backend), bukan jalur
/// generik standar+resolusi — jadi field ini penting buat akurasi sertifikat.
class CalibrationCapability {
  const CalibrationCapability({
    required this.namaAlat,
    this.parameter,
    this.rangeMin,
    this.rangeMax,
    this.rangeNote,
    this.satuan,
    this.ketidakpastianTerbaik,
    this.satuanKetidakpastian,
    this.faktorCakupan,
    this.metode,
  });

  final String namaAlat;
  final String? parameter;

  /// **Bisa `null`** — sebagian kemampuan batasnya bukan angka (titik
  /// tunggal atau teks kayak "ambient"). Lihat [rangeNote].
  final double? rangeMin;
  final double? rangeMax;
  final String? rangeNote;
  final String? satuan;
  final double? ketidakpastianTerbaik;
  final String? satuanKetidakpastian;
  final double? faktorCakupan;
  final String? metode;

  factory CalibrationCapability.fromJson(Map<String, dynamic> json) {
    return CalibrationCapability(
      namaAlat: json['nama_alat'] as String,
      parameter: json['parameter'] as String?,
      rangeMin: (json['range_min'] as num?)?.toDouble(),
      rangeMax: (json['range_max'] as num?)?.toDouble(),
      rangeNote: json['range_note'] as String?,
      satuan: json['satuan'] as String?,
      ketidakpastianTerbaik: (json['ketidakpastian_terbaik'] as num?)
          ?.toDouble(),
      satuanKetidakpastian: json['satuan_ketidakpastian'] as String?,
      faktorCakupan: (json['faktor_cakupan'] as num?)?.toDouble(),
      metode: json['metode'] as String?,
    );
  }
}

/// Respons `GET /api/categories/{kode}` — daftar penuh kemampuan kalibrasi
/// satu kategori, dipakai buat dropdown "Jenis Alat (Kemampuan Kalibrasi)"
/// di form Alat.
class CategoryDetail {
  const CategoryDetail({
    required this.kode,
    required this.nama,
    required this.kemampuan,
  });

  final String kode;
  final String nama;
  final List<CalibrationCapability> kemampuan;

  factory CategoryDetail.fromJson(Map<String, dynamic> json) {
    final list = json['kemampuan'] as List<dynamic>? ?? const [];
    return CategoryDetail(
      kode: json['kode'] as String,
      nama: json['nama'] as String,
      kemampuan: parseListAman(list, CalibrationCapability.fromJson),
    );
  }
}
