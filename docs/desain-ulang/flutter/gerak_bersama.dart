// Tempel ke lib/core/motion/ (atau lib/widgets/) lalu sesuaikan impor.
// Tanpa paket baru. Semua durasi dari AppMotion; hormati "kurangi gerak".
import 'dart:async';

import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Ubin/panel yang masuk layar: pudar + naik 12 dp, berurutan menurut [indeks].
class MasukBerurutan extends StatefulWidget {
  const MasukBerurutan({super.key, required this.indeks, required this.child});

  final int indeks;
  final Widget child;

  @override
  State<MasukBerurutan> createState() => _MasukBerurutanState();
}

class _MasukBerurutanState extends State<MasukBerurutan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _tunda;
  bool _mulai = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mulai) return;
    _mulai = true;
    _c.duration = AppMotion.hormati(context, AppMotion.sedang);
    if (_c.duration == Duration.zero) {
      _c.value = 1;
      return;
    }
    _tunda = Timer(AppMotion.tunda(context, widget.indeks), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _tunda?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: AppMotion.masuk);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 12 * (1 - a.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Umpan balik tekan: skala 0,97 selama ditekan. Bungkus di LUAR InkWell.
class TekanSkala extends StatefulWidget {
  const TekanSkala({super.key, required this.child});

  final Widget child;

  @override
  State<TekanSkala> createState() => _TekanSkalaState();
}

class _TekanSkalaState extends State<TekanSkala> {
  bool _tekan = false;

  void _atur(bool v) {
    if (_tekan != v) setState(() => _tekan = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _atur(true),
      onPointerUp: (_) => _atur(false),
      onPointerCancel: (_) => _atur(false),
      child: AnimatedScale(
        scale: _tekan ? 0.97 : 1,
        duration: AppMotion.hormati(context, AppMotion.kilat),
        curve: AppMotion.masuk,
        child: widget.child,
      ),
    );
  }
}

/// Angka sorot yang menghitung naik sekali. Pembaca layar membaca nilai akhir.
class AngkaNaik extends StatelessWidget {
  const AngkaNaik({super.key, required this.nilai, this.style});

  final int nilai;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$nilai',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: nilai.toDouble()),
          duration: AppMotion.hormati(context, AppMotion.sedang),
          curve: AppMotion.masuk,
          builder: (context, v, _) => Text('${v.round()}', style: style),
        ),
      ),
    );
  }
}
