import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Loader khas Sidik: **dial kalibrasi**. Cincin tick mark (kayak skala alat
/// ukur / jangka sorong) mengelilingi logo, dan seberkas cahaya "menyapu"
/// keliling — tick yang barusan kelewat menyala lalu meredup (ekor komet),
/// persis alat lagi ngkalibrasi. Logo Sidik diam berdenyut halus di tengah.
///
/// Kenapa motif ini: loading = layar paling sering keliatan, jadi worth bikin
/// berkarakter — dan "menyapu skala ukur" itu metafora kalibrasi yang pas,
/// bukan spinner generik. Tanpa gradient (permintaan lab).
///
/// Performa: SATU `AnimationController` + [RepaintBoundary] → cuma area loader
/// yang di-repaint per frame. Aman 60/120fps.
class SidikLoader extends StatefulWidget {
  const SidikLoader({super.key, this.size = 96, this.warna, this.warnaSapuan});

  final double size;

  /// Override warna (default ikut tema). [warna] = tick, [warnaSapuan] = kepala
  /// cahaya yang menyapu.
  final Color? warna;
  final Color? warnaSapuan;

  @override
  State<SidikLoader> createState() => _SidikLoaderState();
}

class _SidikLoaderState extends State<SidikLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final tick = widget.warna ?? (gelap ? AppColors.tealBright : AppColors.teal);
    final sapuan = widget.warnaSapuan ?? AppColors.warning;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            // Denyut logo sinkron sama sapuan lewat "jam 12".
            final pulse = 1 - 0.025 * (0.5 - 0.5 * math.cos(_c.value * 2 * math.pi));
            return CustomPaint(
              painter: _DialPainter(t: _c.value, tick: tick, sapuan: sapuan),
              child: Center(
                child: Transform.scale(scale: pulse, child: child),
              ),
            );
          },
          // Logo dibangun SEKALI di luar builder — badge bundar biar rapi di
          // latar apa pun & jadi "pusat dial".
          child: Center(
            child: Container(
              width: widget.size * 0.5,
              height: widget.size * 0.5,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: widget.size * 0.05,
                    offset: Offset(0, widget.size * 0.015),
                  ),
                ],
              ),
              padding: EdgeInsets.all(widget.size * 0.085),
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

class _DialPainter extends CustomPainter {
  _DialPainter({required this.t, required this.tick, required this.sapuan});

  /// 0..1 progres sapuan.
  final double t;
  final Color tick;
  final Color sapuan;

  /// Jumlah tick keliling dial. Kelipatan 12 → tiap 4 tick = mayor (lebih
  /// panjang), kayak angka jam / skala utama alat ukur.
  static const int _jumlah = 48;

  /// Panjang ekor cahaya (dalam putaran, 0..1). 0,3 = sepertiga lingkaran.
  static const double _ekor = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final pusat = Offset(size.width / 2, size.height / 2);
    final rLuar = size.width * 0.47;
    final tebal = size.width * 0.02;

    for (var i = 0; i < _jumlah; i++) {
      final frac = i / _jumlah;
      // Sudut: mulai dari atas (jam 12), searah jarum jam.
      final sudut = -math.pi / 2 + frac * 2 * math.pi;
      final mayor = i % 4 == 0;
      final panjang = size.width * (mayor ? 0.10 : 0.055);

      // Jarak tick INI di belakang kepala sapuan (0 = pas di kepala).
      var delta = t - frac;
      if (delta < 0) delta += 1;
      // Nyala penuh di kepala, meredup sepanjang ekor.
      final glow = delta <= _ekor ? (1 - delta / _ekor) : 0.0;

      final dim = mayor ? 0.34 : 0.20;
      final alpha = dim + (1 - dim) * glow;
      // Kepala sapuan (glow tinggi) diwarnai amber; sisanya teal.
      final warna = Color.lerp(
        tick,
        sapuan,
        glow > 0.72 ? (glow - 0.72) / 0.28 : 0,
      )!
          .withValues(alpha: alpha);

      final p1 = Offset(
        pusat.dx + math.cos(sudut) * rLuar,
        pusat.dy + math.sin(sudut) * rLuar,
      );
      final p2 = Offset(
        pusat.dx + math.cos(sudut) * (rLuar - panjang),
        pusat.dy + math.sin(sudut) * (rLuar - panjang),
      );

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = warna
          ..strokeWidth = tebal * (mayor ? 1.4 : 1.0)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.t != t || old.tick != tick || old.sapuan != sapuan;
}

/// Loader satu layar penuh — dipakai splash & initial load.
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
