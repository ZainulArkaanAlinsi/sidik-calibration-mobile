import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Panorama senja/malam buat kepala kartu — acuan desain Uiverse karya
/// KSAplay, plus taburan bintang.
///
/// ## Kenapa CustomPainter, bukan tumpukan widget
///
/// Versi CSS-nya 20-an `<div>` bertumpuk. Ditiru mentah di Flutter itu jadi
/// 20-an `Positioned` PER KARTU, dan layar Data Teknisi itu daftar yang
/// discroll — 30 akun berarti 600 widget yang ikut layout tiap frame. Di sini
/// semuanya jadi **satu operasi lukis**: belasan `drawRect`/`drawOval`, nol
/// layout, nol widget anak.
///
/// ## Kenapa bintangnya nggak gerak
///
/// Acuan latar berbintangnya animasi. Di belakang daftar yang discroll, itu
/// artinya frame dijadwalkan terus-menerus selama layarnya kebuka — persis
/// pemborosan yang sudah dilarang di `panggung3d.dart` dan `splash_screen.dart`
/// (dan yang bikin `pumpAndSettle` gantung). Jadi bintangnya **diam**:
/// posisinya diacak dari [benih] biar tiap kartu beda, tapi tetap sama tiap
/// kali dilukis ulang, jadi nggak ada yang kedip waktu discroll.
///
/// Dibungkus [RepaintBoundary]: sekali dilukis, hasilnya dipakai ulang sampai
/// ukurannya berubah. Scroll nggak bikin isinya dilukis ulang sama sekali.
class PanoramaKartu extends StatelessWidget {
  const PanoramaKartu({
    super.key,
    required this.benih,
    this.tinggi = 118,
    this.anak,
  });

  /// Pengacak posisi bintang & pohon. Pakai sesuatu yang stabil per kartu
  /// (mis. id akun) supaya panoramanya nggak berubah tiap rebuild.
  final int benih;

  /// Tinggi panorama. Di kartu selebar layar HP, 104 itu pas; di kartu desktop
  /// yang lebarnya dua kali lipat, pita setinggi itu jadi blok warna yang
  /// menguasai kartunya — yang harusnya jadi aksen malah jadi isi utama.
  /// Pemanggilnya yang nurunin angka ini di layar lebar.
  final double tinggi;
  final Widget? anak;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: tinggi,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PelukisPanorama(benih: benih, gelap: gelap),
          child: anak,
        ),
      ),
    );
  }
}

class _PelukisPanorama extends CustomPainter {
  _PelukisPanorama({required this.benih, required this.gelap});

  final int benih;
  final bool gelap;

  // Palet senja, disalin dari CSS acuannya.
  static const _langitAtas = Color(0xFFE96594);
  static const _langitBawah = Color(0xFFF7E157);
  static const _lautAtas = Color(0xFFF7DA96);
  static const _lautBawah = Color(0xFFF1C07D);
  static const _bukit1 = Color(0xFFE6B29D);
  static const _bukit2 = Color(0xFFC29182);
  static const _bukit3 = Color(0xFFB77873);
  static const _bukit4 = Color(0xFFA16773);

  // Palet malam: bentuknya sama persis, cuma ronanya diturunkan. Dibikin palet
  // kedua, bukan menggelapkan yang pertama pakai lapisan hitam — cara itu
  // ngaburin semua warnanya jadi satu abu.
  static const _malamAtas = Color(0xFF141B3D);
  static const _malamBawah = Color(0xFF5B3A6E);
  static const _lautMalamAtas = Color(0xFF3D2A54);
  static const _lautMalamBawah = Color(0xFF221838);
  static const _bukitMalam1 = Color(0xFF3A2A50);
  static const _bukitMalam2 = Color(0xFF2E2142);
  static const _bukitMalam3 = Color(0xFF241A36);
  static const _bukitMalam4 = Color(0xFF1B1329);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.clipRect(Offset.zero & size);

    _langit(canvas, w, h);
    _bintang(canvas, w, h);
    _matahari(canvas, w, h);

    // Bukit jauh di kanan, lalu lautnya, lalu bukit depan — urutannya yang
    // bikin kedalaman kebaca.
    //
    // Ukurannya diikat ke TINGGI, bukan lebar. Kartu di daftar ini jauh lebih
    // lebar daripada kartu acuannya (760 dp lawan 220 px); bukit selebar
    // `w * 0.62` melar jadi noda yang menyapu separuh gambar. Diikat ke tinggi,
    // bentuknya tetap bukit di lebar berapa pun — yang berubah cuma berapa
    // banyak laut yang kelihatan di antaranya.
    _oval(canvas, w - h * 0.30, h * 0.60, h * 1.55, h * 0.24,
        gelap ? _bukitMalam1 : _bukit1);
    _oval(canvas, w - h * 0.02, h * 0.66, h * 1.55, h * 0.46,
        gelap ? _bukitMalam2 : _bukit2);
    _laut(canvas, w, h);
    _oval(canvas, h * 0.15, h * 1.10, h * 3.0, h * 0.66,
        gelap ? _bukitMalam3 : _bukit3);
    _oval(canvas, w - h * 0.10, h * 1.18, h * 3.0, h * 0.66,
        gelap ? _bukitMalam4 : _bukit4);
    _pohon(canvas, w, h);
    _pudar(canvas, w, h);
  }

  void _langit(Canvas canvas, double w, double h) {
    final cat = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gelap
            ? const [_malamAtas, _malamBawah]
            : const [_langitAtas, _langitBawah],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), cat);
  }

  /// Taburan bintang di sepertiga atas langit — di bawah situ dia ketiban
  /// matahari dan bukit, jadi cuma nambah ongkos lukis tanpa kelihatan.
  void _bintang(Canvas canvas, double w, double h) {
    final acak = math.Random(benih);
    final jumlah = gelap ? 26 : 14;

    for (var i = 0; i < jumlah; i++) {
      final x = acak.nextDouble() * w;
      final y = acak.nextDouble() * h * 0.45;
      final r = 0.5 + acak.nextDouble() * 1.1;
      // Makin ke bawah makin pudar: itu yang bikin taburannya kebaca sebagai
      // langit, bukan sebagai bintik yang ditempel rata.
      final pekat =
          (gelap ? 0.9 : 0.55) * (1 - y / (h * 0.5)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: pekat),
      );
    }
  }

  void _matahari(Canvas canvas, double w, double h) {
    final pusat = Offset(w * 0.26, h * 0.46);
    final r = h * 0.115;

    // Halo pakai gradasi radial, BUKAN MaskFilter.blur. Blur itu satu
    // saveLayer plus konvolusi tiap kali dilukis; gradasi cuma isian biasa.
    canvas.drawCircle(
      pusat,
      r * 3.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: gelap ? 0.22 : 0.32),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: pusat, radius: r * 3.4)),
    );
    canvas.drawCircle(pusat, r, Paint()..color = Colors.white);
  }

  void _laut(Canvas canvas, double w, double h) {
    final atas = h * 0.66;
    final kotak = Rect.fromLTWH(0, atas, w, h - atas);
    canvas.drawRect(
      kotak,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gelap
              ? const [_lautMalamAtas, _lautMalamBawah]
              : const [_lautAtas, _lautBawah],
        ).createShader(kotak),
    );

    // Pantulan: garis putih tipis di bawah matahari, seperti jalur cahaya di
    // air.
    canvas.save();
    canvas.clipRect(kotak);
    // Lebarnya diikat ke tinggi dan digeser-geser, sama alasannya dengan
    // bukit: dipatok ke lebar kartu, pantulannya melar jadi batang seragam yang
    // kebaca kayak bar pemuat, bukan cahaya di air.
    final cat = Paint()..color = Colors.white.withValues(alpha: 0.30);
    for (final (dy, lebar, geser, tebal) in const [
      (0.14, 0.9, -0.10, 1.6),
      (0.36, 1.6, 0.06, 2.0),
      (0.58, 0.7, -0.14, 1.6),
      (0.80, 1.3, 0.02, 2.0),
    ]) {
      final y = atas + (h - atas) * dy;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.26 + h * geser, y),
            width: h * lebar,
            height: tebal,
          ),
          Radius.circular(tebal / 2),
        ),
        cat,
      );
    }
    canvas.restore();
  }

  void _pohon(Canvas canvas, double w, double h) {
    final acak = math.Random(benih + 7);
    final catKanan = Paint()..color = gelap ? _bukitMalam4 : _bukit4;
    final catKiri = Paint()..color = gelap ? _bukitMalam3 : _bukit3;

    // Tiga pohon: dua di bukit kiri, satu di bukit kanan. Bentuknya mahkota
    // bulat + batang — siluet yang sama dengan SVG acuannya di ukuran segini,
    // tanpa perlu ngangkut path SVG.
    for (final (x, dasar, skala, kiri) in [
      (0.10 + acak.nextDouble() * 0.05, 0.86, 1.0, true),
      (0.30 + acak.nextDouble() * 0.06, 0.93, 0.78, true),
      (0.88 - acak.nextDouble() * 0.05, 0.90, 1.15, false),
    ]) {
      final tinggiPohon = h * 0.26 * skala;
      final rMahkota = tinggiPohon * 0.36;
      final px = w * x;
      final py = h * dasar;
      final cat = kiri ? catKanan : catKiri;

      canvas.drawCircle(Offset(px, py - tinggiPohon * 0.62), rMahkota, cat);
      canvas.drawRect(
        Rect.fromLTWH(
          px - tinggiPohon * 0.07,
          py - tinggiPohon * 0.62,
          tinggiPohon * 0.14,
          tinggiPohon * 0.62,
        ),
        cat,
      );
    }
  }

  /// Pudar putih tipis di kaki panorama — `.filter` di CSS acuannya. Ini yang
  /// bikin panoramanya nyambung ke bidang teks di bawahnya, bukan berhenti
  /// dengan garis potong.
  void _pudar(Canvas canvas, double w, double h) {
    final kotak = Rect.fromLTWH(0, h * 0.6, w, h * 0.4);
    canvas.drawRect(
      kotak,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white.withValues(alpha: gelap ? 0.10 : 0.22),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(kotak),
    );
  }

  void _oval(
    Canvas canvas,
    double cx,
    double cy,
    double lebar,
    double tinggi,
    Color warna,
  ) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: lebar, height: tinggi),
      Paint()..color = warna,
    );
  }

  @override
  bool shouldRepaint(_PelukisPanorama old) =>
      old.benih != benih || old.gelap != gelap;
}
