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
    this.sorot = 0.34,
    this.aksen,
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

  /// Posisi sapuan cahaya, 0 = kiri, 1 = kanan. Diikat ke offset PageView
  /// waktu dipakai di carousel.
  final double sorot;

  final Color? aksen;

  /// Gurat mendatar tipis ala panel instrumen. Bagian "retro"-nya — tapi
  /// alphanya kecil banget, jadi dia kebaca sebagai tekstur, bukan motif.
  final bool gurat;

  /// Pengali bayangan luar. 0 = rata sama latar (buat kartu di dalam daftar).
  final double tinggiBayangan;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gelapTema = Theme.of(context).brightness == Brightness.dark;
    final aksenWarna =
        aksen ?? (gelapTema ? AppColors.tealBright : AppColors.teal);
    final s = sorot.clamp(0.0, 1.0);

    final List<Color> dasar;
    final Color garisTepi;
    final Color kilauAtas;
    if (panelGelap) {
      dasar = const [Color(0xFF16304C), Color(0xFF0D3B4A), Color(0xFF0B2036)];
      garisTepi = Colors.white.withValues(alpha: 0.20);
      kilauAtas = Colors.white.withValues(alpha: 0.30);
    } else if (gelapTema) {
      dasar = [
        AppColors.darkElevated.withValues(alpha: 0.92),
        AppColors.darkSurface.withValues(alpha: 0.80),
      ];
      garisTepi = Colors.white.withValues(alpha: 0.14);
      kilauAtas = Colors.white.withValues(alpha: 0.20);
    } else {
      dasar = [
        Colors.white.withValues(alpha: 0.94),
        Colors.white.withValues(alpha: 0.70),
      ];
      garisTepi = Colors.white.withValues(alpha: 0.86);
      kilauAtas = Colors.white;
    }

    final kotak = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dasar,
        ),
        border: Border.all(color: garisTepi),
        boxShadow: tinggiBayangan <= 0
            ? null
            : [
                BoxShadow(
                  color:
                      (panelGelap || gelapTema ? Colors.black : AppColors.navy)
                          .withValues(
                            alpha: (panelGelap ? 0.30 : 0.10) * tinggiBayangan,
                          ),
                  blurRadius: 30 * tinggiBayangan,
                  offset: Offset(0, 14 * tinggiBayangan),
                ),
                BoxShadow(
                  color: aksenWarna.withValues(alpha: 0.10 * tinggiBayangan),
                  blurRadius: 26 * tinggiBayangan,
                  spreadRadius: -8,
                  offset: const Offset(-12, -10),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (gurat)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GuratInstrumen(
                      warna:
                          (panelGelap || gelapTema
                                  ? Colors.white
                                  : AppColors.navy)
                              .withValues(alpha: panelGelap ? 0.045 : 0.030),
                    ),
                  ),
                ),
              ),
            // Sapuan cahaya. Lebarnya sepertiga panel dan tepinya lembut, jadi
            // dia kebaca kayak pantulan yang lewat, bukan garis putih.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [
                        (s - 0.26).clamp(0.0, 1.0),
                        s.clamp(0.0, 1.0),
                        (s + 0.26).clamp(0.0, 1.0),
                      ],
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(
                          alpha: panelGelap ? 0.085 : 0.55,
                        ),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Kilau tipis di bibir atas — satu-satunya garis yang bikin tepi
            // kaca kebaca tebal.
            Positioned(
              top: 0,
              left: radius * 0.6,
              right: radius * 0.6,
              child: Container(height: 1, color: kilauAtas),
            ),
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
