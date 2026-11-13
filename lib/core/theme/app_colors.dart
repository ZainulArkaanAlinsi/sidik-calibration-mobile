import 'package:flutter/material.dart';

import 'palet_lab.dart';

/// Palet Lab (kobalt + netral dingin) di bawah NAMA-NAMA LAMA.
///
/// ## Kenapa namanya tidak diganti
///
/// 33 berkas di luar `core/theme` memanggil `AppColors.xxx` langsung. Mengganti
/// nama berarti menyentuh puluhan layar yang logikanya sudah benar. Jadi yang
/// berubah cuma NILAINYA (13 Nov 2026): tiap nama lama dipetakan ke peran yang
/// sama di palet baru, dan setiap layar yang memakainya ikut berganti tanpa
/// satu baris logika pun disentuh. Nama lama dikikis bertahap oleh paket layar.
///
/// Petanya (nama lama → peran sekarang):
///
/// | Nama lama | Peran |
/// |---|---|
/// | `ivory` | latar layar (`#F2F4F8`) |
/// | `white` | kertas: baris, kartu, isian (`#FFFFFF`) |
/// | `ivoryDim` / `hairline` | permukaan cekung / garis halus |
/// | `ink` / `textMuted` | tinta / tinta kedua |
/// | `cobalt*` | kobalt `#043EA1` dan jenjangnya, satu-satunya warna interaktif |
/// | `mintDeep` / `mintSoft` | status berlaku/PASS + latar tipisnya |
/// | `crimson*` | status gagal/FAIL + latar tipisnya |
/// | `mint` | hijau di atas permukaan gelap saja |
/// | `ink*` (tema gelap) | latar dan permukaan gelap |
///
/// Sumber nilainya `PaletLab`; `SidikMaterial` membaca dari sana juga, dan
/// `test/tema/kontras_sidik_test.dart` menjaga keduanya tetap selaras dan
/// kontrasnya.
///
/// Aturan yang tetap: **tidak ada gradasi dua rona berbeda.**
class AppColors {
  const AppColors._();

  // ── Inti ────────────────────────────────────────────────────────────────
  static const Color crimson = PaletLab.gagalTerang; // FAIL, 7,3:1 di kertas
  static const Color ink = PaletLab.tintaTerang; // tinta, 17,7:1 di kertas
  static const Color mint = PaletLab.lulusGelap; // hijau di atas gelap saja
  static const Color ivory = PaletLab.latarTerang; // latar layar tema terang
  static const Color cobalt = PaletLab.kobalt700; // kobalt, 9,5:1 di kertas

  // ── Turunan (satu rona, beda terang) ────────────────────────────────────
  static const Color cobaltDeep = PaletLab.kobalt900;
  static const Color cobaltSoft = PaletLab.kobalt100;
  static const Color cobaltLight = PaletLab.kobalt300; // kobalt di tema gelap

  static const Color mintDeep = PaletLab.lulusTerang; // LULUS, 7,3:1 di kertas
  static const Color mintSoft = PaletLab.lulusLatarTerang;
  static const Color mintInk = PaletLab.lulusLatarGelap; // dasar LULUS gelap

  static const Color crimsonDeep = PaletLab.gagalTua;
  static const Color crimsonSoft = PaletLab.gagalLatarTerang;
  static const Color crimsonLight = PaletLab.gagalGelap; // GAGAL tema gelap

  // ── Netral terang ───────────────────────────────────────────────────────
  // `white` adalah putih murni sekarang (dulu krem). Tempat yang BENAR-BENAR
  // butuh putih (latar QR, kanvas tanda tangan) memakai `Colors.white`
  // langsung dan tidak terpengaruh.
  static const Color white = PaletLab.kertasTerang;
  static const Color ivoryDim = PaletLab.kertas2Terang; // permukaan cekung
  static const Color hairline = PaletLab.garisHalusTerang; // garis halus
  static const Color textMuted = PaletLab.tinta2Terang; // 7,7:1 di kertas
  // Garis komponen (isian, sakelar): 4,6:1 di kertas, ambang WCAG 1.4.11 = 3:1.
  static const Color outline = PaletLab.garisTegasTerang;

  // ── Netral gelap ────────────────────────────────────────────────────────
  static const Color inkDeep = PaletLab.latarGelap; // latar gelap
  static const Color inkSurface = PaletLab.kertasGelap; // kertas gelap
  static const Color inkElevated = PaletLab.latar2Gelap;
  static const Color inkOutline = PaletLab.garisHalusGelap;
  static const Color inkTextMuted =
      PaletLab.tinta2Gelap; // 7,9:1 di kertas gelap

  // ── Semantik status ─────────────────────────────────────────────────────
  static const Color success = PaletLab.lulusTerang; // PASS / disetujui
  static const Color danger = PaletLab.gagalTerang; // FAIL / ditolak
  // "Butuh dilihat" (segera, perlu revisi). Amber: 5,1:1 di latar tipisnya.
  static const Color warning = PaletLab.awasTerang;
  static const Color info = PaletLab.tungguTerang; // menunggu / draf

  static const Color successDark = PaletLab.lulusGelap;
  static const Color dangerDark = PaletLab.gagalGelap;
  static const Color warningDark = PaletLab.awasGelap;
  static const Color infoDark = PaletLab.tungguGelap;

  static bool _gelap(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Pemilih sadar-tema: panggil ini, bukan konstanta mentah, supaya warna status
  // tetap kebaca di dua tema.
  static Color statusSukses(BuildContext context) =>
      _gelap(context) ? successDark : success;
  static Color statusBahaya(BuildContext context) =>
      _gelap(context) ? dangerDark : danger;
  static Color statusPeringatan(BuildContext context) =>
      _gelap(context) ? warningDark : warning;
  static Color statusInfo(BuildContext context) =>
      _gelap(context) ? infoDark : info;

  /// Latar layar = permukaan latar tema aktif.
  static Color warnaLatar(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? inkDeep : ivory;
  }
}

/// Palet "Cobalt" lama, DIBEKUKAN — khusus onboarding.
///
/// Pemilik proyek minta onboarding (tiga adegan 3D) dan sakelar tema
/// matahari/bulan TIDAK diubah. Onboarding memanggil `AppColors` untuk warna
/// tiap adegannya; tanpa kelas ini, mengganti nilai `AppColors` di atas ikut
/// mengubah adegan itu diam-diam. Jadi onboarding memakai salinan beku ini,
/// dan nilainya sama persis dengan sebelum redesign.
///
/// Jangan dipakai di layar lain. Layar baru pakai `AppColors` atau
/// `SidikMaterial.of(context)`.
class AppColorsTitanium {
  const AppColorsTitanium._();

  static const Color crimson = Color(0xFFD91E41);
  static const Color crimsonDeep = Color(0xFF8C0C26);
  static const Color ink = Color(0xFF1A1A1A);
  static const Color inkDeep = Color(0xFF0F0F0F);
  static const Color ivory = Color(0xFFFDFDF6);
  static const Color cobalt = Color(0xFF2962FF);
  static const Color cobaltDeep = Color(0xFF0A2C9E);
  static const Color mintDeep = Color(0xFF0B7A67);
  static const Color mintInk = Color(0xFF05473B);
}
