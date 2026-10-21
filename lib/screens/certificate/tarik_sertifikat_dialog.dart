import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/certificate_snapshot.dart';
import '../../models/revisi_sertifikat.dart';
import '../../providers/certificate_provider.dart';
import '../../services/kode_galat.dart';

/// Konfirmasi "Tarik ke lembar kerja" (admin & super admin, K-50-03).
///
/// Butuh alasan (min. 10 karakter) DAN sandi akun yang menarik: aksinya
/// menandai sertifikat yang sudah terbit sebagai `ditarik`, jadi bukan klik
/// satu kali. Dijalankan di dalam dialog supaya galat 422 tampil di tempat
/// dan isiannya tidak hilang. Menutup dengan `true` = berhasil ditarik.
class TarikSertifikatDialog extends ConsumerStatefulWidget {
  const TarikSertifikatDialog({super.key, required this.sertifikat});

  final CertificateDetail sertifikat;

  /// `min:10` di `TarikSertifikat` (server).
  static const alasanMinimal = 10;

  @override
  ConsumerState<TarikSertifikatDialog> createState() =>
      _TarikSertifikatDialogState();
}

class _TarikSertifikatDialogState extends ConsumerState<TarikSertifikatDialog> {
  final _alasan = TextEditingController();
  final _sandi = TextEditingController();
  bool _sibuk = false;
  String? _galatAlasan;
  String? _galatSandi;
  String? _banner;

  @override
  void dispose() {
    _alasan.dispose();
    _sandi.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    if (_sibuk) return;

    final alasanPendek =
        _alasan.text.trim().length < TarikSertifikatDialog.alasanMinimal;
    final sandiKosong = _sandi.text.isEmpty;
    if (alasanPendek || sandiKosong) {
      setState(() {
        _galatAlasan = alasanPendek ? l10n.tarikAlasanPendek : null;
        _galatSandi = sandiKosong ? l10n.tarikSandiKosong : null;
      });
      return;
    }

    setState(() {
      _sibuk = true;
      _galatAlasan = null;
      _galatSandi = null;
      _banner = null;
    });
    try {
      await ref
          .read(sertifikatAksiProvider)
          .tarik(
            widget.sertifikat.id,
            alasan: _alasan.text,
            password: _sandi.text,
          );
      navigator.pop(true);
    } on GalatAksi catch (e) {
      if (!mounted) return;
      final sandiSalah = e.kode == KodeGalat.konfirmasiSandiSalah;
      setState(() {
        _sibuk = false;
        _galatAlasan = e.untuk('alasan');
        _galatSandi = sandiSalah
            ? l10n.galatKonfirmasiSandiSalah
            : e.untuk('password');
        // `errors.sertifikat` & galat keadaan lain: sudah ditarik, sudah punya
        // revisi, sesi bukan `disetujui`, dst. — pesan server apa adanya.
        _banner = sandiSalah || _galatAlasan != null || _galatSandi != null
            ? null
            : (e.untuk('sertifikat') ?? e.pesan);
      });
      if (sandiSalah) _sandi.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _banner = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      key: const ValueKey('dialog-tarik-sertifikat'),
      icon: const Icon(Icons.undo),
      title: Text(l10n.tarikJudul),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tarikPetunjuk, style: theme.textTheme.bodyMedium),
          if (_banner != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _banner!,
              key: const ValueKey('banner-tarik'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('isian-tarik-alasan'),
            controller: _alasan,
            enabled: !_sibuk,
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_galatAlasan != null) setState(() => _galatAlasan = null);
            },
            decoration: InputDecoration(
              labelText: l10n.tarikAlasanLabel,
              errorText: _galatAlasan,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('isian-tarik-sandi'),
            controller: _sandi,
            enabled: !_sibuk,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            onChanged: (_) {
              if (_galatSandi != null) setState(() => _galatSandi = null);
            },
            decoration: InputDecoration(
              labelText: l10n.tarikSandiLabel,
              errorText: _galatSandi,
              errorMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sibuk ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.custCancel),
        ),
        FilledButton(
          key: const ValueKey('kirim-tarik-sertifikat'),
          onPressed: _sibuk ? null : _kirim,
          child: _sibuk
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.tarikKirim),
        ),
      ],
    );
  }
}
