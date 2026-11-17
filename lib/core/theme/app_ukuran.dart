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

/// Ukuran Biru Awan (`docs/desain-ulang/tokens.json` → `ukuran`), tambahan di
/// samping [AppUkuran] dan `UkuranLab` yang TIDAK diubah (komponen lama dan
/// `tanda_cek_sel` masih membacanya). Layar yang didesain ulang tidak menulis
/// angka sendiri: semua lewat nama di bawah. Nilai dari
/// `docs/desain-ulang/flutter/bentuk_ukuran_lab.dart`.
abstract final class UkuranBiruAwan {
  static const double tombolUtama = 56;
  static const double tombolTegas = 48;
  static const double tombolBulatKecil = 44;
  static const double tombolKembali = 48;
  static const double tombolMulaiDock = 60;
  static const double butirDockTeknisi = 52;
  static const double butirDockAdmin = 48;
  static const double kolomCari = 56;
  static const double chip = 44;
  static const double stempel = 30;
  static const double barisDaftar = 72;
  static const double barisMenu = 64;
  static const double kartuDrafLebar = 196;
  static const double kartuDrafTinggi = 148;

  /// Minimum, boleh tumbuh.
  static const double ubinPilihAlat = 164;

  /// Minimum.
  static const double hero = 212;
  static const double bilahLangkah = 6;
  static const double visualHero = 188;
  static const double visualUbin = 104;
  static const double visualDraf = 92;
  static const double visualBaris = 44;
}
