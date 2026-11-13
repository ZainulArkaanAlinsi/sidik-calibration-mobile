/// Ukuran komponen yang bukan jarak — ikon, garis, sasaran sentuh, titik
/// patah. Pasangan [AppSpacing] (jarak & sudut): layar tidak menulis angka
/// piksel sendiri, jadi mengubah satu ukuran cukup di sini.
class AppUkuran {
  const AppUkuran._();

  /// Ikon yang sebaris dengan teks (chip, judul PT, jejak).
  static const double ikonSebaris = 18;

  /// Ikon besar pada keadaan kosong / galat / tanpa hasil.
  static const double ikonKeadaan = 48;

  /// Sasaran sentuh minimum (Material & pedoman aksesibilitas Android).
  static const double sasaranSentuh = 48;

  /// Garis tipis (pemisah) dan tebal (sorotan, judul PT).
  static const double garis = 1;
  static const double garisTebal = 2;

  /// Pemuat kecil di ujung daftar ("memuat halaman berikutnya").
  static const double indikatorKecil = 24;

  /// Tinggi garis kemajuan di bawah kotak cari.
  static const double indikatorGaris = 4;

  /// Label chip yang panjang dipotong di sini, bukan meluap.
  static const double labelChipMaks = 220;

  /// Lebar ruang di mana layar dua kolom (daftar + detail) dipakai.
  static const double ambangDuaKolom = 700;

  /// Tinggi maksimum lembar bawah sebagai bagian dari tinggi layar.
  static const double nisbiLembar = 0.8;

  /// Kerangka pemuat: tinggi dan lebar baris judul / baris keterangan.
  static const double skeletonJudul = 16;
  static const double skeletonKeterangan = 12;
  static const double skeletonLebarJudul = 160;
  static const double skeletonLebarKeterangan = 120;
}
