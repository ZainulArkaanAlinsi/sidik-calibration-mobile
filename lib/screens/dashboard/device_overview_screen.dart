import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/equipment_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../equipment/equipment_form_screen.dart';

/// Drill-down ringkas dari kartu ringkasan Dashboard ("Total Alat" /
/// "Jatuh Tempo") — sengaja BUKAN [EquipmentListScreen]: nggak ada
/// search/filter/tombol tambah, murni daftar buat ngeliat cepet. Tap kartu
/// tetap bisa buka detail alatnya (read-only kalau viewer, lewat
/// [EquipmentFormScreen] yang sama dipakai tab Alat).
class DeviceOverviewScreen extends ConsumerWidget {
  const DeviceOverviewScreen({super.key, required this.title, this.statusFilter});

  final String title;
  final String? statusFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final daftarAsync = ref.watch(deviceOverviewProvider(statusFilter));

    final Widget isi;
    final data = daftarAsync.value;
    if (data != null) {
      isi = data.isEmpty ? _Kosong(l10n: l10n) : _Isi(items: data);
    } else if (daftarAsync.hasError) {
      isi = _Gagal(
        pesan: daftarAsync.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.equipLoadFailed,
        onCobaLagi: () => ref.invalidate(deviceOverviewProvider(statusFilter)),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(appBar: AppBar(title: Text(title)), body: isi);
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.items});

  final List<Equipment> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => _DeviceCard(item: items[index]),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.item});

  final Equipment item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EquipmentFormScreen(existing: item),
          ),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.namaAlat,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.serialNumber,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.pelangganNama != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.pelangganNama!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge.fromApi(item.status.rawValue),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.straighten_outlined, size: 56, color: theme.colorScheme.outline),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.equipEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
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
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.cloud_off_outlined, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(pesan, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.equipRetry,
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
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 16, width: 160),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(height: 12, width: 110),
            ],
          ),
        ),
      ),
    );
  }
}
