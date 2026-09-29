import 'package:flutter/material.dart';

/// Palet "Meja Kerja Lab" — di bawah NAMA-NAMA LAMA palet "Cobalt".
///
/// ## Kenapa namanya tidak diganti
///
/// 33 berkas di luar `core/theme` memanggil `AppColors.xxx` langsung. Mengganti
/// nama berarti menyentuh 33 berkas layar yang logikanya sudah benar — dan
/// pemilik proyek minta tugas ini cuma mengganti tampilan. Jadi yang berubah
/// cuma NILAINYA: tiap nama lama dipetakan ke peran yang sama di sistem baru,
/// dan setiap layar yang memakainya ikut berganti tanpa satu baris logika pun
/// disentuh.
///
/// Petanya (nama lama → peran baru):
///
/// | Nama lama | Peran di "Meja Kerja Lab" |
/// |---|---|
/// | `ivory` | MEJA — latar layar |
/// | `white` | KERTAS — kartu & isian |
/// | `ivoryDim` / `hairline` | kertas tingkat dua / tepi kertas |
/// | `ink` / `textMuted` | tinta pulpen / tinta keterangan |
/// | `cobalt*` | biru anodisasi — satu-satunya warna interaktif |
/// | `mintDeep` / `mintSoft` | tinta cap LULUS + dasarnya |
/// | `crimson*` | tinta cap GAGAL + dasarnya |
/// | `mint` | hijau LCD — cuma di atas permukaan gelap/kaca |
/// | `ink*` (tema gelap) | meja & kertas versi gelap |
///
/// Sumber kebenaran nilainya `SidikMaterial` (lihat `sidik_material.dart`);
/// angka di sini disalin dari sana, dan `test/tema/kontras_sidik_test.dart`
/// menjaga kontrasnya. Kalau salah satu digeser, geser dua-duanya.
///
/// Aturan yang tetap sama dari palet lama: **tidak ada gradasi dua rona
/// berbeda.** Kedalaman datang dari bayangan & gradien satu-nada material.
class AppColors {
  const AppColors._();

  // ── Inti ────────────────────────────────────────────────────────────────
  static const Color crimson = Color(0xFFA81B33); // tinta cap GAGAL, 6,5:1 di kertas
  static const Color ink = Color(0xFF1A1F26); // tinta pulpen, 14,7:1 di kertas
  static const Color mint = Color(0xFF7FE3A8); // hijau LCD — di atas gelap saja
  static const Color ivory = Color(0xFFD6D2C8); // MEJA: latar layar tema terang
  static const Color cobalt = Color(0xFF1D4292); // biru anodisasi, 8,3:1 di kertas

  // ── Turunan (satu rona, beda terang) ────────────────────────────────────
  static const Color cobaltDeep = Color(0xFF14306E);
  static const Color cobaltSoft = Color(0xFFDFE7F8);
  static const Color cobaltLight = Color(0xFF8FB0FF); // biru di tema gelap, 7,0:1

  static const Color mintDeep = Color(0xFF125739); // LULUS, 7,6:1 di kertas
  static const Color mintSoft = Color(0xFFDCEBE0);
  static const Color mintInk = Color(0xFF16301F); // dasar LULUS tema gelap

  static const Color crimsonDeep = Color(0xFF7E1426);
  static const Color crimsonSoft = Color(0xFFF6DEE2);
  static const Color crimsonLight = Color(0xFFFF8092); // GAGAL tema gelap, 6,2:1

  // ── Netral terang ───────────────────────────────────────────────────────
  // `white` sekarang KERTAS krem, bukan putih murni. Namanya dipertahankan
  // karena artinya di kode lama memang "permukaan kartu di atas ground".
  // Tempat yang BENAR-BENAR butuh putih (latar QR, kanvas tanda tangan)
  // sudah memakai `Colors.white` langsung dan tidak terpengaruh.
  static const Color white = Color(0xFFF5F1E7);
  static const Color ivoryDim = Color(0xFFEAE5D8); // kertas tingkat dua / baki
  static const Color hairline = Color(0xFFD9D2C0); // tepi kertas
  static const Color textMuted = Color(0xFF4A5059); // 7,2:1 di kertas · 5,4:1 di meja
  // Garis komponen (isian, sakelar) — 3:1 di kertas, ambang WCAG 1.4.11.
  // `logamTepi` #9C998F cuma 2,6:1 dan terlalu pucat untuk batas isian.
  static const Color outline = Color(0xFF7A776F);

  // ── Netral gelap ────────────────────────────────────────────────────────
  static const Color inkDeep = Color(0xFF0F1114); // meja gelap
  // Dulu alias `ink`. Sekarang berdiri sendiri: `ink` adalah TINTA di tema
  // terang, dan menjadikannya permukaan gelap sekaligus membuat satu warna
  // punya dua arti yang berlawanan.
  static const Color inkSurface = Color(0xFF24272D); // kertas gelap
  static const Color inkElevated = Color(0xFF2C3037);
  static const Color inkOutline = Color(0xFF33373E);
  static const Color inkTextMuted = Color(0xFFA6A9B1); // 6,4:1 di kertas gelap

  // ── Semantik status ─────────────────────────────────────────────────────
  static const Color success = mintDeep; // PASS / disetujui
  static const Color danger = crimson; // FAIL / ditolak
  // Overdue / perlu revisi = "butuh dilihat". Di palet Cobalt dulu dipakai
  // biru karena amber lama terbaca coklat kusam di atas ivory. Amber di sini
  // (#8C5C0A) disetel ulang: 5,1:1 di kertas, dan TERANGNYA dijauhkan dari
  // hijau & merah (beda luminans ≥ 0,02) supaya tetap kebeda di fotokopi
  // hitam-putih dan buat mata buta warna merah-hijau. Biru sekarang kembali
  // ke satu arti saja: "bisa dipencet".
  static const Color warning = Color(0xFF8C5C0A);
  static const Color info = Color(0xFF474D55); // menunggu approval / draft

  static const Color successDark = Color(0xFF5DCE93);
  static const Color dangerDark = crimsonLight;
  static const Color warningDark = Color(0xFFF2B655);
  static const Color infoDark = Color(0xFFB6BAC4);

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

  /// Latar layar = permukaan MEJA.
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
