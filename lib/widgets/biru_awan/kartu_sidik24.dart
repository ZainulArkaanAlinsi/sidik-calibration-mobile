import 'package:flutter/material.dart';

import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/warna_biru_awan.dart';

/// Warna dasar [KartuSidik24].
enum LatarKartu {
  /// Putih (biasa).
  kertas,

  /// Kabut: ubin yang disorot.
  kabut,

  /// Merah muda: peringatan galat (jatuh tempo, gagal).
  galat,

  /// Krem: "perlu diperiksa" (revisi, segera). HANYA untuk itu (REVISI 16 Nov
  /// 2026): krem di kartu yang tidak bermasalah adalah peringatan palsu.
  awas,
}

/// Kartu Biru Awan: putih, sudut 16 (`BentukBiruAwan.kartu`), datar, tanpa
/// bayangan, dengan garis halus 1 dp (REVISI 16 Nov 2026; dulu sudut 24 tanpa
/// garis). Pengganti `Card` dan `KartuGradien` di layar yang didesain ulang.
///
/// - Tinggi kartu = minimum isinya; tumbuh bila huruf diperbesar.
/// - [onTap] membuatnya bisa diketuk: riak, skala 0,97 saat ditekan, tinggi
///   minimum 48, dan dibaca sebagai tombol. Tanpa [onTap] kartu hanya wadah.
/// - [terpilih]: isi kabut + garis primer 2 dp (ubin alat terpilih).
/// - [semantik] mengganti label otomatis (gabungan teks isi) bila perlu; juga
///   dipasang tanpa [onTap] (kartu wadah, tanpa aksi).
///
/// Hindari kartu di dalam kartu: untuk kelompok baris pakai `PanelBaris`.
class KartuSidik24 extends StatelessWidget {
  const KartuSidik24({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.latar = LatarKartu.kertas,
    this.terpilih = false,
    this.onTap,
    this.semantik,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final LatarKartu latar;
  final bool terpilih;
  final VoidCallback? onTap;
  final String? semantik;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final bisaDiketuk = onTap != null;

    final Color isi = terpilih
        ? w.isi(IsiBiruAwan.kabut)
        : switch (latar) {
            LatarKartu.kertas => m.kertas,
            LatarKartu.kabut => w.isi(IsiBiruAwan.kabut),
            LatarKartu.galat => w.isi(IsiBiruAwan.koralTipis),
            LatarKartu.awas => w.isi(IsiBiruAwan.kuning),
          };

    final isiKartu = Padding(padding: padding, child: child);
    final kartu = Material(
      color: isi,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BentukBiruAwan.kartu),
        side: terpilih
            ? BorderSide(color: m.biru, width: AppUkuran.garisTebal)
            // Kartu putih bergaris halus; kartu berisi warna tanpa garis.
            : (latar == LatarKartu.kertas
                  ? BorderSide(color: m.kertasTepi, width: AppUkuran.garis)
                  : BorderSide.none),
      ),
      clipBehavior: Clip.antiAlias,
      child: bisaDiketuk
          ? InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppUkuran.sasaranSentuh,
                ),
                child: isiKartu,
              ),
            )
          : isiKartu,
    );

    if (!bisaDiketuk) {
      // Wadah saja, tetapi label pengganti tetap dipasang bila diberikan.
      return semantik == null
          ? kartu
          : Semantics(label: semantik, excludeSemantics: true, child: kartu);
    }

    final bertekan = TekanSkala(child: kartu);
    // Satu node semantik; `excludeSemantics` hanya dipakai bersama `onTap` di
    // node yang sama, karena tanpa itu aksi ketuk milik InkWell ikut terbuang.
    if (semantik != null) {
      return Semantics(
        button: true,
        selected: terpilih ? true : null,
        label: semantik,
        onTap: onTap,
        excludeSemantics: true,
        child: bertekan,
      );
    }
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: terpilih ? true : null,
        onTap: onTap,
        child: bertekan,
      ),
    );
  }
}
