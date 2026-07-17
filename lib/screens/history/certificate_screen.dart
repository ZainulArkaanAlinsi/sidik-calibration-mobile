import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/certificate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';

/// Detail sertifikat — dibuka dari kartu Riwayat yang statusnya `disetujui`.
/// Nggak nampilin `pdf_url` di `WebView`: cukup tombol yang buka link-nya di
/// browser HP, biar nggak nambah dependency baru buat satu layar ini.
class CertificateScreen extends ConsumerWidget {
  const CertificateScreen({super.key, required this.certificateId});

  final int certificateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sertifikat = ref.watch(certificateProvider(certificateId));
    final l10n = AppLocalizations.of(context);

    // Data dulu, baru error, baru loading — sama urutannya kayak
    // dashboard_screen.dart, biar retry otomatis Riverpod yang jalan di
    // belakang layar nggak nyangkutin skeleton selamanya.
    final data = sertifikat.value;

    final Widget isi;
    if (data != null) {
      isi = _Isi(sertifikat: data);
    } else if (sertifikat.hasError) {
      isi = _Gagal(
        onCobaLagi: () => ref.invalidate(certificateProvider(certificateId)),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.certTitle)),
      body: isi,
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.sertifikat});

  final Certificate sertifikat;

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null || !context.mounted) return;

    try {
      await ref
          .read(approvalServiceProvider)
          .retryGenerate(token, sertifikat.id);
    } finally {
      ref.invalidate(certificateProvider(sertifikat.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: Icon(
            Icons.workspace_premium_outlined,
            size: 72,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          sertifikat.nomor,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (sertifikat.status == CertificateStatus.menungguGenerate) ...[
          _StatusBanner(
            icon: Icons.hourglass_empty,
            warna: AppColors.info,
            pesan: l10n.certStatusMenungguGenerate,
          ),
        ] else if (sertifikat.status == CertificateStatus.gagal) ...[
          _StatusBanner(
            icon: Icons.error_outline,
            warna: theme.colorScheme.error,
            pesan: l10n.certStatusGagal,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.certRetry,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: () => _retry(context, ref),
          ),
        ] else if (sertifikat.pdfUrl != null) ...[
          AppButton(
            label: l10n.certOpenPdf,
            icon: Icons.copy_outlined,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: sertifikat.pdfUrl!));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.certPdfUrlCopied)));
            },
          ),
        ],

        if (sertifikat.qrToken != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.certQrToken(sertifikat.qrToken!),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.warna,
    required this.pesan,
  });

  final IconData icon;
  final Color warna;
  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: warna.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: warna),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(pesan)),
        ],
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
          l10n.certLoadFailed,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.historyRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Center(child: SkeletonBox(height: 72, width: 72)),
        const SizedBox(height: AppSpacing.md),
        const Center(child: SkeletonBox(height: 22, width: 180)),
      ],
    );
  }
}
