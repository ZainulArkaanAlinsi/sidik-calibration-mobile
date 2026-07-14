import 'package:flutter/material.dart';

/// Palet warna ASMO.
///
/// Diambil dari warna yang udah dipakai di diagram alur project (vault
/// Obsidian) — teal + navy + aksen kuning — biar app, dokumen, dan diagram
/// kelihatan satu keluarga.
///
/// Kalau nanti PT ASMO ngasih warna brand resmi, cukup ganti nilai di file
/// ini. Nggak boleh ada `Color(0x...)` yang ditulis langsung di widget.
class AppColors {
  const AppColors._();

  // Brand
  static const Color primary = Color(0xFF0E5C68); // teal — warna utama
  static const Color primaryDark = Color(0xFF0A4650);
  static const Color secondary = Color(0xFF1B7A8A); // teal muda
  static const Color navy = Color(0xFF0E2A33); // teks & permukaan gelap
  static const Color accent = Color(0xFFE9C46A); // kuning — aksen & warning

  // Semantik — status hasil kalibrasi & alat.
  // PASS/FAIL sengaja nggak cuma dibedain warna: komponen status selalu
  // bawa ikon + teks, biar tetap kebaca sama yang buta warna.
  static const Color success = Color(0xFF2E7D5B); // PASS / disetujui
  static const Color danger = Color(0xFFC1443A); // FAIL / ditolak
  static const Color warning = Color(0xFFB47C1E); // overdue / perlu revisi
  static const Color info = Color(0xFF1B7A8A); // menunggu approval / draft

  // Netral
  static const Color surfaceLight = Color(0xFFF7F9FA);
  static const Color surfaceDark = Color(0xFF0E2A33);
  static const Color outline = Color(0xFF9BAAB0);
}
