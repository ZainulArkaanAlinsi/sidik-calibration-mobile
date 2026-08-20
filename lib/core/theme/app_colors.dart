import 'package:flutter/material.dart';

/// Palet "Cobalt" — lima warna inti dari palet resmi.
///
/// Aturan pakainya cuma satu, tapi keras: **warna inti dipakai rata, tidak
/// pernah dicampur satu sama lain.** Tidak ada gradasi crimson-ke-cobalt,
/// tidak ada halo mint yang menimpa amber. Kalau butuh tingkatan, yang boleh
/// dilakukan adalah menggelapkan/menerangkan satu warna yang sama (turunan di
/// bawah) — bukan meleburkan dua warna berbeda.
///
/// Pembagian perannya:
/// - **Ivory** bidang dasar terang, **Ink** bidang dasar gelap + semua teks.
/// - **Cobalt** satu-satunya warna interaktif: tombol utama, tautan, penanda
///   aktif. Tidak pernah berarti status.
/// - **Mint** aksen sekunder + status lolos.
/// - **Crimson** status gagal dan error. Dipakai paling irit supaya tetap
///   punya bobot waktu muncul.
///
/// Kalau PT Sidik ganti warna brand, cukup ganti di file ini — tidak boleh ada
/// `Color(0x...)` yang ditulis langsung di widget.
class AppColors {
  const AppColors._();

  // ── Palet inti ──────────────────────────────────────────────────────────
  static const Color crimson = Color(0xFFD91E41); // Crimson Red
  static const Color ink = Color(0xFF1A1A1A); // Jet Black
  static const Color mint = Color(0xFF9FF5E4); // Arctic Mint
  static const Color ivory = Color(0xFFFDFDF6); // Bright Ivory
  static const Color cobalt = Color(0xFF2962FF); // Cobalt Blue

  // ── Turunan ─────────────────────────────────────────────────────────────
  // Masing-masing cuma versi lebih gelap/terang dari satu warna inti, dipakai
  // waktu warna intinya sendiri nggak cukup kontras di posisi itu.
  static const Color cobaltDeep = Color(0xFF0A2C9E); // teks di atas cobaltSoft
  static const Color cobaltSoft = Color(0xFFE4EAFF); // isian kontainer terang
  static const Color cobaltLight = Color(0xFF86A5FF); // cobalt di tema gelap

  // Mint aslinya terlalu terang buat jadi teks di atas bidang putih; versi
  // gelapnya yang dipakai kalau mint harus kebaca sebagai huruf, bukan bidang.
  static const Color mintDeep = Color(0xFF0B7A67);
  static const Color mintSoft = Color(0xFFDDFAF3);
  static const Color mintInk = Color(
    0xFF05473B,
  ); // isian kontainer di tema gelap

  static const Color crimsonDeep = Color(0xFF8C0C26);
  static const Color crimsonSoft = Color(0xFFFFE2E7);
  static const Color crimsonLight = Color(0xFFFF97A9); // crimson di tema gelap

  // ── Netral terang ───────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF); // kartu, di atas ground ivory
  static const Color ivoryDim = Color(0xFFF2F2EA); // permukaan tingkat dua
  static const Color hairline = Color(0xFFE3E3DA); // garis & border
  static const Color textMuted = Color(0xFF55555B);
  static const Color outline = Color(0xFF77777D);

  // ── Netral gelap ────────────────────────────────────────────────────────
  // Ground sengaja lebih gelap dari Jet Black, biar permukaan #1A1A1A yang asli
  // kebaca timbul di atasnya tanpa perlu garis pemisah.
  static const Color inkDeep = Color(0xFF0F0F0F);
  static const Color inkSurface = ink;
  static const Color inkElevated = Color(0xFF262626);
  static const Color inkOutline = Color(0xFF3A3A3A);
  static const Color inkTextMuted = Color(0xFFB4B4AE);

  // ── Semantik ────────────────────────────────────────────────────────────
  // Status hasil kalibrasi & alat. Selalu dipasangkan sama ikon + teks, nggak
  // pernah warna doang. Empat status = empat rona yang beda jelas, supaya
  // teknisi nggak perlu baca dulu buat tahu mana yang bermasalah.
  static const Color success = mintDeep; // PASS / disetujui
  static const Color danger = crimson; // FAIL / ditolak
  // Overdue / perlu revisi = "butuh dilihat", bukan "gagal". Dulu amber, dan
  // amber di atas ivory selalu kebaca coklat kusam — warna kelima yang bukan
  // bagian palet. Cobalt bedanya jelas dari crimson tanpa nambah rona baru;
  // yang bikin dia nggak ketuker sama tombol adalah badge selalu bawa ikon +
  // teks, sementara tombol selalu bidang pekat.
  static const Color warning = cobalt;
  static const Color info = textMuted; // menunggu approval / draft

  // Versi tema gelap. Nggak ada satu nilai pun yang bisa kebaca sekaligus di
  // atas putih dan di atas Jet Black — kalau cukup gelap buat latar terang, dia
  // ketelen sama latar gelap, dan sebaliknya. Jadi tiap status punya dua nilai
  // dan dipilih lewat [statusSukses] dkk.
  static const Color successDark = mint;
  static const Color dangerDark = crimsonLight;
  static const Color warningDark = cobaltLight;
  static const Color infoDark = inkTextMuted;

  static bool _gelap(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color statusSukses(BuildContext context) =>
      _gelap(context) ? successDark : success;
  static Color statusBahaya(BuildContext context) =>
      _gelap(context) ? dangerDark : danger;
  static Color statusPeringatan(BuildContext context) =>
      _gelap(context) ? warningDark : warning;
  static Color statusInfo(BuildContext context) =>
      _gelap(context) ? infoDark : info;

  /// Warna bidang dasar layar. Rata, satu warna — bukan gradasi.
  ///
  /// Kedalaman digambar sama bayangan kartu, bukan sama latar yang melandai:
  /// ground ivory di belakang kartu putih sudah cukup bikin kartunya kebaca
  /// timbul, dan bidang rata bikin warna aksen di atasnya kelihatan bersih.
  static Color warnaLatar(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? inkDeep : ivory;
  }
}
