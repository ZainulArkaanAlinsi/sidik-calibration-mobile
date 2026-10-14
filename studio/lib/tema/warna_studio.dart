import 'package:flutter/material.dart';

/// Token warna **Sidik Studio** — satu-satunya tempat warna Studio ditulis.
///
/// Beda sengaja dari "Meja Kerja Lab" app lapangan (kertas krem, logam,
/// bayangan): Studio adalah alat kerja meja yang padat, mirip spreadsheet.
/// Permukaannya rata, pemisahnya garis 1 px, dan identitasnya diambil dari
/// ikon Studio — navy (kepala tabel) + amber (sel yang sedang ditinjau).
///
/// Aturan pakai amber: amber itu PENANDA (indikator menu aktif, sel terpilih,
/// fokus), bukan warna teks di atas putih — kontrasnya cuma ±2:1. Teks di atas
/// amber selalu navy. Untuk teks beraksen amber di tema terang pakai
/// [aksenTeks].
///
/// Kontras teks dijaga test `studio/test/tema_studio_test.dart` (WCAG AA,
/// ≥ 4,5:1). Jangan ubah satu warna teks tanpa menjalankan test itu.
@immutable
class WarnaStudio extends ThemeExtension<WarnaStudio> {
  const WarnaStudio({
    required this.terang,
    required this.latar,
    required this.permukaan,
    required this.permukaanRendah,
    required this.garis,
    required this.garisKuat,
    required this.teks,
    required this.teks2,
    required this.teksRedup,
    required this.primer,
    required this.diAtasPrimer,
    required this.aksen,
    required this.aksenTeks,
    required this.aksenTipis,
    required this.diAtasAksen,
    required this.sisi,
    required this.sisiAktif,
    required this.sisiTeks,
    required this.sisiTeksRedup,
    required this.sisiGaris,
    required this.lulus,
    required this.lulusTipis,
    required this.gagal,
    required this.gagalTipis,
    required this.awas,
    required this.awasTipis,
    required this.info,
    required this.infoTipis,
  });

  final bool terang;

  // ── Permukaan ─────────────────────────────────────────────────────────
  /// Latar jendela, di belakang panel.
  final Color latar;

  /// Panel, tabel, isian — tempat membaca.
  final Color permukaan;

  /// Kepala tabel, baris selang-seling, baki.
  final Color permukaanRendah;

  /// Pemisah sel & panel (dekoratif, 1 px).
  final Color garis;

  /// Garis kontrol (isian, tombol garis) — cukup tegas untuk dikenali.
  final Color garisKuat;

  // ── Teks ──────────────────────────────────────────────────────────────
  final Color teks;
  final Color teks2;

  /// Keterangan kecil. Masih ≥ 4,5:1 — bukan warna dekoratif.
  final Color teksRedup;

  // ── Interaksi ─────────────────────────────────────────────────────────
  /// Tombol utama, tautan, cincin fokus.
  final Color primer;
  final Color diAtasPrimer;

  /// Amber identitas — penanda, bukan teks.
  final Color aksen;

  /// Amber yang cukup tua untuk dipakai sebagai TEKS di atas [permukaan].
  final Color aksenTeks;

  /// Latar baris/sel terpilih.
  final Color aksenTipis;
  final Color diAtasAksen;

  // ── Sisi (sidebar / rail / drawer) ────────────────────────────────────
  final Color sisi;
  final Color sisiAktif;
  final Color sisiTeks;
  final Color sisiTeksRedup;
  final Color sisiGaris;

  // ── Status ────────────────────────────────────────────────────────────
  final Color lulus;
  final Color lulusTipis;
  final Color gagal;
  final Color gagalTipis;
  final Color awas;
  final Color awasTipis;
  final Color info;
  final Color infoTipis;

  static WarnaStudio of(BuildContext context) =>
      Theme.of(context).extension<WarnaStudio>() ?? terangBawaan;

  // Warna ikon Studio (`ikon_studio.py`): amber F59E0B, amber tua D97706,
  // navy 041E50.
  static const _navy = Color(0xFF041E50);

  static const terangBawaan = WarnaStudio(
    terang: true,
    latar: Color(0xFFF3F4F7),
    permukaan: Color(0xFFFFFFFF),
    permukaanRendah: Color(0xFFEEF1F5),
    garis: Color(0xFFD9DEE6),
    garisKuat: Color(0xFF8A94A6),
    teks: Color(0xFF0F1A2E),
    teks2: Color(0xFF465266),
    teksRedup: Color(0xFF5E6878),
    primer: Color(0xFF0B2A66),
    diAtasPrimer: Color(0xFFFFFFFF),
    aksen: Color(0xFFF59E0B),
    aksenTeks: Color(0xFF9A4A06),
    aksenTipis: Color(0xFFFFF3D6),
    diAtasAksen: _navy,
    sisi: _navy,
    sisiAktif: Color(0xFF14336E),
    sisiTeks: Color(0xFFE8EDF5),
    sisiTeksRedup: Color(0xFFA3B1C8),
    sisiGaris: Color(0xFF1C3A72),
    lulus: Color(0xFF166534),
    lulusTipis: Color(0xFFDCF3E3),
    gagal: Color(0xFFB42318),
    gagalTipis: Color(0xFFFDE5E3),
    awas: Color(0xFF9A4A06),
    awasTipis: Color(0xFFFFF0D4),
    info: Color(0xFF1D4ED8),
    infoTipis: Color(0xFFE1EAFD),
  );

  static const gelapBawaan = WarnaStudio(
    terang: false,
    latar: Color(0xFF0A0F18),
    permukaan: Color(0xFF111827),
    permukaanRendah: Color(0xFF172133),
    garis: Color(0xFF243044),
    garisKuat: Color(0xFF66748A),
    teks: Color(0xFFE7EBF2),
    teks2: Color(0xFFB0BACA),
    teksRedup: Color(0xFF8F9AAD),
    // Di gelap, amber jadi warna interaktif utama: navy tenggelam di latar
    // gelap, amber tetap terbaca dan tetap warna identitas.
    primer: Color(0xFFFBBF24),
    diAtasPrimer: _navy,
    aksen: Color(0xFFFBBF24),
    aksenTeks: Color(0xFFFCD34D),
    aksenTipis: Color(0xFF3A2C0B),
    diAtasAksen: _navy,
    sisi: Color(0xFF060B14),
    sisiAktif: Color(0xFF15213A),
    sisiTeks: Color(0xFFE7EBF2),
    sisiTeksRedup: Color(0xFF94A1B7),
    sisiGaris: Color(0xFF1A2438),
    lulus: Color(0xFF6EE7A0),
    lulusTipis: Color(0xFF10291C),
    gagal: Color(0xFFFF9B91),
    gagalTipis: Color(0xFF3A1714),
    awas: Color(0xFFFCD34D),
    awasTipis: Color(0xFF3A2C0B),
    info: Color(0xFF93B4FF),
    infoTipis: Color(0xFF15254A),
  );

  @override
  WarnaStudio copyWith() => this;

  @override
  WarnaStudio lerp(ThemeExtension<WarnaStudio>? other, double t) {
    if (other is! WarnaStudio) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return WarnaStudio(
      terang: t < 0.5 ? terang : other.terang,
      latar: c(latar, other.latar),
      permukaan: c(permukaan, other.permukaan),
      permukaanRendah: c(permukaanRendah, other.permukaanRendah),
      garis: c(garis, other.garis),
      garisKuat: c(garisKuat, other.garisKuat),
      teks: c(teks, other.teks),
      teks2: c(teks2, other.teks2),
      teksRedup: c(teksRedup, other.teksRedup),
      primer: c(primer, other.primer),
      diAtasPrimer: c(diAtasPrimer, other.diAtasPrimer),
      aksen: c(aksen, other.aksen),
      aksenTeks: c(aksenTeks, other.aksenTeks),
      aksenTipis: c(aksenTipis, other.aksenTipis),
      diAtasAksen: c(diAtasAksen, other.diAtasAksen),
      sisi: c(sisi, other.sisi),
      sisiAktif: c(sisiAktif, other.sisiAktif),
      sisiTeks: c(sisiTeks, other.sisiTeks),
      sisiTeksRedup: c(sisiTeksRedup, other.sisiTeksRedup),
      sisiGaris: c(sisiGaris, other.sisiGaris),
      lulus: c(lulus, other.lulus),
      lulusTipis: c(lulusTipis, other.lulusTipis),
      gagal: c(gagal, other.gagal),
      gagalTipis: c(gagalTipis, other.gagalTipis),
      awas: c(awas, other.awas),
      awasTipis: c(awasTipis, other.awasTipis),
      info: c(info, other.info),
      infoTipis: c(infoTipis, other.infoTipis),
    );
  }
}
