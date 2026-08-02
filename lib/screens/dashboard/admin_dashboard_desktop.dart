import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../models/dashboard_summary.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/work_chart.dart';

/// Dashboard admin versi **DESKTOP** (Windows/macOS) — tata letak lebar ala
/// panel: sapaan + pencarian di kepala, sebaris kartu angka (satu di-highlight),
/// lalu kartu grafik tren besar + ringkasan di sampingnya.
///
/// Sengaja BEDA dari dashboard HP (`dashboard_screen.dart`): layar lebar punya
/// ruang buat nampilin lebih banyak sekaligus tanpa scroll, jadi rugi kalau
/// cuma navbar HP yang digeser ke samping. Komponennya dipakai bareng
/// ([StatCard], [WorkChart]) biar bahasa desainnya tetap satu.
///
/// Ini widget PRESENTASI murni — datanya disuntik dari luar (`ringkasan
/// dashboard`), jadi gampang dicolok ke `ringkasan_screen`/`DesktopShell`.
class AdminDashboardDesktop extends StatelessWidget {
  const AdminDashboardDesktop({
    super.key,
    required this.data,
    required this.nama,
  });

  final DashboardSummary data;
  final String nama;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        // ---- Kepala: sapaan + pencarian + notif ----
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, $nama!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ringkasan aktivitas kalibrasi lab hari ini',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const _KotakCari(),
            const SizedBox(width: AppSpacing.md),
            _BulatIkon(icon: Icons.notifications_outlined, theme: theme),
          ],
        ),
        const SizedBox(height: 28),

        // ---- Sebaris kartu angka (satu di-highlight) ----
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  label: 'Total Alat',
                  nilai: data.totalAlat,
                  icon: Icons.precision_manufacturing_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  label: 'Menunggu Approval',
                  nilai: data.menungguApproval,
                  icon: Icons.hourglass_empty,
                  warna: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  label: 'Alat Overdue',
                  nilai: data.alatOverdue,
                  icon: Icons.warning_amber_rounded,
                  warna: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Kartu "hero" di-highlight (isi teal, teks putih) — kayak kartu
              // hijau di acuan.
              Expanded(
                child: _KartuHighlight(
                  label: 'Sertifikat Bulan Ini',
                  nilai: data.sertifikatBulanIni,
                  icon: Icons.workspace_premium_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ---- Grafik tren besar + ringkasan samping ----
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: _Kartu(
                  judul: 'Tren Pekerjaan Kalibrasi',
                  child: SizedBox(
                    height: 240,
                    child: data.grafikPekerjaan.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada data tren',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : WorkChart(titik: data.grafikPekerjaan),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  children: [
                    _KartuAngka(
                      judul: 'Kalibrasi Selesai',
                      nilai: data.kalibrasiSelesai,
                      total: data.totalSertifikat,
                      warna: AppColors.success,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _KartuAngka(
                      judul: 'Draft Berjalan',
                      nilai: data.kalibrasiDraft,
                      warna: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kotak pencarian (visual) di kepala — gaya pill kayak acuan.
class _KotakCari extends StatelessWidget {
  const _KotakCari();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: TextField(
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Cari alat / sertifikat…',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _BulatIkon extends StatelessWidget {
  const _BulatIkon({required this.icon, required this.theme});

  final IconData icon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// Kartu putih rounded dengan judul kecil di atas.
class _Kartu extends StatelessWidget {
  const _Kartu({required this.judul, required this.child});

  final String judul;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              judul,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// Kartu angka ringkas (judul + angka besar + opsional "dari total").
class _KartuAngka extends StatelessWidget {
  const _KartuAngka({
    required this.judul,
    required this.nilai,
    required this.warna,
    this.total,
  });

  final String judul;
  final int nilai;
  final int? total;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              judul.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$nilai',
                  style: AppTypography.measurement.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: warna,
                  ),
                ),
                if (total != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '/ $total',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu angka "hero" — isi penuh warna aksen, teks putih (kayak kartu hijau
/// di acuan). Dipakai buat satu metrik paling penting biar ada titik fokus.
class _KartuHighlight extends StatelessWidget {
  const _KartuHighlight({
    required this.label,
    required this.nilai,
    required this.icon,
  });

  final String label;
  final int nilai;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
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
                  style: AppTypography.measurement.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 40 / 32,
                    letterSpacing: -0.32,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.9)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
