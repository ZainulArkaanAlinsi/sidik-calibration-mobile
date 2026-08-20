import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/import_excel.dart';
import '../../providers/import_provider.dart';
import '../../widgets/app_button.dart';
import '../auth/widgets/neu.dart';

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
      messenger.showSnackBar(SnackBar(content: Text(l10n.importBelumAdaFile)));
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
        messenger.showSnackBar(SnackBar(content: Text(l10n.importSelesai)));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.importGagal('$e'))));
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

    final c = NeuColors.of(context);

    return Scaffold(
      backgroundColor: c.base,
      appBar: AppBar(
        backgroundColor: c.base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text(
          l10n.importTitle,
          style: TextStyle(
            color: c.text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Pemilih tipe ditaruh di permukaan TENGGELAM (`NeuInset`) — di
          // soft-UI itu bahasa buat "ini kolom isian", sama kayak kolom di
          // layar Login. Kotak bergaris Material di tengah permukaan lembut
          // kelihatan kayak nempel dari aplikasi lain.
          NeuInset(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                initialValue: _tipeTerpilih,
                isExpanded: true,
                dropdownColor: c.base,
                // Diturunkan dari theme — lihat catatan panjang di
                // `blok_kondisi.dart`. `style` di sini MENGGANTI, jadi
                // `TextStyle` telanjang ngebuang fontFamily-nya.
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
                decoration: InputDecoration(
                  labelText: l10n.importPilihTipe,
                  labelStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                items: [
                  for (final t in _tipe)
                    DropdownMenuItem(
                      value: t,
                      child: Text(_labelTipe(l10n, t)),
                    ),
                ],
                onChanged: _sibuk
                    ? null
                    : (v) => setState(() {
                        _tipeTerpilih = v ?? _tipe.first;
                        _hasil = null;
                      }),
              ),
            ),
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
              style: TextStyle(fontSize: 11.5, color: c.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          AppButton(
            label: l10n.importUjiCoba,
            icon: Icons.fact_check_outlined,
            isLoading: _sibuk,
            onPressed: _filePath == null
                ? null
                : () => _jalankan(ujiCoba: true),
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
    final neu = NeuColors.of(context);

    return NeuRaised(
      radius: 20,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.importRingkasan.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: neu.accent,
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
                warna: AppColors.statusSukses(context),
              ),
              _Angka(
                label: l10n.importDiperbarui,
                nilai: hasil.diperbarui,
                warna: AppColors.statusInfo(context),
              ),
              _Angka(
                label: l10n.importDilewati,
                nilai: hasil.dilewati,
                warna: AppColors.statusPeringatan(context),
              ),
            ],
          ),

          if (hasil.kolomDiabaikan.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(height: 1, color: neu.darkShadow.withValues(alpha: 0.35)),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${l10n.importKolomDiabaikan}: '
              '${hasil.kolomDiabaikan.join(", ")}',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.statusPeringatan(context),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Container(height: 1, color: neu.darkShadow.withValues(alpha: 0.35)),
          const SizedBox(height: AppSpacing.md),
          for (final b in hasil.baris) _BarisHasil(baris: b),
        ],
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
    final c = warna ?? NeuColors.of(context).textMuted;

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
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c),
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
    final neu = NeuColors.of(context);

    final (ikon, warna) = switch (baris.tindakan) {
      TindakanImport.dibuat => (
        Icons.add_circle_outline,
        AppColors.statusSukses(context),
      ),
      TindakanImport.diperbarui => (Icons.sync, AppColors.statusInfo(context)),
      TindakanImport.dilewati => (
        Icons.remove_circle_outline,
        AppColors.statusPeringatan(context),
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
                  style: TextStyle(fontSize: 12.5, color: neu.text),
                ),
                if (baris.alasan != null)
                  Text(
                    baris.alasan!,
                    style: TextStyle(fontSize: 11.5, color: warna),
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
    final warna = peringatan
        ? AppColors.statusPeringatan(context)
        : NeuColors.of(context).textMuted;

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
            style: TextStyle(fontSize: 11.5, height: 1.45, color: warna),
          ),
        ),
      ],
    );
  }
}
