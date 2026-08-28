/// Foto lembar kerja + sorotan di tempat satu nilai dibaca.
///
/// Ini yang bikin layar review kepakai: teknisi nggak perlu percaya angka hasil
/// baca mesin, dia bandingin sama coretan aslinya di layar yang sama. Kalau
/// harus buka kertasnya lagi, mending ngetik dari awal.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/skema_dinamis.dart';

/// Kotak dari koordinat CITRA -> koordinat KOTAK TAMPIL, buat `BoxFit.contain`.
///
/// Dipisah jadi fungsi murni SUPAYA bisa diuji tanpa merender apa pun. Di
/// sinilah satu-satunya tempat yang bisa salah, dan salahnya jenis yang paling
/// jahat: sorotannya tetap muncul, cuma menunjuk sel yang keliru. Teknisi yang
/// membandingkan angka dengan kotak yang salah bakal "membetulkan" angka yang
/// sebenarnya sudah benar.
///
/// `contain` menyisakan bilah kosong di dua sisi (letterbox), jadi skalanya aja
/// nggak cukup — offsetnya wajib ikut dihitung. Tanpa offset, sorotan di lembar
/// potret meleset sejauh setengah bilahnya, dan melesetnya KONSISTEN sehingga
/// kelihatan seperti "modelnya emang agak geser".
///
/// `null` kalau kotaknya nggak beririsan sama citranya sama sekali. Sengaja
/// nggak dijepit ke tepi: kotak di luar batas berarti koordinatnya memang
/// salah, dan menjepitnya bikin sorotan menunjuk tepi citra dengan yakin —
/// jawaban salah yang kelihatan seperti jawaban benar.
Rect? kotakTampil({
  required KotakBatas kotak,
  required Size ukuranCitra,
  required Size ukuranTampil,
}) {
  if (ukuranCitra.width <= 0 ||
      ukuranCitra.height <= 0 ||
      ukuranTampil.width <= 0 ||
      ukuranTampil.height <= 0) {
    return null;
  }

  final skala =
      (ukuranTampil.width / ukuranCitra.width) <
          (ukuranTampil.height / ukuranCitra.height)
      ? ukuranTampil.width / ukuranCitra.width
      : ukuranTampil.height / ukuranCitra.height;

  final lebarTampil = ukuranCitra.width * skala;
  final tinggiTampil = ukuranCitra.height * skala;

  final kiri = (ukuranTampil.width - lebarTampil) / 2;
  final atas = (ukuranTampil.height - tinggiTampil) / 2;

  final citra = Rect.fromLTWH(0, 0, ukuranCitra.width, ukuranCitra.height);
  final diCitra = Rect.fromLTWH(kotak.x, kotak.y, kotak.lebar, kotak.tinggi);

  if (!diCitra.overlaps(citra)) return null;

  return Rect.fromLTWH(
    kiri + kotak.x * skala,
    atas + kotak.y * skala,
    kotak.lebar * skala,
    kotak.tinggi * skala,
  );
}

/// Foto + sorotan.
///
/// > Ketepatan sorotannya bergantung pada koordinat yang DIKEMBALIKAN MODEL.
/// > Promptnya minta piksel citra yang dia terima, tapi model bisa saja
/// > mengembalikan koordinat ternormalisasi (0..1). Kalau itu terjadi, semua
/// > sorotan mengumpul jadi titik kecil di pojok kiri atas — SALAH, tapi salah
/// > yang langsung kelihatan. Sengaja nggak ditebak-tebak dan "dibetulkan"
/// > otomatis: tebakan yang meleset jauh lebih berbahaya daripada kegagalan
/// > yang kelihatan, karena yang kelihatan bakal dilaporkan.
class SorotKotakFoto extends StatefulWidget {
  const SorotKotakFoto({super.key, required this.foto, this.kotak});

  final File foto;

  /// `null` = belum ada yang dipilih, jadi nggak ada yang disorot.
  final KotakBatas? kotak;

  @override
  State<SorotKotakFoto> createState() => _SorotKotakFotoState();
}

class _SorotKotakFotoState extends State<SorotKotakFoto> {
  Size? _ukuranCitra;

  @override
  void initState() {
    super.initState();
    _bacaUkuran();
  }

  @override
  void didUpdateWidget(SorotKotakFoto lama) {
    super.didUpdateWidget(lama);

    if (lama.foto.path != widget.foto.path) {
      _ukuranCitra = null;
      _bacaUkuran();
    }
  }

  /// Ukuran ASLI citranya, bukan ukuran tampilnya.
  ///
  /// Wajib dibaca dari berkasnya: bbox dari server ada di koordinat piksel
  /// citra itu, dan tanpa tahu ukurannya nggak ada cara menghitung skalanya.
  Future<void> _bacaUkuran() async {
    try {
      final bytes = await widget.foto.readAsBytes();
      final gambar = await decodeImageFromList(bytes);

      if (!mounted) return;

      setState(() {
        _ukuranCitra = Size(gambar.width.toDouble(), gambar.height.toDouble());
      });

      gambar.dispose();
    } catch (_) {
      // Citra rusak atau nggak kebaca: fotonya tetap digambar (Image.file yang
      // memutuskan), cuma sorotannya nggak bisa ditempatkan.
      if (mounted) setState(() => _ukuranCitra = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, batas) {
        final ukuranTampil = Size(batas.maxWidth, batas.maxHeight);

        final sorot = (widget.kotak == null || _ukuranCitra == null)
            ? null
            : kotakTampil(
                kotak: widget.kotak!,
                ukuranCitra: _ukuranCitra!,
                ukuranTampil: ukuranTampil,
              );

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(widget.foto, fit: BoxFit.contain),
            if (sorot != null)
              Positioned.fromRect(
                rect: sorot,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error,
                        width: 2,
                      ),
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
