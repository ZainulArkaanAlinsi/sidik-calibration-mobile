import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/lab_profile.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/auth_brand_header.dart';

/// Splash bergerak dengan logo PT Sidik.
///
/// Bentuknya **timeline sekali jalan**, bukan animasi yang muter terus:
/// cincin ditarik, logo muncul dari kecil, sapuan cahaya lewat, nama merek
/// naik, tagline masuk — lalu diam. Tiga alasan:
///
/// - Splash yang gerak selamanya bikin `pumpAndSettle` nggak pernah balik.
///   Layar ini muncul di jalur masuk hampir semua tes, jadi satu `repeat()`
///   di sini bikin puluhan tes timeout serentak (kejadian, 18 Agt 2026).
/// - Yang bikin gerakan kebaca "mahal" itu urutan & timing-nya, bukan
///   pengulangannya. Animasi berdenyut tanpa awal-akhir malah kebaca kayak
///   spinner.
/// - Semua digambar canvas + transform: nol video, nol GIF, nol tambahan
///   ukuran aplikasi.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else if (!_motion.isAnimating && _motion.value == 0) {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  /// Potong satu bagian timeline jadi 0..1 sendiri. Ini yang bikin tahapannya
  /// bisa tumpang tindih — cincin masih menutup waktu logonya udah mulai
  /// naik, jadi gerakannya nyambung, bukan antre satu-satu.
  static double _tahap(double t, double mulai, double selesai) =>
      ((t - mulai) / (selesai - mulai)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF102C46), Color(0xFF0A535A), Color(0xFF0B1D35)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final t = _motion.value;
              final cincin = Curves.easeOutCubic.transform(_tahap(t, 0, 0.55));
              final logo = Curves.easeOutBack.transform(_tahap(t, 0.14, 0.62));
              final sapu = _tahap(t, 0.38, 0.78);
              final nama = Curves.easeOutCubic.transform(_tahap(t, 0.52, 0.86));
              final tagline = Curves.easeOut.transform(_tahap(t, 0.70, 1.0));

              return Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _OrbitSplash(cincin: cincin, sapuan: sapu),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          // Mulai dari 0.62, bukan 0: benda yang tumbuh dari
                          // nol kebaca kayak glitch render, bukan gerakan.
                          scale: 0.62 + 0.38 * logo,
                          child: Opacity(
                            opacity: logo.clamp(0.0, 1.0),
                            child: _Cakram(sapuan: sapu),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Opacity(
                          opacity: nama,
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - nama)),
                            child: Text(
                              LabProfile.namaSingkat,
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                // Huruf merapat sambil naik — trik motion
                                // graphics paling tua yang masih ampuh.
                                letterSpacing: 0.5 + 9 * (1 - nama),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: tagline,
                          child: Text(
                            l10n.appTagline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.74),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: tagline,
                      child: const AuthPoweredBy(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Cakram logo: lingkaran putih + logo asli + sapuan cahaya yang lewat sekali.
class _Cakram extends StatelessWidget {
  const _Cakram({required this.sapuan});

  final double sapuan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      height: 156,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.76),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealBright.withValues(alpha: 0.34),
            blurRadius: 40,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/logo_pt_sidik.png', fit: BoxFit.cover),
            // Sapuan kilau. Cuma sekali lewat: sesudah `sapuan` nyampe 1 dia
            // udah di luar bidang dan nggak dirender lagi.
            if (sapuan > 0 && sapuan < 1)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [
                        (sapuan * 1.6 - 0.34).clamp(0.0, 1.0),
                        (sapuan * 1.6 - 0.16).clamp(0.0, 1.0),
                        (sapuan * 1.6).clamp(0.0, 1.0),
                      ],
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.62),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dua cincin orbit yang "ditarik" (sapuan busur dari nol ke penuh) plus dua
/// titik penanda. Nggak ada yang muter selamanya — begitu [cincin] = 1,
/// gambarnya diam.
class _OrbitSplash extends CustomPainter {
  const _OrbitSplash({required this.cincin, required this.sapuan});

  final double cincin;
  final double sapuan;

  @override
  void paint(Canvas canvas, Size size) {
    if (cincin <= 0) return;
    final pusat = Offset(size.width / 2, size.height / 2 - 20);
    final garis = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.18 * cincin);

    canvas.drawArc(
      Rect.fromCenter(center: pusat, width: size.width * 0.94, height: 142),
      -math.pi / 2,
      math.pi * 2 * cincin,
      false,
      garis,
    );
    canvas.drawArc(
      Rect.fromCenter(center: pusat, width: 156, height: 268),
      -math.pi / 2,
      math.pi * 2 * Curves.easeOut.transform(cincin),
      false,
      garis..color = AppColors.tealBright.withValues(alpha: 0.22 * cincin),
    );

    // Titik yang jalan di sepanjang cincin luar, berhenti di ujung sapuan.
    final sudut = -math.pi / 2 + math.pi * 2 * cincin;
    final titik =
        pusat +
        Offset(math.cos(sudut) * size.width * 0.47, math.sin(sudut) * 71);
    canvas.drawCircle(
      titik,
      13,
      Paint()..color = AppColors.signalAmber.withValues(alpha: 0.16 * cincin),
    );
    canvas.drawCircle(
      titik,
      5,
      Paint()..color = AppColors.signalAmber.withValues(alpha: cincin),
    );
    canvas.drawCircle(
      pusat + const Offset(-118, -56),
      4,
      Paint()..color = AppColors.tealBright.withValues(alpha: 0.9 * sapuan),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitSplash old) =>
      old.cincin != cincin || old.sapuan != sapuan;
}
