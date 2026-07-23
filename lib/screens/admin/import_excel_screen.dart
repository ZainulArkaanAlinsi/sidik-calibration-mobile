import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/import_excel.dart';
import '../../providers/import_provider.dart';
import '../../widgets/app_button.dart';

/// Import Excel buat masa transisi (spesifikasi poin 12C).
///
/// **Dua langkah, dan itu disengaja**: unggah → uji coba → baca ringkasannya →
/// baru terapkan. Satu tombol yang langsung nulis ke database dari file Excel
/// orang lain itu cara paling cepat ngerusak master data, dan yang rusak baru
/// ketahuan berminggu-minggu kemudian waktu ada sertifikat yang datanya aneh.
///
/// Uji coba di server tetap NULIS beneran dulu lalu di-rollback — cuma dengan
/// begitu "sudah ada / belum" & error constraint kelihatan apa adanya, bukan
/// ditebak.
class ImportExcelScreen extends ConsumerStatefulWidget {
  const ImportExcelScreen({super.key});

  @override
  ConsumerState<ImportExcelScreen> createState() => _ImportExcelScreenState();
}

class _ImportExcelScreenState extends ConsumerState<ImportExcelScreen> {
  /// Urutannya sengaja: pelanggan → standar → alat. Alat butuh PT-nya udah ada.
  static const _tipe = ['customers', 'standards', 'equipments'];

  String _tipeTerpilih = _tipe.first;
  String? _filePath;
  String? _fileNama;
  HasilImport? _hasil;
  bool _sibuk = false;

  Future<void> _pilihFile() async {
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
    );

    final path = hasil?.files.single.path;
    if (path == null) return;

    setState(() {
      _filePath = path;
      _fileNama = hasil!.files.single.name;
      // File ganti = ringkasan lama nggak berlaku lagi. Kalau dibiarin, admin
      // bisa nekan "Terapkan" sambil ngeliat ringkasan file sebelumnya.
      _hasil = null;
    });
  }

  Future<void> _jalankan({required bool ujiCoba}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final path = _filePath;
    if (path == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importBelumAdaFile)),
      );
      return;
    }

    setState(() => _sibuk = true);
    try {
      final hasil = await ref
          .read(importControllerProvider)
          .jalankan(filePath: path, tipe: _tipeTerpilih, ujiCoba: ujiCoba);

      if (!mounted) return;
      setState(() => _hasil = hasil);

      if (!ujiCoba) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.importSelesai)),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.importGagal('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasil = _hasil;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _tipeTerpilih,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.importPilihTipe,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final t in _tipe)
                DropdownMenuItem(value: t, child: Text(_labelTipe(l10n, t))),
            ],
            onChanged: _sibuk
                ? null
                : (v) => setState(() {
                    _tipeTerpilih = v ?? _tipe.first;
                    _hasil = null;
                  }),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Catatan(teks: l10n.importUrutanCatatan),
          const SizedBox(height: AppSpacing.lg),

          AppButton(
            label: l10n.importPilihFile,
            icon: Icons.upload_file_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: _sibuk ? null : _pilihFile,
          ),
          if (_fileNama != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.importFileTerpilih(_fileNama!),
              style: theme.textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          AppButton(
            label: l10n.importUjiCoba,
            icon: Icons.fact_check_outlined,
            isLoading: _sibuk,
            onPressed: _filePath == null ? null : () => _jalankan(ujiCoba: true),
          ),

          if (hasil != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Ringkasan(hasil: hasil),
            const SizedBox(height: AppSpacing.md),

            // Tombol terapkan cuma muncul SESUDAH uji coba, dan cuma kalau
            // emang ada yang berubah — nggak ada jalan pintas dari "pilih
            // file" langsung ke "tulis ke database".
            if (hasil.ujiCoba)
              AppButton(
                label: l10n.importTerapkan,
                icon: Icons.save_outlined,
                isLoading: _sibuk,
                onPressed: hasil.adaPerubahan
                    ? () => _jalankan(ujiCoba: false)
                    : null,
              )
            else
              AppButton(
                label: l10n.importUlangi,
                icon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                onPressed: _sibuk ? null : _pilihFile,
              ),

            if (hasil.ujiCoba && !hasil.adaPerubahan) ...[
              const SizedBox(height: AppSpacing.sm),
              _Catatan(teks: l10n.importTanpaPerubahan),
            ],
          ],

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  static String _labelTipe(AppLocalizations l10n, String tipe) =>
      switch (tipe) {
        'customers' => l10n.importTipeCustomers,
        'standards' => l10n.importTipeStandards,
        _ => l10n.importTipeEquipments,
      };
}

class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.hasil});

  final HasilImport hasil;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.importRingkasan,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (hasil.ujiCoba) ...[
              _Catatan(teks: l10n.importUjiCobaCatatan, peringatan: true),
              const SizedBox(height: AppSpacing.sm),
            ],

            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _Angka(label: l10n.importDibaca, nilai: hasil.dibaca),
                _Angka(
                  label: l10n.importDibuat,
                  nilai: hasil.dibuat,
                  warna: AppColors.success,
                ),
                _Angka(
                  label: l10n.importDiperbarui,
                  nilai: hasil.diperbarui,
                  warna: AppColors.info,
                ),
                _Angka(
                  label: l10n.importDilewati,
                  nilai: hasil.dilewati,
                  warna: AppColors.warning,
                ),
              ],
            ),

            if (hasil.kolomDiabaikan.isNotEmpty) ...[
              const Divider(height: AppSpacing.lg),
              Text(
                '${l10n.importKolomDiabaikan}: '
                '${hasil.kolomDiabaikan.join(", ")}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],

            const Divider(height: AppSpacing.lg),
            for (final b in hasil.baris) _BarisHasil(baris: b),
          ],
        ),
      ),
    );
  }
}

class _Angka extends StatelessWidget {
  const _Angka({required this.label, required this.nilai, this.warna});

  final String label;
  final int nilai;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = warna ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        '$nilai $label',
        style: theme.textTheme.labelSmall?.copyWith(color: c),
      ),
    );
  }
}

class _BarisHasil extends StatelessWidget {
  const _BarisHasil({required this.baris});

  final BarisImport baris;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final (ikon, warna) = switch (baris.tindakan) {
      TindakanImport.dibuat => (Icons.add_circle_outline, AppColors.success),
      TindakanImport.diperbarui => (Icons.sync, AppColors.info),
      TindakanImport.dilewati => (
        Icons.remove_circle_outline,
        AppColors.warning,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 15, color: warna),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Nomor barisnya ditulis biar admin tau persis mana yang
                  // harus dibenerin di file Excel-nya.
                  '${l10n.importBarisKe(baris.baris)} · ${baris.nama ?? "—"}',
                  style: theme.textTheme.bodySmall,
                ),
                if (baris.alasan != null)
                  Text(
                    baris.alasan!,
                    style: theme.textTheme.labelSmall?.copyWith(color: warna),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Catatan extends StatelessWidget {
  const _Catatan({required this.teks, this.peringatan = false});

  final String teks;
  final bool peringatan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warna = peringatan
        ? AppColors.warning
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          peringatan ? Icons.warning_amber_outlined : Icons.info_outline,
          size: 14,
          color: warna,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            teks,
            style: theme.textTheme.labelSmall?.copyWith(color: warna),
          ),
        ),
      ],
    );
  }
}
