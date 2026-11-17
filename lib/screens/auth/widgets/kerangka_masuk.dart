import 'package:flutter/material.dart';

import '../../../core/config/lab_profile.dart';
import '../../../core/motion/gerak_bersama.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/bentuk_lab.dart';
import '../../../core/theme/palet_lab.dart';
import '../../../core/theme/sidik_material.dart';
import '../../../core/theme/sidik_theme.dart';
import '../../../core/theme/token_komponen_biru_awan.dart';
import '../../../core/theme/warna_biru_awan.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/biru_awan/kartu_sidik24.dart';
import '../../../widgets/biru_awan/ubin_ikon.dart';
import 'motif_skala.dart';

/// Nama produk di hero masuk dan splash (artboard E0 dan E1). Nama merek tidak
/// diterjemahkan.
const String namaMerekSidikLab = 'SIDIK Lab';

/// Kunci hero dan kartu (dipakai tes untuk mengukur tata letak).
const Key kunciHeroMasuk = ValueKey<String>('masuk-hero');
const Key kunciKartuMasuk = ValueKey<String>('masuk-kartu');

/// Ukuran artboard E0 Masuk (`docs/desain-ulang/referensi-html/Login.dc.html`)
/// dan E1 Splash yang dipakai bersama, DIPERKECIL oleh REVISI 16 Nov 2026
/// (kurangi banner tinggi, logo besar, sudut ekstrem, bayangan berat). Nama
/// berarti, bukan angka telanjang di layar.
abstract final class UkuranMasuk {
  /// Hero langit setinggi atas (di bawah bilah status): 190 pada layar 844,
  /// yaitu [heroNisbi] dari tinggi layar, tidak melebihi [heroTinggi] dan tidak
  /// kurang dari [heroMin] (dulu 330 / 210). Pada layar pendek (jendela 600, HP
  /// lipat, mendatar) tombol Masuk tetap terlihat tanpa menggulir.
  static const double heroTinggi = 190;
  static const double heroNisbi = 190 / 844;
  static const double heroMin = 150;

  /// Plat logo bulat putih di hero (dulu 104).
  static const double platLogo = 72;
  static const double logoLebar = 36;
  static const double logoTinggi = 50;

  /// Kartu putih menumpang hero sedalam ini (dulu 36).
  static const double kartuTumpang = 24;
  static const double kartuRadius = BentukBiruAwan.kartu;
  static const double kartuVertikal = 20;
  static const double kartuHorizontal = 20;

  /// Lebar isi di layar lebar (tablet, jendela desktop).
  static const double lebarIsi = 420;

  /// Motif skala di hero: 380 x 150, geser keluar kiri bawah, putih 55 %.
  static const double motifLebar = 380;
  static const double motifTinggi = 150;
  static const double motifGeserKiri = -80;
  static const double motifGeserBawah = -40;
  static const double motifOpasitas = 0.55;
}

/// Huruf khusus artboard E0 yang belum ada di [HurufBiruAwan]: nama produk
/// hero 22/28 dan judul kartu 24/30, keduanya 600 tanpa spasi huruf negatif
/// (REVISI 16 Nov 2026; dulu 28 dan 24 berat 800).
abstract final class HurufMasuk {
  static const TextStyle namaHero = TextStyle(
    fontFamily: SidikTheme.keluarga,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle judulKartu = TextStyle(
    fontFamily: SidikTheme.keluarga,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w600,
  );
}

/// Warna hero langit. `langit` belum punya penyangga di `SidikMaterial` atau
/// `WarnaBiruAwan` (hanya hero memakainya), jadi dibaca dari [PaletLab] di sini:
/// terang `langit` (navy di atasnya 6,48:1; putih DILARANG, 2,26:1), gelap
/// `langitGelap` (tinta terang di atasnya 5,3:1). Plat logo selalu putih
/// (logonya digambar untuk latar putih); motif hero putih. Hero kini panel
/// pendek (190 dp), bukan blok setinggi sepertiga layar.
@immutable
class WarnaMasuk {
  const WarnaMasuk._({
    required this.langit,
    required this.plat,
    required this.motifHero,
  });

  final Color langit;
  final Color plat;
  final Color motifHero;

  factory WarnaMasuk.dari(SidikMaterial m) => WarnaMasuk._(
    langit: m.terang ? PaletLab.langit : PaletLab.langitGelap,
    plat: PaletLab.kertas,
    motifHero: PaletLab.kertas,
  );

  static WarnaMasuk of(BuildContext context) =>
      WarnaMasuk.dari(SidikMaterial.of(context));
}

/// Plat logo bulat putih (logo PT SIDIK), tanpa bayangan (REVISI 16 Nov 2026);
/// dipakai hero masuk (72) dan splash. Logo hiasan: namanya sudah ada di judul.
class PlatLogo extends StatelessWidget {
  const PlatLogo({
    super.key,
    required this.diameter,
    required this.logoLebar,
    required this.logoTinggi,
  });

  final double diameter;
  final double logoLebar;
  final double logoTinggi;

  @override
  Widget build(BuildContext context) {
    final w = WarnaMasuk.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: w.plat),
      child: SizedBox.square(
        dimension: diameter,
        child: Center(
          child: Image.asset(
            LabProfile.logoAsset,
            width: logoLebar,
            height: logoTinggi,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// Kerangka layar masuk dan lupa sandi (artboard E0): hero langit setinggi atas
/// berisi motif skala, plat logo, dan nama produk; kartu putih menumpang hero
/// 36 dp; akreditasi di dasar layar.
///
/// [isiKartu] disusun berjarak 16. [bawahKartu] (panel bantuan dev, tautan)
/// berada di bawah kartu. [kiriAtas] (tombol kembali) menumpang hero di kiri
/// atas. Layar bisa digulir (papan ketik, huruf besar); akreditasi menempel di
/// dasar hanya bila ada ruang. Kerangka tidak punya logika: semua keadaan datang
/// dari layar pemakainya.
class KerangkaMasuk extends StatelessWidget {
  const KerangkaMasuk({
    super.key,
    required this.isiKartu,
    this.bawahKartu,
    this.kiriAtas,
  });

  final List<Widget> isiKartu;
  final Widget? bawahKartu;
  final Widget? kiriAtas;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final l10n = AppLocalizations.of(context);
    final inset = MediaQuery.paddingOf(context).top;
    final heroIsi = (MediaQuery.sizeOf(context).height * UkuranMasuk.heroNisbi)
        .clamp(UkuranMasuk.heroMin, UkuranMasuk.heroTinggi)
        .toDouble();
    final heroTotal = heroIsi + inset;

    return Scaffold(
      backgroundColor: m.meja,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: heroTotal,
                    child: _HeroLangit(
                      key: kunciHeroMasuk,
                      inset: inset,
                      kiriAtas: kiriAtas,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: heroTotal - UkuranMasuk.kartuTumpang),
                      _LebarIsi(
                        child: MasukBerurutan(
                          indeks: 1,
                          child: _KartuMasuk(
                            key: kunciKartuMasuk,
                            children: isiKartu,
                          ),
                        ),
                      ),
                      if (bawahKartu != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: _LebarIsi(child: bawahKartu!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    l10n.masukAkreditasi(LabProfile.nomorAkreditasi),
                    textAlign: TextAlign.center,
                    style: HurufBiruAwan.catatan.copyWith(color: m.tinta2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Isi di tengah dengan lebar maksimum [UkuranMasuk.lebarIsi] dan bantalan
/// samping 16.
class _LebarIsi extends StatelessWidget {
  const _LebarIsi({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: UkuranMasuk.lebarIsi),
          child: child,
        ),
      ),
    );
  }
}

class _HeroLangit extends StatelessWidget {
  const _HeroLangit({super.key, required this.inset, required this.kiriAtas});

  final double inset;
  final Widget? kiriAtas;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final w = WarnaMasuk.of(context);

    return ClipRect(
      child: ColoredBox(
        color: w.langit,
        child: Stack(
          children: [
            Positioned(
              left: UkuranMasuk.motifGeserKiri,
              bottom: UkuranMasuk.motifGeserBawah,
              child: MotifSkala(
                warna: w.motifHero,
                lebar: UkuranMasuk.motifLebar,
                tinggi: UkuranMasuk.motifTinggi,
                opasitas: UkuranMasuk.motifOpasitas,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: inset),
              child: Center(
                child: MasukBerurutan(
                  indeks: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PlatLogo(
                        diameter: UkuranMasuk.platLogo,
                        logoLebar: UkuranMasuk.logoLebar,
                        logoTinggi: UkuranMasuk.logoTinggi,
                      ),
                      const SizedBox(height: JarakBiruAwan.blok),
                      Semantics(
                        header: true,
                        child: Text(
                          namaMerekSidikLab,
                          textAlign: TextAlign.center,
                          style: HurufMasuk.namaHero.copyWith(color: m.tinta),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (kiriAtas != null)
              Positioned(
                left: AppSpacing.md,
                top: inset + AppSpacing.sm,
                child: kiriAtas!,
              ),
          ],
        ),
      ),
    );
  }
}

class _KartuMasuk extends StatelessWidget {
  const _KartuMasuk({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);

    // Garis 1 dp, bukan bayangan (REVISI 16 Nov 2026).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: m.kertas,
        borderRadius: BorderRadius.circular(UkuranMasuk.kartuRadius),
        border: Border.all(color: m.kertasTepi),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: UkuranMasuk.kartuVertikal,
          horizontal: UkuranMasuk.kartuHorizontal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: children,
        ),
      ),
    );
  }
}

/// Pesan galat di dalam kartu masuk: kartu koral tipis + ubin ikon koral 48 +
/// kalimat apa adanya (dari server atau dari [AuthException]). Dibaca otomatis
/// oleh pembaca layar saat muncul (`liveRegion`). Tidak memvonis apa pun: hanya
/// memajang pesan yang diberikan layar.
class PesanGalatMasuk extends StatelessWidget {
  const PesanGalatMasuk({super.key, required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: KartuSidik24(
        latar: LatarKartu.galat,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UbinIkon.baris(
              ikon: Icons.error_outline,
              warna: IsiBiruAwan.koral,
            ),
            const SizedBox(width: JarakBiruAwan.blok),
            Expanded(
              child: Text(
                pesan,
                style: HurufBiruAwan.keterangan.copyWith(color: m.tinta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
