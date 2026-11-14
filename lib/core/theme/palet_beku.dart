import 'package:flutter/painting.dart';

/// PALET BEKU: salinan MENTAH `PaletLab` per 14 Nov 2026 (desain ulang Lab, L1a).
///
/// Lembar kerja berstatus BEKU (`docs/desain-ulang/BEKU.md`): warnanya tidak
/// boleh berubah walau palet Lab diganti ke Biru Awan. Karena itu berkas ini
/// menulis ulang nilainya sebagai angka dan TIDAK merujuk `PaletLab`; yang
/// membacanya hanya `TemaBeku`, `BentukBeku`/`UkuranBeku` di bawah, dan
/// `AppColors` (pemakai terakhirnya layar beku).
///
/// ## Jangan diubah
///
/// Nilai di sini tidak boleh digeser oleh PR desain mana pun. Merah di
/// `test/beku/lembar_kerja_golden_test.dart` atau
/// `test/beku/berkas_beku_test.dart` berarti ada yang menyentuhnya. Palet baru
/// ditulis di `palet_lab.dart`, bukan di sini. Nama sengaja SAMA dengan
/// `PaletLab` supaya salinan ini bisa dibandingkan baris demi baris.
///
/// Warna ditulis sebagai angka hanya boleh di folder `lib/core/theme/`
/// (`test/support/pemindai_token.dart`); karena itu tidak ada pengecualian baru
/// di `test/tema/token_only_test.dart`.
abstract final class PaletBeku {
  // ── Kobalt: satu warna merek, empat jenjang ─────────────────────────────
  /// Jenjang 100: sel aktif, baris terpilih, tombol tonal.
  static const Color kobalt100 = Color(0xFFDCE6FA);

  /// Jenjang 300: kobalt di atas permukaan gelap.
  static const Color kobalt300 = Color(0xFF8CB0FF);

  /// Jenjang 700: aksi, fokus, tab aktif, tautan (logo PT SIDIK).
  static const Color kobalt700 = Color(0xFF043EA1);

  /// Jenjang 900: teks di atas kobalt tipis.
  static const Color kobalt900 = Color(0xFF0A2A6B);

  /// Label di atas kobalt 300 (tombol utama tema gelap).
  static const Color kobaltDiAtas300 = Color(0xFF04265F);

  /// Isi tonal kobalt di tema gelap, dan teksnya.
  static const Color kobaltGelapTipis = Color(0xFF14306F);
  static const Color kobaltGelapTeks = Color(0xFFD6E3FF);

  // ── Netral dingin, tema terang ──────────────────────────────────────────
  static const Color putih = Color(0xFFFFFFFF);

  /// Latar belakang layar.
  static const Color latarTerang = Color(0xFFF2F4F8);

  /// Permukaan baris, lembar, sel.
  static const Color kertasTerang = Color(0xFFFFFFFF);

  /// Permukaan cekung (baki, isi isian).
  static const Color kertas2Terang = Color(0xFFF8F9FC);

  /// Permukaan terangkat (wadah sekunder).
  static const Color latar2Terang = Color(0xFFE9EDF4);

  static const Color tintaTerang = Color(0xFF111827);
  static const Color tinta2Terang = Color(0xFF475467);

  /// Garis tegas: tepi isian, sel, tombol sekunder, ikon penting (3:1).
  static const Color garisTegasTerang = Color(0xFF6B7588);

  /// Abu yang masih 4,5:1 di latar dan baki, untuk keterangan redup yang
  /// memakai `colorScheme.outline` sebagai TEKS.
  static const Color garisTeksTerang = Color(0xFF5F6B7E);

  /// Garis halus: pemisah baris. Hiasan, tidak boleh membawa makna sendiri.
  static const Color garisHalusTerang = Color(0xFFDDE2EB);

  // ── Netral dingin, tema gelap ───────────────────────────────────────────
  static const Color latarGelap = Color(0xFF0E1320);
  static const Color kertasGelap = Color(0xFF171D2B);
  static const Color kertas2Gelap = Color(0xFF131927);
  static const Color latar2Gelap = Color(0xFF1E2535);
  static const Color tintaGelap = Color(0xFFE6EAF2);
  static const Color tinta2Gelap = Color(0xFFA9B2C3);
  static const Color garisTegasGelap = Color(0xFF7C879B);
  static const Color garisHalusGelap = Color(0xFF2C3548);

  /// Isi snack bar dan tooltip tema gelap.
  static const Color terangkatGelap = Color(0xFF283044);

  // ── Status, tema terang: tinta + latar tipis ────────────────────────────
  static const Color lulusTerang = Color(0xFF125739);
  static const Color lulusLatarTerang = Color(0xFFE1F0E8);

  /// Amber lebih terang dari milik Pelanggan (`#7A4F08`): jaraknya dari merah
  /// dan hijau >= 0,02 luminans, supaya tetap beda di fotokopi hitam-putih dan
  /// bagi mata buta warna. 5,1:1 di latar tipisnya, >= 4,9:1 di semua permukaan.
  static const Color awasTerang = Color(0xFF8C5C0A);
  static const Color awasLatarTerang = Color(0xFFFBF0DA);
  static const Color gagalTerang = Color(0xFFA81B33);
  static const Color gagalLatarTerang = Color(0xFFFBE4E8);
  static const Color tungguTerang = Color(0xFF344054);
  static const Color tungguLatarTerang = Color(0xFFE6EAF2);

  // ── Status, tema gelap ──────────────────────────────────────────────────
  static const Color lulusGelap = Color(0xFF6FD3A0);
  static const Color lulusLatarGelap = Color(0xFF12301F);

  /// Beda dari milik Pelanggan (`#F2B655`, hampir sama terangnya dengan hijau
  /// gelap): jarak luminans >= 0,05 dari hijau dan merah, 6,1:1 sampai 7,7:1.
  static const Color awasGelap = Color(0xFFDB9A2B);
  static const Color awasLatarGelap = Color(0xFF33260C);
  static const Color gagalGelap = Color(0xFFFF8FA0);
  static const Color gagalLatarGelap = Color(0xFF3A1720);
  static const Color tungguGelap = Color(0xFFC3CAD8);
  static const Color tungguLatarGelap = Color(0xFF262E40);

  /// Label di atas isi merah tema gelap (tombol bahaya).
  static const Color gagalDiAtasGelap = Color(0xFF24070D);

  // ── Tinta pensil (angka saran OCR, belum dipastikan manusia) ────────────
  static const Color pensilTerang = garisTeksTerang;
  static const Color pensilGelap = Color(0xFF8E98AC);

  // ── Lain-lain ───────────────────────────────────────────────────────────
  /// Tembus pandang total: pengganti kilau/lekuk material lama.
  static const Color tembus = Color(0x00FFFFFF);

  /// Merah tua untuk `AppColors.crimsonDeep` (tidak ada di keluarga Pelanggan).
  static const Color gagalTua = Color(0xFF7E1426);
}

/// Salinan literal `BentukLab` (radius, dp) yang dibaca `TemaBeku`. Angka, bukan
/// rujukan: mengubah `BentukLab` nanti tidak boleh menggeser sudut lembar kerja.
abstract final class BentukBeku {
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

/// Salinan literal `UkuranLab` (tinggi area sentuh, dp) yang dibaca `TemaBeku`.
abstract final class UkuranBeku {
  /// Aksi utama layar: satu per layar.
  static const double aksiUtama = 56;

  /// Semua aksi lain: tombol sekunder, tombol teks, ikon, baris yang diketuk.
  static const double aksi = 48;

  /// Desktop (alat tunjuk tetikus).
  static const double aksiMeja = 44;
}
