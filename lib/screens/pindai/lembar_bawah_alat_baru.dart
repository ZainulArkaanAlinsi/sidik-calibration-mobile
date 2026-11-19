import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Layar "sempit" = panel "Alat baru" dibuka sebagai lembar bawah; selain itu
/// tetap inline di blok identitas.
///
/// DASAR (diukur, bukan ditebak): `test/tampilan/ukur_jatah_alat_baru_test.dart`
/// merender LembarKerjaScreen sungguhan (legenda, banner jenis, tombol foto,
/// bilah kirim beku; bilah status 24 dp, bilah gestur 16 dp, papan ketik 280 dp)
/// dan mencatat dua angka: tinggi ALAMI panel inline dan JATAH (`tinggiMaks`)
/// yang diberikan lembar kepadanya, papan ketik tertutup.
///
///   layar (dp) x huruf   alami  jatah  tampak   dengan papan ketik
///   320 x 640  x 2,0     1042    122    12 %     0 dp
///   360 x 640  x 1,3      738    110    15 %     0 dp
///   360 x 800  x 1,0      646    260    40 %    60 dp
///   392 x 852  x 1,0      622    312    50 %    96 dp   <- acuan "lega"
///   392 x 852  x 1,15     686    303    44 %    90 dp
///   411 x 891  x 1,0      622    373    60 %   146 dp
///   600 x 900  x 1,0      604    404    67 %   146 dp   <- acuan tablet
///   600 x 900  x 1,3      661    389    59 %   136 dp
///   600 x 900  x 2,0      886    402    45 %   162 dp
///   840 x 360  x 1,0      604      0     0 %     0 dp   (lanskap HP)
///
/// Tinggi alami ~ 240 + 380 x skala huruf (dp). Jatah ~ tinggi layar dikurangi
/// 520 dp (huruf 1,0) sampai ~580 dp (huruf >= 1,5): yang memakan tempat adalah
/// kerangka lembar beku, dan ia tidak bisa dikecilkan dari sini.
///
/// Panel inline dianggap layak bila sedikitnya ~45 % isinya tampak tanpa papan
/// ketik. Garis itu, ditulis dengan tinggi layar dan skala huruf (dua hal yang
/// TIDAK berubah ketika papan ketik naik-turun, jadi pilihannya tidak pernah
/// berbalik di tengah ketikan), menjadi:
///
///   lembar bawah  bila  tinggi layar < 580 + 240 x skala huruf  (dp)
///
/// Hasilnya: 392 x 852 x 1,0, 411 x 891 x 1,0, dan tablet 600 x 900 x 1,0 tetap
/// inline (tidak berubah); 360 x 640 x 1,3, 320 x 640 x 2,0, HP 800 dp ke
/// bawah, huruf besar di HP biasa, dan lanskap HP memakai lembar bawah.
///
/// Lebar tidak ikut: lebar 320 lawan 392 hanya menambah ~24 dp tinggi alami
/// (baris teks yang terlipat), jauh di bawah selisih jatah akibat tinggi layar.
bool alatBaruSebagaiLembarBawah({
  required Size layar,
  required double skalaHuruf,
}) => layar.height < tinggiLayarMinInline + tinggiPerSkalaInline * skalaHuruf;

/// Konstanta garis di atas (dp). Publik hanya supaya tes bisa menyebutnya.
const tinggiLayarMinInline = 580.0;
const tinggiPerSkalaInline = 240.0;

/// Kerangka lembar bawah panel "Alat baru" di layar SEMPIT (lihat
/// [alatBaruSebagaiLembarBawah]). Isinya sama dengan panel inline di blok
/// identitas; yang beda hanya tempat dan susunannya:
///
///  - judul + tombol tutup di atas (tetap);
///  - [badan] (petunjuk, kotak isian, PT mirip, galat) bergulir di tengah;
///  - [aksi] (Batal, "Buat dan lanjut") menempel di bawah dan TIDAK ikut
///    bergulir, jadi tombol utama selalu terlihat, juga saat papan ketik
///    terbuka.
///
/// Papan ketik: lembar diangkat setinggi `viewInsets.bottom` (tinggi layar yang
/// tersisa dipakai [badan] untuk menggulir). Area aman bawah (bilah gestur)
/// dipatuhi hanya selama papan ketik tertutup.
class KerangkaLembarAlatBaru extends StatelessWidget {
  const KerangkaLembarAlatBaru({
    super.key,
    required this.judul,
    required this.tutup,
    required this.badan,
    required this.aksi,
  });

  /// Teks judul (dibaca pembaca layar sebagai header).
  final Widget judul;

  /// Tombol tutup (sasaran sentuh >= 48 dp).
  final Widget tutup;

  /// Isi yang bergulir.
  final List<Widget> badan;

  /// Baris tombol di dasar lembar.
  final Widget aksi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.xs,
                top: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(child: Semantics(header: true, child: judul)),
                  tutup,
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: badan,
                ),
              ),
            ),
            Divider(height: 1, color: tema.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: aksi,
            ),
          ],
        ),
      ),
    );
  }
}
