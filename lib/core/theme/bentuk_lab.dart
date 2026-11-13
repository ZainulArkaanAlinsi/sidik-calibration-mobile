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
