import '../../../models/usulan_ocr_awan.dart';

/// Teks layar usulan OCR awan, Bahasa Indonesia, satu tempat.
///
/// Sengaja BUKAN lewat `lib/l10n/*.arb` pada tahap draf ini: berkas hasil
/// generate (`app_localizations*.dart`, ratusan KB) ikut berubah dan bentrok
/// dengan PR lain. Setelah tampilannya disetujui pemilik, string ini dipindah
/// ke ARB dalam satu commit terpisah.
abstract final class TeksOcrAwan {
  static const judul = 'Usulan bacaan awan';

  static const penjelasan =
      'Ini usulan, bukan hasil. Cocokkan tiap angka dengan kertas, '
      'lalu putuskan satu per satu.';

  static String sisa(int menunggu) => menunggu == 0
      ? 'Semua usulan sudah diputuskan.'
      : '$menunggu usulan belum diputuskan.';

  static const sebagian = 'Sebagian sel tidak sempat dibaca awan.';

  static String dilewati(int jumlah) =>
      '$jumlah sel tidak dibaca awan. Isi sendiri atau pakai pembaca di HP.';

  static const labelAwan = 'Terbaca awan';
  static const labelNormal = 'Dirapikan jadi angka';
  static const labelUsulan = 'Usulan angka';

  static const duaBentukBeda =
      'Dua bentuk ini berbeda. Pilih yang sesuai dengan kertas.';

  static const pakai = 'Pakai usulan';
  static const ubah = 'Ubah';
  static const tolak = 'Tolak';
  static const batalkan = 'Batalkan';
  static const simpan = 'Simpan';
  static const batal = 'Batal';

  static const perluDicek = 'Perlu dicek';
  static const dipakai = 'Dipakai';
  static const diubah = 'Diubah';
  static const ditolak = 'Ditolak';

  static const labelIsian = 'Angka dari kertas';
  static const galatIsian = 'Hanya angka, mis. 4,01';

  static String nilaiPegangan(String teks) => 'Nilai: $teks';

  static const judulTanpaUsulan = 'Tanpa usulan, isi sendiri';

  static String tanpaUsulan(AlasanTanpaUsulan sebab) => switch (sebab) {
    AlasanTanpaUsulan.merah =>
      'Bacaan awan tidak dipakai. Isi sendiri dari kertas.',
    AlasanTanpaUsulan.kosong =>
      'Awan tidak melihat tulisan di sel ini. Tetap kosong sampai diisi.',
    AlasanTanpaUsulan.bentukTidakDikenal =>
      'Bacaan awan bukan angka murni, jadi tidak ditawarkan. Isi sendiri.',
    AlasanTanpaUsulan.selIdentitas =>
      'Kolom identitas tidak dibaca awan. Isi sendiri.',
  };

  /// Alasan sel dalam kalimat manusia. Daftar dari
  /// `docs/perintah-frontend-ocr-lembar-kerja.md` (aturan layar review).
  /// Kode yang tidak dikenal TIDAK ditampilkan mentah dan tidak ditebak.
  static String alasan(String kode) =>
      _alasan[kode] ??
      'Ada catatan dari server yang belum dikenal aplikasi ini. '
          'Cocokkan dengan kertas.';

  static const _alasan = <String, String>{
    'teks_meluber_dari_sel':
        'Tulisannya keluar dari kotak, bisa jadi terbaca dari kolom sebelah.',
    'di_luar_rentang': 'Angkanya di luar rentang wajar titik ini.',
    'magnitudo_meleset': 'Angkanya jauh dari nilai standar titik ini.',
    'ada_koreksi_karakter': 'Ada huruf yang ditebak jadi angka.',
    'desimal_kebanyakan': 'Desimalnya lebih banyak dari resolusi alat.',
    'bukan_kelipatan_resolusi':
        'Angkanya tidak mungkin keluar dari alat dengan resolusi ini.',
    'jauh_dari_repeat_lain':
        'Angkanya jauh beda dari Repeat lain di baris ini.',
    'sebar_repeat_tidak_diuji':
        'Repeat yang terbaca terlalu sedikit untuk dibandingkan.',
    'terlalu_banyak_substitusi': 'Terlalu banyak huruf yang harus ditebak.',
    'karakter_di_luar_whitelist':
        'Ada karakter yang bukan angka, jadi bacaan ditolak.',
    'spasi_di_dalam_angka': 'Ada spasi di tengah angka.',
    'pemisah_ribuan_tidak_didukung':
        'Ada pemisah ribuan (mis. 1.234,56). Tidak dibuang otomatis.',
    'bentuk_angka_tidak_wajar': 'Bentuk angkanya tidak masuk akal.',
    'digit_kebanyakan': 'Digitnya kebanyakan untuk kolom ini.',
    'pemisah_desimal_tidak_wajar': 'Letak koma atau titiknya tidak wajar.',
    'desimal_ambigu': 'Tidak jelas titik itu koma desimal atau pemisah ribuan.',
    'minus_di_tengah': 'Ada tanda minus di tengah angka.',
    'minus_tidak_diizinkan': 'Kolom ini tidak boleh bernilai negatif.',
  };
}
