import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import 'data_administrasi.dart' show panjangMaksNomorOrder;

/// Isian dialog Setujui: Order Number (selalu) dan No. Sertifikat (kecuali
/// sesi yang sertifikatnya ditarik — nomor `-R<n>` dibuat server).
typedef IsianSetujui = ({String nomorOrder, String? nomorSertifikat});

/// Panjang maksimal No. Sertifikat — sama dengan aturan server (K-50-04).
const panjangMaksNomorSertifikat = 100;

final _karakterAman = RegExp(r'^[A-Za-z0-9._/\-]+$');
final _akhiranRevisi = RegExp(r'-R\d+$', caseSensitive: false);

/// Cermin aturan server untuk umpan balik cepat; server tetap yang memutuskan
/// (`nomor_sertifikat_tidak_valid`).
bool nomorSertifikatLayak(String nomor) =>
    nomor.isNotEmpty &&
    nomor.length <= panjangMaksNomorSertifikat &&
    _karakterAman.hasMatch(nomor) &&
    !_akhiranRevisi.hasMatch(nomor);

/// Minta Order Number + No. Sertifikat sebelum menyetujui. `null` = dibatalkan.
///
/// [galatSertifikat] / [galatOrder] = pesan dari penolakan 422 server di putaran
/// sebelumnya, ditampilkan di kotaknya masing-masing dengan isian yang sama.
Future<IsianSetujui?> mintaDataSetujui(
  BuildContext context, {
  String? nomorOrder,
  String? nomorSertifikat,
  bool tanpaNomorSertifikat = false,
  String? galatSertifikat,
  String? galatOrder,
}) => showDialog<IsianSetujui>(
  context: context,
  builder: (_) => DialogSetujui(
    nomorOrder: nomorOrder,
    nomorSertifikat: nomorSertifikat,
    tanpaNomorSertifikat: tanpaNomorSertifikat,
    galatSertifikat: galatSertifikat,
    galatOrder: galatOrder,
  ),
);

class DialogSetujui extends StatefulWidget {
  const DialogSetujui({
    super.key,
    this.nomorOrder,
    this.nomorSertifikat,
    this.tanpaNomorSertifikat = false,
    this.galatSertifikat,
    this.galatOrder,
  });

  final String? nomorOrder;
  final String? nomorSertifikat;
  final bool tanpaNomorSertifikat;
  final String? galatSertifikat;
  final String? galatOrder;

  @override
  State<DialogSetujui> createState() => _DialogSetujuiState();
}

class _DialogSetujuiState extends State<DialogSetujui> {
  late final _order = TextEditingController(text: widget.nomorOrder ?? '');
  late final _sertifikat = TextEditingController(
    text: widget.nomorSertifikat ?? '',
  );
  String? _galatOrder;
  String? _galatSertifikat;

  @override
  void initState() {
    super.initState();
    _galatOrder = widget.galatOrder;
    _galatSertifikat = widget.galatSertifikat;
  }

  @override
  void dispose() {
    _order.dispose();
    _sertifikat.dispose();
    super.dispose();
  }

  void _setuju() {
    final l10n = AppLocalizations.of(context);
    final order = _order.text.trim();
    final nomor = _sertifikat.text.trim();

    String? galatOrder;
    String? galatSertifikat;
    if (order.isEmpty) galatOrder = l10n.adminNomorOrderKosong;
    if (!widget.tanpaNomorSertifikat) {
      if (nomor.isEmpty) {
        galatSertifikat = l10n.setujuiNomorSertifikatKosong;
      } else if (!nomorSertifikatLayak(nomor)) {
        galatSertifikat = l10n.setujuiNomorSertifikatFormat;
      }
    }

    if (galatOrder != null || galatSertifikat != null) {
      setState(() {
        _galatOrder = galatOrder;
        _galatSertifikat = galatSertifikat;
      });
      return;
    }

    Navigator.of(context).pop((
      nomorOrder: order,
      nomorSertifikat: widget.tanpaNomorSertifikat ? null : nomor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      key: const ValueKey('dialog-setujui'),
      title: Text(l10n.setujuiJudul),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.setujuiPetunjuk, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('isian-nomor-order'),
            controller: _order,
            maxLength: panjangMaksNomorOrder,
            textInputAction: widget.tanpaNomorSertifikat
                ? TextInputAction.done
                : TextInputAction.next,
            onChanged: (_) {
              if (_galatOrder != null) setState(() => _galatOrder = null);
            },
            decoration: InputDecoration(
              labelText: l10n.perhitNomorOrder,
              errorText: _galatOrder,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.tanpaNomorSertifikat)
            Text(
              l10n.setujuiNomorRevisiOtomatis,
              key: const ValueKey('petunjuk-nomor-revisi'),
              style: theme.textTheme.bodySmall,
            )
          else
            TextField(
              key: const ValueKey('isian-nomor-sertifikat'),
              controller: _sertifikat,
              maxLength: panjangMaksNomorSertifikat,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _setuju(),
              onChanged: (_) {
                if (_galatSertifikat != null) {
                  setState(() => _galatSertifikat = null);
                }
              },
              decoration: InputDecoration(
                labelText: l10n.setujuiNomorSertifikatLabel,
                helperText: l10n.setujuiNomorSertifikatPetunjuk,
                helperMaxLines: 3,
                errorText: _galatSertifikat,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.custCancel),
        ),
        FilledButton(
          key: const ValueKey('simpan-setujui'),
          onPressed: _setuju,
          child: Text(l10n.setujuiAksi),
        ),
      ],
    );
  }
}
