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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final warna = tema.colorScheme;

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
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.document_scanner_outlined,
                size: 20,
                color: warna.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.otomatis
                            ? l10n.pindaiBannerOtomatis(info.jenis)
                            : l10n.pindaiBannerDipilih(info.jenis),
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: warna.onSecondaryContainer,
                        ),
                      ),
                      if (perluAlat)
                        Text(
                          l10n.pindaiBannerPilihAlat,
                          key: kunciPetunjukAlat,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: warna.onSecondaryContainer,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              TextButton(
                key: kunciGanti,
                onPressed: onGanti,
                child: Text(l10n.pindaiGantiJenis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
