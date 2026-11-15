import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_ukuran.dart';
import '../../core/theme/bentuk_lab.dart';
import '../../core/theme/token_komponen_biru_awan_lanjut.dart';

/// Hero langit Biru Awan (`BerandaAdmin.dc.html`, `LAYAR.md` hero): bidang
/// `langit` sudut 28 berisi [child], dengan motif skala (busur skala + jarum +
/// penggaris, BUKAN awan) di sudut kiri bawah.
///
/// - Motif satu per hero, diam, putih 50 % (gelap: tinta 50 %); murni hiasan,
///   keluar dari pembaca layar. Digambar dari koordinat `motif_skala.svg`
///   ([MotifSkala]); lihat `test/biru_awan/hero_langit_test.dart`.
/// - Teks di dalamnya NAVY: bungkus bawaan memasang `tintaHero` lewat
///   [DefaultTextStyle]. Putih di atas langit DILARANG (2,26:1).
/// - [tinggiMin] 212 (beranda teknisi); beranda admin 196, profil 204. Hero
///   tumbuh bila isi atau huruf sistem membesar, tidak pernah memotong isi.
/// - [visual] (gambar alat, L4) menumpang di kanan bawah dan keluar sebagian
///   dari hero; hiasan, tidak membawa semantik.
/// - Hero bukan kontrol: tidak bisa diketuk. Tombol di dalamnya (`TombolSidik`
///   navy) membawa aksinya sendiri.
/// - Tanpa gerak sendiri: masuknya dibungkus pemanggil dengan `MasukBerurutan`.
class HeroLangit extends StatelessWidget {
  const HeroLangit({
    super.key,
    required this.child,
    this.tinggiMin = UkuranBiruAwan.hero,
    this.visual,
  });

  final Widget child;
  final double tinggiMin;
  final Widget? visual;

  @override
  Widget build(BuildContext context) {
    final w = WarnaLanjutBiruAwan.of(context);
    final radius = BorderRadius.circular(BentukBiruAwan.hero);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(color: w.isiHero),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tinggiMin),
          child: Stack(
            children: [
              const Positioned(
                left: UkuranLanjutBiruAwan.motifGeserKiri,
                bottom: UkuranLanjutBiruAwan.motifGeserBawah,
                width: UkuranLanjutBiruAwan.motifLebar,
                height: UkuranLanjutBiruAwan.motifTinggi,
                child: ExcludeSemantics(child: _MotifSkala()),
              ),
              if (visual != null)
                Positioned(
                  right: UkuranLanjutBiruAwan.visualGeserKanan,
                  bottom: UkuranLanjutBiruAwan.visualGeserBawah,
                  child: ExcludeSemantics(child: visual!),
                ),
              Padding(
                padding: const EdgeInsets.all(
                  UkuranLanjutBiruAwan.heroBantalan,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: w.tintaHero),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MotifSkala extends StatelessWidget {
  const _MotifSkala();

  @override
  Widget build(BuildContext context) {
    final w = WarnaLanjutBiruAwan.of(context);
    return IgnorePointer(
      child: CustomPaint(painter: PelukisMotifSkala(warna: w.motifHero)),
    );
  }
}

/// Menggambar [MotifSkala] memenuhi kanvas, diskalakan dari 300 x 120. Seluruh
/// motif digambar buram di satu lapisan lalu ditempel dengan alfa
/// `motifAlfa`, seperti `opacity` pada elemen `svg` (garis yang bertumpuk tidak
/// menjadi lebih pekat).
class PelukisMotifSkala extends CustomPainter {
  const PelukisMotifSkala({required this.warna});

  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    final skala = size.width / MotifSkala.lebar;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = warna.withValues(alpha: UkuranLanjutBiruAwan.motifAlfa),
    );
    canvas.scale(skala);

    Paint pena(double tebal) => Paint()
      ..color = warna
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = tebal;

    // Busur luar: dari kiri (180 derajat) ke atas (270), searah jarum jam.
    const halfPi = math.pi / 2;
    final luar = Path()
      ..addArc(
        Rect.fromCircle(center: MotifSkala.poros, radius: MotifSkala.jariBusur),
        math.pi,
        halfPi,
      );
    canvas.drawPath(luar, pena(MotifSkala.tebalBusur));

    // Busur dalam putus-putus: 2 on, 6 off sepanjang busur.
    final dalam = Path()
      ..addArc(
        Rect.fromCircle(center: MotifSkala.poros, radius: MotifSkala.jariTitik),
        math.pi,
        halfPi,
      );
    final penaTitik = pena(MotifSkala.tebalBusurTitik);
    for (final ukur in dalam.computeMetrics()) {
      var jarak = 0.0;
      while (jarak < ukur.length) {
        final akhir = jarak + MotifSkala.titikPanjang;
        canvas.drawPath(
          ukur.extractPath(jarak, akhir > ukur.length ? ukur.length : akhir),
          penaTitik,
        );
        jarak += MotifSkala.titikPanjang + MotifSkala.titikJeda;
      }
    }

    for (final g in MotifSkala.garis()) {
      canvas.drawLine(g.dari, g.ke, pena(g.tebal));
    }

    canvas.drawCircle(
      MotifSkala.poros,
      MotifSkala.jariPoros,
      Paint()
        ..color = warna
        ..style = PaintingStyle.fill,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PelukisMotifSkala lama) => lama.warna != warna;
}
