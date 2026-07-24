import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/notification_item.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/notification_provider.dart';
import '../history/calibration_detail_screen.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';

/// Notifikasi — pengingat jatuh tempo, update approval & revisi. Pola
/// state-nya sama kayak Dashboard & Riwayat (loading/empty/normal/error),
/// plus satu aksi tambahan: tap kartu buat nandain dibaca.
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notif = ref.watch(notificationProvider);
    final l10n = AppLocalizations.of(context);

    final data = notif.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty ? const _Kosong() : _Isi(items: data);
    } else if (notif.hasError) {
      isi = _Gagal(
        pesan: notif.error is TokenHilangException
            ? l10n.notifSessionExpired
            : l10n.notifLoadFailed,
        onCobaLagi: () => ref.read(notificationProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    final adaBelumDibaca = data?.any((n) => !n.dibaca) ?? false;

    return Scaffold(
      // Halaman sendiri (spesifikasi poin 4), jadi tombol back-nya bawaan
      // AppBar — poin 5.
      appBar: AppBar(
        title: Text(l10n.navNotifications),
        actions: [
          if (adaBelumDibaca)
            IconButton(
              tooltip: l10n.notifTandaiSemua,
              icon: const Icon(Icons.done_all),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref
                    .read(notificationProvider.notifier)
                    .tandaiSemuaDibaca();
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.notifSemuaDibaca)),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationProvider.notifier).muatUlang(),
        child: isi,
      ),
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.items});

  final List<NotificationItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];

        return _NotificationCard(
          item: item,
          onTap: () {
            if (!item.dibaca) {
              ref.read(notificationProvider.notifier).tandaiDibaca(item.id);
            }
            bukaTautanNotifikasi(context, item.tautan);
          },
        );
      },
    );
  }
}

/// Buka layar tujuan dari `tautan: {tipe, id}`.
///
/// Tujuannya ditentuin **backend**, bukan ditebak mobile dari kategori: satu
/// kategori bisa nunjuk ke layar beda tergantung datanya. Tipe yang belum
/// dikenal (mis. dari backend yang lebih baru) sengaja nggak ngapa-ngapain —
/// notifikasinya tetap kebaca, cuma nggak lompat ke mana-mana. Itu jauh lebih
/// baik daripada nebak dan mendarat di layar yang salah.
void bukaTautanNotifikasi(BuildContext context, NotifTautan? tautan) {
  if (tautan == null) return;

  final route = switch (tautan.tipe) {
    'calibration' => MaterialPageRoute<void>(
      builder: (_) => CalibrationDetailScreen(calibrationId: tautan.id),
    ),
    _ => null,
  };

  if (route != null) Navigator.of(context).push(route);
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback? onTap;

  (IconData, Color) _ikon(BuildContext context) {
    final theme = Theme.of(context);
    return switch (item.kategori) {
      NotifKategori.jatuhTempo => (Icons.schedule, AppColors.warning),
      NotifKategori.sesiMenungguApproval => (
        Icons.hourglass_empty,
        AppColors.warning,
      ),
      NotifKategori.sesiDisetujui => (
        Icons.verified_outlined,
        AppColors.success,
      ),
      NotifKategori.sesiPerluRevisi => (
        Icons.edit_outlined,
        theme.colorScheme.error,
      ),
      NotifKategori.sertifikatTerbit => (
        Icons.workspace_premium_outlined,
        AppColors.success,
      ),
      NotifKategori.umum => (
        Icons.info_outline,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final waktu = DateFormat('d MMM, HH:mm', locale).format(item.dibuatPada);
    final (icon, warna) = _ikon(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, size: 20, color: warna),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.judul,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: item.dibaca
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.isi,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      waktu,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.dibaca) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  height: 9,
                  width: 9,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.notifications_none,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.notifEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.notifEmptyBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
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
          label: AppLocalizations.of(context).notifRetry,
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
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const SkeletonBox(height: 40, width: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(height: 14, width: 160),
                    SizedBox(height: AppSpacing.xs),
                    SkeletonBox(height: 12, width: 200),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
