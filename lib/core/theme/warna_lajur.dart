import 'package:flutter/material.dart';

import 'palet_lab.dart';
import 'sidik_material.dart';

/// Warna Lajur Bacaan: panel instrumen yang SELALU gelap, di dua tema.
///
/// Tidak menulis nilai mentah: semuanya dibaca dari [PaletLab] dan
/// [SidikMaterial]. Peran:
///
/// - [panel]: terang = `#0E1320` (permukaan alat ukur, gelap di atas terang);
///   gelap = `#171D2B` (permukaan), diberi [garisAtas] supaya tidak melebur
///   dengan latar `#0E1320`.
/// - [angka], [redup], [aksen], [peringatan]: teks angka, keterangan, kursor dan
///   tik aktif, catatan.
/// - [tombol], [teksTombol]: tombol "Berikutnya" (kobalt 300, label kobalt tua).
/// - [kunci], [tepiKunci]: tombol keypad dan garis tegas tepinya (3:1).
///
/// Sengaja TIDAK ada warna hijau, merah, atau "lulus/gagal": Lajur tidak
/// menghitung, tidak memvonis, dan tidak mewarnai angka menurut hasilnya
/// (`docs/standar-kualitas-desain.md`). `peringatan` adalah amber untuk
/// CATATAN keadaan sel (mis. "saran dari foto"), bukan penilaian angka.
///
/// Kontras dijaga `test/tema/kontras_komponen_test.dart`.
@immutable
class WarnaLajur {
  const WarnaLajur({
    required this.panel,
    required this.garisAtas,
    required this.angka,
    required this.redup,
    required this.aksen,
    required this.tombol,
    required this.teksTombol,
    required this.kunci,
    required this.tepiKunci,
    required this.peringatan,
  });

  final Color panel;
  final Color garisAtas;
  final Color angka;
  final Color redup;
  final Color aksen;
  final Color tombol;
  final Color teksTombol;
  final Color kunci;
  final Color tepiKunci;
  final Color peringatan;

  /// Turunan dari token tema [m].
  factory WarnaLajur.dari(SidikMaterial m) => WarnaLajur(
    panel: m.terang ? m.kaca : m.kaca2,
    // Terang: garis atas sewarna panel (tidak terlihat, tidak perlu). Gelap:
    // garis tegas supaya panel terpisah dari latar.
    garisAtas: m.terang ? m.kaca : PaletLab.garisTegasGelap,
    angka: m.lcdTeks,
    redup: PaletLab.tinta2Gelap,
    aksen: m.biruAtas,
    tombol: m.biruAtas,
    teksTombol: PaletLab.kobaltDiAtas300,
    kunci: m.terang ? m.kaca2 : PaletLab.latar2Gelap,
    tepiKunci: PaletLab.garisTegasGelap,
    peringatan: m.lcdAmber,
  );

  /// Ambil dari tema yang sedang berlaku.
  static WarnaLajur of(BuildContext context) =>
      WarnaLajur.dari(SidikMaterial.of(context));
}
