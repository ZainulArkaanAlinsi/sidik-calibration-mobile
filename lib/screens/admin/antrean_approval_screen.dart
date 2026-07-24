import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/history_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/notification_bell.dart';
import 'perhitungan_screen.dart';

/// Antrean approval admin (spesifikasi poin 12A, rencana §2.1).
///
/// **Teknisi banyak, admin satu pintu**: semua kiriman dari semua akun teknisi
/// masuk ke sini, bukan cuma punya admin sendiri. Bedanya dari layar Riwayat
/// itu di query — Riwayat pakai `mine=true`, ini `status=menunggu_approval`.
///
/// Tap satu baris → lembar PERHITUNGAN, tempat admin beneran mutusin.
class AntreanApprovalScreen extends ConsumerWidget {
  const AntreanApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final antrean = ref.watch(antreanApprovalProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.antreanTitle),
        actions: const [NotificationBell(), SizedBox(width: AppSpacing.sm)],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(antreanApprovalProvider.notifier).muatUlang(),
        child: switch (antrean) {
          AsyncData(:final value) =>
            value.isEmpty ? const _Kosong() : _Daftar(items: value),
          AsyncError() => _Gagal(
            onCobaLagi: () =>
                ref.read(antreanApprovalProvider.notifier).muatUlang(),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Daftar extends StatelessWidget {
  const _Daftar({required this.items});

  final List<CalibrationHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _Kartu(item: items[i]),
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({required this.item});

  final CalibrationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.hourglass_top_outlined,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(item.namaAlat, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${l10n.antreanOleh(item.namaTeknisi)} · '
          '${DateFormat('d MMM yyyy', locale).format(item.tanggalKalibrasi)}',
          style: theme.textTheme.labelSmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PerhitunganScreen(calibrationId: item.id),
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
          Icons.inbox_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.antreanKosong,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.antreanKosongBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
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
          l10n.antreanGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.perhitPeriksa,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
