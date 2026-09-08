import 'package:flutter/material.dart';

/// Folder kertas — acuan desain Uiverse (folder kuning bertumpuk kertas).
///
/// Waktu disentuh: folder naik sedikit, tutup depannya rebah ke belakang, dan
/// tiga lembar kertas di dalamnya menyembul sambil sedikit terkipas.
///
/// Digambar satu [CustomPainter]: layar Arsip itu daftar, dan meniru 8 elemen
/// bertumpuk CSS-nya jadi 8 widget per baris bikin daftar panjang membayar
/// ongkos layout yang nggak perlu. Semua bentuknya persegi membulat, jadi
/// nol gambar dan nol dependency baru.
///
/// Animasinya BERUJUNG — sekali jalan waktu disentuh lalu diam. Aturan yang
/// sama sudah dipatok `splash_screen.dart` dan `panggung3d.dart`: animasi
/// tanpa ujung bikin frame kejadwal terus dan bikin `pumpAndSettle` gantung.
class FolderKertas extends StatefulWidget {
  const FolderKertas({super.key, this.ukuran = 56, this.terbuka = false});

  final double ukuran;

  /// Dipaksa terbuka tanpa perlu disentuh — dipakai buat folder yang sedang
  /// dibuka di layar.
  final bool terbuka;

  @override
  State<FolderKertas> createState() => _FolderKertasState();
}

class _FolderKertasState extends State<FolderKertas> {
  bool _hover = false;
  bool _tekan = false;

  @override
  Widget build(BuildContext context) {
    final maju = widget.terbuka || _hover || _tekan;
    final durasi = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 450);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _tekan = true),
        onPointerUp: (_) => setState(() => _tekan = false),
        onPointerCancel: (_) => setState(() => _tekan = false),
        child: SizedBox(
          width: widget.ukuran,
          height: widget.ukuran * 0.8,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: maju ? 1.0 : 0.0),
            duration: durasi,
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              painter: _PelukisFolder(t: t),
            ),
          ),
        ),
      ),
    );
  }
}

class _PelukisFolder extends CustomPainter {
  _PelukisFolder({required this.t});

  final double t;

  static const _belakang1 = Color(0xFFF7C14B);
  static const _belakang2 = Color(0xFFE9A52F);
  static const _depan1 = Color(0xFFFFD970);
  static const _depan2 = Color(0xFFFBC548);
  static const _kertas = Color(0xFFFDFDFB);
  static const _kertas2 = Color(0xFFF6F4EE);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final naik = -3.0 * t;

    canvas.save();
    canvas.translate(0, naik);

    // Badan belakang + lidah kecil di kiri atas.
    final catBelakang = Paint()
      ..shader = const LinearGradient(colors: [_belakang1, _belakang2])
          .createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.14, w, h * 0.86),
        Radius.circular(w * 0.08),
      ),
      catBelakang,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.02, w * 0.46, h * 0.18),
        Radius.circular(w * 0.03),
      ),
      catBelakang,
    );

    // Tiga lembar kertas. Yang tengah paling lebar, dua sisanya terkipas ke
    // kiri dan kanan — itu yang bikin tumpukannya kebaca sebagai isi, bukan
    // satu bidang putih.
    for (final (lebar, tinggi, geserX, putar, warna) in [
      (0.62, 0.52, -0.16 * t, -0.12 * t, _kertas2),
      (0.66, 0.56, 0.14 * t, 0.10 * t, const Color(0xFFFBFAF6)),
      (0.70, 0.60, 0.0, 0.0, _kertas),
    ]) {
      canvas.save();
      final kx = w * (0.5 + geserX);
      final ky = h * (0.86 - 0.22 * t);
      canvas.translate(kx, ky);
      canvas.rotate(putar);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * lebar / 2, -h * tinggi, w * lebar, h * tinggi),
          Radius.circular(w * 0.035),
        ),
        Paint()..color = warna,
      );
      canvas.restore();
    }

    // Tutup depan. Rebah ke belakang waktu terbuka — didekati dengan
    // memendekkan tingginya, bukan rotasi 3D: di ukuran ikon daftar bedanya
    // nggak kebaca, dan `Matrix4` perspektif bikin tiap baris bayar ongkos
    // transform yang nggak perlu.
    final tinggiDepan = h * (0.62 - 0.34 * t);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h - tinggiDepan, w, tinggiDepan),
        Radius.circular(w * 0.08),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_depan1, _depan2],
        ).createShader(Rect.fromLTWH(0, h - tinggiDepan, w, tinggiDepan)),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PelukisFolder old) => old.t != t;
}
