import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dashboard_summary.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../calibration/category_picker_screen.dart';
import '../calibration/lembar_kerja_screen.dart';
import 'device_overview_screen.dart';

/// Dashboard — 4 state sesuai task 21 Jul:
/// `loading` (skeleton) · `empty` (belum ada apa-apa) · `normal` (angka) ·
/// `error` (gagal muat + tombol coba lagi).
///
/// Isinya beda per role: teknisi lihat angka miliknya sendiri, admin lihat
/// angka lintas-teknisi. **Backend yang nentuin dari token** — mobile cuma
/// ngubah judul & sorotan, nggak ngitung sendiri.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringkasan = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).value;
    final l10n = AppLocalizations.of(context);

    // JANGAN pattern-match `AsyncLoading()` duluan di sini.
    //
    // Riverpod 3 otomatis nyoba ulang provider yang gagal, dan selama nyoba
    // ulang itu state-nya tetap `AsyncLoading` **yang bawa error**. Kalau
    // loading dicek duluan, layar bakal nampilin skeleton selamanya — user
    // nggak pernah lihat pesan gagal atau tombol coba lagi, dan app-nya
    // kelihatan nge-hang. Jadi urutannya: ada data? → ada error? → baru
    // loading.
    final data = ringkasan.value;

    final Widget isi;
    if (data != null) {
      isi = data.kosong ? _Kosong(user: user) : _Isi(data: data, user: user);
    } else if (ringkasan.hasError) {
      isi = _Gagal(
        pesan: ringkasan.error is TokenHilangException
            ? l10n.dashSessionExpired
            : l10n.dashLoadFailed,
        onCobaLagi: () => ref.read(dashboardProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navDashboard)),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).muatUlang(),
        child: isi,
      ),
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.data, required this.user});

  final DashboardSummary data;
  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final admin = user?.role.isAdmin ?? false;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (user != null) _Sapaan(user: user!),
        const SizedBox(height: AppSpacing.lg),

        _JudulSeksi(admin ? l10n.dashSummaryOrg : l10n.dashSummaryYours),
        const SizedBox(height: AppSpacing.sm),

        StatCardRow(
          kiri: StatCard(
            label: l10n.dashTotalDevices,
            nilai: data.totalAlat,
            icon: Icons.straighten_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DeviceOverviewScreen(title: l10n.dashTotalDevices),
              ),
            ),
          ),
          kanan: StatCard(
            label: l10n.dashOverdue,
            nilai: data.alatOverdue,
            icon: Icons.schedule,
            warna: data.alatOverdue > 0 ? AppColors.warning : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DeviceOverviewScreen(
                  title: l10n.dashOverdue,
                  statusFilter: 'overdue',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        StatCardRow(
          kiri: admin
              ? StatCard(
                  label: l10n.dashPendingApproval,
                  nilai: data.menungguApproval,
                  icon: Icons.hourglass_empty,
                  warna: data.menungguApproval > 0 ? AppColors.info : null,
                )
              : StatCard(
                  label: l10n.dashCalibrationDraft,
                  nilai: data.kalibrasiDraft,
                  icon: Icons.edit_note,
                ),
          kanan: StatCard(
            label: l10n.dashCertsThisMonth,
            nilai: data.sertifikatBulanIni,
            icon: Icons.workspace_premium_outlined,
            warna: AppColors.success,
          ),
        ),

        if (data.alatOverdue > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _PeringatanOverdue(jumlah: data.alatOverdue),
        ],

        // Viewer read-only: tombol aksi nggak dirender sama sekali.
        if (user?.role.bisaInput ?? false) ...[
          const SizedBox(height: AppSpacing.lg),
          _JudulSeksi(l10n.dashQuickActions),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppButton(
                    label: l10n.dashStartCalibration,
                    icon: Icons.add_task,
                    // Nggak langsung ke form generik lagi — sekarang lewat
                    // 2 langkah pilihan (kategori besar → jenis alat
                    // spesifik) biar teknisi nggak dihadapin dropdown datar
                    // isinya 10+ kategori sekaligus.
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CategoryPickerScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Shortcut cepat: pH Meter juga bisa dicapai lewat alur
                  // Kategori → Instrumen Analitik → pH Meter di atas, tapi
                  // tombol ini dipertahankan sebagai jalan pintas karena itu
                  // prioritas atasan & paling sering dipakai — form-nya juga
                  // jauh lebih spesifik (kondisi lingkungan awal/akhir,
                  // 3 titik buffer x 5 pembacaan before/after adjustment).
                  AppButton(
                    label: l10n.dashStartPhCalibration,
                    icon: Icons.science_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LembarKerjaScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: l10n.dashAddDevice,
                    icon: Icons.add,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _snack(context, l10n.snackAddDeviceSoon),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _snack(BuildContext context, String pesan) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(pesan)));
  }
}

/// Judul seksi — huruf besar, spasi lebar, warna kalem. Dia penunjuk arah,
/// bukan isi, jadi sengaja nggak ikut nyolok kayak angka di kartu.
class _JudulSeksi extends StatelessWidget {
  const _JudulSeksi(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      teks.toUpperCase(),
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Sapaan extends StatelessWidget {
  const _Sapaan({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).dashGreeting,
                style: theme.textTheme.bodySmall,
              ),
              Text(user.nama, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        StatusBadge(
          label: user.role.label,
          tone: user.role.isAdmin ? BadgeTone.info : BadgeTone.neutral,
          icon: Icons.badge_outlined,
        ),
      ],
    );
  }
}

class _PeringatanOverdue extends StatelessWidget {
  const _PeringatanOverdue({required this.jumlah});

  final int jumlah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppLocalizations.of(context).dashOverdueWarning(jumlah),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final bisaInput = user?.role.bisaInput ?? false;

    // ListView (bukan Center) biar tetap bisa ditarik buat refresh.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.inbox_outlined, size: 56, color: theme.colorScheme.outline),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.dashEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          bisaInput ? l10n.dashEmptyBodyInput : l10n.dashEmptyBodyReadonly,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (bisaInput) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.dashAddDevice,
            icon: Icons.add,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.snackAddDeviceSoon)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          pesan,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppLocalizations.of(context).dashRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SkeletonBox(height: 14, width: 60),
        const SizedBox(height: AppSpacing.sm),
        const SkeletonBox(height: 28, width: 180),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonBox(height: 12, width: 140),
        const SizedBox(height: AppSpacing.sm),
        const StatCardRow(kiri: StatCardSkeleton(), kanan: StatCardSkeleton()),
        const SizedBox(height: AppSpacing.sm),
        const StatCardRow(kiri: StatCardSkeleton(), kanan: StatCardSkeleton()),
      ],
    );
  }
}
