import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/standard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart' show standardCrudProvider;
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import 'standard_form_screen.dart';

/// Layar kelola Standar Acuan — beda sama dropdown di layar kalibrasi
/// (`standardListProvider`, read-only): ini CRUD penuh, admin doang
/// (`docs/kontrak-api.md` §4, `role:admin` di routes backend).
class StandardListScreen extends ConsumerWidget {
  const StandardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standar = ref.watch(standardCrudProvider);
    final l10n = AppLocalizations.of(context);
    final isAdmin = ref.watch(authProvider).value?.role.isAdmin ?? false;

    final data = standar.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty ? const _Kosong() : _Isi(items: data, isAdmin: isAdmin);
    } else if (standar.hasError) {
      isi = _Gagal(
        pesan: standar.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.standarLoadFailed,
        onCobaLagi: () => ref.read(standardCrudProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.standarTitle)),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(standardCrudProvider.notifier).muatUlang(),
              child: isi,
            ),
          ),
          if (isAdmin)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: AppButton(
                  label: l10n.standarAdd,
                  icon: Icons.add,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StandardFormScreen(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.items, required this.isAdmin});

  final List<Standard> items;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) =>
          _StandardCard(item: items[index], isAdmin: isAdmin),
    );
  }
}

class _StandardCard extends ConsumerWidget {
  const _StandardCard({required this.item, required this.isAdmin});

  final Standard item;
  final bool isAdmin;

  Future<void> _hapus(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.standarDeleteConfirmTitle),
        content: Text(l10n.standarDeleteConfirmBody(item.nama)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.custCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.custDelete),
          ),
        ],
      ),
    );

    if (yakin != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(standardCrudProvider.notifier).hapus(item.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.standarDeleteFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final subjudul = [
      item.merk,
      item.model,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StandardFormScreen(existing: item),
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
                      item.nama,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subjudul.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subjudul,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '± ${item.ketidakpastian} ${item.satuanKetidakpastian} '
                      '(k=${item.faktorCakupan.toStringAsFixed(0)})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: item.masihBerlaku
                    ? l10n.standarBerlaku
                    : l10n.standarKadaluarsa,
                tone: item.masihBerlaku ? BadgeTone.success : BadgeTone.danger,
                icon: item.masihBerlaku
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
              ),
              if (isAdmin)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => _hapus(context, ref),
                ),
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
        Icon(Icons.straighten_outlined, size: 56, color: theme.colorScheme.outline),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.standarEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.standarEmptyBody,
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
          label: AppLocalizations.of(context).standarRetry,
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
      itemBuilder: (context, index) => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 16, width: 160),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(height: 12, width: 120),
            ],
          ),
        ),
      ),
    );
  }
}
