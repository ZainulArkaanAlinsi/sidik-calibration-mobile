import 'package:flutter/material.dart';

import '../../core/theme/sidik_material.dart';

/// Permukaan dasar sistem "Meja Kerja Lab".
///
/// Tiap widget di sini = satu material. Pilih berdasarkan **apa yang dilakukan
/// orang di atasnya**, bukan berdasarkan enaknya kelihatan:
///
/// - [Kertas]      → membaca & mengisi
/// - [Baki]        → wadah cekung di atas kertas
/// - [PanelLogam]  → bingkai yang megang, tempat tombol
/// - [PanelKaca]   → angka hidup yang dilirik

/// Lembar kertas. Pengganti `Card`, `GlassSurface.rata`, dan `SoftRaised`.
class Kertas extends StatelessWidget {
  const Kertas({
    super.key,
    required this.child,
    this.padding,
    this.radius = SidikMaterial.sudutKertas,
    this.warna,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? warna;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    Widget isi = Container(
      padding: padding,
      decoration: m.kertasLembar(radius: radius, warna: warna),
      child: child,
    );

    if (onTap != null) {
      isi = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          // Ripple dilemahkan: di atas kertas, percikan Material kebaca
          // seperti noda tinta. Umpan baliknya cukup dari highlight tipis.
          splashColor: m.biru.withValues(alpha: 0.06),
          highlightColor: m.biru.withValues(alpha: 0.04),
          child: isi,
        ),
      );
    }
    return margin == null ? isi : Padding(padding: margin!, child: isi);
  }
}

/// Wadah cekung di atas kertas — buat blok pendukung (ringkasan hitung,
/// catatan, pratinjau). Pengganti kartu abu-abu datar.
class Baki extends StatelessWidget {
  const Baki({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = SidikMaterial.sudutKertas,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Container(
      padding: padding,
      decoration: m.kertasBaki(radius: radius),
      child: child,
    );
  }
}

/// Panel aluminium disikat: app bar kustom, bar aksi bawah, bingkai nav.
///
/// Garis sikatnya digambar [SikatLogam] di atas gradien. Karena dia CustomPaint
/// seukuran panel, jangan dipakai buat area sebesar layar penuh — panel logam
/// memang cuma dipakai di bilah-bilah kecil.
class PanelLogam extends StatelessWidget {
  const PanelLogam({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.garisAtas = false,
    this.garisBawah = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;

  /// Garis pemisah + bayangan ke arah isi layar.
  final bool garisAtas;
  final bool garisBawah;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          if (garisAtas || garisBawah)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: -3,
              offset: Offset(0, garisAtas ? -2 : 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius ?? BorderRadius.zero,
        child: Container(
          decoration: m.logamPanel(
            radius: radius,
            border: Border(
              top: garisAtas
                  ? BorderSide(color: m.logamTepi)
                  : BorderSide.none,
              bottom: garisBawah
                  ? BorderSide(color: m.logamTepi)
                  : BorderSide.none,
            ),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: SikatLogam()),
              // Kilau tipis di sisi atas panel — sisi yang kena cahaya.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(height: 1, color: m.kilau),
              ),
              Padding(padding: padding ?? EdgeInsets.zero, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Layar readout cekung. Selalu gelap, di dua tema — sama seperti layar alat
/// ukur asli yang tetap hitam entah lampu ruangan nyala atau mati.
///
/// Dipakai panel teknisi (yang di dalamnya ada objek 3D `Panggung3D` — objek
/// itu TIDAK diubah, cuma wadahnya).
class PanelKaca extends StatelessWidget {
  const PanelKaca({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = SidikMaterial.sudutKaca,
    this.vernier = true,
    this.sekrup = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Skala vernier terukir di tepi kanan panel — motif identitas app.
  final bool vernier;

  /// Sekrup di empat sudut panel.
  final bool sekrup;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Container(
      decoration: m.kacaCekung(radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (vernier)
              Positioned(
                right: 0,
                top: 16,
                bottom: 16,
                width: 14,
                child: CustomPaint(painter: _PelukisVernier()),
              ),
            if (sekrup) ...[
              const Positioned(top: 8, left: 8, child: _Sekrup()),
              const Positioned(top: 8, right: 8, child: _Sekrup()),
              const Positioned(bottom: 8, left: 8, child: _Sekrup()),
              const Positioned(bottom: 8, right: 8, child: _Sekrup()),
            ],
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _PelukisVernier extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final kecil = Paint()
      ..color = const Color(0xFF3A434B)
      ..strokeWidth = 1;
    final besar = Paint()
      ..color = const Color(0xFF6C7A84)
      ..strokeWidth = 1;
    var i = 0;
    for (double y = 0; y < size.height; y += 8, i++) {
      final panjang = i % 5 == 0 ? 12.0 : 6.0;
      canvas.drawLine(
        Offset(size.width - panjang, y),
        Offset(size.width, y),
        i % 5 == 0 ? besar : kecil,
      );
    }
  }

  @override
  bool shouldRepaint(_PelukisVernier oldDelegate) => false;
}

class _Sekrup extends StatelessWidget {
  const _Sekrup();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: CustomPaint(painter: _PelukisSekrup()),
    );
  }
}

class _PelukisSekrup extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final pusat = Offset(r, r);
    canvas.drawCircle(
      pusat,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFF6E747C), Color(0xFF2C3037)],
        ).createShader(Rect.fromCircle(center: pusat, radius: r)),
    );
    // Alur obeng.
    canvas.drawLine(
      Offset(1.5, r),
      Offset(size.width - 1.5, r),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PelukisSekrup oldDelegate) => false;
}
