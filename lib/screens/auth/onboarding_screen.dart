import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/scene3d/alat_3d.dart';
import '../../widgets/scene3d/mesh3d.dart';
import '../../widgets/scene3d/panggung3d.dart';
import '../../widgets/scene3d/renderer3d.dart';

/// Onboarding tiga layar buat akun yang baru pertama kali masuk di perangkat
/// ini.
///
/// Isinya bukan tur fitur: tiga layar itu **tiga langkah alur kerja
/// sebenarnya** — pilih alat, isi/foto lembar kerja, kirim biar sertifikatnya
/// terbit. Karyawan baru yang lewat sini udah tau bentuk pekerjaannya sebelum
/// pertama kali buka lembar beneran.
///
/// Ilustrasinya model 3D yang dirender langsung ([Panggung3D]), bukan gambar:
/// nol tambahan ukuran APK, tajam di semua kerapatan layar, dan objeknya ikut
/// muter waktu halaman digeser — jadi geserannya berasa punya isi, bukan cuma
/// ganti slide.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.user});

  final User user;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  double _posisi = 0;

  @override
  void initState() {
    super.initState();
    // Dipantau terus-menerus (bukan cuma `onPageChanged`) karena SEMUA gerak
    // di layar ini diikat ke posisi jari: gelombang latar, putaran objek 3D,
    // dan geser teks. Tanpa ini, animasinya cuma jalan sesudah halaman
    // kelepas — dan geserannya kerasa mati.
    _page.addListener(() {
      final p = _page.page;
      if (p != null && p != _posisi) setState(() => _posisi = p);
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _selesai() =>
      ref.read(onboardingProvider.notifier).selesai(widget.user.id);

  Future<void> _lanjut(int jumlah) async {
    if (_posisi >= jumlah - 1.05) return _selesai();
    await _page.nextPage(
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final adegan = <_Adegan>[
      _Adegan(
        judul: l10n.onbStep1Title,
        isi: l10n.onbStep1Body,
        mesh: Alat3D.anakTimbangan(),
        warna: AppColors.cobalt,
        warnaDua: AppColors.cobaltDeep,
        kamera: const Kamera3D(jarak: 4.4, pitch: 0.26),
      ),
      _Adegan(
        judul: l10n.onbStep2Title,
        isi: l10n.onbStep2Body,
        mesh: Alat3D.lembarKerja(),
        warna: AppColors.mintDeep,
        warnaDua: AppColors.mintInk,
        kamera: const Kamera3D(jarak: 5.4, pitch: 0.50),
        pusat: const Vek3(0, -0.6, 0),
      ),
      _Adegan(
        judul: l10n.onbStep3Title,
        isi: l10n.onbStep3Body,
        mesh: Alat3D.sertifikat(),
        warna: AppColors.crimson,
        warnaDua: AppColors.crimsonDeep,
        kamera: const Kamera3D(jarak: 4.8, pitch: 0.20),
      ),
    ];

    final terakhir = _posisi >= adegan.length - 1.05;

    return Scaffold(
      body: Stack(
        children: [
          // Gelombang latar. Warnanya dicampur antar-adegan sesuai posisi
          // geseran, jadi pergantian temanya mulus — bukan ganti warna
          // mendadak pas halaman kelepas.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _LatarGelombang(
                  posisi: _posisi,
                  adegan: adegan,
                  gelap: theme.brightness == Brightness.dark,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: [
                      const _Merek(),
                      const Spacer(),
                      TextButton(
                        onPressed: _selesai,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.ivory,
                        ),
                        child: Text(l10n.onbSkip),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _page,
                    itemCount: adegan.length,
                    itemBuilder: (context, i) {
                      final jarak = (_posisi - i).clamp(-1.0, 1.0);
                      return _AdeganView(adegan: adegan[i], jarak: jarak);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      _Titik(posisi: _posisi, jumlah: adegan.length),
                      const SizedBox(width: AppSpacing.md),
                      // `Expanded`, bukan tombol telanjang: tema app nyetel
                      // `minimumSize: Size.fromHeight(52)` buat SEMUA
                      // FilledButton, dan lebar minimum tak terhingga di dalam
                      // Row bikin layout meledak ("BoxConstraints forces an
                      // infinite width"). Dibatasi Expanded, tombolnya jadi
                      // selebar sisa baris — sekalian target sentuh yang lega.
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _lanjut(adegan.length),
                          icon: Icon(
                            terakhir
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(terakhir ? l10n.onbEnter : l10n.onbNext),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Adegan {
  const _Adegan({
    required this.judul,
    required this.isi,
    required this.mesh,
    required this.warna,
    required this.warnaDua,
    required this.kamera,
    this.pusat = const Vek3(0, -0.95, 0),
  });

  final String judul;
  final String isi;
  final Mesh3D mesh;
  final Color warna;
  final Color warnaDua;
  final Kamera3D kamera;
  final Vek3 pusat;
}

/// Satu halaman: objek 3D di atas, teks di bawah.
///
/// [jarak] = seberapa jauh halaman ini dari tengah layar (-1..1). Semua
/// gerakannya diturunkan dari angka itu — objek dan teks bergerak dengan
/// kecepatan beda (paralaks), yang bikin lapisan-lapisannya kebaca punya
/// kedalaman.
class _AdeganView extends StatelessWidget {
  const _AdeganView({required this.adegan, required this.jarak});

  final _Adegan adegan;
  final double jarak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dekat = 1 - jarak.abs();

    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Transform.translate(
            // Objek digeser BERLAWANAN arah jari dan lebih pelan dari
            // halamannya: itu inti paralaks.
            offset: Offset(jarak * 46, 0),
            child: Panggung3D(
              mesh: adegan.mesh,
              kamera: adegan.kamera,
              pusatObjek: adegan.pusat,
              cahaya: Cahaya3D(warnaTepi: adegan.warna, kuatTepi: 0.5),
              // Objek ikut muter sesuai posisi geseran, bukan animasi sendiri.
              progress: AlwaysStoppedAnimation<double>(dekat.clamp(0.0, 1.0)),
              yawAwal: -1.1,
              yawAkhir: 0.45,
              bayangan: 1.7,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Opacity(
            opacity: dekat.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(jarak * -70, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      width: 44,
                      decoration: BoxDecoration(
                        color: adegan.warna,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      adegan.judul,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      adegan.isi,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Merek di pojok kiri-atas. Berdiri di atas panggung warna adegan — yang
/// warnanya ganti tiap halaman — jadi warnanya dikunci ivory, bukan ikut
/// `onSurface`. Kalau ikut tema, di halaman terang huruf gelapnya ketelen
/// bidang cobalt/crimson di belakangnya.
class _Merek extends StatelessWidget {
  const _Merek();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: AppColors.ivory,
          ),
          child: const Icon(
            Icons.straighten,
            color: AppColors.ink,
            size: 17,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'SIDIK',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.ivory,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Titik extends StatelessWidget {
  const _Titik({required this.posisi, required this.jumlah});

  final double posisi;
  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final warna = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(jumlah, (i) {
        // Lebarnya ikut posisi pecahan, bukan indeks bulat — titiknya
        // "meleleh" pelan ke titik sebelah selama jari masih nempel.
        final dekat = (1 - (posisi - i).abs()).clamp(0.0, 1.0);
        return Container(
          height: 6,
          width: 6 + 18 * dekat,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            color: Color.lerp(warna.outlineVariant, warna.primary, dekat),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

/// Panggung warna di paruh atas layar: dua pita lengkung pekat yang jalan
/// lebih pelan dari halamannya, dengan warna adegan yang lagi kebuka.
class _LatarGelombang extends CustomPainter {
  const _LatarGelombang({
    required this.posisi,
    required this.adegan,
    required this.gelap,
  });

  final double posisi;
  final List<_Adegan> adegan;
  final bool gelap;

  /// Warna adegan terdekat, bukan campuran dua adegan.
  ///
  /// Dulu di sini `Color.lerp` antar adegan: di tengah geseran, cobalt dan
  /// crimson ketemu jadi warna ungu yang nggak ada di palet. Sekarang warnanya
  /// loncat di titik tengah — yang gerak tetap gelombang dan paralaksnya, jadi
  /// perpindahannya tetap kebaca halus tanpa perlu warna antara.
  Color _adeganTerdekat(Color Function(_Adegan) ambil) {
    final i = posisi.clamp(0.0, adegan.length - 1.0);
    return ambil(adegan[i.round().clamp(0, adegan.length - 1)]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final warna = _adeganTerdekat((a) => a.warna);
    final warnaDua = _adeganTerdekat((a) => a.warnaDua);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = gelap ? AppColors.inkDeep : AppColors.ivory,
    );

    final geser = -posisi * size.width * 0.18;
    // Panggung warnanya berhenti di 0,52 tinggi layar — di bawah situ judul
    // dan isi teks berdiri di atas ivory polos. Kalau pitanya lebih turun,
    // huruf gelap nabrak bidang warna dan kontrasnya jatuh.
    final tinggi = size.height * 0.52;

    // Pita digambar **pekat**, tanpa alpha. Dulu dua pita ini ditumpuk pakai
    // alpha di atas ivory: cobalt jadi lavender pucat, crimson jadi merah
    // muda kusam — warnanya bukan warna palet lagi, dan sekelas layar penuh
    // warna kusam itu yang bikin onboarding kebaca murah.
    void pita(double y, double amplitudo, Color c) {
      final path = Path()..moveTo(-size.width, 0);
      path.lineTo(-size.width, y);
      for (var x = -size.width; x <= size.width * 2; x += size.width / 12) {
        path.lineTo(
          x,
          y + math.sin((x + geser) / size.width * math.pi * 2.1) * amplitudo,
        );
      }
      path.lineTo(size.width * 2, 0);
      path.close();
      canvas.drawPath(path, Paint()..color = c);
    }

    // Dua pita = dua tingkat dari rona yang sama, bukan dua warna beda. Yang
    // lebih tua di belakang bikin tepi gelombangnya kebaca punya tebal.
    pita(tinggi * 1.06, size.height * 0.032, warnaDua);
    pita(tinggi * 0.96, size.height * 0.026, warna);

    // Bulatan kecil yang ikut geser lebih cepat dari gelombang — lapisan
    // paling depan di paralaks. Ivory pekat, jadi kebaca sebagai lubang di
    // bidang warna, bukan sebagai warna ketiga.
    final titik = Paint()..color = AppColors.ivory;
    canvas.drawCircle(
      Offset(size.width * 0.82 + geser * 1.6, size.height * 0.16),
      7,
      titik,
    );
    canvas.drawCircle(
      Offset(size.width * 0.16 + geser * 2.1, size.height * 0.30),
      4,
      titik,
    );
  }

  @override
  bool shouldRepaint(covariant _LatarGelombang old) =>
      old.posisi != posisi || old.gelap != gelap;
}
