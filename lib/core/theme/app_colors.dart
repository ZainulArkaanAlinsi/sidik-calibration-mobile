import 'package:flutter/material.dart';

import 'palet_beku.dart';

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
/// Sumber nilainya `PaletBeku` (salinan beku `PaletLab` per 14 Nov 2026; desain
/// ulang Lab L1a), BUKAN `PaletLab`: pemakai `AppColors` yang masih beku
/// (lembar kerja) tidak boleh ikut berubah saat palet Lab diganti.
/// `test/tema/kontras_sidik_test.dart` menjaga kesejajarannya dengan
/// `SidikMaterial` milik `TemaBeku`, dan kontrasnya.
///
/// Catatan: `AppColors` juga dipakai layar yang TIDAK beku (138 pemakaian di 35
/// berkas luar `core/theme`, dihitung 14 Nov 2026; hanya 8 di antaranya di tiga
/// berkas beku). Layar itu tetap membaca nilai lama sampai ia sendiri didesain
/// ulang dan berhenti memakai `AppColors`.
///
/// Aturan yang tetap: **tidak ada gradasi dua rona berbeda.**
class AppColors {
  const AppColors._();

  // ── Inti ────────────────────────────────────────────────────────────────
  static const Color crimson = PaletBeku.gagalTerang; // FAIL, 7,3:1 di kertas
  static const Color ink = PaletBeku.tintaTerang; // tinta, 17,7:1 di kertas
  static const Color mint = PaletBeku.lulusGelap; // hijau di atas gelap saja
  static const Color ivory = PaletBeku.latarTerang; // latar layar tema terang
  static const Color cobalt = PaletBeku.kobalt700; // kobalt, 9,5:1 di kertas

  // ── Turunan (satu rona, beda terang) ────────────────────────────────────
  static const Color cobaltDeep = PaletBeku.kobalt900;
  static const Color cobaltSoft = PaletBeku.kobalt100;
  static const Color cobaltLight = PaletBeku.kobalt300; // kobalt di tema gelap

  static const Color mintDeep = PaletBeku.lulusTerang; // LULUS, 7,3:1 di kertas
  static const Color mintSoft = PaletBeku.lulusLatarTerang;
  static const Color mintInk = PaletBeku.lulusLatarGelap; // dasar LULUS gelap

  static const Color crimsonDeep = PaletBeku.gagalTua;
  static const Color crimsonSoft = PaletBeku.gagalLatarTerang;
  static const Color crimsonLight = PaletBeku.gagalGelap; // GAGAL tema gelap

  // ── Netral terang ───────────────────────────────────────────────────────
  // `white` adalah putih murni sekarang (dulu krem). Tempat yang BENAR-BENAR
  // butuh putih (latar QR, kanvas tanda tangan) memakai `Colors.white`
  // langsung dan tidak terpengaruh.
  static const Color white = PaletBeku.kertasTerang;
  static const Color ivoryDim = PaletBeku.kertas2Terang; // permukaan cekung
  static const Color hairline = PaletBeku.garisHalusTerang; // garis halus
  static const Color textMuted = PaletBeku.tinta2Terang; // 7,7:1 di kertas
  // Garis komponen (isian, sakelar): 4,6:1 di kertas, ambang WCAG 1.4.11 = 3:1.
  static const Color outline = PaletBeku.garisTegasTerang;

  // ── Netral gelap ────────────────────────────────────────────────────────
  static const Color inkDeep = PaletBeku.latarGelap; // latar gelap
  static const Color inkSurface = PaletBeku.kertasGelap; // kertas gelap
  static const Color inkElevated = PaletBeku.latar2Gelap;
  static const Color inkOutline = PaletBeku.garisHalusGelap;
  static const Color inkTextMuted =
      PaletBeku.tinta2Gelap; // 7,9:1 di kertas gelap

  // ── Semantik status ─────────────────────────────────────────────────────
  static const Color success = PaletBeku.lulusTerang; // PASS / disetujui
  static const Color danger = PaletBeku.gagalTerang; // FAIL / ditolak
  // "Butuh dilihat" (segera, perlu revisi). Amber: 5,1:1 di latar tipisnya.
  static const Color warning = PaletBeku.awasTerang;
  static const Color info = PaletBeku.tungguTerang; // menunggu / draf

  static const Color successDark = PaletBeku.lulusGelap;
  static const Color dangerDark = PaletBeku.gagalGelap;
  static const Color warningDark = PaletBeku.awasGelap;
  static const Color infoDark = PaletBeku.tungguGelap;

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
