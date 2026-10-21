import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/tanggal_pendek.dart';
import '../../l10n/app_localizations.dart';
import '../../models/equipment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/equipment_provider.dart';
import '../../providers/jatuh_tempo_provider.dart';
import '../../services/ubah_jatuh_tempo_service.dart';

/// "Ubah jatuh tempo" (admin & super admin, izin `alat.ubah-jatuh-tempo`).
///
/// Sebelum menyimpan, dialog MENJELASKAN beda dua jalur server: alat dengan
/// sertifikat aktif → tanggal tercetak berubah → dibuat revisi `-R<n>`;
/// tanpa itu → jadwal alat berubah langsung. Jalur yang benar-benar terjadi
/// dibaca dari `jalur` pada jawaban, lalu diberitahukan lewat snackbar.
Future<void> tampilkanUbahJatuhTempo(
  BuildContext context,
  WidgetRef ref,
  Equipment alat,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  final hasil = await showDialog<HasilUbahJatuhTempo>(
    context: context,
    builder: (_) => _DialogUbahJatuhTempo(alat: alat),
  );
  if (hasil == null) return;

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        hasil.revisiSertifikat
            ? l10n.jtUbahBerhasilRevisi(hasil.nomorRevisi ?? '-R')
            : l10n.jtUbahBerhasilJadwal,
      ),
    ),
  );
  // Jadwal alat bisa baru berubah setelah PDF revisi terbit; tarik ulang saja
  // supaya daftar mengikuti server, bukan tebakan klien.
  ref.invalidate(jatuhTempoProvider);
}

class _DialogUbahJatuhTempo extends ConsumerStatefulWidget {
  const _DialogUbahJatuhTempo({required this.alat});

  final Equipment alat;

  @override
  ConsumerState<_DialogUbahJatuhTempo> createState() =>
      _DialogUbahJatuhTempoState();
}

class _DialogUbahJatuhTempoState extends ConsumerState<_DialogUbahJatuhTempo> {
  final _alasan = TextEditingController();
  DateTime? _tanggal;
  bool _kirim = false;
  String? _galatTanggal;
  String? _galatAlasan;
  String? _galatServer;

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final awal = _tanggal ?? widget.alat.tanggalJatuhTempo ?? DateTime.now();
    final dipilih = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (dipilih != null) {
      setState(() {
        _tanggal = dipilih;
        _galatTanggal = null;
      });
    }
  }

  Future<void> _simpan() async {
    final l10n = AppLocalizations.of(context);
    final alasan = _alasan.text.trim();
    setState(() {
      _galatTanggal = _tanggal == null ? l10n.jtUbahTanggalKosong : null;
      _galatAlasan = alasan.length < 5 ? l10n.jtUbahAlasanMin : null;
      _galatServer = null;
    });
    if (_tanggal == null || alasan.length < 5) return;

    setState(() => _kirim = true);
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw StateError('token hilang');
      final hasil = await ref
          .read(ubahJatuhTempoServiceProvider)
          .ubah(token, widget.alat.id, tanggal: _tanggal!, alasan: alasan);
      if (mounted) Navigator.of(context).pop(hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kirim = false;
        _galatServer = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.jtUbahJudul),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.alat.namaAlat, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.jtUbahDampak, style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.jtUbahDampakSertifikat,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.jtUbahDampakJadwal,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _kirim ? null : _pilihTanggal,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _tanggal == null
                    ? l10n.jtUbahPilihTanggal
                    : tanggalPendek(context, _tanggal),
              ),
            ),
            if (_galatTanggal != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _galatTanggal!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _alasan,
              enabled: !_kirim,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: l10n.jtUbahAlasan,
                errorText: _galatAlasan,
              ),
            ),
            if (_galatServer != null)
              Text(
                _galatServer!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _kirim ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.jtUbahBatal),
        ),
        FilledButton(
          onPressed: _kirim ? null : _simpan,
          child: _kirim
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.jtUbahSimpan),
        ),
      ],
    );
  }
}
