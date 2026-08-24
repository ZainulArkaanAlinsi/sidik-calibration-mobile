/// Versi aplikasi terbaru yang terbit, hasil `GET /api/app/versi-terbaru`.
///
/// Backend menumpang GitHub Releases repo ini — bukan tabel sendiri — supaya
/// tidak ada dua tempat yang harus dijaga tetap sama. Lihat
/// `VersiAplikasiController` di repo API.
library;

/// Perbandingan dua nomor versi bergaya `1.4.12`.
///
/// **Bukan perbandingan teks.** `'1.4.9'.compareTo('1.4.12')` memulangkan
/// angka POSITIF karena `'9' > '1'` sebagai huruf — artinya teknisi yang
/// memegang 1.4.9 dianggap lebih baru daripada 1.4.12 dan tidak pernah
/// ditawari pemutakhiran. Itu gagal tanpa error, dan baru ketahuan waktu
/// seseorang sadar dia ketinggalan berbulan-bulan.
///
/// Bagian yang bukan angka diperlakukan sebagai 0, dan panjang yang berbeda
/// disamakan dengan 0 — `1.4` lawan `1.4.0` sama.
int bandingkanVersi(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  final n = pa.length > pb.length ? pa.length : pb.length;

  for (var i = 0; i < n; i++) {
    final va = i < pa.length ? (int.tryParse(pa[i].trim()) ?? 0) : 0;
    final vb = i < pb.length ? (int.tryParse(pb[i].trim()) ?? 0) : 0;
    if (va != vb) return va < vb ? -1 : 1;
  }

  return 0;
}

class VersiAplikasi {
  const VersiAplikasi({
    required this.versi,
    required this.urlUnduh,
    this.build,
    this.tag,
    this.ukuran,
    this.catatan,
    this.wajib = false,
  });

  /// `1.4.12` — tanpa `v` dan tanpa nomor build.
  final String versi;

  /// Tautan langsung ke berkas APK di GitHub Release.
  final String urlUnduh;

  final int? build;
  final String? tag;

  /// Byte. 0/null = backend tidak tahu ukurannya.
  final int? ukuran;

  final String? catatan;

  /// Pemutakhiran yang tidak boleh ditunda — mis. bentuk payload berubah dan
  /// versi lama diam-diam mengirim data yang salah.
  ///
  /// Backend sudah mengirimkannya sejak sekarang walau nilainya selalu
  /// `false`, supaya begitu suatu hari memang perlu, yang berubah cukup sisi
  /// rilis — tidak perlu menunggu aplikasi lama diperbarui lebih dulu, yang
  /// justru mustahil karena aplikasi lama itulah yang mau dipaksa update.
  final bool wajib;

  /// Ukuran dalam MB, dibulatkan — buat ditulis di tombol unduh. Teknisi di
  /// lapangan memakai data seluler, dan 50 MB itu keputusan buat dia.
  String? get ukuranMb {
    final b = ukuran;
    if (b == null || b <= 0) return null;

    return '${(b / 1024 / 1024).round()} MB';
  }

  /// Versi ini lebih baru daripada [terpasang]?
  bool lebihBaruDari(String terpasang) =>
      terpasang.trim().isNotEmpty && bandingkanVersi(terpasang, versi) < 0;

  /// `null` kalau backend menjawab `tersedia: false` — GitHub tidak terjawab,
  /// belum ada rilis, atau rilisnya tanpa APK. Ketiganya bukan error yang
  /// perlu ditampilkan: aplikasinya tetap jalan, cuma tidak tahu ada versi
  /// baru atau tidak.
  static VersiAplikasi? fromJson(Map<String, dynamic> json) {
    if (json['tersedia'] != true) return null;

    final versi = (json['versi'] as String? ?? '').trim();
    final url = (json['url_unduh'] as String? ?? '').trim();
    if (versi.isEmpty || url.isEmpty) return null;

    return VersiAplikasi(
      versi: versi,
      urlUnduh: url,
      build: (json['build'] as num?)?.toInt(),
      tag: json['tag'] as String?,
      ukuran: (json['ukuran'] as num?)?.toInt(),
      catatan: json['catatan'] as String?,
      wajib: json['wajib'] as bool? ?? false,
    );
  }
}
