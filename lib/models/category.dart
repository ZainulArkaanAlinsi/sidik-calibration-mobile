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
    this.profil,
    this.tanpaCmc = false,
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

  /// Kode profil lembar kerja buat alat ini (`tits`, `oven`, `ph_meter`, ...),
  /// dituturkan backend di tiap baris kemampuan. `null` = nggak punya lembar
  /// khusus, pakai form generik.
  ///
  /// Ini SUMBER KEBENARAN-nya sekarang. Sebelum ini profilnya ditebak di HP
  /// lewat `profilLembarKerjaUntuk()` — tabel ejaan nama alat yang ikut
  /// ke-bundel di dalam APK. Akibatnya alat yang baru ditambah admin atau
  /// teknisi mustahil dapat lembar yang benar sampai ada rilis APK baru:
  /// tabelnya ada di HP orang, bukan di server.
  final String? profil;

  /// `true` = alat ini belum punya baris CMC di lampiran akreditasi
  /// LK-285-IDN — biasanya nama alat yang baru ditambah teknisi sendiri lewat
  /// `POST /api/categories/{kode}/kemampuan`.
  ///
  /// Bukan sekadar catatan: tanpa baris CMC, sesi yang memakai alat ini nggak
  /// punya lantai ketidakpastian, jadi U95 yang terbit bisa lebih KECIL
  /// daripada yang diakreditasi lab — dan nggak ada satu pun error yang bunyi,
  /// angkanya cuma keluar kelihatan terlalu bagus. Makanya penandanya wajib
  /// kelihatan di kartu picker.
  final bool tanpaCmc;

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
      profil: _bacaProfil(json['profil']),
      tanpaCmc: _bacaTanpaCmc(json['tanpa_cmc']),
    );
  }
}

/// `profil` yang bukan String, atau string kosong, dianggap `null` = form
/// generik.
///
/// Dua kegagalan yang dicegah. Satu, `json['profil'] as String?` NGELEMPAR
/// kalau backend suatu saat ngirim angka atau objek di situ — dan lemparan itu
/// ditelan [parseListAman], jadi barisnya dibuang diam-diam dan kartu alatnya
/// HILANG dari picker. Dua, string kosong bakal dioper apa adanya ke
/// `LembarKerjaScreen` dan bikin layar minta bentuk lembar `''` ke server.
String? _bacaProfil(dynamic nilai) {
  if (nilai is! String) return null;
  final bersih = nilai.trim();
  return bersih.isEmpty ? null : bersih;
}

/// `tanpa_cmc` yang nggak ada = `false` — server lama nggak ngirim field ini
/// sama sekali, dan itu nggak boleh mematikan layar.
///
/// Sengaja nerima `1`/`0` & `"true"`/`"false"` juga, bukan cuma bool: kolom
/// tinyint yang lupa di-`cast` di Eloquent nyampe ke sini sebagai `1`, dan
/// `as bool?` bakal ngelempar di situ. Alasannya sama kayak [_bacaProfil] —
/// [parseListAman] nelen lemparannya dan kartu alatnya ikut hilang. Penanda
/// yang meleset masih jauh lebih baik daripada kartu yang nggak ada.
bool _bacaTanpaCmc(dynamic nilai) {
  if (nilai is bool) return nilai;
  if (nilai is num) return nilai != 0;
  if (nilai is String) {
    final n = nilai.trim().toLowerCase();
    return n == 'true' || n == '1';
  }
  return false;
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
