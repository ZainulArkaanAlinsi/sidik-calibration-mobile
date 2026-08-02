import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Loader khas Sidik: logo di tengah + satu satelit mengorbit di lintasan
/// miring (gaya "planet") — bukan `CircularProgressIndicator` polos.
///
/// Kenapa custom: loading itu layar yang paling sering keliatan, jadi paling
/// worth dibikin berkarakter. Motif orbit = alat kalibrasi yang "mengelilingi"
/// standar — on-brand tanpa gradient (permintaan lab: no gradient).
///
/// Performa: SATU `AnimationController`, dibungkus [RepaintBoundary] biar cuma
/// area loader yang di-repaint tiap frame (bukan seluruh layar) — aman 60/120fps.
/// Logo di-`precache` sama harness/app; di sini cukup `Image.asset` yang murah.
class SidikLoader extends StatefulWidget {
  const SidikLoader({super.key, this.size = 96, this.warnaOrbit, this.warnaSatelit});

  final double size;

  /// Override warna (default ikut tema). Orbit = teal/tealBright, satelit = amber.
  final Color? warnaOrbit;
  final Color? warnaSatelit;

  @override
  State<SidikLoader> createState() => _SidikLoaderState();
}

class _SidikLoaderState extends State<SidikLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final orbit = widget.warnaOrbit ?? (gelap ? AppColors.tealBright : AppColors.teal);
    final satelit = widget.warnaSatelit ?? AppColors.warning;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final theta = _c.value * 2 * math.pi;
            // Napas halus logo — skala 0,97..1,0 (bukan berdenyut norak).
            final pulse = 1 - 0.03 * (0.5 - 0.5 * math.cos(_c.value * 4 * math.pi));

            return CustomPaint(
              // Orbit + bayangan + satelit-saat-di-belakang.
              painter: _OrbitPainter(theta: theta, orbit: orbit, satelit: satelit, depan: false),
              // Satelit-saat-di-depan (nutup logo) — biar ada kedalaman.
              foregroundPainter: _OrbitPainter(theta: theta, orbit: orbit, satelit: satelit, depan: true),
              child: Center(
                child: Transform.scale(
                  scale: pulse,
                  child: child,
                ),
              ),
            );
          },
          // Logo dibangun SEKALI (di luar builder) — nggak ikut kebuild tiap
          // frame. Dibungkus badge bundar (kayak "planet") biar orbitnya kebaca
          // & logonya nggak kotak di latar apa pun.
          child: Center(
            child: Container(
              width: widget.size * 0.56,
              height: widget.size * 0.56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: widget.size * 0.06,
                    offset: Offset(0, widget.size * 0.02),
                  ),
                ],
              ),
              padding: EdgeInsets.all(widget.size * 0.10),
              child: Image.asset(
                'assets/images/logo_pt_sidik.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.theta,
    required this.orbit,
    required this.satelit,
    required this.depan,
  });

  final double theta;
  final Color orbit;
  final Color satelit;

  /// true = lapisan depan (cuma gambar satelit kalau lagi di depan logo).
  final bool depan;

  // Kemiringan lintasan orbit (radian) — bikin kesan 3D "planet".
  static const double _tilt = -0.42;

  Offset _posSatelit(Size size) {
    final a = size.width * 0.46;
    final b = size.width * 0.15;
    final x = a * math.cos(theta);
    final y = b * math.sin(theta);
    final xr = x * math.cos(_tilt) - y * math.sin(_tilt);
    final yr = x * math.sin(_tilt) + y * math.cos(_tilt);
    return Offset(size.width / 2 + xr, size.height / 2 + yr);
  }

  /// Satelit di paruh BELAKANG orbit (jauh) waktu sin(theta) < 0.
  bool get _diBelakang => math.sin(theta) < 0;

  @override
  void paint(Canvas canvas, Size size) {
    final pusat = Offset(size.width / 2, size.height / 2);

    if (!depan) {
      // Bayangan lembut di bawah logo (kesan melayang, kayak acuan).
      final bayangan = Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(pusat.dx, size.height * 0.9),
          width: size.width * 0.5,
          height: size.height * 0.09,
        ),
        bayangan,
      );

      // Lintasan orbit (elips miring, tipis).
      canvas.save();
      canvas.translate(pusat.dx, pusat.dy);
      canvas.rotate(_tilt);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: size.width * 0.92, height: size.width * 0.30),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.018
          ..color = orbit.withValues(alpha: 0.28),
      );
      canvas.restore();
    }

    // Gambar satelit HANYA di lapisan yang sesuai kedalamannya.
    final gambarSekarang = depan ? !_diBelakang : _diBelakang;
    if (!gambarSekarang) return;

    final pos = _posSatelit(size);
    final r = size.width * 0.055;
    // Halo lembut biar "berpendar".
    canvas.drawCircle(pos, r * 1.9, Paint()..color = satelit.withValues(alpha: 0.18));
    canvas.drawCircle(pos, r, Paint()..color = satelit);
    // Kilau kecil.
    canvas.drawCircle(
      pos.translate(-r * 0.3, -r * 0.3),
      r * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.theta != theta || old.orbit != orbit || old.satelit != satelit;
}

/// Loader satu layar penuh — dipakai splash & initial load. Logo berorbit +
/// label kalem, latar ikut tema.
class SidikLoadingScreen extends StatelessWidget {
  const SidikLoadingScreen({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SidikLoader(size: 120),
            if (label != null) ...[
              const SizedBox(height: 20),
              Text(
                label!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
