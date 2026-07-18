import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_detail.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/history_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import 'certificate_screen.dart';

String _fmt(double? v, {int decimals = 4}) =>
    v == null ? '—' : v.toStringAsFixed(decimals);

/// Detail satu sesi kalibrasi — breakdown per titik ukur (rata-rata, error,
/// koreksi, Type A/B, ketidakpastian diperluas, keputusan PASS/FAIL), sama
/// persis kayak yang ditampilin sheet "PERHITUNGAN" di master worksheet.
///
/// **Nggak ada rumus GUM di sini** — semua angka datang mentah-mentah dari
/// `GET /api/calibrations/{id}` (`docs/kontrak-api.md` §4). Kalau sesi belum
/// dihitung backend (`draft` / lagi antre), tabel titik kosong dan layar
/// nampilin pesan "belum dihitung" — bukan spinner selamanya.
class CalibrationDetailScreen extends ConsumerWidget {
  const CalibrationDetailScreen({super.key, required this.calibrationId});

  final int calibrationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(calibrationDetailProvider(calibrationId));
    final l10n = AppLocalizations.of(context);

    final data = detail.value;

    final Widget isi;
    if (data != null) {
      isi = _Isi(detail: data);
    } else if (detail.hasError) {
      isi = _Gagal(
        onCobaLagi: () =>
            ref.invalidate(calibrationDetailProvider(calibrationId)),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.detailTitle)),
      body: isi,
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.detail});

  final CalibrationDetail detail;

  StatusBadge _statusBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (detail.status == CalibrationStatus.disetujui) {
      return switch (detail.keputusan) {
        Keputusan.fail => StatusBadge(
          label: l10n.historyStatusFail,
          tone: BadgeTone.danger,
          icon: Icons.cancel_outlined,
        ),
        _ => StatusBadge(
          label: l10n.historyStatusPass,
          tone: BadgeTone.success,
          icon: Icons.check_circle_outline,
        ),
      };
    }

    return switch (detail.status) {
      CalibrationStatus.draft => StatusBadge(
        label: l10n.historyStatusDraft,
        tone: BadgeTone.neutral,
        icon: Icons.edit_note,
      ),
      CalibrationStatus.menungguApproval => StatusBadge(
        label: l10n.historyStatusMenungguApproval,
        tone: BadgeTone.info,
        icon: Icons.hourglass_empty,
      ),
      CalibrationStatus.perluRevisi => StatusBadge(
        label: l10n.historyStatusPerluRevisi,
        tone: BadgeTone.warning,
        icon: Icons.edit_outlined,
      ),
      CalibrationStatus.disetujui => throw StateError('unreachable'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final tanggal = DateFormat(
      'd MMMM yyyy',
      locale,
    ).format(detail.tanggalKalibrasi);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.namaAlat,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${detail.namaTeknisi} · $tanggal',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (detail.nomorSesi != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.detailNomorSesi(detail.nomorSesi!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _statusBadge(context),
          ],
        ),

        if (detail.status == CalibrationStatus.perluRevisi &&
            detail.catatanRevisi != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: Text(l10n.historyCatatanRevisi(detail.catatanRevisi!)),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.detailKondisiLingkungan.toUpperCase(),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail.standarAcuan != null)
                  _InfoRow(
                    label: l10n.detailStandarAcuan,
                    value: detail.standarAcuan!.nama,
                  ),
                if (detail.suhuRuang != null)
                  _InfoRow(
                    label: l10n.detailSuhuRuang,
                    value: '${_fmt(detail.suhuRuang, decimals: 1)} °C',
                  ),
                if (detail.kelembaban != null)
                  _InfoRow(
                    label: l10n.detailKelembaban,
                    value: '${_fmt(detail.kelembaban, decimals: 1)} %RH',
                  ),
                if (detail.lokasi != null)
                  _InfoRow(
                    label: l10n.detailLokasi,
                    value: detail.lokasi == 'onsite'
                        ? l10n.detailLokasiOnsite
                        : l10n.detailLokasiLab,
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.detailTitikUkurTitle.toUpperCase(),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),

        if (detail.titik.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(l10n.detailBelumDihitung)),
              ],
            ),
          )
        else
          for (final titik in detail.titik) ...[
            _TitikResultCard(
              titik: titik,
              pembacaan: detail.pembacaanMentah
                  .where((p) => p.titikKe == titik.titikKe)
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

        if (detail.certificateId != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.detailLihatSertifikat,
            icon: Icons.workspace_premium_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    CertificateScreen(certificateId: detail.certificateId!),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TitikResultCard extends StatelessWidget {
  const _TitikResultCard({required this.titik, this.pembacaan = const []});

  final MeasurementResult titik;
  final List<RawMeasurement> pembacaan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pass = titik.keputusan == Keputusan.pass;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.detailTitikLabel(
                      titik.titikKe,
                      _fmt(titik.titikUkur, decimals: 2),
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge(
                  label: pass ? l10n.historyStatusPass : l10n.historyStatusFail,
                  tone: pass ? BadgeTone.success : BadgeTone.danger,
                  icon: pass ? Icons.check_circle_outline : Icons.cancel_outlined,
                ),
              ],
            ),
            if (titik.standarAcuan != null) ...[
              const SizedBox(height: 2),
              Text(
                titik.standarAcuan!.nama,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (pembacaan.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                pembacaan.map((p) => _fmt(p.pembacaan, decimals: 3)).join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: l10n.detailRataRata,
              value: _fmt(titik.rataRata, decimals: 3),
            ),
            _InfoRow(label: l10n.detailError, value: _fmt(titik.error)),
            _InfoRow(label: l10n.detailKoreksi, value: _fmt(titik.koreksi)),
            _InfoRow(
              label: l10n.detailStandarDeviasi,
              value:
                  '${_fmt(titik.standarDeviasi)} (n=${titik.jumlahPengulangan})',
            ),
            _InfoRow(label: l10n.detailTypeA, value: _fmt(titik.typeA)),
            _InfoRow(label: l10n.detailTypeB, value: _fmt(titik.typeB)),
            if (titik.typeBComponents.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.detailKomponenTypeB,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    for (final komponen in titik.typeBComponents)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '• ${komponen.keterangan}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const Divider(height: AppSpacing.lg),
            _InfoRow(
              label: l10n.detailToleransi,
              value: '± ${_fmt(titik.toleransi)}',
            ),
            _InfoRow(
              label: l10n.detailKetidakpastianGabungan,
              value: _fmt(titik.ketidakpastianGabungan),
            ),
            _InfoRow(
              label: l10n.detailFaktorCakupan,
              value: _fmt(titik.faktorCakupanK, decimals: 2),
            ),
            _InfoRow(
              label: l10n.detailU95,
              value: '± ${_fmt(titik.ketidakpastianDiperluas)}',
            ),
          ],
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
          l10n.detailLoadFailed,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SkeletonBox(height: 24, width: 200),
        const SizedBox(height: AppSpacing.xs),
        const SkeletonBox(height: 14, width: 140),
        const SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 90, width: double.infinity),
        const SizedBox(height: AppSpacing.md),
        SkeletonBox(height: 160, width: double.infinity),
      ],
    );
  }
}
