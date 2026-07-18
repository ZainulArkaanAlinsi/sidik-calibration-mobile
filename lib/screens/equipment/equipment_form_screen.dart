import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/equipment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart' show categoryListProvider;
import '../../providers/equipment_provider.dart';
import '../../providers/master_data_provider.dart' show customerProvider;
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Form tambah/edit alat. `existing == null` → mode tambah.
///
/// Viewer bisa buka layar ini (baca alat itu hak semua role,
/// `docs/kontrak-api.md` §3), tapi field-nya `enabled: false` dan nggak ada
/// tombol simpan/hapus — nulis cuma buat admin & teknisi
/// ([UserRole.bisaInput]).
class EquipmentFormScreen extends ConsumerStatefulWidget {
  const EquipmentFormScreen({super.key, this.existing});

  final Equipment? existing;

  @override
  ConsumerState<EquipmentFormScreen> createState() =>
      _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends ConsumerState<EquipmentFormScreen> {
  late final _namaAlat = TextEditingController(text: widget.existing?.namaAlat);
  late final _serialNumber = TextEditingController(
    text: widget.existing?.serialNumber,
  );
  late final _merk = TextEditingController(text: widget.existing?.merk);
  late final _model = TextEditingController(text: widget.existing?.model);
  late final _noIdentifikasi = TextEditingController(
    text: widget.existing?.noIdentifikasi,
  );
  late final _rangeMin = TextEditingController(
    text: widget.existing?.rangeMin?.toString(),
  );
  late final _rangeMax = TextEditingController(
    text: widget.existing?.rangeMax?.toString(),
  );
  late final _satuan = TextEditingController(text: widget.existing?.satuan);
  late final _resolusi = TextEditingController(
    text: widget.existing?.resolusi?.toString(),
  );
  late final _toleransi = TextEditingController(
    text: widget.existing?.toleransi?.toString(),
  );
  late final _lokasi = TextEditingController(text: widget.existing?.lokasi);

  String? _kategori;
  int? _pelangganId;
  EquipmentStatus _status = EquipmentStatus.aktif;

  bool _menyimpan = false;
  String? _errorNama;
  String? _errorSerial;
  String? _errorKategori;
  String? _errorPelanggan;

  @override
  void initState() {
    super.initState();
    _kategori = widget.existing?.kategori;
    _pelangganId = widget.existing?.pelangganId;
    _status = widget.existing?.status ?? EquipmentStatus.aktif;
  }

  @override
  void dispose() {
    _namaAlat.dispose();
    _serialNumber.dispose();
    _merk.dispose();
    _model.dispose();
    _noIdentifikasi.dispose();
    _rangeMin.dispose();
    _rangeMax.dispose();
    _satuan.dispose();
    _resolusi.dispose();
    _toleransi.dispose();
    _lokasi.dispose();
    super.dispose();
  }

  double? _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);

    setState(() {
      _errorNama = _namaAlat.text.trim().isEmpty ? l10n.custFieldRequired : null;
      _errorSerial =
          _serialNumber.text.trim().isEmpty ? l10n.custFieldRequired : null;
      _errorKategori = _kategori == null ? l10n.custFieldRequired : null;
      _errorPelanggan = _pelangganId == null ? l10n.custFieldRequired : null;
    });
    if (_errorNama != null ||
        _errorSerial != null ||
        _errorKategori != null ||
        _errorPelanggan != null) {
      return;
    }

    setState(() => _menyimpan = true);

    final data = Equipment(
      id: widget.existing?.id ?? 0,
      namaAlat: _namaAlat.text.trim(),
      serialNumber: _serialNumber.text.trim(),
      kategori: _kategori!,
      status: _status,
      merk: _merk.text.trim(),
      model: _model.text.trim(),
      noIdentifikasi: _noIdentifikasi.text.trim(),
      pelangganId: _pelangganId,
      rangeMin: _parse(_rangeMin.text),
      rangeMax: _parse(_rangeMax.text),
      satuan: _satuan.text.trim(),
      resolusi: _parse(_resolusi.text),
      toleransi: _parse(_toleransi.text),
      lokasi: _lokasi.text.trim(),
    );

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.existing == null) {
        await ref.read(equipmentProvider.notifier).tambah(data);
      } else {
        await ref.read(equipmentProvider.notifier).ubah(data);
      }
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.equipSaveFailed(e.toString()))),
      );
      setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mengedit = widget.existing != null;
    final bisaInput = ref.watch(authProvider).value?.role.bisaInput ?? false;
    final kategoriList = ref.watch(categoryListProvider).value ?? const [];
    final pelangganList = ref.watch(customerProvider).value ?? const <Customer>[];

    return Scaffold(
      appBar: AppBar(title: Text(mengedit ? l10n.equipEdit : l10n.equipAdd)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppTextField(
            label: l10n.equipNamaAlat,
            controller: _namaAlat,
            errorText: _errorNama,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.equipSerialNumber,
            controller: _serialNumber,
            errorText: _errorSerial,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),

          Text(l10n.equipKategori.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _kategori,
            isExpanded: true,
            hint: Text(l10n.equipKategoriHint),
            items: kategoriList
                .map((k) => DropdownMenuItem(value: k.kode, child: Text(k.nama)))
                .toList(),
            onChanged: bisaInput
                ? (value) => setState(() {
                    _kategori = value;
                    _errorKategori = null;
                  })
                : null,
            decoration: InputDecoration(errorText: _errorKategori),
          ),
          const SizedBox(height: AppSpacing.md),

          Text(l10n.equipPelanggan.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int>(
            initialValue: _pelangganId,
            isExpanded: true,
            hint: Text(l10n.equipPelangganHint),
            items: pelangganList
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nama)))
                .toList(),
            onChanged: bisaInput
                ? (value) => setState(() {
                    _pelangganId = value;
                    _errorPelanggan = null;
                  })
                : null,
            decoration: InputDecoration(errorText: _errorPelanggan),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: l10n.equipMerk,
                  controller: _merk,
                  enabled: bisaInput,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: l10n.equipModel,
                  controller: _model,
                  enabled: bisaInput,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.equipNoIdentifikasi,
            controller: _noIdentifikasi,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: AppTextField.measurement(
                  label: l10n.equipRangeMin,
                  controller: _rangeMin,
                  enabled: bisaInput,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField.measurement(
                  label: l10n.equipRangeMax,
                  controller: _rangeMax,
                  enabled: bisaInput,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: l10n.equipSatuan,
                  controller: _satuan,
                  enabled: bisaInput,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField.measurement(
                  label: l10n.equipResolusi,
                  controller: _resolusi,
                  enabled: bisaInput,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField.measurement(
            label: l10n.equipToleransi,
            controller: _toleransi,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.equipLokasi,
            controller: _lokasi,
            enabled: bisaInput,
          ),
          const SizedBox(height: AppSpacing.md),

          Text(l10n.equipStatus.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<EquipmentStatus>(
            initialValue: _status,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: EquipmentStatus.aktif,
                child: Text(l10n.equipStatusAktif),
              ),
              DropdownMenuItem(
                value: EquipmentStatus.nonaktif,
                child: Text(l10n.equipStatusNonaktif),
              ),
            ],
            onChanged: bisaInput
                ? (value) => setState(() => _status = value!)
                : null,
          ),

          if (bisaInput) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: l10n.equipSave,
              isLoading: _menyimpan,
              onPressed: _menyimpan ? null : _simpan,
            ),
          ],
        ],
      ),
    );
  }
}
