import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/equipment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/equipment_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Tambah/ubah Alat. `equipment == null` = mode tambah.
class EquipmentFormScreen extends ConsumerStatefulWidget {
  const EquipmentFormScreen({super.key, this.equipment});

  final Equipment? equipment;

  @override
  ConsumerState<EquipmentFormScreen> createState() =>
      _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends ConsumerState<EquipmentFormScreen> {
  late final _nama = TextEditingController(text: widget.equipment?.namaAlat);
  late final _serial = TextEditingController(
    text: widget.equipment?.serialNumber,
  );
  late final _merk = TextEditingController(text: widget.equipment?.merk);
  late final _toleransi = TextEditingController(
    text: widget.equipment?.toleransi?.toString(),
  );
  late final _pelangganIdManual = TextEditingController(
    text: widget.equipment?.pelanggan?.id.toString(),
  );

  String? _kategori;
  // `overdue` dihitung backend, nggak bisa dipilih manual — kalau alat yang
  // diedit lagi overdue, defaultnya balik ke `aktif` (user yang mutusin ulang).
  late EquipmentStatus _status =
      widget.equipment?.status == EquipmentStatus.overdue
      ? EquipmentStatus.aktif
      : (widget.equipment?.status ?? EquipmentStatus.aktif);
  Customer? _pelangganTerpilih;

  String? _namaError;
  String? _serialError;
  String? _merkError;
  String? _kategoriError;

  bool _loading = false;
  String? _errorKirim;

  bool get _modeUbah => widget.equipment != null;

  /// Buka duluan kalau alat yang diedit udah punya toleransi/pelanggan —
  /// data yang udah keisi nggak boleh ketutup diam-diam di balik "tap dulu
  /// buat liat".
  bool get _detailAwalTerbuka =>
      widget.equipment?.toleransi != null ||
      widget.equipment?.pelanggan != null;

  @override
  void initState() {
    super.initState();
    _kategori = widget.equipment?.kategori;
  }

  @override
  void dispose() {
    _nama.dispose();
    _serial.dispose();
    _merk.dispose();
    _toleransi.dispose();
    _pelangganIdManual.dispose();
    super.dispose();
  }

  bool _validasi(AppLocalizations l10n) {
    setState(() {
      _namaError = _nama.text.trim().isEmpty ? l10n.equipmentNameRequired : null;
      _serialError = _serial.text.trim().isEmpty
          ? l10n.equipmentSerialRequired
          : null;
      _merkError = _merk.text.trim().isEmpty ? l10n.equipmentBrandRequired : null;
      _kategoriError = _kategori == null ? l10n.equipmentCategoryRequired : null;
    });

    return _namaError == null &&
        _serialError == null &&
        _merkError == null &&
        _kategoriError == null;
  }

  /// `Exception('pesan')` (dari `MockEquipmentService`) nge-toString jadi
  /// "Exception: pesan" — dibuang prefix-nya biar nggak dobel kayak
  /// "Gagal nyimpen: Exception: pesan".
  String _pesanError(Object error) {
    if (error is AuthException) return error.message;
    final teks = error.toString();
    return teks.startsWith('Exception: ') ? teks.substring(11) : teks;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_validasi(l10n)) return;

    final admin = ref.read(authProvider).value?.role.isAdmin ?? false;
    final pelangganId = admin
        ? _pelangganTerpilih?.id
        : int.tryParse(_pelangganIdManual.text.trim());

    setState(() {
      _loading = true;
      _errorKirim = null;
    });

    final equipment = Equipment(
      id: widget.equipment?.id ?? 0,
      namaAlat: _nama.text.trim(),
      serialNumber: _serial.text.trim(),
      kategori: _kategori!,
      merk: _merk.text.trim(),
      status: _status,
      toleransi: double.tryParse(_toleransi.text.trim().replaceAll(',', '.')),
    );

    var sukses = false;
    try {
      final notifier = ref.read(equipmentListProvider.notifier);
      if (_modeUbah) {
        await notifier.ubah(
          widget.equipment!.id,
          equipment,
          pelangganId: pelangganId,
        );
      } else {
        await notifier.tambah(equipment, pelangganId: pelangganId);
      }
      sukses = true;
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorKirim = l10n.equipmentSaveFailed(_pesanError(e)),
        );
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (sukses) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.equipmentSaved)));
      Navigator.of(context).pop();
    }
  }

  Future<void> _hapus() async {
    final l10n = AppLocalizations.of(context);

    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.equipmentDeleteConfirmTitle),
        content: Text(l10n.equipmentDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.equipmentDeleteConfirmAction),
          ),
        ],
      ),
    );

    if (yakin != true || !mounted) return;

    setState(() {
      _loading = true;
      _errorKirim = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(equipmentListProvider.notifier)
          .hapus(widget.equipment!.id);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.equipmentDeleted)));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorKirim = l10n.equipmentDeleteFailed(_pesanError(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final admin = ref.watch(authProvider).value?.role.isAdmin ?? false;
    final kategoriAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _modeUbah ? l10n.equipmentFormTitleEdit : l10n.equipmentFormTitleAdd,
        ),
        actions: [
          if (_modeUbah)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: l10n.equipmentDelete,
              onPressed: _loading ? null : _hapus,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (_errorKirim != null) ...[
              _BannerError(pesan: _errorKirim!),
              const SizedBox(height: AppSpacing.md),
            ],

            _JudulSeksi(l10n.equipmentSectionIdentity),
            const SizedBox(height: AppSpacing.sm),

            AppTextField(
              label: l10n.equipmentNameLabel,
              controller: _nama,
              hint: l10n.equipmentNameHint,
              errorText: _namaError,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),

            AppTextField(
              label: l10n.equipmentSerialLabel,
              controller: _serial,
              hint: l10n.equipmentSerialHint,
              errorText: _serialError,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),

            AppTextField(
              label: l10n.equipmentBrandLabel,
              controller: _merk,
              hint: l10n.equipmentBrandHint,
              errorText: _merkError,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),

            _LabeledField(
              label: l10n.equipmentCategoryLabel,
              errorText: _kategoriError,
              child: DropdownButtonFormField<String>(
                initialValue: _kategori,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  for (final k in kategoriAsync.value ?? const [])
                    DropdownMenuItem(value: k.kode, child: Text(k.nama)),
                ],
                onChanged: _loading
                    ? null
                    : (v) => setState(() => _kategori = v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _LabeledField(
              label: l10n.equipmentStatusLabel,
              child: SegmentedButton<EquipmentStatus>(
                segments: [
                  ButtonSegment(
                    value: EquipmentStatus.aktif,
                    label: Text(l10n.equipmentStatusActive),
                  ),
                  ButtonSegment(
                    value: EquipmentStatus.nonaktif,
                    label: Text(l10n.equipmentStatusInactive),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: _loading
                    ? null
                    : (v) => setState(() => _status = v.first),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Progressive disclosure: toleransi & pelanggan nggak wajib buat
            // nyimpen alat, jadi disembunyiin di belakang satu tap biar form
            // utamanya nggak berat dilihat. Kebuka otomatis kalau alat yang
            // diedit udah punya salah satu data ini, biar nggak "hilang".
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _detailAwalTerbuka,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: AppSpacing.sm),
                title: Text(
                  l10n.equipmentSectionAdditional,
                  style: theme.textTheme.titleSmall,
                ),
                children: [
                  AppTextField.measurement(
                    label: l10n.equipmentToleranceLabel,
                    controller: _toleransi,
                    hint: l10n.equipmentToleranceHint,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  admin
                      ? _PelangganDropdownAdmin(
                          value: _pelangganTerpilih,
                          equipmentPelanggan: widget.equipment?.pelanggan,
                          enabled: !_loading,
                          onChanged: (v) =>
                              setState(() => _pelangganTerpilih = v),
                        )
                      : _LabeledField(
                          label: l10n.equipmentCustomerIdLabel,
                          helperText: l10n.equipmentCustomerIdHelper,
                          child: AppTextField(
                            label: '',
                            controller: _pelangganIdManual,
                            enabled: !_loading,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton(
              label: _modeUbah ? l10n.equipmentSubmitEdit : l10n.equipmentSubmitAdd,
              isLoading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown pelanggan admin — daftar dari `customersProvider`
/// (`GET /api/customers`, admin-only). Kalau lagi ngedit alat yang udah
/// punya pelanggan, opsinya di-preselect dari data itu (bukan nunggu
/// provider-nya nemu ID yang sama di daftar).
class _PelangganDropdownAdmin extends ConsumerStatefulWidget {
  const _PelangganDropdownAdmin({
    required this.value,
    required this.equipmentPelanggan,
    required this.enabled,
    required this.onChanged,
  });

  final Customer? value;
  final EquipmentCustomer? equipmentPelanggan;
  final bool enabled;
  final ValueChanged<Customer?> onChanged;

  @override
  ConsumerState<_PelangganDropdownAdmin> createState() =>
      _PelangganDropdownAdminState();
}

class _PelangganDropdownAdminState
    extends ConsumerState<_PelangganDropdownAdmin> {
  bool _sudahPreselect = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pelangganAsync = ref.watch(customersProvider);
    final daftar = pelangganAsync.value ?? const <Customer>[];

    // Preselect dari data equipment (sekali aja) begitu daftar pelanggannya
    // udah kemuat, biar dropdown nunjukin pilihan yang bener waktu buka form
    // edit.
    if (!_sudahPreselect &&
        widget.value == null &&
        widget.equipmentPelanggan != null &&
        daftar.isNotEmpty) {
      _sudahPreselect = true;
      final cocok = daftar.where((c) => c.id == widget.equipmentPelanggan!.id);
      if (cocok.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onChanged(cocok.first);
        });
      }
    }

    return _LabeledField(
      label: l10n.equipmentCustomerLabel,
      child: DropdownButtonFormField<int?>(
        initialValue: widget.value?.id,
        isExpanded: true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        hint: Text(l10n.equipmentCustomerNone),
        items: [
          DropdownMenuItem<int?>(child: Text(l10n.equipmentCustomerNone)),
          for (final c in daftar)
            DropdownMenuItem<int?>(value: c.id, child: Text(c.nama)),
        ],
        onChanged: widget.enabled
            ? (id) => widget.onChanged(
                id == null ? null : daftar.firstWhere((c) => c.id == id),
              )
            : null,
      ),
    );
  }
}

/// Judul kecil di atas seksi form — HURUF BESAR, konsisten sama pola label
/// seksi yang udah dipakai di layar Dashboard & Profile.
class _JudulSeksi extends StatelessWidget {
  const _JudulSeksi(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      teks.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.errorText,
    this.helperText,
  });

  final String label;
  final Widget child;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        child,
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _BannerError extends StatelessWidget {
  const _BannerError({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(pesan, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
