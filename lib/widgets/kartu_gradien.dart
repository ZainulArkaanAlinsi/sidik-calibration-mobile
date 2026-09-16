import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

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
          // Nol, bukan 5. Bingkai 5 px itu bikin pita gradiennya berhenti
          // sebelum tepi kartu — dari layar hasilnya bukan "panel di dalam
          // kartu" melainkan kotak biru yang melayang di atas kotak putih yang
          // lebarnya beda (16 Sep 2026). Pita sekarang menempel rapat ke tepi.
          padding: EdgeInsets.zero,
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
                  // Tanpa sudut sendiri: kartunya sudah `clipBehavior:
                  // antiAlias`, jadi sudut atas pita mengikuti sudut kartu dan
                  // sudut bawahnya lurus — batas rapi ke isi di bawahnya.
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
                  // Tinggi pita dikunci lewat padding yang sama di semua
                  // kartu; tombol aksi dipaksa masuk ke tinggi itu (lihat
                  // `aksi`), jadi kartu bertombol dan tanpa tombol tidak lagi
                  // punya kepala setinggi beda.
                  padding: EdgeInsets.fromLTRB(14, 12, aksi.isEmpty ? 14 : 6, 12),
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
                  // Isi kartu: rata KIRI dan mengalir ke bawah, bukan dibagi
                  // kolom selebar sama yang dipisah garis tegak. Pembagian
                  // kolom itu yang bikin layar Standar Acuan tidak kebaca —
                  // merk terpotong jadi "Metrology · CMG-9…" dan "k=2" jatuh
                  // sendirian di baris berikutnya, sementara kolom "Berlaku"
                  // di sebelahnya kosong melompong (16 Sep 2026).
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < butir.length; i++) ...[
                        if (i > 0) const SizedBox(height: 4),
                        _Butir(butir: butir[i]),
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

    // Keterangan menempel di baris yang SAMA, dipisah titik tengah: "± 4,1 µm
    // · k=2" kebaca sebagai satu keterangan, sementara dua baris terpisah
    // kebaca sebagai dua data yang tidak berhubungan.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            butir.utama,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: butir.warna,
            ),
          ),
        ),
        if (butir.keterangan != null) ...[
          const SizedBox(width: 6),
          Text(
            '· ${butir.keterangan!}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
