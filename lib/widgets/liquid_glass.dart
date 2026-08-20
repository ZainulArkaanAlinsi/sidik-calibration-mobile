import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Kaca cair — lempeng kaca yang punya **sapuan cahaya** yang bisa digeser,
/// plus gurat halus ala panel instrumen.
///
/// Bedanya sama [GlassSurface] yang udah ada: `GlassSurface` itu permukaan
/// kartu yang tenang buat isi bacaan. `LiquidGlass` dipakai buat bidang yang
/// **ikut gerak** — halaman profil yang digeser samping, panel hero di
/// dashboard. Sapuan cahayanya diikat ke posisi geseran, jadi pas jari
/// gerak, kacanya kelihatan mantulin cahaya, bukan cuma ikut translasi.
///
/// Nol `BackdropFilter`. Semua lapisannya gradient statis di dalam satu
/// `DecoratedBox` — jadi biaya rasternya sama aja kayak kotak biasa, dan
/// panelnya aman ditumpuk banyak dalam satu layar. (Alasan panjangnya kenapa
/// blur dijatah ada di `glass_surface.dart`.)
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
    final gelapTema = Theme.of(context).brightness == Brightness.dark;

    // Bidang panelnya satu warna rata. Yang dulu di sini — dasar tiga warna
    // buat panel gelap, dan dasar terang yang di-`lerp` sama aksen — bikin
    // warna aksen kelebur jadi semburat, jadi cobalt/mint nggak pernah kebaca
    // sebagai warnanya sendiri. Sekarang aksen cuma muncul di isi panel.
    final Color dasar;
    final Color tepi;
    if (panelGelap) {
      // Panel hero tetap gelap walau temanya terang: itu yang bikin dia kebaca
      // sebagai "layar alat", bukan kartu biasa.
      dasar = AppColors.ink;
      tepi = AppColors.inkOutline;
    } else if (gelapTema) {
      dasar = AppColors.inkElevated;
      tepi = AppColors.inkOutline;
    } else {
      dasar = AppColors.white;
      tepi = AppColors.hairline;
    }

    // Tepi digambar lewat Container 1,2px yang isinya ditempel di dalam —
    // sama seperti sebelumnya, cuma warnanya sekarang rata, bukan gradasi.
    final kotak = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: tepi,
        boxShadow: tinggiBayangan <= 0
            ? null
            : [
                BoxShadow(
                  color: AppColors.ink.withValues(
                    alpha:
                        (panelGelap || gelapTema ? 0.36 : 0.12) *
                        tinggiBayangan,
                  ),
                  blurRadius: 30 * tinggiBayangan,
                  offset: Offset(0, 14 * tinggiBayangan),
                ),
              ],
      ),
      padding: const EdgeInsets.all(1.2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1.2),
        child: DecoratedBox(
          decoration: BoxDecoration(color: dasar),
          child: Stack(
            children: [
              // Gurat cuma di panel gelap. Di bidang terang, garis-garis ini
              // dulu ketutup gradasi & pantulan; sekarang permukaannya rata,
              // jadi mereka kebaca jelas dan kartunya kelihatan kayak kertas
              // bergaris — bukan panel instrumen.
              if (gurat && panelGelap)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _GuratInstrumen(
                        warna:
                            (panelGelap || gelapTema
                                    ? Colors.white
                                    : AppColors.ink)
                                .withValues(alpha: panelGelap ? 0.045 : 0.030),
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return kotak;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
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
