import 'package:flutter/material.dart';

import '../core/theme/sidik_material.dart';

/// Panel bidang besar — sekarang dua rupa "Meja Kerja Lab".
///
/// Nama kelasnya peninggalan (dulu "kaca cair" dengan sapuan cahaya). Dipakai
/// halaman profil & panel teknisi; kontraknya tidak berubah.
///
/// - `panelGelap: true` → **KACA LCD**: layar readout cekung yang selalu gelap
///   di dua tema, dengan gurat instrumen. Tempat angka hidup dilirik (panel
///   teknisi: draf, menunggu, selesai).
/// - selain itu → **LEMBAR KERTAS**: tempat membaca.
///
/// Nol `BackdropFilter`, sama seperti sebelumnya.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = const EdgeInsets.all(18),
    this.panelGelap = false,
    this.gurat = true,
    this.tinggiBayangan = 1.0,
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Panel gelap (hero teknisi) atau kaca terang (kartu di layar terang).
  /// Bukan diambil dari tema: di layar terang pun panel hero-nya tetap gelap,
  /// itu yang bikin dia kebaca sebagai "layar alat", bukan kartu biasa.
  final bool panelGelap;

  /// Gurat mendatar tipis ala panel instrumen. Bagian "retro"-nya — tapi
  /// alphanya kecil banget, jadi dia kebaca sebagai tekstur, bukan motif.
  final bool gurat;

  /// Pengali bayangan luar. 0 = rata sama latar (buat kartu di dalam daftar).
  final double tinggiBayangan;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // "Meja Kerja Lab": panel gelap = KACA LCD (layar readout cekung, gelap di
    // dua tema — tempat angka hidup dilirik); selain itu = LEMBAR KERTAS.
    // Kontraknya sama; `tinggiBayangan` 0 tetap mematikan bayangan.
    final m = SidikMaterial.of(context);
    final sudut = panelGelap
        ? SidikMaterial.sudutKaca
        : (radius <= 12 ? radius : SidikMaterial.sudutKertas + 3);

    final BoxDecoration dekor;
    if (panelGelap) {
      dekor = m.kacaCekung(radius: sudut);
    } else {
      final lembar = m.kertasLembar(radius: sudut);
      dekor = tinggiBayangan <= 0 ? lembar.copyWith(boxShadow: const []) : lembar;
    }

    final kotak = Container(
      decoration: dekor,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(sudut),
        child: Stack(
          children: [
            if (gurat && panelGelap)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GuratInstrumen(
                      warna: Colors.white.withValues(alpha: 0.045),
                    ),
                  ),
                ),
              ),
            // Teks di atas kaca harus terang di dua tema: kaca selalu gelap.
            if (panelGelap)
              DefaultTextStyle.merge(
                style: TextStyle(color: m.lcdTeks),
                child: IconTheme.merge(
                  data: IconThemeData(color: m.lcdTeks),
                  child: Padding(padding: padding, child: child),
                ),
              )
            else
              Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap == null) return kotak;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          panelGelap ? SidikMaterial.sudutKaca : (radius <= 12 ? radius : SidikMaterial.sudutKertas + 3),
        ),
        child: kotak,
      ),
    );
  }
}

/// Gurat mendatar + satu garis tegak di tepi kanan, kayak skala di badan alat
/// ukur. Statis: nggak ikut animasi apa pun, jadi aman dibungkus panel yang
/// sering di-repaint.
class _GuratInstrumen extends CustomPainter {
  const _GuratInstrumen({required this.warna});

  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = warna
      ..strokeWidth = 1;
    for (var y = 8.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    // Tanda skala pendek di tepi kanan — tiap tanda kelima lebih panjang,
    // persis kayak skala nonius.
    final tanda = Paint()
      ..color = warna
      ..strokeWidth = 1.4;
    var i = 0;
    for (var y = 14.0; y < size.height - 10; y += 10) {
      final panjang = i % 5 == 0 ? 12.0 : 6.0;
      canvas.drawLine(
        Offset(size.width - panjang, y),
        Offset(size.width - 2, y),
        tanda,
      );
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _GuratInstrumen old) => old.warna != warna;
}
