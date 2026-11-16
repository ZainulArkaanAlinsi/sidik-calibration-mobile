/// Token bentuk (radius) dan ukuran sentuh Lab. Satu set, dengan alasan:
/// kalau layar butuh sudut, ambil dari sini, bukan angka bebas.
abstract final class BentukLab {
  /// 4 dp: sel tabel dan stempel status.
  static const double sel = 4;
  static const double stempel = 4;

  /// 8 dp: panel data (kartu ringkasan, sel pemeriksaan, dialog kecil).
  static const double panel = 8;

  /// 10 dp: kontrol (tombol sekunder, isian, chip filter, ubin).
  static const double kontrol = 10;

  /// 16 dp: tombol utama.
  static const double utama = 16;

  /// 20 dp: lembar bawah, dock, dialog.
  static const double lembar = 20;

  /// Pil penuh. Hanya lencana angka.
  static const double pil = 999;
}

/// Sudut Biru Awan, diselaraskan ke REVISI 16 Nov 2026
/// (`docs/desain-ulang/REVISI-16NOV.md`): kartu 12-16, tombol dan isian 8-12,
/// tanpa sudut ekstrem. Tambahan di samping [BentukLab] yang TIDAK diubah:
/// `AppSpacing.radius*`, `SidikMaterial.sudut*` dan komponen lama (termasuk yang
/// dipakai area beku) masih membacanya. Layar yang didesain ulang memakai set
/// ini.
///
/// Pil (999) tinggal untuk bentuk yang memang lingkaran: avatar, titik,
/// tombol bulat. Tombol, lencana status, kolom cari, dan saringan memakai sudut
/// persegi di bawah.
abstract final class BentukBiruAwan {
  /// Ikon ubin.
  static const double ikonUbin = 12;

  /// Kotak isian.
  static const double isian = 12;

  /// Kartu, baris-panel, antrean, ubin.
  static const double kartu = 16;

  /// Panel kecil berilustrasi (hero, ubin KPI sorot) dan wadah segmen.
  static const double hero = 16;

  /// Dialog.
  static const double dialog = 16;

  /// Sudut ATAS lembar bawah dan sudut kanan laci.
  static const double lembarBawah = 16;

  /// Tombol berlabel (utama, tegas, sekunder, teks, bahaya).
  static const double tombol = 10;

  /// Kolom cari, saringan (chip), dan wadah segmen.
  static const double saringan = 12;

  /// Butir terpilih di dalam segmen.
  static const double penandaSegmen = 8;

  /// Lencana status dan lencana jumlah (kotak kecil, bukan pil).
  static const double lencana = 6;

  /// Lingkaran sungguhan saja: avatar, titik, tombol bulat.
  static const double pil = 999;
}

/// Ukuran area sentuh (dp). Aksi utama 56, sisanya 48 (WCAG 2.5.8 minimal 24;
/// Material 48). Desktop Windows dipakai dengan tetikus, jadi lebih rapat.
abstract final class UkuranLab {
  /// Aksi utama layar: satu per layar.
  static const double aksiUtama = 56;

  /// Semua aksi lain: tombol sekunder, tombol teks, ikon, baris yang diketuk.
  static const double aksi = 48;

  /// Desktop (alat tunjuk tetikus).
  static const double aksiMeja = 44;
}
