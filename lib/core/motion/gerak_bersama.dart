import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Angka gerak Biru Awan di luar [AppMotion] (`docs/desain-ulang/tokens.json`
/// → `gerak`). Durasi dan kurva TETAP dari [AppMotion]; di sini hanya jarak dan
/// skala.
abstract final class GerakBersama {
  /// Ubin dan panel masuk layar naik sejauh ini (dp).
  static const double geserMasuk = 12;

  /// Skala selama ditekan.
  static const double skalaTekan = 0.97;
}

/// Ubin atau panel yang masuk layar: pudar + naik [GerakBersama.geserMasuk] dp,
/// berurutan menurut [indeks] (35 ms per butir, maksimum 210 ms).
///
/// Dari kerangka `docs/desain-ulang/flutter/gerak_bersama.dart`, dengan satu
/// perubahan: tundaan tidak memakai `Timer`, tetapi bagian awal satu
/// `AnimationController` (kurva `Interval`). Hasilnya sama di layar, dan tes
/// widget tidak meninggalkan timer yang menggantung.
///
/// "Kurangi gerak" (`MediaQuery.disableAnimations`): anak langsung tampil utuh,
/// tanpa tundaan. Pembungkus ini tidak mengubah ukuran maupun semantik anak, dan
/// tidak dipakai untuk angka ukur (angka ukur tidak dianimasikan).
class MasukBerurutan extends StatefulWidget {
  const MasukBerurutan({super.key, required this.indeks, required this.child});

  /// Urutan butir di daftar (0 = pertama).
  final int indeks;
  final Widget child;

  @override
  State<MasukBerurutan> createState() => _MasukBerurutanState();
}

class _MasukBerurutanState extends State<MasukBerurutan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late Animation<double> _a = const AlwaysStoppedAnimation<double>(1);
  bool _mulai = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mulai) return;
    _mulai = true;

    final gerak = AppMotion.hormati(context, AppMotion.sedang);
    if (gerak == Duration.zero) {
      _c.value = 1;
      return;
    }
    final tunda = AppMotion.tunda(context, widget.indeks);
    final total = tunda + gerak;
    _c.duration = total;
    _a = CurvedAnimation(
      parent: _c,
      curve: Interval(
        tunda.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppMotion.masuk,
      ),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, GerakBersama.geserMasuk * (1 - _a.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Umpan balik tekan: skala [GerakBersama.skalaTekan] selama ditekan (120 ms).
/// Bungkus di LUAR `InkWell`/tombol.
///
/// [aktif] `false` (tombol mati, baris tanpa aksi) = anak apa adanya, tanpa
/// skala. "Kurangi gerak" membuat perpindahan skala seketika.
class TekanSkala extends StatefulWidget {
  const TekanSkala({super.key, required this.child, this.aktif = true});

  final Widget child;
  final bool aktif;

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
    final ditekan = widget.aktif && _tekan;
    return Listener(
      onPointerDown: (_) => _atur(true),
      onPointerUp: (_) => _atur(false),
      onPointerCancel: (_) => _atur(false),
      child: AnimatedScale(
        scale: ditekan ? GerakBersama.skalaTekan : 1,
        duration: AppMotion.hormati(context, AppMotion.kilat),
        curve: AppMotion.masuk,
        child: widget.child,
      ),
    );
  }
}
