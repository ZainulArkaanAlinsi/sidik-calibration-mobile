import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mesh3d.dart';
import 'renderer3d.dart';

/// Panggung 3D deklaratif — kasih mesh, dia yang ngurus kamera, cahaya,
/// animasi masuk, dan interaksi geser.
///
/// Gaya API-nya niru React Three Fiber (`<Canvas><mesh/></Canvas>`): yang
/// ditulis di tempat pakai cuma *apa* yang mau dilihat, bukan urutan perintah
/// gambar. Bedanya, di sini nggak ada `useFrame` yang jalan selamanya — dan
/// itu disengaja:
///
/// ## Kenapa nggak ada animasi yang muter terus
///
/// Objek yang muter tanpa henti keliatan keren di video, tapi di app ini dia
/// bikin dua kerusakan nyata:
///
/// 1. **Baterai & panas.** Dashboard adalah layar yang paling lama kebuka di
///    HP teknisi. Frame 60fps nonstop di layar diam itu ongkos yang dibayar
///    seharian, buat hiasan yang udah nggak dilihat lagi sesudah detik ketiga.
/// 2. **Tes jadi ngegantung.** `pumpAndSettle` nunggu sampai nggak ada frame
///    terjadwal. Animasi yang `repeat()` nggak pernah nyampe situ, jadi
///    SELURUH tes yang kebetulan mumpung layar itu langsung timeout — bukan
///    gagal dengan pesan yang jelas, tapi mati 10 menit lalu merah.
///
/// Jadi geraknya dibikin **selalu berujung**: animasi masuk sekali waktu
/// muncul, lalu diam. Sesudah itu gerak cuma terjadi kalau orangnya yang
/// minta — geser buat muter, ketuk buat satu putaran penuh.
class Panggung3D extends StatefulWidget {
  const Panggung3D({
    super.key,
    required this.mesh,
    this.kamera = const Kamera3D(),
    this.cahaya = const Cahaya3D(),
    this.yawAwal = -1.15,
    this.yawAkhir = 0.42,
    this.durasiMasuk = const Duration(milliseconds: 2200),
    this.bayangan = 1.9,
    this.garisTepi = 0.0,
    this.bisaDiputar = true,
    this.pusatObjek = const Vek3(0, -0.95, 0),
    this.progress,
    this.semantics,
  });

  final Mesh3D mesh;
  final Kamera3D kamera;
  final Cahaya3D cahaya;

  /// Sudut waktu objek pertama muncul, dan sudut diamnya. Objek masuk sambil
  /// muter dari [yawAwal] ke [yawAkhir] — kesannya "dipajang", bukan
  /// tiba-tiba nongol.
  final double yawAwal;
  final double yawAkhir;

  final Duration durasiMasuk;

  /// Lebar bayangan kontak. 0 = benda ngambang (dipakai kalau adegannya
  /// emang di udara).
  final double bayangan;

  final double garisTepi;

  /// Geser buat muter, ketuk buat satu putaran penuh.
  final bool bisaDiputar;

  /// Titik tengah objek digeser ke sini sebelum dirender, supaya objek yang
  /// berdiri di lantai (y = 0) kelihatan pas di tengah panel.
  final Vek3 pusatObjek;

  /// Kalau diisi, animasi masuk dikendalikan dari luar (0..1) — dipakai
  /// onboarding, biar objek ngikut jari waktu halaman digeser, bukan jalan
  /// sendiri.
  final Animation<double>? progress;

  final String? semantics;

  @override
  State<Panggung3D> createState() => _Panggung3DState();
}

class _Panggung3DState extends State<Panggung3D> with TickerProviderStateMixin {
  late final AnimationController _masuk;
  late final AnimationController _putar;

  /// Sudut tambahan dari jari pengguna. Kepisah dari animasi supaya geseran
  /// nggak ke-reset tiap animasi masuk kelar.
  double _yawTangan = 0;
  double _yawPutaran = 0;

  @override
  void initState() {
    super.initState();
    _masuk = AnimationController(vsync: this, duration: widget.durasiMasuk);
    _putar =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        )..addListener(() {
          setState(() {
            _yawPutaran =
                Curves.easeOutCubic.transform(_putar.value) * math.pi * 2;
          });
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.progress != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _masuk.value = 1;
    } else if (!_masuk.isAnimating && _masuk.value == 0) {
      _masuk.forward();
    }
  }

  @override
  void dispose() {
    _masuk.dispose();
    _putar.dispose();
    super.dispose();
  }

  void _ketuk() {
    if (!widget.bisaDiputar || _putar.isAnimating) return;
    _yawTangan += _yawPutaran;
    _yawPutaran = 0;
    _putar.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress ?? _masuk;

    final panggung = RepaintBoundary(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(progress.value.clamp(0, 1));
          final yaw =
              widget.yawAwal +
              (widget.yawAkhir - widget.yawAwal) * t +
              _yawTangan +
              _yawPutaran;

          return CustomPaint(
            // `SizedBox.expand`, bukan CustomPaint telanjang: CustomPaint
            // tanpa anak ukurannya `Size.zero`, dan begitu induknya ngasih
            // batas longgar (Column, Wrap, Stack non-positioned) lebarnya
            // beneran jadi nol — panggungnya ngilang tanpa error apa pun.
            isComplex: true,
            willChange: progress.isAnimating || _putar.isAnimating,
            painter: _PanggungPainter(
              adegan: Adegan3D(
                objek: [
                  Objek3D(
                    mesh: widget.mesh,
                    posisi: widget.pusatObjek,
                    putarY: yaw,
                    // Naik sedikit + ngembang waktu masuk. Skala mulai dari
                    // 0.86, bukan 0: benda yang tumbuh dari nol kebaca kayak
                    // gangguan render, bukan gerakan.
                    skala: 0.86 + 0.14 * t,
                    bayangan: widget.bayangan * (0.35 + 0.65 * t),
                    opasitas: (t * 1.6).clamp(0.0, 1.0),
                  ),
                ],
                kamera: widget.kamera,
                cahaya: widget.cahaya,
                garisTepi: widget.garisTepi,
              ),
            ),
            // `SizedBox.expand`, bukan CustomPaint telanjang: CustomPaint
            // tanpa anak ukurannya `Size.zero`, dan begitu induknya ngasih
            // batas longgar (Column, Wrap, Stack non-positioned) lebarnya
            // beneran jadi nol — panggungnya ngilang tanpa error apa pun.
            child: const SizedBox.expand(),
          );
        },
      ),
    );

    if (!widget.bisaDiputar) {
      return Semantics(label: widget.semantics, child: panggung);
    }

    return Semantics(
      label: widget.semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _ketuk,
        onHorizontalDragUpdate: (d) =>
            setState(() => _yawTangan += d.delta.dx * 0.012),
        child: panggung,
      ),
    );
  }
}

class _PanggungPainter extends CustomPainter {
  const _PanggungPainter({required this.adegan});

  final Adegan3D adegan;

  @override
  void paint(Canvas canvas, Size size) => gambarAdegan(canvas, size, adegan);

  @override
  bool shouldRepaint(covariant _PanggungPainter old) => true;
}
