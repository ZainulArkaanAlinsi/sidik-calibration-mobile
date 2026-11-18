import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'dari_foto_lembar.dart';

/// Banner di atas lembar kerja yang dibuka dari foto beranda: menyebut jenis
/// yang dikenali dan memberi "Ganti jenis" (satu ketukan ke pilihan lain).
///
/// Wajib ada selama identifikasi belum dikalibrasi dengan foto nyata
/// (`keputusan_pindai_lembar.dart`): lembar yang terbuka otomatis tidak
/// boleh terasa final. Hanya token tema; tidak ada warna sendiri.
class BannerJenisDariFoto extends StatelessWidget {
  const BannerJenisDariFoto({
    super.key,
    required this.info,
    required this.onGanti,
    this.perluAlat = false,
  });

  final DariFotoLembar info;

  /// `null` = tombol mati (foto sedang dibaca).
  final VoidCallback? onGanti;

  /// Alat belum ditentukan: banner menambahkan satu baris petunjuk.
  final bool perluAlat;

  static const kunciBanner = ValueKey('banner-jenis-dari-foto');
  static const kunciGanti = ValueKey('banner-ganti-jenis');
  static const kunciPetunjukAlat = ValueKey('banner-petunjuk-alat');

  /// Lebar minimal (dp) dan skala huruf maksimal yang masih memuat teks dan
  /// tombol dalam SATU baris. Di bawahnya tombol turun ke bawah teks: baris
  /// tunggal di HP sempit atau huruf besar menyisakan lebar teks nyaris nol
  /// (teks pecah per huruf dan lembar meluap).
  static const lebarSebaris = 520.0;
  static const skalaSebaris = 1.3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final warna = tema.colorScheme;
    final skala = MediaQuery.textScalerOf(context).scale(14) / 14;

    final teks = Text(
      info.otomatis
          ? l10n.pindaiBannerOtomatis(info.jenis)
          : l10n.pindaiBannerDipilih(info.jenis),
      style: tema.textTheme.bodyMedium?.copyWith(
        color: warna.onSecondaryContainer,
      ),
    );
    final petunjuk = perluAlat
        ? Text(
            l10n.pindaiBannerPilihAlat,
            key: kunciPetunjukAlat,
            style: tema.textTheme.bodySmall?.copyWith(
              color: warna.onSecondaryContainer,
            ),
          )
        : null;
    final ganti = TextButton(
      key: kunciGanti,
      onPressed: onGanti,
      child: Text(l10n.pindaiGantiJenis),
    );
    final ikon = Icon(
      Icons.document_scanner_outlined,
      size: 20,
      color: warna.onSecondaryContainer,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Material(
        key: kunciBanner,
        color: warna.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: LayoutBuilder(
          builder: (context, c) {
            final sebaris = c.maxWidth >= lebarSebaris && skala <= skalaSebaris;

            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: sebaris
                  ? Row(
                      children: [
                        ikon,
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [teks, ?petunjuk],
                          ),
                        ),
                        ganti,
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: ikon,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [teks, ?petunjuk],
                              ),
                            ),
                          ],
                        ),
                        Align(alignment: Alignment.centerRight, child: ganti),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}
