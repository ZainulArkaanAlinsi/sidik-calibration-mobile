import 'package:flutter/material.dart';

import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';

/// Ubin berwarna berisi satu ikon (atau gambar kecil): latar ikon baris menu
/// (bulat 44) dan ubin visual baris daftar (persegi sudut 16, 48).
///
/// Warna dari [IsiBiruAwan] (kabut, hijau, awan, kuning, koral tipis), tinta ikon
/// selalu navy di tema terang. Ubin bersifat HIAS: pembaca layar membaca baris
/// atau tombol di sekitarnya, jadi ubin disembunyikan dari semantik kecuali
/// [semantik] diisi (ubin yang berdiri sendiri).
class UbinIkon extends StatelessWidget {
  /// Ubin baris menu: bulat 44.
  const UbinIkon({
    super.key,
    this.ikon,
    this.child,
    this.warna = IsiBiruAwan.kabut,
    this.ukuran = UkuranKomponenBiruAwan.ubinMenu,
    this.bulat = true,
    this.semantik,
  }) : assert(ikon != null || child != null, 'UbinIkon butuh ikon atau child.');

  /// Ubin baris daftar: persegi sudut 16, 48.
  const UbinIkon.baris({
    super.key,
    this.ikon,
    this.child,
    this.warna = IsiBiruAwan.kabut,
    this.semantik,
  }) : ukuran = UkuranKomponenBiruAwan.ubinBaris,
       bulat = false,
       assert(ikon != null || child != null, 'UbinIkon butuh ikon atau child.');

  final IconData? ikon;

  /// Gantinya [ikon] untuk isi lain (mis. gambar alat); warnanya diatur pemakai.
  final Widget? child;
  final IsiBiruAwan warna;
  final double ukuran;

  /// `true` = lingkaran; `false` = persegi sudut [BentukBiruAwan.ikonUbin].
  final bool bulat;

  /// Nama ubin untuk pembaca layar; `null` = hiasan.
  final String? semantik;

  @override
  Widget build(BuildContext context) {
    final w = WarnaBiruAwan.of(context);
    final ubin = SizedBox.square(
      dimension: ukuran,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: w.isi(warna),
          shape: bulat ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: bulat
              ? null
              : BorderRadius.circular(BentukBiruAwan.ikonUbin),
        ),
        child: Center(
          child:
              child ??
              Icon(
                ikon,
                size: UkuranKomponenBiruAwan.ikonUbin,
                color: w.tinta(warna),
              ),
        ),
      ),
    );
    if (semantik == null) return ExcludeSemantics(child: ubin);
    return Semantics(
      label: semantik,
      image: true,
      excludeSemantics: true,
      child: ubin,
    );
  }
}
