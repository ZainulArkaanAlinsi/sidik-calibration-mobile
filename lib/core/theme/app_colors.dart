import 'package:flutter/material.dart';

/// Palet "Titanium" — diambil dari desain di
/// `Project-PT-Sidik/gambar/` (DESIGN.md + screenshot login & register).
///
/// Karakternya: monokrom high-contrast (navy nyaris hitam di atas putih),
/// teal dipakai **irit** cuma buat sinyal fungsional (sukses, data
/// tervalidasi, link). Bukan warna hiasan.
///
/// Kalau PT Sidik ngasih warna brand resmi, cukup ganti di file ini —
/// nggak boleh ada `Color(0x...)` yang ditulis langsung di widget.
class AppColors {
  const AppColors._();

  // Brand — Titanium
  static const Color navy = Color(0xFF0F172A); // primary, teks, tombol utama
  static const Color navyDeep = Color(0xFF0B1C30);
  static const Color teal = Color(0xFF006B5F); // aksen fungsional, dipakai irit
  static const Color tealBright = Color(0xFF14B8A6); // aksen di tema gelap
  // Aksen "instrument panel". Amber dipakai terbatas untuk penanda aktif,
  // bukan sebagai warna status, supaya ada rasa retro yang hangat tanpa
  // mengganggu arti hijau/merah pada data kalibrasi.
  static const Color signalAmber = Color(0xFFF2B84B);
  static const Color electricBlue = Color(0xFF5CC8FF);

  // Netral (light)
  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8F9FA);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color titanium = Color(0xFFE2E8F0); // garis rambut & border
  static const Color textMuted = Color(0xFF45464D);
  static const Color outline = Color(0xFF76777D);

  // Netral (dark) — dari screenshot login
  static const Color darkBase = Color(0xFF0B1E26);
  static const Color darkSurface = Color(0xFF0E2A33);
  static const Color darkElevated = Color(0xFF13333D);
  static const Color darkOutline = Color(0xFF34505A);
  static const Color darkTextMuted = Color(0xFFB6C9D4);

  // Semantik — status hasil kalibrasi & alat.
  // Selalu dipasangkan sama ikon + teks, nggak pernah warna doang.
  static const Color success = Color(0xFF006B5F); // PASS / disetujui
  static const Color danger = Color(0xFFBA1A1A); // FAIL / ditolak
  static const Color warning = Color(0xFFB47C1E); // overdue / perlu revisi
  static const Color info = Color(0xFF3F465C); // menunggu approval / draft

  /// Latar bergradasi buat layar yang isinya kartu timbul (`SoftRaised`).
  ///
  /// Bayangan lembut cuma kebaca sebagai kedalaman kalau bidang di belakangnya
  /// punya arah cahaya. Di atas warna rata, bayangan yang sama malah kelihatan
  /// kayak noda abu-abu.
  ///
  /// Condong ke biru, bukan abu-abu netral. Kartu putih di atas bidang biru
  /// muda kebaca lebih "ngambang" — bayangannya punya warna buat dikontraskan.
  /// Di atas abu-abu, kartu putih dan bayangannya nyaris menyatu.
  static LinearGradient gradasiLatar(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gelap
          ? const [Color(0xFF102C38), Color(0xFF091A21)]
          : const [Color(0xFFDCE8F7), Color(0xFFF4F8FD)],
    );
  }

  /// Halo warna besar di belakang permukaan kaca. Bukan pola digital/matrix:
  /// cukup dua sumber cahaya lembut agar UI terasa seperti panel instrumen
  /// retro yang dilapis kaca.
  static List<BoxShadow> glowLatar(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: (gelap ? tealBright : electricBlue).withValues(
          alpha: gelap ? 0.11 : 0.15,
        ),
        blurRadius: 90,
        spreadRadius: 18,
        offset: const Offset(-42, -66),
      ),
      BoxShadow(
        color: signalAmber.withValues(alpha: gelap ? 0.055 : 0.09),
        blurRadius: 100,
        spreadRadius: 12,
        offset: const Offset(110, 180),
      ),
    ];
  }
}
