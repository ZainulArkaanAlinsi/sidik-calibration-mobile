import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/standard.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calibration_input_provider.dart' show standardCrudProvider;
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

/// Form tambah/edit standar acuan. `existing == null` → mode tambah.
///
/// Nulis admin doang ([UserRole.isAdmin]) — beda sama Alat yang admin &
/// teknisi bisa nulis (`docs/kontrak-api.md` §4: salah ngetik ketidakpastian
/// standar bikin SEMUA sertifikat yang pakai standar itu ikut salah).
class StandardFormScreen extends ConsumerStatefulWidget {
  const StandardFormScreen({super.key, this.existing});

  final Standard? existing;

  @override
  ConsumerState<StandardFormScreen> createState() => _StandardFormScreenState();
}

class _StandardFormScreenState extends ConsumerState<StandardFormScreen> {
  late final _nama = TextEditingController(text: widget.existing?.nama);
  late final _merk = TextEditingController(text: widget.existing?.merk);
  late final _model = TextEditingController(text: widget.existing?.model);
  late final _serialNumber = TextEditingController(
    text: widget.existing?.serialNumber,
  );
  late final _noSertifikat = TextEditingController(
    text: widget.existing?.noSertifikat,
  );
  late final _tertelusurKe = TextEditingController(
    text: widget.existing?.tertelusurKe,
  );
  late final _ketidakpastian = TextEditingController(
    // `?.toString()` doang nggak cukup: `ketidakpastian` sendiri boleh null
    // (thermohygro nggak pakai kolom ini), dan `null.toString()` di Dart
    // ngasih string "null" yang kekunci di kotak isian.
    text: widget.existing?.ketidakpastian?.toString(),
  );
  late final _satuanKetidakpastian = TextEditingController(
    text: widget.existing?.satuanKetidakpastian,
  );
  late final _faktorCakupan = TextEditingController(
    text: (widget.existing?.faktorCakupan ?? 2).toString(),
  );
  late final _drift = TextEditingController(
    text: widget.existing?.drift?.toString(),
  );

  late DateTime? _berlakuSampai = widget.existing?.berlakuSampai;

  bool _menyimpan = false;
  String? _errorNama;
  String? _errorKetidakpastian;
  String? _errorFaktorCakupan;

  @override
  void dispose() {
    _nama.dispose();
    _merk.dispose();
    _model.dispose();
    _serialNumber.dispose();
    _noSertifikat.dispose();
    _tertelusurKe.dispose();
    _ketidakpastian.dispose();
    _satuanKetidakpastian.dispose();
    _faktorCakupan.dispose();
    _drift.dispose();
    super.dispose();
  }

  double? _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  Future<void> _pilihTanggal() async {
    final dipilih = await showDatePicker(
      context: context,
      initialDate: _berlakuSampai ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (dipilih != null) setState(() => _berlakuSampai = dipilih);
  }

  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);
    final ketidakpastian = _parse(_ketidakpastian.text);
    final faktorCakupan = _parse(_faktorCakupan.text);

    setState(() {
      _errorNama = _nama.text.trim().isEmpty ? l10n.custFieldRequired : null;
      _errorKetidakpastian =
          ketidakpastian == null ? l10n.custFieldRequired : null;
      _errorFaktorCakupan = faktorCakupan == null || faktorCakupan < 1
          ? l10n.standarFaktorCakupanInvalid
          : null;
    });
    if (_errorNama != null ||
        _errorKetidakpastian != null ||
        _errorFaktorCakupan != null) {
      return;
    }

    setState(() => _menyimpan = true);

    final data = Standard(
      id: widget.existing?.id ?? 0,
      nama: _nama.text.trim(),
      merk: _merk.text.trim(),
      model: _model.text.trim(),
      serialNumber: _serialNumber.text.trim(),
      noSertifikat: _noSertifikat.text.trim(),
      tertelusurKe: _tertelusurKe.text.trim(),
      berlakuSampai: _berlakuSampai,
      masihBerlaku: widget.existing?.masihBerlaku ?? true,
      ketidakpastian: ketidakpastian!,
      satuanKetidakpastian: _satuanKetidakpastian.text.trim(),
      faktorCakupan: faktorCakupan!,
      drift: _parse(_drift.text),
    );

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.existing == null) {
        await ref.read(standardCrudProvider.notifier).tambah(data);
      } else {
        await ref.read(standardCrudProvider.notifier).ubah(data);
      }
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.standarSaveFailed(e.toString()))),
      );
      setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final mengedit = widget.existing != null;
    final isAdmin = ref.watch(authProvider).value?.role.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(mengedit ? l10n.standarEdit : l10n.standarAdd),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppTextField(
            label: l10n.standarNama,
            controller: _nama,
            errorText: _errorNama,
            enabled: isAdmin,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: l10n.standarMerk,
                  controller: _merk,
                  enabled: isAdmin,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: l10n.standarModel,
                  controller: _model,
                  enabled: isAdmin,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.standarSerialNumber,
            controller: _serialNumber,
            enabled: isAdmin,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.standarNoSertifikat,
            controller: _noSertifikat,
            enabled: isAdmin,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: l10n.standarTertelusurKe,
            controller: _tertelusurKe,
            hint: l10n.standarTertelusurKeHint,
            enabled: isAdmin,
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: isAdmin ? _pilihTanggal : null,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.standarBerlakuSampai.toUpperCase(),
                prefixIcon: const Icon(Icons.event_busy_outlined, size: 20),
              ),
              child: Text(
                _berlakuSampai == null
                    ? l10n.orgPilihTanggal
                    : DateFormat('d MMM yyyy', locale).format(_berlakuSampai!),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            l10n.standarKetidakpastianTitle.toUpperCase(),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField.measurement(
                  label: l10n.standarKetidakpastian,
                  controller: _ketidakpastian,
                  errorText: _errorKetidakpastian,
                  enabled: isAdmin,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: l10n.standarSatuanKetidakpastian,
                  controller: _satuanKetidakpastian,
                  enabled: isAdmin,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField.measurement(
                  label: l10n.standarFaktorCakupan,
                  controller: _faktorCakupan,
                  errorText: _errorFaktorCakupan,
                  enabled: isAdmin,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField.measurement(
                  label: l10n.standarDrift,
                  controller: _drift,
                  enabled: isAdmin,
                ),
              ),
            ],
          ),

          if (isAdmin) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: l10n.standarSave,
              isLoading: _menyimpan,
              onPressed: _menyimpan ? null : _simpan,
            ),
          ],
        ],
      ),
    );
  }
}
