import 'package:flutter/material.dart';

import 'palet_lab.dart';
import 'sidik_material.dart';

/// Isi berwarna yang dipakai komponen Biru Awan (stempel, ubin ikon, bulatan
/// jumlah di chip). Nama mengikuti `tokens.json`.
enum IsiBiruAwan {
  /// Ubin terpilih, latar ikon. `kabut`.
  kabut,

  /// Lulus, disetujui. `hijau`.
  hijau,

  /// Perlu dicek, revisi, segera. `kuning`.
  kuning,

  /// Menunggu approval. `awan`.
  awan,

  /// Ditolak, tak terbaca, lewat jadwal. `koral`.
  koral,

  /// Latar tipis galat (ubin ikon). `kabutGagal`.
  koralTipis,

  /// Draf, tanpa keputusan. `netralStempel`.
  netral,
}

/// Warna yang dibutuhkan komponen Biru Awan tetapi tidak ada di
/// [SidikMaterial] (tanpa `koral`, `netralStempel`, `koralBatang`), diturunkan
/// dari [PaletLab] (terang) dan pasangan status [SidikMaterial] yang sudah ada
/// (gelap). Tidak menulis nilai mentah; mengikuti pola `WarnaLajur`.
///
/// Kenapa bukan field baru di [SidikMaterial]: konstruktornya dipakai
/// `tema_beku.dart` (di-hash, `BEKU.md`), jadi menambah field wajib mengubah
/// berkas beku.
///
/// ## Terang
/// Isi `tokens.json`; tinta di atasnya SELALU navy (`tinta`): 11,23 hijau,
/// 10,59 kuning, 10,19 awan, 6,85 koral, 13,50 kabut.
///
/// ## Gelap (utang desain, `standar-kualitas-desain.md` §11 butir 1)
/// `tokens.json` belum punya status gelap. Dipakai pasangan yang sudah ada
/// (`lulusTipis`+`lulus`, dst.); netral memakai garis halus gelap; FAIL memakai
/// isi `gagal` gelap dengan `teksDiGagal`.
///
/// Kontras tiap pasangan dijaga `test/tema/kontras_biru_awan_test.dart`.
@immutable
class WarnaBiruAwan {
  const WarnaBiruAwan._({
    required Map<IsiBiruAwan, Color> isi,
    required Map<IsiBiruAwan, Color> tinta,
    required this.isiFail,
    required this.tintaFail,
    required this.tepiGalat,
    required this.tintaGalat,
    required this.latarMati,
    required this.tepiMati,
    required this.isiTombolMati,
    required this.tintaTombolMati,
    required this.bayanganMulai,
  }) : _isi = isi,
       _tinta = tinta;

  final Map<IsiBiruAwan, Color> _isi;
  final Map<IsiBiruAwan, Color> _tinta;

  /// FAIL "Tidak memenuhi toleransi": navy pekat + teks putih (terang), tidak
  /// dilunakkan (`DESIGN.md`).
  final Color isiFail;
  final Color tintaFail;

  /// Tepi isian galat (`koralBatang`, 3,36:1 di putih; gelap: `gagal`).
  final Color tepiGalat;

  /// Teks dan ikon galat (`SidikMaterial.gagal`).
  final Color tintaGalat;

  /// Isian mati: latar dan tepi.
  final Color latarMati;
  final Color tepiMati;

  /// Tombol mati: isi netral dan label tinta kedua.
  final Color isiTombolMati;
  final Color tintaTombolMati;

  /// Bayangan tombol Mulai (primer; alfa dipasang pemakai).
  final Color bayanganMulai;

  /// Isi dan tinta pasangannya untuk [n].
  Color isi(IsiBiruAwan n) => _isi[n]!;
  Color tinta(IsiBiruAwan n) => _tinta[n]!;

  factory WarnaBiruAwan.dari(SidikMaterial m) {
    if (m.terang) {
      return WarnaBiruAwan._(
        isi: const {
          IsiBiruAwan.kabut: PaletLab.kabut,
          IsiBiruAwan.hijau: PaletLab.hijau,
          IsiBiruAwan.kuning: PaletLab.kuning,
          IsiBiruAwan.awan: PaletLab.awan,
          IsiBiruAwan.koral: PaletLab.koral,
          IsiBiruAwan.koralTipis: PaletLab.kabutGagal,
          IsiBiruAwan.netral: PaletLab.netralStempel,
        },
        tinta: {for (final n in IsiBiruAwan.values) n: m.tinta},
        isiFail: m.tinta,
        tintaFail: m.kertas,
        tepiGalat: PaletLab.koralBatang,
        tintaGalat: m.gagal,
        latarMati: m.meja,
        tepiMati: m.kertasTepi,
        isiTombolMati: PaletLab.netralStempel,
        tintaTombolMati: m.tinta2,
        bayanganMulai: m.biru,
      );
    }
    return WarnaBiruAwan._(
      isi: {
        IsiBiruAwan.kabut: m.biruTipis,
        IsiBiruAwan.hijau: m.lulusTipis,
        IsiBiruAwan.kuning: m.awasTipis,
        IsiBiruAwan.awan: m.tungguTipis,
        IsiBiruAwan.koral: m.gagalTipis,
        IsiBiruAwan.koralTipis: m.gagalTipis,
        IsiBiruAwan.netral: m.kertasTepi,
      },
      tinta: {
        IsiBiruAwan.kabut: m.tinta,
        IsiBiruAwan.hijau: m.lulus,
        IsiBiruAwan.kuning: m.awas,
        IsiBiruAwan.awan: m.tunggu,
        IsiBiruAwan.koral: m.gagal,
        IsiBiruAwan.koralTipis: m.tinta,
        IsiBiruAwan.netral: m.tinta,
      },
      isiFail: m.gagal,
      tintaFail: m.teksDiGagal,
      tepiGalat: m.gagal,
      tintaGalat: m.gagal,
      latarMati: m.meja,
      tepiMati: m.kertasTepi,
      isiTombolMati: m.kertasTepi,
      tintaTombolMati: m.tinta2,
      bayanganMulai: m.biru,
    );
  }

  /// Dari tema yang sedang berlaku.
  static WarnaBiruAwan of(BuildContext context) =>
      WarnaBiruAwan.dari(SidikMaterial.of(context));
}
