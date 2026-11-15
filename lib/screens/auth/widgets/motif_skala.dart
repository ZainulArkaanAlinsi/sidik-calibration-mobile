import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Motif hiasan Biru Awan: bagian alat kalibrasi (busur skala dengan tik dan
/// jarum, garis penggaris bertik) dari `docs/desain-ulang/aset/motif_skala.svg`
/// (viewBox 300 x 120). Satu-satunya hiasan, diam, hanya di hero (masuk, splash).
///
/// Digambar dengan kanvas (proyek tidak memakai paket SVG) mengikuti SVG-nya:
/// garis berujung bulat, busur luar 110 dan busur titik-titik 86 yang berpusat
/// di (300, 120), 16 tik tiap 6 derajat (tiap tik kelima panjang dan tebal),
/// jarum, penggaris 0..180, dan hub.
///
/// Ukurannya mengikuti [lebar] x [tinggi] dengan aturan `meet` (seluruh motif
/// terlihat, di tengah), sama seperti `<svg width height>` pada artboard.
/// Warna dan [opasitas] dari pemanggil; motif tidak punya warna sendiri.
/// Hiasan murni: tidak dibaca pembaca layar dan tidak menerima sentuhan.
class MotifSkala extends StatelessWidget {
  const MotifSkala({
    super.key,
    required this.warna,
    required this.lebar,
    required this.tinggi,
    this.opasitas = 1,
  });

  final Color warna;
  final double lebar;
  final double tinggi;

  /// 0..1; artboard memakai 0,55 (putih di atas langit) dan 0,25 sampai 0,35
  /// (langit di atas latar).
  final double opasitas;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(lebar, tinggi),
          painter: PelukisMotifSkala(warna.withValues(alpha: opasitas)),
        ),
      ),
    );
  }
}

/// Pelukis [MotifSkala]. Publik agar tes bisa memeriksa warnanya.
class PelukisMotifSkala extends CustomPainter {
  const PelukisMotifSkala(this.warna);

  final Color warna;

  // Geometri viewBox SVG (satuan SVG, bukan dp).
  static const double _lebarKotak = 300;
  static const double _tinggiKotak = 120;
  static const Offset _pusat = Offset(300, 120);
  static const double _radiusBusur = 110;
  static const double _radiusTitik = 86;
  static const int _jumlahTik = 16;
  static const double _sudutTik = 6 * math.pi / 180;
  static const double _tikPanjang = 16;
  static const double _tikPendek = 8;
  static const double _tebalBusur = 3;
  static const double _tebalBusurTitik = 1.5;
  static const double _tebalTikPanjang = 3;
  static const double _tebalTikPendek = 2;
  static const double _tebalJarum = 4;
  static const Offset _ujungJarum = Offset(245, 70.5);
  static const double _tebalPenggaris = 2.5;
  static const double _yPenggaris = 118;
  static const double _akhirPenggaris = 180;
  static const double _langkahPenggaris = 10;
  static const int _tikPenggarisPanjangTiap = 5;
  static const double _tinggiTikPenggarisPanjang = 14;
  static const double _tinggiTikPenggarisPendek = 7;
  static const double _tebalTikPenggarisPendek = 1.6;
  static const double _radiusHub = 9;
  static const double _panjangTitik = 2;
  static const double _jedaTitik = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final skala = math.min(
      size.width / _lebarKotak,
      size.height / _tinggiKotak,
    );
    canvas
      ..save()
      ..translate(
        (size.width - _lebarKotak * skala) / 2,
        (size.height - _tinggiKotak * skala) / 2,
      )
      ..scale(skala);

    Paint garis(double tebal) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = tebal
      ..color = warna;

    // Busur luar: dari barat (180 derajat) ke utara, seperempat putaran.
    canvas.drawArc(
      Rect.fromCircle(center: _pusat, radius: _radiusBusur),
      math.pi,
      math.pi / 2,
      false,
      garis(_tebalBusur),
    );

    // Busur titik-titik: potongan 2 dengan jeda 6 sepanjang busur dalam.
    final busurTitik = Path()
      ..addArc(
        Rect.fromCircle(center: _pusat, radius: _radiusTitik),
        math.pi,
        math.pi / 2,
      );
    final titik = garis(_tebalBusurTitik);
    for (final ukuran in busurTitik.computeMetrics()) {
      for (
        var d = 0.0;
        d < ukuran.length;
        d += _panjangTitik + _jedaTitik
      ) {
        canvas.drawPath(
          ukuran.extractPath(d, math.min(d + _panjangTitik, ukuran.length)),
          titik,
        );
      }
    }

    // Tik busur: 16 tik, tiap 6 derajat dari utara ke barat.
    for (var i = 0; i < _jumlahTik; i++) {
      final panjang = i % 5 == 0;
      final sudut = i * _sudutTik;
      final arah = Offset(-math.sin(sudut), -math.cos(sudut));
      canvas.drawLine(
        _pusat + arah * _radiusBusur,
        _pusat + arah * (_radiusBusur - (panjang ? _tikPanjang : _tikPendek)),
        garis(panjang ? _tebalTikPanjang : _tebalTikPendek),
      );
    }

    // Jarum.
    canvas.drawLine(_pusat, _ujungJarum, garis(_tebalJarum));

    // Penggaris bertik di kiri bawah.
    canvas.drawLine(
      const Offset(0, _yPenggaris),
      const Offset(_akhirPenggaris, _yPenggaris),
      garis(_tebalPenggaris),
    );
    var nomor = 0;
    for (
      var x = 0.0;
      x <= _akhirPenggaris;
      x += _langkahPenggaris, nomor++
    ) {
      final panjang = nomor % _tikPenggarisPanjangTiap == 0;
      canvas.drawLine(
        Offset(x, _yPenggaris),
        Offset(
          x,
          _yPenggaris -
              (panjang
                  ? _tinggiTikPenggarisPanjang
                  : _tinggiTikPenggarisPendek),
        ),
        garis(panjang ? _tebalPenggaris : _tebalTikPenggarisPendek),
      );
    }

    // Hub jarum.
    canvas.drawCircle(
      _pusat,
      _radiusHub,
      Paint()
        ..style = PaintingStyle.fill
        ..color = warna,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PelukisMotifSkala lama) => lama.warna != warna;
}
