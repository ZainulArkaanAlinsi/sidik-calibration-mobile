import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/equipment_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import 'equipment_form_screen.dart';

/// Daftar Alat — 4 state sama kayak `DashboardScreen`: `loading` (skeleton) ·
/// `empty` (belum ada alat sama sekali) · `error` (gagal muat + coba lagi) ·
/// `data` (list, bisa nampilin "nggak ketemu" kalau search/filter kosong).
class EquipmentListScreen extends ConsumerStatefulWidget {
  const EquipmentListScreen({super.key});

  @override
  ConsumerState<EquipmentListScreen> createState() =>
      _EquipmentListScreenState();
}

class _EquipmentListScreenState extends ConsumerState<EquipmentListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _cariBerubah(String nilai) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(equipmentListProvider.notifier).ubahPencarian(nilai);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final daftar = ref.watch(equipmentListProvider);
    final user = ref.watch(authProvider).value;
    final bisaInput = user?.role.bisaInput ?? false;

    // Sama kayak dashboard: cek data duluan, baru error, baru loading —
    // Riverpod 3 nyoba ulang provider yang gagal, dan selama itu state-nya
    // masih `AsyncLoading` yang bawa error.
    final data = daftar.value;

    final Widget isi;
    if (data != null) {
      isi = data.kosong
          ? _Kosong(bisaInput: bisaInput)
          : _Isi(state: data, bisaInput: bisaInput);
    } else if (daftar.hasError) {
      isi = _Gagal(
        pesan: daftar.error is TokenHilangException
            ? l10n.dashSessionExpired
            : l10n.equipmentLoadFailed,
        onCobaLagi: () => ref.read(equipmentListProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navEquipment)),
      floatingActionButton: bisaInput
          ? FloatingActionButton(
              tooltip: l10n.dashAddDevice,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EquipmentFormScreen(),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: AppTextField(
              label: l10n.equipmentSearchHint,
              controller: _searchController,
              prefixIcon: Icons.search,
              onChanged: _cariBerubah,
            ),
          ),
          const _BarisFilter(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(equipmentListProvider.notifier).muatUlang(),
              child: isi,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dua dropdown filter (kategori + status) berdampingan.
class _BarisFilter extends ConsumerWidget {
  const _BarisFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(equipmentListProvider).value;
    final kategoriAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _DropdownFilter(
              placeholder: l10n.equipmentCategoryAll,
              value: filter?.kategori,
              options: kategoriAsync.value == null
                  ? const []
                  : [
                      for (final k in kategoriAsync.value!) (k.kode, k.nama),
                    ],
              onChanged: (nilai) => ref
                  .read(equipmentListProvider.notifier)
                  .ubahFilter(kategori: nilai, status: filter?.status),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _DropdownFilter(
              placeholder: l10n.equipmentStatusAll,
              value: filter?.status,
              options: [
                ('aktif', l10n.equipmentStatusActive),
                ('overdue', l10n.dashOverdue),
                ('nonaktif', l10n.equipmentStatusInactive),
              ],
              onChanged: (nilai) => ref
                  .read(equipmentListProvider.notifier)
                  .ubahFilter(kategori: filter?.kategori, status: nilai),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  const _DropdownFilter({
    required this.placeholder,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String placeholder;
  final String? value;
  final List<(String, String)> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          isExpanded: true,
          hint: Text(
            placeholder,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          items: [
            DropdownMenuItem<String?>(
              child: Text(placeholder, overflow: TextOverflow.ellipsis),
            ),
            for (final o in options)
              DropdownMenuItem<String?>(
                value: o.$1,
                child: Text(o.$2, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.state, required this.bisaInput});

  final EquipmentListState state;
  final bool bisaInput;

  @override
  Widget build(BuildContext context) {
    if (state.tidakAdaHasil) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.xl),
          Icon(
            Icons.search_off,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.equipmentNoResultsTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.equipmentNoResultsBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        88, // clearance FAB + bottom-nav mengambang.
      ),
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) =>
          _KartuAlat(equipment: state.items[index], bisaInput: bisaInput),
    );
  }
}

class _KartuAlat extends StatelessWidget {
  const _KartuAlat({required this.equipment, required this.bisaInput});

  final Equipment equipment;
  final bool bisaInput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final jatuhTempo = equipment.tanggalJatuhTempo;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        // Viewer read-only: nggak ada form buat dibuka, jadi kartu nggak
        // bisa di-tap sama sekali (bukan dibawa ke form yang isinya
        // nggak bisa disave apa-apa).
        onTap: bisaInput
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EquipmentFormScreen(equipment: equipment),
                ),
              )
            : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
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
                          equipment.namaAlat,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${equipment.merk} · ${equipment.serialNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge.fromApi(equipment.status.apiValue),
                ],
              ),
              if (jatuhTempo != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${l10n.equipmentDueDatePrefix} '
                      '${DateFormat('d MMM yyyy', Localizations.localeOf(context).toString()).format(jatuhTempo)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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
  const _Kosong({required this.bisaInput});

  final bool bisaInput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.straighten_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
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
      children: const [
        SkeletonBox(height: 80, width: double.infinity),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 80, width: double.infinity),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 80, width: double.infinity),
      ],
    );
  }
}
