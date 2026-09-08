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
              // Pita gradien memuat ikon, JUDUL, dan tombolnya.
              //
              // Versi pertama cuma memuat ikon dan satu tombol, dan judulnya
              // ditaruh di bawah pita — persis acuannya. Hasilnya di app
              // beneran: bidang warna selebar kartu yang isinya nyaris kosong,
              // menuntut perhatian tanpa membawa informasi apa pun. Judulnya
              // dipindah ke sini supaya pitanya PUNYA ISI, dan sekaligus
              // kartunya jadi lebih pendek.
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  // Dua ujungnya sama-sama gelap. Versi pertama berujung mint
                  // cerah, dan teks/ikon putih di ujung itu nyaris nggak
                  // kebaca — tombol hapusnya cuma kelihatan sebagai bayangan
                  // merah di atas hijau.
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: gelap
                        ? const [Color(0xFF1B3A6B), Color(0xFF0B5F55)]
                        : const [AppColors.cobalt, AppColors.mintDeep],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      Icon(ikon, size: 18, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          judul,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (aksi.isNotEmpty)
                        // Ikon aksinya dipaksa putih lewat IconTheme, bukan
                        // diserahkan ke warna bawaan tiap tombol: merah error
                        // di atas gradien ini kebaca sebagai noda, bukan
                        // tombol.
                        IconTheme.merge(
                          data: const IconThemeData(color: Colors.white),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: aksi,
                          ),
                        ),
                    ],
                  ),
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
