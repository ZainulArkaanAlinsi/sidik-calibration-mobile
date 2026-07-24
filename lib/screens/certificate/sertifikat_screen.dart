import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/certificate_snapshot.dart';
import '../../providers/auth_provider.dart';
import '../../providers/certificate_provider.dart';
import '../../providers/history_provider.dart';
import '../../services/pdf_downloader.dart';
import '../../widgets/app_button.dart';

/// Pratinjau sertifikat (spesifikasi poin 9), plus unduh PDF/Excel & QR
/// (poin 10 & 13).
///
/// **Yang dirender cuma `snapshot`** — isi yang dibekukan waktu sertifikat
/// terbit. Nggak ada satu pun field tambahan di luar strukturnya, dan nggak
/// ada angka yang dihitung di sini. Itu yang bikin PDF, Excel, halaman
/// verifikasi QR, dan layar ini mustahil beda isi.
class SertifikatScreen extends ConsumerWidget {
  const SertifikatScreen({super.key, required this.certificateId});

  final int certificateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(certificateDetailProvider(certificateId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sertPratinjau)),
      body: switch (async) {
        AsyncData(:final value) => _Isi(sertifikat: value),
        AsyncError() => _Gagal(
          onCobaLagi: () =>
              ref.invalidate(certificateDetailProvider(certificateId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: async.value?.siap ?? false
          ? _BilahUnduh(sertifikat: async.value!)
          : null,
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.sertifikat});

  final CertificateDetail sertifikat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snap = sertifikat.snapshot;

    if (snap == null) {
      // PDF-nya belum jadi = snapshot-nya juga belum ada. Isinya dibekukan
      // waktu terbit, jadi nggak ada yang bisa ditampilin selain statusnya.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.sertBelumTerbit, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (snap.gagal) ...[
          _PitaFail(),
          const SizedBox(height: AppSpacing.md),
        ],

        // Header — 16 field, urutannya persis sertifikat cetak.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, nilai) in snap.header.baris())
                  _BarisHeader(label: label, nilai: nilai),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _TabelHasil(snapshot: snap),
        const SizedBox(height: AppSpacing.md),

        // Dua catatan baku — datang dari backend, bukan ditulis ulang di sini.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in snap.catatan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '• $c',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _TabelStandar(standar: snap.standarDigunakan),
        const SizedBox(height: AppSpacing.md),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BarisHeader(
                  label: l10n.sertFooterTerbit,
                  nilai: snap.footer.issuanceDate,
                ),
                _BarisHeader(
                  label: l10n.sertFooterTtd,
                  nilai: snap.footer.penandatangan,
                ),
                _BarisHeader(
                  label: l10n.sertFooterJabatan,
                  nilai: snap.footer.jabatan,
                ),
                _BarisHeader(
                  label: l10n.sertFooterKode,
                  nilai: snap.footer.kodeDokumen,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(
          l10n.sertCorrectionCatatan,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _PitaFail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, size: 20, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // Sesi FAIL tetap terbit sertifikatnya — isinya "tidak laik
              // pakai". Yang beda keputusannya, bukan boleh/nggaknya terbit.
              'FAIL — alat tidak laik pakai',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisHeader extends StatelessWidget {
  const _BarisHeader({required this.label, required this.nilai});

  final String label;
  final String? nilai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          Text(': ', style: theme.textTheme.labelSmall),
          Expanded(
            child: Text(
              (nilai == null || nilai!.isEmpty) ? '—' : nilai!,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tabel hasil — **empat kolom, nggak lebih** (spesifikasi poin 9).
class _TabelHasil extends StatelessWidget {
  const _TabelHasil({required this.snapshot});

  final CertificateSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = snapshot.desimal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sertHasilJudul,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.1),
                1: FlexColumnWidth(1.1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    _sel(context, l10n.sertKolStandard, tebal: true),
                    _sel(context, l10n.sertKolUut, tebal: true),
                    _sel(context, l10n.sertKolCorrection, tebal: true),
                    _sel(context, l10n.sertKolU95, tebal: true),
                  ],
                ),
                for (final b in snapshot.hasil)
                  TableRow(
                    children: [
                      // Jumlah desimalnya ditentukan backend dari resolusi
                      // alatnya — jangan dipatok di layar.
                      _sel(context, b.standardValue.toStringAsFixed(d)),
                      _sel(context, b.unitUnderTest.toStringAsFixed(d)),
                      _sel(context, b.correction.toStringAsFixed(d)),
                      _sel(context, b.u95.toStringAsFixed(d)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sel(BuildContext context, String teks, {bool tebal = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: Text(
        teks,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: tebal ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _TabelStandar extends StatelessWidget {
  const _TabelStandar({required this.standar});

  final List<StandarDigunakan> standar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (standar.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sertStandarJudul,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final s in standar)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name ?? '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        s.merkType,
                        s.serialNumber,
                        s.traceableTo,
                      ].whereType<String>().join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tiga bentuk unduhan dari sertifikat yang sama: PDF (kirim resmi ke klien),
/// Excel (arsip/rekap), QR (akses cepat) — spesifikasi poin 10 & 13.
class _BilahUnduh extends ConsumerStatefulWidget {
  const _BilahUnduh({required this.sertifikat});

  final CertificateDetail sertifikat;

  @override
  ConsumerState<_BilahUnduh> createState() => _BilahUnduhState();
}

class _BilahUnduhState extends ConsumerState<_BilahUnduh> {
  bool _sibuk = false;

  Future<void> _unduh(String url, String namaFile, {bool buka = true}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null || !mounted) return;

    setState(() => _sibuk = true);
    try {
      // File-nya di disk privat backend dan butuh header Authorization —
      // nggak bisa dibuka langsung di browser HP.
      final path = await ref
          .read(pdfDownloaderProvider)
          .unduh(token, url, namaFile: namaFile);

      if (!buka) {
        _tampilkanQr(path);
        return;
      }

      final hasil = await OpenFilex.open(path);
      if (hasil.type != ResultType.done && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.sertUnduhGagal(hasil.message))),
        );
      }
    } on PdfDownloadException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.sertUnduhGagal(e.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  void _tampilkanQr(String path) {
    final l10n = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sertQrJudul),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QR-nya digambar BACKEND — mobile cuma nampilin PNG-nya, jadi
            // isi yang di-encode nggak mungkin beda dari halaman verifikasi.
            Image.file(File(path), width: 200, height: 200),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.sertQrBody, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.folderBatal),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final svc = ref.read(certificateServiceProvider);
    final id = widget.sertifikat.id;
    final nomor = widget.sertifikat.nomor;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.sertUnduhPdf,
                  icon: Icons.picture_as_pdf_outlined,
                  isLoading: _sibuk,
                  onPressed: () => _unduh(svc.urlPdf(id), '$nomor.pdf'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: l10n.sertUnduhExcel,
                  icon: Icons.table_chart_outlined,
                  variant: AppButtonVariant.secondary,
                  isLoading: _sibuk,
                  onPressed: () => _unduh(svc.urlExcel(id), '$nomor.xlsx'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: l10n.sertLihatQr,
                  icon: Icons.qr_code_2,
                  variant: AppButtonVariant.secondary,
                  isLoading: _sibuk,
                  onPressed: () =>
                      _unduh(svc.urlQr(id), '$nomor-qr.png', buka: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
          l10n.sertGagalMuat,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.folderRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
