import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';
import '../providers/certificate_provider.dart';
import 'app_button.dart';

/// Isi sertifikat = PDF server yang sama dengan tombol Unduh (G4). Struktur
/// per jenis alat (lembar SERTIFIKAT) otomatis identik; app tidak merakit ulang.
/// Zoom/geser dari penampil; muat ulang lewat tombol saat gagal.
class SertifikatPdfView extends ConsumerWidget {
  const SertifikatPdfView({super.key, required this.certificateId});

  final int certificateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(pdfSertifikatProvider(certificateId));

    return switch (async) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (value.dariCache)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                l10n.sertPdfLuring,
                key: const ValueKey('pdf-sertifikat-luring'),
                style: theme.textTheme.labelSmall,
              ),
            ),
          Expanded(
            child: PdfViewer.data(
              Uint8List.fromList(value.bytes),
              key: const ValueKey('pdf-sertifikat-viewer'),
              sourceName: 'sertifikat-$certificateId.pdf',
            ),
          ),
        ],
      ),
      AsyncError() => Center(
        key: const ValueKey('pdf-sertifikat-gagal'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.sertPdfGagal, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: l10n.folderRetry,
                icon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    ref.invalidate(pdfSertifikatProvider(certificateId)),
              ),
            ],
          ),
        ),
      ),
      _ => const _KerangkaPdf(),
    };
  }
}

/// Kerangka halaman A4 statis (tanpa animasi, aman buat pumpAndSettle) sebagai pengganti penampil selama memuat.
class _KerangkaPdf extends StatelessWidget {
  const _KerangkaPdf();

  @override
  Widget build(BuildContext context) {
    final warna = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Center(
      key: const ValueKey('pdf-sertifikat-memuat'),
      child: AspectRatio(
        aspectRatio: 1 / 1.414,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: warna,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(
            Icons.picture_as_pdf_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
