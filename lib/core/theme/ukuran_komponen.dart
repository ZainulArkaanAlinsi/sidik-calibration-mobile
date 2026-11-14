/// Ukuran komponen bersama Lab (Paket 2): ikon, huruf angka, tik skala, keypad,
/// navigasi, dan ambang tata letak.
///
/// Pelengkap [BentukLab] (sudut, sentuh) dan `AppSpacing` (jarak): komponen di
/// `lib/widgets/sidik/` tidak menulis angka piksel sendiri, jadi mengubah satu
/// ukuran cukup di sini. Angka mengikuti skala di `docs/standar-kualitas-desain.md`.
library;

/// Ambang tata letak yang dipakai lebih dari satu komponen.
abstract final class AmbangLab {
  /// Di bawah lebar ini (dp) tombol berdampingan dan baris berstempel kanan
  /// pindah ke susunan bertumpuk.
  static const double lebarSempit = 360;

  /// Skala huruf sistem di atas ini dianggap "huruf besar": susunan bertumpuk,
  /// keypad layar tidak dipakai. Sama dengan ambang `bolehKeypadLayar`.
  static const double hurufBesar = 1.15;

  /// Lebar (dp) mulai navigasi pindah dari bar bawah ke rail samping. Sama
  /// dengan `MainShell._lebarRail`.
  static const double rail = 900;

  /// Sisi terpendek layar (dp) yang dianggap tablet: keypad dan angka bacaan
  /// memakai ukuran tablet.
  static const double tablet = 600;

  /// Lebar baca maksimum satu daftar.
  static const double lebarBaca = 720;

  /// Lebar maksimum bilah aksi dan isi Lajur Bacaan di layar lebar.
  static const double lebarBilah = 560;
}

/// Ukuran baris daftar.
abstract final class UkuranBaris {
  /// Tinggi minimum baris yang diketuk (dua tingkat teks).
  static const double minimum = 64;

  /// Bagian lebar baris yang boleh dipakai stempel di kanan; sisanya untuk
  /// judul. Stempel yang lebih panjang membungkus.
  static const double bagianStempel = 0.4;
}

/// Ukuran ikon (dp).
abstract final class UkuranIkonLab {
  /// Ikon di dalam stempel status.
  static const double stempel = 16;

  /// Ikon yang sebaris dengan teks isi (penunjuk, meta baris, tanda galat).
  static const double sebaris = 20;

  /// Ikon navigasi (bar dan rail).
  static const double navigasi = 24;

  /// Pemutar kecil di dalam tombol yang sibuk.
  static const double pemutar = 20;
}

/// Ukuran huruf yang bukan bagian skala `textTheme` (dp). Minimum tetap 12.
abstract final class UkuranTeksLab {
  /// Stempel status: 13/16, berat 700.
  static const double stempel = 13;
  static const double stempelBaris = 16;

  /// Lencana angka di navigasi.
  static const double lencana = 12;

  /// Angka bacaan Lajur Bacaan (Plex Mono 500): HP 40/48, tablet 56/64.
  static const double angkaBacaan = 40;
  static const double angkaBacaanBaris = 48;
  static const double angkaBacaanTablet = 56;
  static const double angkaBacaanTabletBaris = 64;

  /// Angka bacaan di mode ringkas (papan ketik sistem terbuka).
  static const double angkaRingkas = 24;

  /// Satuan di samping angka bacaan.
  static const double satuanBacaan = 20;

  /// Digit pada tombol keypad.
  static const double tombolKeypad = 22;
}

/// Ukuran tik dan batang pada skala (SkalaTempo, SkalaSel).
abstract final class UkuranTikLab {
  /// Tinggi batang (trek) skala jatuh tempo.
  static const double trek = 8;

  /// Tinggi tik jadwal dan penanda "hari ini".
  static const double penanda = 20;

  /// Lebar tik jadwal dan penanda "hari ini".
  static const double batangJadwal = 2;
  static const double batangHariIni = 4;

  /// Tinggi tik bulanan di sepanjang batang (lebih tinggi dari [trek] supaya
  /// menonjol di atas dan di bawahnya).
  static const double tikBulan = 14;

  /// Tinggi satu tik sel pada SkalaSel.
  static const double tikSel = 16;

  /// Jarak antar tik sel.
  static const double jarakTikSel = 2;

  /// Lebar tik pengulangan di kepala Lajur Bacaan.
  static const double tikUlang = 12;
  static const double tinggiTikUlang = 4;
}

/// Ukuran Lajur Bacaan.
abstract final class UkuranLajur {
  /// Tinggi tombol keypad: 52 di HP, 64 di tablet.
  static const double tombolHp = 52;
  static const double tombolTablet = 64;

  /// Lebar kursor di belakang angka.
  static const double kursor = 3;

  /// Jumlah baris keypad yang direntang tombol "Berikutnya" (>= 3).
  static const int barisBerikutnya = 3;
}

/// Ukuran navigasi adaptif.
abstract final class UkuranNavigasi {
  /// Tinggi minimum bar bawah.
  static const double tinggiBar = 72;

  /// Lebar rail samping (berlabel).
  static const double lebarRail = 80;

  /// Kapsul keadaan aktif di belakang ikon.
  static const double kapsulLebar = 64;
  static const double kapsulTinggi = 32;

  /// Tinggi minimum satu butir rail.
  static const double butirRailMin = 72;

  /// Sisi minimum lencana angka (kotak, lalu dibulatkan menjadi pil).
  static const double lencana = 20;
}
