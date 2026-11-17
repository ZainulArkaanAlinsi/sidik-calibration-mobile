import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';

/// Ukuran [TombolBulat]: 44 (cari, tambah), 48 (kembali, lonceng, menu), 60
/// (Mulai di dock).
enum UkuranTombolBulat { kecil, standar, mulai }

/// Isi [TombolBulat].
enum RagamTombolBulat {
  /// Primer, ikon putih: tambah, cari, Mulai.
  primer,

  /// Putih berisi ikon navy: kembali, lonceng.
  putih,

  /// Navy berisi ikon putih: menu.
  navy,
}

/// Tombol bulat berisi satu ikon (`Komponen.dc.html`): 44, 48, atau 60.
///
/// - Tombol ikon tidak punya kata, jadi [label] WAJIB (dibaca pembaca layar).
/// - Gambarnya 44 untuk [UkuranTombolBulat.kecil], tetapi area sentuhnya
///   selalu >= 48 (`AppUkuran.sasaranSentuh`): bidang transparan 2 dp di
///   sekeliling juga menanggapi ketukan.
/// - [UkuranTombolBulat.mulai] membawa bayangan primer 40 %: satu-satunya
///   tombol yang boleh berbayangan (`ELEMEN.md`).
/// - [onPressed] `null` = mati (isi netral).
/// - Tekan: skala 0,97 (`TekanSkala`).
class TombolBulat extends StatelessWidget {
  const TombolBulat({
    super.key,
    required this.ikon,
    required this.label,
    required this.onPressed,
    this.ukuran = UkuranTombolBulat.standar,
    this.ragam = RagamTombolBulat.putih,
  });

  final IconData ikon;

  /// Nama aksi untuk pembaca layar ("Kembali", "Buka menu").
  final String label;

  /// `null` = mati.
  final VoidCallback? onPressed;
  final UkuranTombolBulat ukuran;
  final RagamTombolBulat ragam;

  /// Garis tengah gambar menurut [ukuran].
  static double garisTengah(UkuranTombolBulat u) => switch (u) {
    UkuranTombolBulat.kecil => UkuranBiruAwan.tombolBulatKecil,
    UkuranTombolBulat.standar => UkuranBiruAwan.tombolKembali,
    UkuranTombolBulat.mulai => UkuranBiruAwan.tombolMulaiDock,
  };

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final s = Theme.of(context).colorScheme;
    final w = WarnaBiruAwan.of(context);
    final aktif = onPressed != null;
    final d = garisTengah(ukuran);

    final (Color isi, Color tinta) = aktif
        ? switch (ragam) {
            RagamTombolBulat.primer => (s.primary, s.onPrimary),
            RagamTombolBulat.putih => (m.kertas, m.tinta),
            RagamTombolBulat.navy => (m.tinta, m.kertas),
          }
        : (w.isiTombolMati, w.tintaTombolMati);

    final tepi = aktif && ragam == RagamTombolBulat.putih
        ? BorderSide(color: m.kertasTepi, width: AppUkuran.garis)
        : BorderSide.none;
    final bayangan = aktif && ukuran == UkuranTombolBulat.mulai
        ? [
            BoxShadow(
              color: w.bayanganMulai.withValues(
                alpha: UkuranKomponenBiruAwan.bayanganMulaiAlfa,
              ),
              offset: const Offset(
                0,
                UkuranKomponenBiruAwan.bayanganMulaiGeser,
              ),
              blurRadius: UkuranKomponenBiruAwan.bayanganMulaiBlur,
            ),
          ]
        : null;

    final gambar = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: bayangan),
      child: Material(
        color: isi,
        shape: CircleBorder(side: tepi),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: d,
            child: Center(
              child: Icon(
                ikon,
                size: ukuran == UkuranTombolBulat.mulai
                    ? UkuranKomponenBiruAwan.ikonBulatMulai
                    : UkuranKomponenBiruAwan.ikonBulat,
                color: tinta,
              ),
            ),
          ),
        ),
      ),
    );

    final sisi = math.max(d, AppUkuran.sasaranSentuh);
    return Semantics(
      button: true,
      enabled: aktif,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: TekanSkala(
        aktif: aktif,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: sisi,
            child: Center(child: gambar),
          ),
        ),
      ),
    );
  }
}
