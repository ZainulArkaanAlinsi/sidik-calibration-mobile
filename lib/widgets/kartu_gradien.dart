import 'package:flutter/material.dart';

import '../core/theme/sidik_material.dart';

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

/// Kartu daftar master data: LEMBAR KERTAS dengan PELAT LOGAM di kepalanya.
///
/// Nama kelasnya peninggalan (dulu pita gradien cobalt→mint bertakik, acuan
/// Uiverse). Dipertahankan karena Metode Kalibrasi & Standar Acuan memanggilnya
/// — yang berubah cuma rupanya, bukan kontraknya.
///
/// ## Kenapa gradiennya dibuang
///
/// Gradien dua rona (biru → hijau) itu yang dikeluhkan pemilik proyek sebagai
/// "AI banget": bidang warna selebar kartu yang tidak berarti apa-apa, dan
/// hijaunya bertabrakan dengan hijau status LULUS di baris bawahnya — di
/// layar Standar Acuan dua hijau berbeda arti duduk di satu kartu.
///
/// Gantinya pelat nama logam, persis label yang dipaku di laci arsip lab:
/// satu rona, timbul lewat terang-gelap, teks terukir. Judul tetap di pelat
/// (keputusan 16 Sep: pita tanpa isi cuma menuntut perhatian), dan boleh dua
/// baris supaya nama standar tidak terpotong.
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

  /// Tombol di kanan pelat. Satu saja idealnya — aksi merusak (hapus) sebaiknya
  /// di menu ⋮ atau di layar detail, bukan ikon telanjang di setiap baris.
  final List<Widget> aksi;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: m.logamPanel(
                border: Border(bottom: BorderSide(color: m.logamTepi)),
              ),
              child: Padding(
                // Tinggi pelat dikunci lewat padding yang sama di semua kartu;
                // kartu bertombol & tanpa tombol punya kepala setinggi sama.
                padding: EdgeInsets.fromLTRB(10, 8, aksi.isEmpty ? 14 : 4, 8),
                child: Row(
                  children: [
                    // Ubin ikon: benda logam kecil yang timbul di pelat.
                    Container(
                      width: 32,
                      height: 32,
                      decoration: m.logamTimbul(radius: 7),
                      alignment: Alignment.center,
                      child: Icon(ikon, size: 18, color: m.etsa),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        judul,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: m.etsa,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              color: m.terang
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.6),
                              offset: Offset(0, m.terang ? 1 : -1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (aksi.isNotEmpty)
                      IconTheme.merge(
                        data: IconThemeData(color: m.etsa),
                        child: Row(mainAxisSize: MainAxisSize.min, children: aksi),
                      ),
                  ],
                ),
              ),
            ),
            if (butir.isNotEmpty)
              Padding(
                // Isi rata KIRI dan mengalir ke bawah — pembagian kolom selebar
                // sama bikin merk terpotong "Metrology · CMG-9…" (16 Sep 2026).
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
