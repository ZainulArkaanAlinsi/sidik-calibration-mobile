import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/history_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../arsip/arsip_screen.dart';
import 'calibration_detail_screen.dart';

/// Riwayat kalibrasi — sama pola 4-state-nya kayak Dashboard
/// (`loading` skeleton · `empty` · `normal` daftar sesi · `error` + coba
/// lagi), biar teknisi/admin nggak bingung ketemu dua behavior beda buat
/// masalah yang sama (jaringan lemot, sesi habis, dst).
///
/// Admin dapat tambahan: tombol setujui/tolak langsung di kartu sesi yang
/// `menunggu_approval` — nggak ada layar approval terpisah, biar admin
/// nggak perlu loncat-loncat antara "lihat riwayat" dan "approve sesuatu".
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riwayat = ref.watch(historyProvider);
    final l10n = AppLocalizations.of(context);
    final isAdmin = ref.watch(authProvider).value?.role.isAdmin ?? false;

    // Urutan cek sama kayak dashboard: data dulu, baru error, baru loading —
    // biar retry Riverpod yang jalan di belakang layar nggak nyangkut di
    // skeleton selamanya (lihat komentar di dashboard_screen.dart).
    final data = riwayat.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty
          ? const _Kosong()
          : _Isi(items: data, isAdmin: isAdmin);
    } else if (riwayat.hasError) {
      isi = _Gagal(
        pesan: riwayat.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.historyLoadFailed,
        onCobaLagi: () => ref.read(historyProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navHistory),
        actions: [
          // Arsip ditaruh di sini juga, bukan cuma di Profil: Riwayat itu
          // daftar datar semua sesi, dan pertanyaan "mana punya PT anu"
          // paling sering muncul justru waktu lagi di layar ini.
          IconButton(
            tooltip: l10n.arsipTitle,
            icon: const Icon(Icons.folder_copy_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ArsipScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(historyProvider.notifier).muatUlang(),
        child: isi,
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.items, required this.isAdmin});

  final List<CalibrationHistoryItem> items;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) =>
          _HistoryCard(item: items[index], isAdmin: isAdmin),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.isAdmin});

  final CalibrationHistoryItem item;
  final bool isAdmin;

  StatusBadge _badge(AppLocalizations l10n) {
    if (item.status == CalibrationStatus.disetujui) {
      return switch (item.keputusan) {
        Keputusan.pass => StatusBadge(
          label: l10n.historyStatusPass,
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline,
        ),
        Keputusan.fail => StatusBadge(
          label: l10n.historyStatusFail,
          tone: BadgeTone.danger,
          icon: Icons.cancel_outlined,
        ),
        null => StatusBadge(
          label: l10n.historyStatusPass,
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline,
        ),
      };
    }

    return switch (item.status) {
      CalibrationStatus.draft => StatusBadge(
        label: l10n.historyStatusDraft,
        tone: BadgeTone.neutral,
        icon: Icons.edit_note,
      ),
      CalibrationStatus.menungguApproval => StatusBadge(
        label: l10n.historyStatusMenungguApproval,
        tone: BadgeTone.info,
        icon: Icons.hourglass_empty,
      ),
      CalibrationStatus.perluRevisi => StatusBadge(
        label: l10n.historyStatusPerluRevisi,
        tone: BadgeTone.warning,
        icon: Icons.edit_outlined,
      ),
      CalibrationStatus.disetujui => throw StateError('unreachable'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final tanggal = DateFormat('d MMM yyyy', locale).format(
      item.tanggalKalibrasi,
    );

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CalibrationDetailScreen(calibrationId: item.id),
          ),
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          '${item.namaTeknisi} · $tanggal',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (item.nomorSertifikat != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.historyCertNumber(item.nomorSertifikat!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _badge(l10n),
                ],
              ),
              if (item.status == CalibrationStatus.perluRevisi &&
                  item.catatanRevisi != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.historyCatatanRevisi(item.catatanRevisi!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
              if (isAdmin && item.status == CalibrationStatus.menungguApproval) ...[
                const SizedBox(height: AppSpacing.sm),
                _ApprovalActions(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol setujui/tolak — komponen sendiri (bukan langsung di `_HistoryCard`)
/// biar bisa nyimpen state `_busy` lokal: dua tombol ini harus nonaktif
/// bareng begitu salah satu dipencet, daripada admin nggak sabar mencet dua
/// kali dan approve-nya dobel keproses.
class _ApprovalActions extends ConsumerStatefulWidget {
  const _ApprovalActions({required this.item});

  final CalibrationHistoryItem item;

  @override
  ConsumerState<_ApprovalActions> createState() => _ApprovalActionsState();
}

class _ApprovalActionsState extends ConsumerState<_ApprovalActions> {
  bool _busy = false;

  Future<void> _setujui() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    try {
      await ref.read(historyProvider.notifier).approve(widget.item.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.historyApproveFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tolak() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    final catatan = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.historyRejectDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.historyRejectDialogHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.historyRejectDialogCancel),
          ),
          TextButton(
            onPressed: () {
              final teks = controller.text.trim();
              if (teks.isEmpty) return;
              Navigator.of(dialogContext).pop(teks);
            },
            child: Text(l10n.historyRejectDialogSubmit),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (catatan == null) return; // dibatalin
    if (catatan.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.historyRejectDialogEmpty)));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    try {
      await ref
          .read(historyProvider.notifier)
          .reject(widget.item.id, catatan);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.historyRejectFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: l10n.historyReject,
            variant: AppButtonVariant.secondary,
            isLoading: _busy,
            onPressed: _busy ? null : _tolak,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppButton(
            label: l10n.historyApprove,
            isLoading: _busy,
            onPressed: _busy ? null : _setujui,
          ),
        ),
      ],
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
          Icons.history_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.historyEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.historyEmptyBody,
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
          label: AppLocalizations.of(context).historyRetry,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(height: 16, width: 160),
              const SizedBox(height: AppSpacing.xs),
              const SkeletonBox(height: 12, width: 120),
            ],
          ),
        ),
      ),
    );
  }
}
