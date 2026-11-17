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

/// Ukuran Biru Awan (`docs/desain-ulang/tokens.json` → `ukuran`, diselaraskan ke
/// REVISI 16 Nov 2026), tambahan di samping [AppUkuran] dan `UkuranLab` yang
/// TIDAK diubah (komponen lama, area beku, dan `tanda_cek_sel` masih
/// membacanya). Layar yang didesain ulang tidak menulis angka sendiri: semua
/// lewat nama di bawah.
///
/// Tombol dan isian utama 48 (revisi: 44-48), lencana status 24, tanpa blok
/// besar. Sasaran sentuh tetap >= 48 (area ketuk dilebarkan komponen bila
/// gambarnya lebih kecil).
abstract final class UkuranBiruAwan {
  static const double tombolUtama = 48;
  static const double tombolTegas = 48;
  static const double tombolBulatKecil = 44;
  static const double tombolKembali = 48;

  /// Tombol Mulai di tengah bilah teknisi.
  static const double tombolMulaiDock = 48;

  /// Tinggi bilah navigasi bawah (belum termasuk tepi sistem).
  static const double tinggiBilah = 64;

  /// Kapsul penanda butir aktif di bilah: 56 x 32.
  static const double kapsulBilahLebar = 56;
  static const double kapsulBilahTinggi = 32;
  static const double kolomCari = 48;
  static const double chip = 44;
  static const double stempel = 24;
  static const double barisDaftar = 64;
  static const double barisMenu = 64;

  /// Minimum, boleh tumbuh.
  static const double ubinPilihAlat = 164;

  /// Minimum panel hero (kecil: hanya ilustrasi, bukan banner layar).
  static const double hero = 140;
  static const double bilahLangkah = 6;
  static const double visualHero = 188;
  static const double visualUbin = 104;
  static const double visualDraf = 92;
  static const double visualBaris = 44;
}
