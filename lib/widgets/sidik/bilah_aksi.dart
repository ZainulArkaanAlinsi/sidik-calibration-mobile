import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_ukuran.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/ukuran_komponen.dart';
import 'tombol_utama.dart';

/// Satu aksi di [BilahAksi]: label, ikon opsional, dan tindakan (`null` = mati).
@immutable
class AksiBilah {
  const AksiBilah({required this.label, required this.onPressed, this.ikon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? ikon;
}

/// Bilah aksi di bawah layar: SATU aksi utama (56 dp, [TombolUtama]) dan nol
/// atau lebih aksi sekunder (48 dp, garis tegas).
///
/// Susunan mengikuti ruang ([berdampingan]):
///
/// - berdampingan (tinggi isi 56 dp) bila ada tepat satu aksi sekunder, lebar
///   bilah >= 360 dp, dan skala huruf <= 1,15: sekunder di kiri, utama di kanan;
/// - bertumpuk (56 + 8 + 48 dp) selain itu: utama di atas, sekunder di bawah.
///
/// Isi dibatasi 560 dp dan dipusatkan, jadi di tablet bilah tidak membentang
/// ±1.250 dp. Permukaan kertas dengan garis halus di atas, tanpa bayangan.
///
/// [alasanMati] (saat aksi utama mati) tampil di atas kedua tombol. [sibuk]
/// memutar aksi utama dan mematikan semua aksi supaya tidak terkirim dua kali.
class BilahAksi extends StatelessWidget {
  const BilahAksi({
    super.key,
    required this.utama,
    this.sekunder = const [],
    this.sibuk = false,
    this.alasanMati,
  });

  final AksiBilah utama;
  final List<AksiBilah> sekunder;
  final bool sibuk;

  /// Kalimat pendek di atas bilah saat aksi utama mati.
  final String? alasanMati;

  /// Apakah susunan berdampingan dipakai pada lebar [lebar] (dp) dan skala
  /// huruf [skala] dengan [jumlahSekunder] aksi sekunder.
  static bool berdampingan({
    required double lebar,
    required double skala,
    required int jumlahSekunder,
  }) =>
      jumlahSekunder == 1 &&
      lebar >= AmbangLab.lebarSempit &&
      skala <= AmbangLab.hurufBesar;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    final skala = MediaQuery.textScalerOf(context).scale(10) / 10;

    Widget tombolSekunder(AksiBilah a) {
      final aksi = sibuk ? null : a.onPressed;
      final teks = Text(a.label, textAlign: TextAlign.center);
      // Label tombol mati tetap terbaca (lihat TombolUtama).
      final gaya = OutlinedButton.styleFrom(
        disabledForegroundColor: s.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      );
      return a.ikon == null
          ? OutlinedButton(onPressed: aksi, style: gaya, child: teks)
          : OutlinedButton.icon(
              onPressed: aksi,
              style: gaya,
              icon: Icon(a.ikon),
              label: teks,
            );
    }

    final tombolUtama = TombolUtama(
      label: utama.label,
      ikon: utama.ikon,
      onPressed: utama.onPressed,
      sibuk: sibuk,
    );

    final tampilAlasan =
        alasanMati != null && utama.onPressed == null && !sibuk;

    // Ambang 360 dp dibaca dari lebar bilah ini sendiri (sama dengan lebar
    // layar saat bilah dipasang di dasar layar).
    return LayoutBuilder(
      builder: (context, batas) {
        final sejajar = berdampingan(
          lebar: batas.maxWidth,
          skala: skala,
          jumlahSekunder: sekunder.length,
        );
        return Material(
          color: m.kertas,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: m.kertasTepi, width: AppUkuran.garis),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AmbangLab.lebarBilah,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (tampilAlasan)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(alasanMati!, style: t.bodySmall),
                          ),
                        if (sejajar)
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: tombolSekunder(sekunder.single),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(flex: 3, child: tombolUtama),
                            ],
                          )
                        else ...[
                          tombolUtama,
                          for (final a in sekunder) ...[
                            const SizedBox(height: AppSpacing.sm),
                            tombolSekunder(a),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
