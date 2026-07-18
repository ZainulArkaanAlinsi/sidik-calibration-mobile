import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../models/certificate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import 'calibration_detail_screen.dart';

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
        const SizedBox(height: AppSpacing.lg),
        _Ringkasan(calibrationId: sertifikat.calibrationId),
        const SizedBox(height: AppSpacing.lg),

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

/// Ringkasan hasil (alat, standar dipakai, kondisi lingkungan, keputusan)
/// diambil dari `GET /api/calibrations/{id}` — sertifikat sendiri
/// (`docs/kontrak-api.md` §5) cuma punya nomor & link PDF, nggak bawa data
/// ini. Supplementer doang: kalau gagal dimuat, disembunyikan aja daripada
/// nge-block layar sertifikat yang sebenernya sukses.
class _Ringkasan extends ConsumerWidget {
  const _Ringkasan({required this.calibrationId});

  final int calibrationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(calibrationDetailProvider(calibrationId));
    final data = detail.value;

    if (detail.isLoading && data == null) {
      return const Column(
        children: [
          SkeletonBox(height: 16, width: 180),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(height: 90, width: double.infinity),
        ],
      );
    }

    if (data == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.certRingkasanTitle.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.namaAlat,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: data.keputusan == Keputusan.fail
                          ? l10n.historyStatusFail
                          : l10n.historyStatusPass,
                      tone: data.keputusan == Keputusan.fail
                          ? BadgeTone.danger
                          : BadgeTone.success,
                      icon: data.keputusan == Keputusan.fail
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (data.standarAcuan != null)
                  _RingkasanRow(
                    label: l10n.detailStandarAcuan,
                    value: data.standarAcuan!,
                  ),
                if (data.suhuRuang != null && data.kelembaban != null)
                  _RingkasanRow(
                    label: l10n.detailKondisiLingkungan,
                    value:
                        '${data.suhuRuang!.toStringAsFixed(1)} °C · '
                        '${data.kelembaban!.toStringAsFixed(1)} %RH',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.certLihatDetail,
          icon: Icons.list_alt_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CalibrationDetailScreen(calibrationId: calibrationId),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingkasanRow extends StatelessWidget {
  const _RingkasanRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
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
