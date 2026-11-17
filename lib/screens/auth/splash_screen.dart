import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/lab_profile.dart';
import '../../core/motion/app_motion.dart';
import '../../core/motion/gerak_bersama.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../core/theme/token_komponen_biru_awan.dart';
import '../../core/theme/warna_biru_awan.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/kerangka_masuk.dart';
import 'widgets/motif_skala.dart';

/// Jadwal splash (artboard E1, `docs/desain-ulang/ELEMEN.md` §Splash), dalam
/// milidetik sejak layar muncul. Satu timeline, SEKALI jalan:
///
/// 0 sampai 100 diam, cincin ditarik 700 ms (mulai 100), plat logo muncul 420
/// ms (mulai 500), sapuan cahaya 600 ms (mulai 900), "SIDIK Lab" naik 280 ms
/// (mulai 1100), kalimat akreditasi 280 ms (mulai 1250), nama PT 280 ms (mulai
/// 1400), lalu diam. Total [total] ms.
abstract final class JadwalSplash {
  static const int cincinMulai = 100;
  static const int cincinDurasi = 700;
  static const int platMulai = 500;
  static const int platDurasi = 420;
  static const int sapuMulai = 900;
  static const int sapuDurasi = 600;
  static const int namaMulai = 1100;
  static const int namaDurasi = 280;
  static const int taglineMulai = 1250;
  static const int taglineDurasi = 280;
  static const int perusahaanMulai = 1400;
  static const int perusahaanDurasi = 280;

  static const int total = perusahaanMulai + perusahaanDurasi;
  static const Duration durasi = Duration(milliseconds: total);

  /// Potongan 0..1 dari timeline untuk satu tahap, lengkap dengan kurvanya.
  static Interval tahap(int mulai, int lama, Curve kurva) =>
      Interval(mulai / total, (mulai + lama) / total, curve: kurva);
}

/// Ukuran splash (artboard E1).
abstract final class _UkuranSplash {
  static const double cincin = 168;
  static const double cincinTebal = 6;
  static const double cincinRadius = 78;
  static const double plat = 128;
  static const double logoLebar = 62;
  static const double logoTinggi = 86;
  static const double platSkalaAwal = 0.92;

  /// Isi diletakkan sedikit di atas tengah (artboard: 250 dp dari atas pada
  /// layar 844): sumbu vertikal Align.
  static const double letakVertikal = -0.16;
  static const double jarakCincinNama = 32;
  static const double jarakNamaTagline = 8;

  /// Pita putih di dasar layar dan nama PT di atas dasarnya.
  static const double pitaTinggi = 120;
  static const double perusahaanDariDasar = 44;

  /// Motif penggaris: dua salinan di latar (langit 35 % dan 25 %).
  static const double motifBawahLebar = 420;
  static const double motifBawahTinggi = 170;
  static const double motifBawahKiri = -60;
  static const double motifBawahDariDasar = 40;
  static const double motifBawahOpasitas = 0.35;
  static const double motifKananLebar = 300;
  static const double motifKananTinggi = 120;
  static const double motifKananKanan = -90;
  static const double motifKananDariDasar = 130;
  static const double motifKananOpasitas = 0.25;

  /// Sapuan cahaya: bilah 26 lebar, miring 20 derajat, menyapu -110 sampai 110.
  static const double sapuLebar = 26;
  static const double sapuLebihan = 20;
  static const double sapuMiring = 20 * math.pi / 180;
  static const double sapuJarak = 110;
  static const double sapuAlfa = 0.75;
}

/// Huruf splash: nama produk 28/34 · 600 dan kalimat 15/20 (artboard E1,
/// diselaraskan ke REVISI 16 Nov 2026: tanpa berat 800 dan spasi negatif).
abstract final class _HurufSplash {
  static const TextStyle nama = TextStyle(
    fontFamily: SidikTheme.keluarga,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle tagline = TextStyle(
    fontFamily: SidikTheme.keluarga,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
  );
}

/// Splash Biru Awan (artboard E1).
///
/// Bentuknya **timeline sekali jalan**, bukan animasi yang berputar terus:
/// cincin primer ditarik mengelilingi plat logo, plat muncul, cahaya menyapu
/// logo, lalu nama produk, kalimat akreditasi, dan nama PT masuk berurutan
/// ([JadwalSplash]) dan layar diam. Tiga alasan tanpa pengulangan:
///
/// - Splash yang bergerak selamanya membuat `pumpAndSettle` tidak pernah balik.
///   Layar ini muncul di jalur masuk hampir semua tes (kejadian 18 Agt 2026:
///   satu `repeat()` membuat puluhan tes timeout serentak).
/// - Yang membuat gerak terbaca bagus adalah urutan dan waktunya, bukan
///   pengulangannya.
/// - Semua digambar kanvas dan transform: nol video, nol GIF, nol tambahan
///   ukuran aplikasi.
///
/// "Kurangi gerak" (`MediaQuery.disableAnimations`) langsung menampilkan
/// keadaan akhir tanpa pengendali animasi yang berjalan.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gerak;

  @override
  void initState() {
    super.initState();
    _gerak = AnimationController(vsync: this, duration: JadwalSplash.durasi);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _gerak.value = 1;
    } else if (!_gerak.isAnimating && _gerak.value == 0) {
      _gerak.forward();
    }
  }

  @override
  void dispose() {
    _gerak.dispose();
    super.dispose();
  }

  /// Nilai 0..1 satu tahap pada waktu [t] (0..1 dari seluruh timeline).
  static double _nilai(double t, int mulai, int lama, Curve kurva) =>
      JadwalSplash.tahap(mulai, lama, kurva).transform(t);

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaBiruAwan.of(context);
    final warna = WarnaMasuk.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: m.meja,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Latar: dua salinan motif penggaris (langit), lalu pita putih di
          // atasnya (urutan sama dengan artboard).
          Positioned(
            left: _UkuranSplash.motifBawahKiri,
            bottom: _UkuranSplash.motifBawahDariDasar,
            child: MotifSkala(
              warna: warna.langit,
              lebar: _UkuranSplash.motifBawahLebar,
              tinggi: _UkuranSplash.motifBawahTinggi,
              opasitas: _UkuranSplash.motifBawahOpasitas,
            ),
          ),
          Positioned(
            right: _UkuranSplash.motifKananKanan,
            bottom: _UkuranSplash.motifKananDariDasar,
            child: MotifSkala(
              warna: warna.langit,
              lebar: _UkuranSplash.motifKananLebar,
              tinggi: _UkuranSplash.motifKananTinggi,
              opasitas: _UkuranSplash.motifKananOpasitas,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _UkuranSplash.pitaTinggi,
            child: ColoredBox(color: m.kertas),
          ),
          AnimatedBuilder(
            animation: _gerak,
            builder: (context, _) {
              final t = _gerak.value;
              final cincin = _nilai(
                t,
                JadwalSplash.cincinMulai,
                JadwalSplash.cincinDurasi,
                AppMotion.masuk,
              );
              final plat = _nilai(
                t,
                JadwalSplash.platMulai,
                JadwalSplash.platDurasi,
                AppMotion.masuk,
              );
              final sapu = _nilai(
                t,
                JadwalSplash.sapuMulai,
                JadwalSplash.sapuDurasi,
                Curves.easeOut,
              );
              final nama = _nilai(
                t,
                JadwalSplash.namaMulai,
                JadwalSplash.namaDurasi,
                AppMotion.masuk,
              );
              final tagline = _nilai(
                t,
                JadwalSplash.taglineMulai,
                JadwalSplash.taglineDurasi,
                AppMotion.masuk,
              );
              final perusahaan = _nilai(
                t,
                JadwalSplash.perusahaanMulai,
                JadwalSplash.perusahaanDurasi,
                AppMotion.masuk,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: const Alignment(0, _UkuranSplash.letakVertikal),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CincinLogo(
                          cincin: cincin,
                          plat: plat,
                          sapu: sapu,
                          warnaTrek: w.isi(IsiBiruAwan.kabut),
                          warnaBusur: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: _UkuranSplash.jarakCincinNama),
                        _Naik(
                          kunci: const Key('splash-nama'),
                          maju: nama,
                          child: Semantics(
                            header: true,
                            child: Text(
                              namaMerekSidikLab,
                              textAlign: TextAlign.center,
                              style: _HurufSplash.nama.copyWith(color: m.tinta),
                            ),
                          ),
                        ),
                        const SizedBox(height: _UkuranSplash.jarakNamaTagline),
                        _Naik(
                          kunci: const Key('splash-tagline'),
                          maju: tagline,
                          child: Text(
                            l10n.splashTagline,
                            textAlign: TextAlign.center,
                            style: _HurufSplash.tagline.copyWith(
                              color: m.tinta2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: _UkuranSplash.perusahaanDariDasar,
                    child: _Naik(
                      kunci: const Key('splash-perusahaan'),
                      maju: perusahaan,
                      child: Text(
                        LabProfile.nama,
                        textAlign: TextAlign.center,
                        style: HurufBiruAwan.keteranganKecil.copyWith(
                          color: m.tinta2,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Muncul sambil naik 12 dp (`naik` pada artboard): [maju] 0..1.
class _Naik extends StatelessWidget {
  const _Naik({required this.kunci, required this.maju, required this.child});

  final Key kunci;
  final double maju;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      key: kunci,
      opacity: maju.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, GerakBersama.geserMasuk * (1 - maju)),
        child: child,
      ),
    );
  }
}

/// Cincin primer yang ditarik mengelilingi plat logo putih, lalu cahaya yang
/// menyapu logo satu kali.
class _CincinLogo extends StatelessWidget {
  const _CincinLogo({
    required this.cincin,
    required this.plat,
    required this.sapu,
    required this.warnaTrek,
    required this.warnaBusur,
  });

  final double cincin;
  final double plat;
  final double sapu;
  final Color warnaTrek;
  final Color warnaBusur;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final warna = WarnaMasuk.of(context);

    return SizedBox.square(
      dimension: _UkuranSplash.cincin,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: CustomPaint(
              key: const Key('splash-cincin'),
              size: const Size.square(_UkuranSplash.cincin),
              painter: PelukisCincinSplash(
                progres: cincin,
                warnaTrek: warnaTrek,
                warnaBusur: warnaBusur,
              ),
            ),
          ),
          Opacity(
            key: const Key('splash-plat'),
            opacity: plat,
            child: Transform.scale(
              scale:
                  _UkuranSplash.platSkalaAwal +
                  (1 - _UkuranSplash.platSkalaAwal) * plat,
              child: DecoratedBox(
                // Garis 1 dp, bukan bayangan (REVISI 16 Nov 2026).
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: warna.plat,
                  border: Border.all(color: m.kertasTepi),
                ),
                child: SizedBox.square(
                  dimension: _UkuranSplash.plat,
                  child: ClipOval(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          LabProfile.logoAsset,
                          width: _UkuranSplash.logoLebar,
                          height: _UkuranSplash.logoTinggi,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                        // Sapuan cahaya: sekali lewat dari kiri ke kanan. Di
                        // luar plat (sebelum mulai dan sesudah selesai) tidak
                        // digambar sama sekali.
                        if (sapu > 0 && sapu < 1)
                          ExcludeSemantics(
                            child: IgnorePointer(
                              child: Transform.translate(
                                offset: Offset(
                                  _UkuranSplash.sapuJarak * (2 * sapu - 1),
                                  0,
                                ),
                                child: Transform.rotate(
                                  angle: _UkuranSplash.sapuMiring,
                                  child: SizedBox(
                                    width: _UkuranSplash.sapuLebar,
                                    height:
                                        _UkuranSplash.plat +
                                        2 * _UkuranSplash.sapuLebihan,
                                    child: ColoredBox(
                                      key: const Key('splash-sapuan'),
                                      color: m.kertas.withValues(
                                        alpha: _UkuranSplash.sapuAlfa,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cincin: trek penuh (kabut) dan busur primer yang ditarik searah jarum jam
/// dari atas sebesar [progres] (0..1). Tidak ada yang berputar terus: begitu
/// [progres] = 1 gambarnya diam.
class PelukisCincinSplash extends CustomPainter {
  const PelukisCincinSplash({
    required this.progres,
    required this.warnaTrek,
    required this.warnaBusur,
  });

  final double progres;
  final Color warnaTrek;
  final Color warnaBusur;

  @override
  void paint(Canvas canvas, Size size) {
    final pusat = size.center(Offset.zero);
    final garis = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _UkuranSplash.cincinTebal
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      pusat,
      _UkuranSplash.cincinRadius,
      garis..color = warnaTrek,
    );
    if (progres <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: pusat, radius: _UkuranSplash.cincinRadius),
      -math.pi / 2,
      2 * math.pi * progres.clamp(0.0, 1.0),
      false,
      garis..color = warnaBusur,
    );
  }

  @override
  bool shouldRepaint(covariant PelukisCincinSplash lama) =>
      lama.progres != progres ||
      lama.warnaTrek != warnaTrek ||
      lama.warnaBusur != warnaBusur;
}
