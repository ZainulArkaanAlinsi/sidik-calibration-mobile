import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/skeleton.dart';
import 'pesan_galat_sa.dart';

/// Potongan bersama daftar paginasi kursor (alat pelanggan, riwayat
/// sertifikat): kerangka memuat, pesan galat di tempat, dan kaki daftar.

/// Kalimat galat daftar: pesan yang sudah manusiawi dipakai apa adanya;
/// galat tak dikenal diganti kalimat [cadangan] yang menyebut daftarnya.
String pesanDaftarKursor(AppLocalizations l10n, Object galat, String cadangan) {
  final pesan = pesanGalatSa(l10n, galat);
  return pesan == l10n.saGalatUmum ? cadangan : pesan;
}

class KerangkaKartuKursor extends StatelessWidget {
  const KerangkaKartuKursor({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 16, width: 180),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 130),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 12, width: 100),
          ],
        ),
      ),
    );
  }
}

/// Galat di tempat (bukan layar penuh): kalimat + Coba lagi.
class PesanInlineKursor extends StatelessWidget {
  const PesanInlineKursor({
    super.key,
    required this.teks,
    required this.saatCoba,
  });

  final String teks;
  final VoidCallback saatCoba;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            teks,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.error,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.saCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          ringkas: true,
          onPressed: saatCoba,
        ),
      ],
    );
  }
}

/// Kaki daftar kursor: penunjuk memuat, galat halaman berikutnya + Coba
/// lagi, atau tombol Muat lebih banyak. Daftar habis → tidak ada apa-apa.
class KakiDaftarKursor extends StatelessWidget {
  const KakiDaftarKursor({
    super.key,
    required this.memuatLagi,
    required this.galat,
    required this.adaLagi,
    required this.saatMuat,
  });

  final bool memuatLagi;
  final String? galat;
  final bool adaLagi;
  final VoidCallback saatMuat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (galat != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: PesanInlineKursor(
          key: const Key('kaki-galat'),
          teks: galat!,
          saatCoba: saatMuat,
        ),
      );
    }
    if (!adaLagi) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: memuatLagi
            ? Semantics(
                liveRegion: true,
                label: l10n.saMemuat,
                child: const SizedBox(
                  key: Key('kaki-memuat'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : AppButton(
                key: const Key('kaki-muat-lagi'),
                label: l10n.saMuatLagi,
                icon: Icons.expand_more,
                variant: AppButtonVariant.secondary,
                ringkas: true,
                onPressed: saatMuat,
              ),
      ),
    );
  }
}
