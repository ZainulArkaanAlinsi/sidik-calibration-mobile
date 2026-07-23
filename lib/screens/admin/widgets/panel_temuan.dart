import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/validasi.dart';

/// Hasil tombol "Periksa" (spesifikasi poin 11).
///
/// Tiga tingkat dibedain warnanya karena perilakunya beda, bukan cuma
/// tampilannya:
/// - **merah** (`error`) — approve diblokir, nggak bisa dilewati
/// - **kuning** (`peringatan`) — approve ditolak sekali, admin harus lanjut
///   secara sadar
/// - **abu** (`info`) — cuma pemberitahuan kolom kosong, nggak nahan apa-apa
class PanelTemuan extends StatelessWidget {
  const PanelTemuan({super.key, required this.validasi});

  final HasilValidasi validasi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (validasi.temuan.isEmpty) {
      return Card(
        color: AppColors.success.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 20,
                color: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.perhitTemuanBersih,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.perhitTemuanJudul,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final t in TingkatTemuan.values)
                  if (validasi.jumlah(t) > 0)
                    _Lencana(tingkat: t, jumlah: validasi.jumlah(t)),
              ],
            ),
            const Divider(height: AppSpacing.lg),

            // Diurut dari yang paling berat — yang nahan penerbitan harus
            // kebaca duluan, bukan ketimbun di bawah daftar info.
            for (final tingkat in TingkatTemuan.values)
              for (final temuan in validasi.pada(tingkat))
                _BarisTemuan(temuan: temuan),
          ],
        ),
      ),
    );
  }
}

(Color, IconData, String) _gaya(TingkatTemuan t, AppLocalizations l10n) =>
    switch (t) {
      TingkatTemuan.error => (
        AppColors.danger,
        Icons.error_outline,
        l10n.perhitTingkatError,
      ),
      TingkatTemuan.peringatan => (
        AppColors.warning,
        Icons.warning_amber_outlined,
        l10n.perhitTingkatPeringatan,
      ),
      TingkatTemuan.info => (
        AppColors.info,
        Icons.info_outline,
        l10n.perhitTingkatInfo,
      ),
    };

class _Lencana extends StatelessWidget {
  const _Lencana({required this.tingkat, required this.jumlah});

  final TingkatTemuan tingkat;
  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (warna, ikon, label) = _gaya(tingkat, l10n);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: warna),
          const SizedBox(width: 4),
          Text(
            '$jumlah $label',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: warna),
          ),
        ],
      ),
    );
  }
}

class _BarisTemuan extends StatelessWidget {
  const _BarisTemuan({required this.temuan});

  final Temuan temuan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final (warna, ikon, _) = _gaya(temuan.tingkat, l10n);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 16, color: warna),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(temuan.pesan, style: theme.textTheme.bodySmall),
                if (temuan.kode.isNotEmpty)
                  Text(
                    temuan.kode,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
