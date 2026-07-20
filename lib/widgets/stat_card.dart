import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'glass_surface.dart';
import 'skeleton.dart';

/// Kartu angka di Dashboard.
///
/// Susunannya: **angka dulu, label di bawahnya** (bukan sebaliknya). Alasannya
/// dua kartu yang sebaris jadi angkanya rata atas — kalau label yang di atas,
/// label yang kepanjangan bikin angka sebelahnya melorot sendirian.
///
/// [warna] dipakai buat angka yang butuh perhatian (alat jatuh tempo, antrean
/// approval). Warnanya **selalu dibarengin ikon**, bukan warna doang — biar
/// teknisi yang buta warna tetap nangkep.
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

  /// Null = netral (angka ikut warna teks biasa, ikon jadi kalem).
  final Color? warna;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warnaAngka = warna ?? theme.colorScheme.onSurface;
    // Ikon kartu netral sengaja dikalemin: dia penanda, bukan isi. Yang harus
    // ditangkap mata duluan itu angkanya.
    final warnaIkon = warna ?? theme.colorScheme.onSurfaceVariant;

    return SoftRaised(
      onTap: onTap,
      radius: AppSpacing.radiusLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '$nilai',
                  // Lebar digit tetap — biar angka antar kartu lurus dan
                  // nggak goyang tiap nilainya berubah.
                  style: AppTypography.measurement.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 40 / 32,
                    letterSpacing: -0.32,
                    color: warnaAngka,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: warnaIkon),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Label = metadata, jadi huruf besar + spasi lebar (DESIGN.md),
          // biar kebedain dari angkanya.
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Dua kartu sebaris, tingginya disamain **ngikut isi** — bukan rasio tetap.
///
/// Ini yang dulu bikin kartu overflow 7,5px: `GridView.count` maksa tiap kartu
/// jadi kotak seukuran `childAspectRatio`, jadi begitu labelnya jatuh ke 2
/// baris (atau user gedein ukuran font HP-nya), isinya nggak muat. Sekarang
/// tingginya ngikut isi, jadi overflow-nya nggak bisa kejadian lagi — sekalian
/// ilangin ruang kosong yang nganggur di bawah tiap kartu.
class StatCardRow extends StatelessWidget {
  const StatCardRow({super.key, required this.kiri, this.kanan});

  final Widget kiri;

  /// Boleh kosong kalau jumlah kartunya ganjil. Slot kanannya tetap dipesan
  /// (bukan bikin kartu kiri melar selebar layar), biar lebar kartu konsisten
  /// dengan baris-baris di atasnya.
  final Widget? kanan;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: kiri),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: kanan ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// Versi skeleton-nya — bentuk & tinggginya sama persis kayak kartu isi, jadi
/// waktu data masuk layoutnya nggak loncat.
class StatCardSkeleton extends StatelessWidget {
  const StatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 40, width: 56),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 16, width: 88),
          ],
        ),
      ),
    );
  }
}
