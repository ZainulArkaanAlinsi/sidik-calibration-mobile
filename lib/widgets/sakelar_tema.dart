import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/theme_mode_provider.dart';

/// Sakelar terang ↔ gelap bergaya "sun & moon" (acuan desain Uiverse karya
/// RiccardoRapelli): trek biru berubah hitam, matahari kuning meluncur sambil
/// berputar jadi bulan putih bertotol, awan ikut kegeser keluar trek, dan
/// bintang naik dari bawah waktu mode gelap nyala.
///
/// Digambar pakai [CustomPainter], bukan tumpukan widget: isinya cuma
/// lingkaran + satu path bintang, jadi satu layer lukis lebih murah ketimbang
/// belasan `Positioned` + `AnimatedOpacity` yang relayout tiap frame.
class SakelarTema extends ConsumerWidget {
  const SakelarTema({super.key, this.skala = 1});

  /// Pengali ukuran dari basis 60×34 dp.
  final double skala;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gelap = Theme.of(context).brightness == Brightness.dark;

    return SakelarSunMoon(
      gelap: gelap,
      skala: skala,
      label: AppLocalizations.of(context).panelTema,
      onTap: () =>
          ref.read(themeModeProvider.notifier).toggle(gelapSekarang: gelap),
    );
  }
}

/// Bagian visual sakelar, tanpa Riverpod — dipakai langsung kalau ada layar
/// yang mau mengendalikan nilainya sendiri.
class SakelarSunMoon extends StatefulWidget {
  const SakelarSunMoon({
    super.key,
    required this.gelap,
    required this.onTap,
    this.label,
    this.skala = 1,
  });

  final bool gelap;
  final VoidCallback onTap;
  final String? label;
  final double skala;

  @override
  State<SakelarSunMoon> createState() => _SakelarSunMoonState();
}

class _SakelarSunMoonState extends State<SakelarSunMoon>
    with TickerProviderStateMixin {
  /// Peralihan terang→gelap. 400 ms, sama seperti `transition: .4s` di CSS.
  late final AnimationController _geser = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: widget.gelap ? 1 : 0,
  );

  /// Awan mengambang + bintang berkelip. Di CSS acuannya dua animasi ini
  /// `infinite`, di sini **sengaja berujung**: sekali jalan tiap kali
  /// sakelarnya ditekan, habis itu diam.
  ///
  /// Alasannya sama persis kayak yang ditulis di `splash_screen.dart` dan
  /// `panggung3d.dart` — `repeat()` bikin frame kejadwal terus (boros baterai
  /// di layar yang cuma didiemin) dan bikin `pumpAndSettle` di test mana pun
  /// yang kebetulan nampilin sakelar ini gantung sampai timeout.
  late final AnimationController _latar = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didUpdateWidget(covariant SakelarSunMoon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gelap == oldWidget.gelap) return;

    // Hormati "kurangi gerak" di setelan HP: yang penting posisi akhirnya
    // benar, bukan perjalanannya.
    if (MediaQuery.disableAnimationsOf(context)) {
      _geser.value = widget.gelap ? 1 : 0;
      return;
    }
    _geser.animateTo(widget.gelap ? 1 : 0, curve: Curves.easeInOut);
    _latar.forward(from: 0);
  }

  @override
  void dispose() {
    _geser.dispose();
    _latar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lebar = _PelukisSakelar.lebar * widget.skala;
    final tinggi = _PelukisSakelar.tinggi * widget.skala;

    return Semantics(
      button: true,
      toggled: widget.gelap,
      label: widget.label,
      child: Tooltip(
        message: widget.label ?? '',
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          // Kotak sentuh minimal 48 dp walau sakelarnya cuma setinggi 34.
          child: SizedBox(
            width: math.max(lebar, 48),
            height: math.max(tinggi, 48),
            child: Center(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_geser, _latar]),
                  builder: (context, _) => CustomPaint(
                    size: Size(lebar, tinggi),
                    painter: _PelukisSakelar(
                      t: _geser.value,
                      // Satu putaran awan dan dua kedipan bintang per jalan.
                      faseAwan: _latar.value,
                      faseKelip: _latar.value * 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PelukisSakelar extends CustomPainter {
  _PelukisSakelar({
    required this.t,
    required this.faseAwan,
    required this.faseKelip,
  });

  /// 0 = terang, 1 = gelap.
  final double t;
  final double faseAwan;
  final double faseKelip;

  static const double lebar = 60;
  static const double tinggi = 34;

  static const _biru = Color(0xFF2196F3);
  static const _kuning = Color(0xFFFFFF00);
  static const _abuTotol = Color(0xFF808080);
  static const _awanGelap = Color(0xFFCCCCCC);
  static const _awanTerang = Color(0xFFEEEEEE);

  /// Semua koordinat di bawah ditulis dalam satuan basis 60×34 — persis angka
  /// CSS acuannya — lalu kanvasnya diskala sekali di awal.
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / lebar);

    final trek = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, lebar, tinggi),
      const Radius.circular(tinggi / 2),
    );
    canvas.drawRRect(trek, Paint()..color = Color.lerp(_biru, Colors.black, t)!);

    canvas.save();
    canvas.clipRRect(trek);
    _lukisMatahariBulan(canvas);
    _lukisBintang(canvas);
    canvas.restore();
  }

  void _lukisMatahariBulan(Canvas canvas) {
    canvas.save();
    canvas.translate(4 + 26 * t, 4);
    // Satu putaran penuh selama peralihan — di CSS ini `rotate-center`.
    canvas.translate(13, 13);
    canvas.rotate(t * 2 * math.pi);
    canvas.translate(-13, -13);

    // Sorot cahaya: tiga lingkaran putih tipis di belakang badan matahari.
    final cahaya = Paint()..color = Colors.white.withValues(alpha: 0.10);
    _bulat(canvas, -8, -8, 43, cahaya);
    _bulat(canvas, -13, -13, 55, cahaya);
    _bulat(canvas, -18, -18, 60, cahaya);

    _bulat(
      canvas,
      0,
      0,
      26,
      Paint()..color = Color.lerp(_kuning, Colors.white, t)!,
    );

    // Awan nempel ke matahari, makanya waktu mode gelap dia kebawa meluncur ke
    // kanan lalu kepotong sama trek.
    final gerakTerang = _ayunAwan(faseAwan);
    final gerakGelap = _ayunAwan(faseAwan - 1 / 6); // CSS: animation-delay 1s.
    final catGelap = Paint()..color = _awanGelap;
    final catTerang = Paint()..color = _awanTerang;
    _bulat(canvas, 30 + gerakGelap, 15, 40, catGelap);
    _bulat(canvas, 44 + gerakGelap, 10, 20, catGelap);
    _bulat(canvas, 18 + gerakGelap, 24, 30, catGelap);
    _bulat(canvas, 36 + gerakTerang, 18, 40, catTerang);
    _bulat(canvas, 48 + gerakTerang, 14, 20, catTerang);
    _bulat(canvas, 22 + gerakTerang, 26, 30, catTerang);

    if (t > 0) {
      final totol = Paint()..color = _abuTotol.withValues(alpha: t);
      _bulat(canvas, 10, 3, 6, totol);
      _bulat(canvas, 2, 10, 10, totol);
      _bulat(canvas, 16, 18, 3, totol);
    }

    canvas.restore();
  }

  void _lukisBintang(Canvas canvas) {
    if (t <= 0) return;

    canvas.save();
    // Bintangnya turun dari atas trek sambil memudar masuk.
    canvas.translate(0, -32 * (1 - t));
    final cat = Paint()..color = Colors.white.withValues(alpha: t);

    // (kiri, atas, ukuran, jeda kelip dalam detik).
    const bintang = [
      (3.0, 2.0, 20.0, 0.3),
      (3.0, 16.0, 6.0, 0.0),
      (10.0, 20.0, 12.0, 0.6),
      (18.0, 0.0, 18.0, 1.3),
    ];
    for (final (kiri, atas, ukuran, jeda) in bintang) {
      canvas.save();
      canvas.translate(kiri + ukuran / 2, atas + ukuran / 2);
      canvas.scale(_skalaKelip(faseKelip - jeda / 2));
      canvas.translate(-ukuran / 2, -ukuran / 2);
      canvas.drawPath(_pathBintang(ukuran), cat);
      canvas.restore();
    }
    canvas.restore();
  }

  /// Bintang empat sudut dengan sisi cekung — salinan path SVG acuan
  /// (viewBox 20×20), diskalakan ke [ukuran].
  Path _pathBintang(double ukuran) {
    final s = ukuran / 20;
    return Path()
      ..moveTo(0, 10 * s)
      ..cubicTo(10 * s, 10 * s, 10 * s, 10 * s, 10 * s, 20 * s)
      ..cubicTo(10 * s, 10 * s, 10 * s, 10 * s, 20 * s, 10 * s)
      ..cubicTo(10 * s, 10 * s, 10 * s, 10 * s, 10 * s, 0)
      ..cubicTo(10 * s, 10 * s, 10 * s, 10 * s, 0, 10 * s)
      ..close();
  }

  void _bulat(Canvas canvas, double kiri, double atas, double d, Paint cat) {
    canvas.drawCircle(Offset(kiri + d / 2, atas + d / 2), d / 2, cat);
  }

  /// Keyframe `cloud-move`: 0 → 4 → −4 → 0 px.
  double _ayunAwan(double fase) {
    final f = fase % 1;
    if (f < 0.4) return lerpDouble(0, 4, f / 0.4)!;
    if (f < 0.8) return lerpDouble(4, -4, (f - 0.4) / 0.4)!;
    return lerpDouble(-4, 0, (f - 0.8) / 0.2)!;
  }

  /// Keyframe `star-twinkle`: 1 → 1.2 → 0.8 → 1.
  double _skalaKelip(double fase) {
    final f = fase % 1;
    if (f < 0.4) return lerpDouble(1, 1.2, f / 0.4)!;
    if (f < 0.8) return lerpDouble(1.2, 0.8, (f - 0.4) / 0.4)!;
    return lerpDouble(0.8, 1, (f - 0.8) / 0.2)!;
  }

  @override
  bool shouldRepaint(_PelukisSakelar old) =>
      old.t != t || old.faseAwan != faseAwan || old.faseKelip != faseKelip;
}
