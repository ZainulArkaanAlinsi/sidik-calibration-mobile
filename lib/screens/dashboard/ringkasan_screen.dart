import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/dashboard_summary.dart';
import '../../models/izin.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/izin_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/work_chart.dart';
import '../admin/antrean_approval_screen.dart';

/// Halaman pembuka panel admin desktop.
///
/// Isinya sama sumbernya sama Dashboard di HP (`GET /api/dashboard`), tapi
/// tata letaknya beda peruntukan: di HP angkanya ditumpuk buat dibaca sambil
/// jalan, di sini semuanya dijejer supaya kelihatan sekaligus tanpa scroll di
/// layar 1280px.
class RingkasanScreen extends ConsumerWidget {
  const RingkasanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);

    return switch (async) {
      AsyncData(:final value) => _Isi(ringkas: value),
      AsyncError() => _Gagal(
          onCobaLagi: () => ref.read(dashboardProvider.notifier).muatUlang(),
        ),
      _ => const _Skeleton(),
    };
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.ringkas});

  final DashboardSummary ringkas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final peran = ref.watch(authProvider).value?.role;

    final bolehSetujui = ref.bolehkah(
      NamaIzin.kalibrasiSetujui,
      cadangan: peran.adminSaja,
    );

    final totalSesi =
        ringkas.kalibrasiDraft + ringkas.menungguApproval + ringkas.kalibrasiSelesai;

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardProvider.notifier).muatUlang(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.panelRingkasan,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.panelRingkasanSub,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (bolehSetujui)
                // **Bukan `AppButton`.** Tema app masang
                // `minimumSize: Size.fromHeight(52)` ke semua tombol — dan itu
                // `Size(infinity, 52)`, jadi tombolnya selalu selebar induknya.
                // Di HP itu yang dimau; di sini induknya `Row` yang ngasih
                // lebar tak terbatas, dan hasilnya assert "BoxConstraints
                // forces an infinite width" yang bikin SELURUH halaman blank.
                // Jadi tombol di baris desktop mesti nentuin ukurannya sendiri.
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AntreanApprovalScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.inbox_outlined, size: 18),
                  label: Text(l10n.panelBukaAntrean),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Empat kartu dijejer di layar lebar, dan melipat sendiri begitu
          // jendelanya dikecilin — kartu 4 kolom di jendela 900px bikin
          // angkanya kepotong.
          LayoutBuilder(
            builder: (context, constraints) {
              final perBaris = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              const jarak = AppSpacing.md;
              final lebar =
                  (constraints.maxWidth - jarak * (perBaris - 1)) / perBaris;

              return Wrap(
                spacing: jarak,
                runSpacing: jarak,
                children: [
                  SizedBox(
                    width: lebar,
                    child: _KartuAngka(
                      label: l10n.dashTotalDevices,
                      angka: ringkas.totalAlat,
                      keterangan: l10n.panelSesiSelesai(ringkas.kalibrasiSelesai),
                    ),
                  ),
                  SizedBox(
                    width: lebar,
                    child: _KartuAngka(
                      label: l10n.dashOverdue,
                      angka: ringkas.alatOverdue,
                      keterangan: l10n.panelPerluTindakLanjut,
                      keteranganMenonjol: ringkas.alatOverdue > 0,
                      bagian: ringkas.totalAlat == 0
                          ? null
                          : ringkas.alatOverdue / ringkas.totalAlat,
                      warna: AppColors.danger,
                    ),
                  ),
                  SizedBox(
                    width: lebar,
                    child: _KartuAngka(
                      label: l10n.dashPendingApproval,
                      angka: ringkas.menungguApproval,
                      keterangan: l10n.panelMasihDraft(ringkas.kalibrasiDraft),
                      bagian: totalSesi == 0
                          ? null
                          : ringkas.menungguApproval / totalSesi,
                    ),
                  ),
                  SizedBox(
                    width: lebar,
                    child: _KartuAngka(
                      label: l10n.dashCertsThisMonth,
                      angka: ringkas.sertifikatBulanIni,
                      keterangan: l10n.panelTotalSepanjangMasa(
                        ringkas.totalSertifikat,
                      ),
                      bagian: ringkas.totalSertifikat == 0
                          ? null
                          : ringkas.sertifikatBulanIni / ringkas.totalSertifikat,
                      warna: AppColors.success,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),

          LayoutBuilder(
            builder: (context, constraints) {
              final grafik = _Panel(
                judul: l10n.dashWorkChart,
                child: ringkas.grafikPekerjaan.isEmpty
                    ? _PanelKosong(pesan: l10n.dashEmptyTitle)
                    : WorkChart(titik: ringkas.grafikPekerjaan),
              );
              final sebaran = _Panel(
                judul: l10n.panelSebaranStatus,
                child: _Sebaran(ringkas: ringkas),
              );

              // Di bawah 1000px dua panel bersebelahan bikin grafiknya jadi
              // terlalu sempit buat kebaca — ditumpuk aja.
              if (constraints.maxWidth < 1000) {
                return Column(
                  children: [
                    grafik,
                    const SizedBox(height: AppSpacing.md),
                    sebaran,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: grafik),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 2, child: sebaran),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- potongan

class _KartuAngka extends StatelessWidget {
  const _KartuAngka({
    required this.label,
    required this.angka,
    required this.keterangan,
    this.bagian,
    this.warna,
    this.keteranganMenonjol = false,
  });

  final String label;
  final int angka;
  final String keterangan;

  /// Porsi 0..1 buat bilah tipis di bawah angka. `null` = nggak ada pembanding
  /// yang jujur, jadi bilahnya nggak digambar sama sekali — bilah tanpa
  /// pembagi cuma hiasan yang kelihatan kayak data.
  final double? bagian;

  final Color? warna;
  final bool keteranganMenonjol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aksen = warna ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$angka',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            keterangan,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: keteranganMenonjol
                  ? aksen
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: keteranganMenonjol ? FontWeight.w700 : null,
            ),
          ),
          if (bagian != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: bagian!.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(aksen),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.judul, required this.child});

  final String judul;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
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
    );
  }
}

class _Sebaran extends StatelessWidget {
  const _Sebaran({required this.ringkas});

  final DashboardSummary ringkas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final baris = <(String, int)>[
      (l10n.dashCalibrationDraft, ringkas.kalibrasiDraft),
      (l10n.dashPendingApproval, ringkas.menungguApproval),
      (l10n.dashCalibrationDone, ringkas.kalibrasiSelesai),
    ];
    final puncak = baris.map((b) => b.$2).fold(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, nilai) in baris) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(label, style: theme.textTheme.bodySmall),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: puncak == 0 ? 0 : nilai / puncak,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$nilai',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        // Status keempat ("perlu revisi") ada di enum CalibrationStatus tapi
        // angkanya belum dikirim `GET /dashboard`. Ditulis apa adanya daripada
        // dibiarin kosong — pembaca panel perlu tahu daftarnya belum lengkap,
        // bukan ngira lab-nya nol revisi.
        Text(
          l10n.panelStatusBelumLengkap,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PanelKosong extends StatelessWidget {
  const _PanelKosong({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 148,
      child: Center(
        child: Text(
          pesan,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.error),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.dashLoadFailed, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.dashRetry,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: onCobaLagi,
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        SkeletonBox(height: 44, width: 260),
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 128, width: double.infinity)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonBox(height: 128, width: double.infinity)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonBox(height: 128, width: double.infinity)),
            SizedBox(width: AppSpacing.md),
            Expanded(child: SkeletonBox(height: 128, width: double.infinity)),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 220, width: double.infinity),
      ],
    );
  }
}
