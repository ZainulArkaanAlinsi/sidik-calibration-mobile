import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/ukuran_komponen.dart';
import '../../l10n/app_localizations.dart';

/// Bentuk navigasi pada satu lebar layar.
enum TataNavigasi {
  /// Bar bawah (HP).
  bar,

  /// Rail samping berlabel (tablet).
  rail,

  /// Tidak ada navigasi tetap (tablet dengan kurang dari 3 tujuan; layar
  /// memberi jalan lain, mis. avatar ke Profil).
  tanpa,
}

/// Satu tujuan navigasi: kata, ikon garis (tidak aktif), ikon terisi (aktif),
/// dan lencana angka opsional.
///
/// Kata tab SAMA di semua lebar layar: tab tidak berganti nama menurut
/// perangkat. [namaSemantik] (bila ada) adalah nama panjang untuk pembaca layar
/// dan harus MEMUAT kata yang terlihat ([label]), supaya perintah suara "ketuk
/// Antrean" (Voice Access, WCAG 2.5.3) cocok.
@immutable
class TujuanNavigasi {
  TujuanNavigasi({
    required this.label,
    required this.ikon,
    required this.ikonAktif,
    this.namaSemantik,
    this.lencana = 0,
    this.satuanLencana = 'baru',
  }) : assert(
         namaSemantik == null ||
             namaSemantik.length >= label.length &&
                 namaSemantik.toLowerCase().contains(label.toLowerCase()),
         'namaSemantik harus memuat label yang terlihat',
       );

  final String label;
  final IconData ikon;
  final IconData ikonAktif;

  /// Nama untuk pembaca layar bila lebih panjang dari [label]; memuat [label].
  final String? namaSemantik;

  /// Jumlah pada lencana; 0 = tanpa lencana.
  final int lencana;

  /// Kata untuk pembaca layar sesudah angka lencana ("3 menunggu").
  final String satuanLencana;

  /// Kalimat untuk pembaca layar: "Antrean persetujuan, 3 menunggu".
  String get semantik {
    final nama = namaSemantik ?? label;
    return lencana > 0 ? '$nama, $lencana $satuanLencana' : nama;
  }

  TujuanNavigasi denganLencana(int jumlah) => TujuanNavigasi(
    label: label,
    ikon: ikon,
    ikonAktif: ikonAktif,
    namaSemantik: namaSemantik,
    lencana: jumlah,
    satuanLencana: satuanLencana,
  );
}

/// Daftar tujuan bawaan per peran (brief desain Lab, 5.4). Belum disambungkan
/// ke rute: shell memetakan indeks ke layar. Kata dari ARB (`navLab*`, id dan
/// en).
///
/// Tab kedua admin bernama "Antrean" di SEMUA lebar (keputusan pemilik): kata
/// "Persetujuan" tidak muat di bar lima tab pada HP umum, dan tab yang berganti
/// nama menurut perangkat membingungkan. Judul layarnya "Antrean persetujuan",
/// dan nama semantiknya "Antrean persetujuan, N menunggu".
abstract final class TujuanLab {
  /// Admin dan super admin: lima tab.
  static List<TujuanNavigasi> admin(
    AppLocalizations l10n, {
    int persetujuan = 0,
  }) => [
    TujuanNavigasi(
      label: l10n.navLabBeranda,
      ikon: Icons.home_outlined,
      ikonAktif: Icons.home,
    ),
    TujuanNavigasi(
      label: l10n.navLabAntrean,
      namaSemantik: l10n.navLabAntreanSemantik,
      ikon: Icons.fact_check_outlined,
      ikonAktif: Icons.fact_check,
      lencana: persetujuan,
      satuanLencana: l10n.navLabLencana,
    ),
    TujuanNavigasi(
      label: l10n.navLabKalibrasi,
      ikon: Icons.straighten_outlined,
      ikonAktif: Icons.straighten,
    ),
    TujuanNavigasi(
      label: l10n.navLabArsip,
      ikon: Icons.inventory_2_outlined,
      ikonAktif: Icons.inventory_2,
    ),
    TujuanNavigasi(
      label: l10n.navLabLainnya,
      ikon: Icons.grid_view_outlined,
      ikonAktif: Icons.grid_view,
    ),
  ];

  /// Teknisi: dua tab.
  static List<TujuanNavigasi> teknisi(AppLocalizations l10n) => [
    TujuanNavigasi(
      label: l10n.navLabKalibrasi,
      ikon: Icons.straighten_outlined,
      ikonAktif: Icons.straighten,
    ),
    TujuanNavigasi(
      label: l10n.navLabProfil,
      ikon: Icons.person_outline,
      ikonAktif: Icons.person,
    ),
  ];
}

/// Navigasi utama yang menyesuaikan lebar: bar bawah di HP, rail 80 dp di
/// tablet (lebar >= 900 dp), tanpa navigasi tetap bila tujuan kurang dari tiga
/// di layar lebar. Bar dan rail memakai SATU bahasa visual: keadaan aktif =
/// kapsul kobalt tipis + ikon terisi + kata tebal (bukan hijau, yang berarti
/// "lulus"), lencana angka di sudut ikon.
///
/// Komponen presentasi: tidak tahu rute. [onPilih] menerima indeks; [isi]
/// adalah layar yang ditampilkan di samping atau di atas navigasi.
class NavigasiAdaptif extends StatelessWidget {
  const NavigasiAdaptif({
    super.key,
    required this.tujuan,
    required this.indeks,
    required this.onPilih,
    required this.isi,
  }) : assert(tujuan.length >= 2, 'navigasi butuh minimal dua tujuan');

  final List<TujuanNavigasi> tujuan;
  final int indeks;
  final ValueChanged<int> onPilih;
  final Widget isi;

  /// Bentuk navigasi pada lebar [lebar] (dp) dengan [jumlah] tujuan.
  static TataNavigasi tata({required double lebar, required int jumlah}) {
    if (lebar < AmbangLab.rail) return TataNavigasi.bar;
    return jumlah >= 3 ? TataNavigasi.rail : TataNavigasi.tanpa;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, batas) {
        switch (tata(lebar: batas.maxWidth, jumlah: tujuan.length)) {
          case TataNavigasi.bar:
            return Column(
              children: [
                Expanded(child: isi),
                BarNavigasi(tujuan: tujuan, indeks: indeks, onPilih: onPilih),
              ],
            );
          case TataNavigasi.rail:
            return Row(
              children: [
                RailNavigasi(tujuan: tujuan, indeks: indeks, onPilih: onPilih),
                Expanded(child: isi),
              ],
            );
          case TataNavigasi.tanpa:
            return isi;
        }
      },
    );
  }
}

/// Memilih skala huruf label untuk butir selebar [lebar] (dp, sudah dikurangi
/// bantalan).
///
/// Kata tab TIDAK berubah menurut lebar: label muat satu baris karena skala
/// huruf label diturunkan dari skala sistem sampai kata terpanjang muat, tetapi
/// TIDAK PERNAH di bawah 1,0 (12 sp). Skalanya SATU untuk semua butir supaya
/// baris label tidak naik-turun. Bar lima tab pada 320 dp x huruf 1,3 tidak
/// mungkin memuat "Kalibrasi" 15,6 sp di butir 64 dp; ini menggantikan
/// ellipsis. Konsekuensi yang disengaja: navigasi tidak sepenuhnya mengikuti
/// pembesaran huruf pengguna (lantai 12 sp, bukan skala sistem), seperti
/// NavigationBar Material yang membatasi skala labelnya; di bawah ±280 dp label
/// bisa terpotong sebagai pilihan terakhir.
double _skalaLabel(
  BuildContext context,
  List<TujuanNavigasi> tujuan,
  double lebar,
) {
  final gaya = Theme.of(
    context,
  ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);
  final arah = Directionality.of(context);

  double lebarSatu(String kata) {
    final pengukur = TextPainter(
      text: TextSpan(text: kata, style: gaya),
      textDirection: arah,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();
    final w = pengukur.width;
    pengukur.dispose();
    return w;
  }

  var skala = MediaQuery.textScalerOf(context).scale(10) / 10;
  for (final t in tujuan) {
    final w = lebarSatu(t.label);
    if (w > 0) skala = math.min(skala, lebar / w);
  }
  return math.max(skala, 1.0);
}

/// Bar bawah: butir sama lebar, tinggi minimum 72 dp, garis halus di atas.
class BarNavigasi extends StatelessWidget {
  const BarNavigasi({
    super.key,
    required this.tujuan,
    required this.indeks,
    required this.onPilih,
  });

  final List<TujuanNavigasi> tujuan;
  final int indeks;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Material(
      color: m.kertas,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: m.kertasTepi, width: AppUkuran.garis),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: UkuranNavigasi.tinggiBar,
            ),
            child: LayoutBuilder(
              builder: (context, batas) {
                final skala = _skalaLabel(
                  context,
                  tujuan,
                  batas.maxWidth / tujuan.length - 2 * AppSpacing.xs,
                );
                return _SkalaLabel(
                  skala: skala,
                  child: Row(
                    children: [
                      for (var i = 0; i < tujuan.length; i++)
                        Expanded(
                          child: _Butir(
                            tujuan: tujuan[i],
                            aktif: i == indeks,
                            nomor: i + 1,
                            jumlah: tujuan.length,
                            rail: false,
                            onTap: () => onPilih(i),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Rail samping 80 dp berlabel; bergulir bila layar pendek.
class RailNavigasi extends StatelessWidget {
  const RailNavigasi({
    super.key,
    required this.tujuan,
    required this.indeks,
    required this.onPilih,
  });

  final List<TujuanNavigasi> tujuan;
  final int indeks;
  final ValueChanged<int> onPilih;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final skala = _skalaLabel(
      context,
      tujuan,
      UkuranNavigasi.lebarRail - 2 * AppSpacing.xs,
    );
    return Material(
      color: m.kertas,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: m.kertasTepi, width: AppUkuran.garis),
          ),
        ),
        child: SafeArea(
          right: false,
          child: SizedBox(
            width: UkuranNavigasi.lebarRail,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: _SkalaLabel(
                skala: skala,
                child: Column(
                  children: [
                    for (var i = 0; i < tujuan.length; i++)
                      _Butir(
                        tujuan: tujuan[i],
                        aktif: i == indeks,
                        nomor: i + 1,
                        jumlah: tujuan.length,
                        rail: true,
                        onTap: () => onPilih(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Menetapkan skala huruf untuk seluruh butir navigasi (lihat [_skalaLabel]).
class _SkalaLabel extends StatelessWidget {
  const _SkalaLabel({required this.skala, required this.child});

  final double skala;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(skala)),
    child: child,
  );
}

class _Butir extends StatelessWidget {
  const _Butir({
    required this.tujuan,
    required this.aktif,
    required this.nomor,
    required this.jumlah,
    required this.rail,
    required this.onTap,
  });

  final TujuanNavigasi tujuan;
  final bool aktif;
  final int nomor;
  final int jumlah;
  final bool rail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final t = Theme.of(context).textTheme;
    final gaya = t.labelMedium?.copyWith(
      color: aktif ? m.tinta : m.tinta2,
      fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
    );

    return Semantics(
      selected: aktif,
      button: true,
      label: tujuan.semantik,
      hint: AppLocalizations.of(context).navLabTabHint(nomor, jumlah),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BentukLab.kontrol),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: rail ? UkuranNavigasi.butirRailMin : UkuranLab.aksi,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.hormati(context, AppMotion.kilat),
                      curve: AppMotion.masuk,
                      width: UkuranNavigasi.kapsulLebar,
                      height: UkuranNavigasi.kapsulTinggi,
                      decoration: BoxDecoration(
                        color: aktif ? m.biruTipis : Colors.transparent,
                        borderRadius: BorderRadius.circular(BentukLab.utama),
                      ),
                      child: Icon(
                        aktif ? tujuan.ikonAktif : tujuan.ikon,
                        size: UkuranIkonLab.navigasi,
                        color: aktif ? m.biruTinta : m.tinta2,
                      ),
                    ),
                    if (tujuan.lencana > 0)
                      // Tepi kiri lencana mulai sedikit di kanan tengah ikon:
                      // lencana lebar ("99+") tumbuh ke kanan, bukan menutupi
                      // ikon.
                      Positioned(
                        top: -AppSpacing.xs,
                        left: UkuranNavigasi.kapsulLebar / 2 + AppSpacing.xs,
                        child: _Lencana(tujuan.lencana),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tujuan.label,
                  key: const ValueKey('navigasi-label'),
                  style: gaya,
                  textAlign: TextAlign.center,
                  maxLines: rail ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lencana angka: satu-satunya pemakai pil penuh.
class _Lencana extends StatelessWidget {
  const _Lencana(this.jumlah);

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final t = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: UkuranNavigasi.lencana,
        minHeight: UkuranNavigasi.lencana,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: m.gagal,
          borderRadius: BorderRadius.circular(BentukLab.pil),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              jumlah > 99 ? '99+' : '$jumlah',
              style: t.labelMedium?.copyWith(
                color: m.teksDiGagal,
                fontSize: UkuranTeksLab.lencana,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
