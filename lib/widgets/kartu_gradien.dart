import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Satu butir data di baris bawah kartu.
class ButirKartu {
  const ButirKartu({required this.utama, this.keterangan, this.warna});

  /// Baris atas — yang dibaca duluan.
  final String utama;

  /// Baris bawah, lebih kecil dan redup. Boleh kosong.
  final String? keterangan;

  /// Warna baris atas. Null = ikut warna teks biasa. Dipakai buat butir yang
  /// isinya vonis, mis. standar yang masa berlakunya habis.
  final Color? warna;
}

/// Kartu berpanel gradien bertakik — acuan desain Uiverse karya Smit-Prajapati.
///
/// Bentuknya: pita gradien di atas dengan **takik** di pojok kiri tempat
/// ikonnya duduk; lalu judul; lalu sebaris butir data yang dipisah garis tegak.
///
/// ## Yang diubah dari acuannya, dan kenapa
///
/// Panel gradien di acuannya setinggi 150 px, dan itu benar buat kartu tunggal
/// yang berdiri sendiri. Layar Standar Acuan isinya **dua puluhan baris**;
/// panel setinggi itu per baris bikin satu layar cuma muat dua kartu, dan yang
/// dicari orang di situ — nama standarnya — kalah besar sama hiasannya. Jadi
/// panelnya jadi pita tipis: takiknya tetap, gradiennya tetap, porsinya yang
/// disesuaikan sama isi layarnya.
///
/// Gradiennya juga diganti dari sian-terang acuannya ke cobalt→mint milik app
/// ini. Sian terang di atas kertas krem tema terang nggak punya tempat
/// berpijak — dia melayang seperti stiker yang ketempel.
///
/// ## Takiknya dipotong, bukan ditempel
///
/// Takik di acuannya dirakit dari elemen ter-skew plus tiga `box-shadow` yang
/// saling menutupi. Di Flutter itu dikerjakan sekali lewat [Path.combine]:
/// bentuk panel dikurangi bentuk takik. Satu path, nol widget bertumpuk, dan
/// hasilnya tetap benar di lebar berapa pun.
class KartuGradien extends StatelessWidget {
  const KartuGradien({
    super.key,
    required this.judul,
    required this.ikon,
    this.butir = const [],
    this.aksi = const [],
    this.onTap,
  });

  final String judul;
  final IconData ikon;

  /// Maksimal tiga; lebih dari itu tiap kolomnya jadi terlalu sempit buat
  /// dibaca di layar HP.
  final List<ButirKartu> butir;

  /// Tombol di kanan pita gradien.
  final List<Widget> aksi;

  final VoidCallback? onTap;

  /// Tinggi pita gradien.
  ///
  /// Sempat 52. Di daftar dua puluhan baris, pita setebal itu jadi bidang
  /// warna besar yang isinya cuma ikon dan satu tombol — warnanya nuntut
  /// perhatian tapi nggak membawa informasi apa-apa. 40 cukup buat menampung
  /// takik dan tombolnya, dan di situ dia kebaca sebagai AKSEN, bukan panel.
  static const _tinggiPita = 40.0;

  /// Ukuran takik. Ikonnya duduk di sini.
  static const _lebarTakik = 44.0;
  static const _tinggiTakik = 26.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gelap = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // 5 px di acuannya — bingkai tipis warna badan yang mengelilingi
          // panel gradien. Itu yang bikin panelnya kebaca "di dalam" kartu,
          // bukan menempel di tepinya.
          padding: const EdgeInsets.all(5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _tinggiPita,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipPath(
                        clipper: const _PemotongTakik(
                          lebarTakik: _lebarTakik,
                          tinggiTakik: _tinggiTakik,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: gelap
                                  ? const [AppColors.cobalt, AppColors.mint]
                                  : const [
                                      AppColors.cobalt,
                                      AppColors.mintDeep,
                                    ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Ikon duduk DI TAKIK — di atas warna badan kartu, bukan di
                    // atas gradiennya. Itu inti bentuknya: takiknya kebaca
                    // sebagai lubang tempat ikonnya nongol.
                    Positioned(
                      left: 4,
                      top: 0,
                      width: _lebarTakik,
                      height: _tinggiTakik,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          ikon,
                          size: 19,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (aksi.isNotEmpty)
                      Positioned(
                        right: 2,
                        top: 0,
                        bottom: 0,
                        child: Row(mainAxisSize: MainAxisSize.min, children: aksi),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  4,
                ),
                child: Text(
                  judul,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (butir.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs,
                    0,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < butir.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 1,
                            height: 26,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        Expanded(child: _Butir(butir: butir[i])),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Butir extends StatelessWidget {
  const _Butir({required this.butir});

  final ButirKartu butir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            butir.utama,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: butir.warna,
            ),
          ),
          if (butir.keterangan != null)
            Text(
              butir.keterangan!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Memotong pita gradien: bentuk membulat dikurangi takik di pojok kiri atas.
class _PemotongTakik extends CustomClipper<Path> {
  const _PemotongTakik({required this.lebarTakik, required this.tinggiTakik});

  final double lebarTakik;
  final double tinggiTakik;

  @override
  Path getClip(Size size) {
    final panel = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(15)),
      );

    // Takiknya membulat di pojok kanan-bawahnya — itu yang bikin potongannya
    // kebaca sebagai lekukan, bukan gigitan persegi.
    final takik = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, lebarTakik, tinggiTakik),
          bottomRight: const Radius.circular(12),
        ),
      );

    return Path.combine(PathOperation.difference, panel, takik);
  }

  @override
  bool shouldReclip(_PemotongTakik old) =>
      old.lebarTakik != lebarTakik || old.tinggiTakik != tinggiTakik;
}
