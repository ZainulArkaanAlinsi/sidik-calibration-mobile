import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'skeleton.dart';

/// Kartu angka di Dashboard.
///
/// [penting] dipakai buat angka yang butuh perhatian (alat jatuh tempo,
/// antrean approval). Warnanya ikut warna semantik + **selalu ada ikonnya** —
/// bukan cuma merah doang, biar teknisi yang buta warna tetap nangkep.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.nilai,
    required this.icon,
    this.warna,
    this.onTap,
  });

  final String label;
  final int nilai;
  final IconData icon;

  /// Null = netral (ikut warna teks biasa).
  final Color? warna;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warnaEfektif = warna ?? theme.colorScheme.onSurface;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: warnaEfektif),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$nilai',
                // Angka pakai lebar digit tetap — biar kolom angka nggak
                // goyang tiap nilainya berubah.
                style: AppTypography.measurement.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: warnaEfektif,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Versi skeleton-nya — bentuknya sama, jadi waktu data masuk, layoutnya
/// nggak loncat.
class StatCardSkeleton extends StatelessWidget {
  const StatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(height: 20, width: 20),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 28, width: 56),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 12, width: 88),
          ],
        ),
      ),
    );
  }
}
