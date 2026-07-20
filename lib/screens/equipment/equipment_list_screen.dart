import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart' show categoryListProvider;
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/equipment_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import 'equipment_form_screen.dart';

/// Layar Daftar Alat — CRUD penuh (`GET/POST/PUT/DELETE /api/equipments`,
/// `docs/kontrak-api.md` §3). Baca boleh semua role; tombol tambah & aksi
/// hapus cuma muncul buat admin/teknisi (`UserRole.bisaInput`) — viewer
/// tetap bisa buka tiap kartu buat lihat detail, form-nya cuma jadi
/// read-only.
class EquipmentListScreen extends ConsumerStatefulWidget {
  const EquipmentListScreen({super.key});

  @override
  ConsumerState<EquipmentListScreen> createState() =>
      _EquipmentListScreenState();
}

class _EquipmentListScreenState extends ConsumerState<EquipmentListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _kategori;
  String? _status;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(equipmentProvider.notifier).cari(query);
    });
  }

  void _onFilterChanged({String? kategori, String? status}) {
    setState(() {
      _kategori = kategori;
      _status = status;
    });
    ref.read(equipmentProvider.notifier).filter(kategori: kategori, status: status);
  }

  @override
  Widget build(BuildContext context) {
    final alat = ref.watch(equipmentProvider);
    final l10n = AppLocalizations.of(context);
    final bisaInput = ref.watch(authProvider).value?.role.bisaInput ?? false;
    final kategoriList = ref.watch(categoryListProvider).value ?? const [];

    final data = alat.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty ? const _Kosong() : _Isi(items: data);
    } else if (alat.hasError) {
      isi = _Gagal(
        pesan: alat.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.equipLoadFailed,
        onCobaLagi: () => ref.read(equipmentProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navEquipment)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.equipSearchHint,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _FilterDropdown<String?>(
                    hint: l10n.equipFilterKategoriHint,
                    value: _kategori,
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.equipFilterSemua)),
                      for (final k in kategoriList)
                        DropdownMenuItem(value: k.kode, child: Text(k.nama)),
                    ],
                    onChanged: (value) =>
                        _onFilterChanged(kategori: value, status: _status),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _FilterDropdown<String?>(
                    hint: l10n.equipFilterStatusHint,
                    value: _status,
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.equipFilterSemua)),
                      DropdownMenuItem(value: 'aktif', child: Text(l10n.equipStatusAktif)),
                      DropdownMenuItem(
                        value: 'overdue',
                        child: Text(l10n.equipStatusOverdue),
                      ),
                      DropdownMenuItem(
                        value: 'nonaktif',
                        child: Text(l10n.equipStatusNonaktif),
                      ),
                    ],
                    onChanged: (value) =>
                        _onFilterChanged(kategori: _kategori, status: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(equipmentProvider.notifier).muatUlang(),
              child: isi,
            ),
          ),
          if (bisaInput)
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
                  label: l10n.equipAdd,
                  icon: Icons.add,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EquipmentFormScreen(),
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

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String hint;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      items: items,
      onChanged: (v) => onChanged(v as T),
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.items});

  final List<Equipment> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bisaMuatLagi = ref.read(equipmentProvider.notifier).bisaMuatLagi;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: items.length + (bisaMuatLagi ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return _MuatLebihBanyak(label: l10n.equipMuatLebihBanyak);
        }
        return _EquipmentCard(item: items[index]);
      },
    );
  }
}

class _MuatLebihBanyak extends ConsumerStatefulWidget {
  const _MuatLebihBanyak({required this.label});

  final String label;

  @override
  ConsumerState<_MuatLebihBanyak> createState() => _MuatLebihBanyakState();
}

class _MuatLebihBanyakState extends ConsumerState<_MuatLebihBanyak> {
  bool _memuat = false;

  Future<void> _muat() async {
    setState(() => _memuat = true);
    await ref.read(equipmentProvider.notifier).muatLebihBanyak();
    if (mounted) setState(() => _memuat = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: AppButton(
        label: widget.label,
        variant: AppButtonVariant.secondary,
        isLoading: _memuat,
        onPressed: _memuat ? null : _muat,
      ),
    );
  }
}

class _EquipmentCard extends ConsumerWidget {
  const _EquipmentCard({required this.item});

  final Equipment item;

  Future<void> _hapus(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.equipDeleteConfirmTitle),
        content: Text(l10n.equipDeleteConfirmBody(item.namaAlat)),
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
      await ref.read(equipmentProvider.notifier).hapus(item.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.equipDeleteFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bisaInput = ref.watch(authProvider).value?.role.bisaInput ?? false;

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
              if (bisaInput)
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
          l10n.equipEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.equipEmptyBody,
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
          label: AppLocalizations.of(context).equipRetry,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
