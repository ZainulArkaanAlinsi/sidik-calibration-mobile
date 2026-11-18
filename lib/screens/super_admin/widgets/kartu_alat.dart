import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/alat_pelanggan.dart';
import 'format_sa.dart';
import 'lencana_status_alat.dart';

/// Ringkasan satu alat pelanggan: nama, merek/model, nomor seri, status,
/// jadwal kalibrasi ulang, jumlah sertifikat, sertifikat terbaru. Dengan
/// [saatTekan] kartunya membuka riwayat sertifikat alat itu; tanpa itu dipakai
/// sebagai kepala layar riwayat (atau kartu biasa bila akunnya tidak berhak
/// melihat riwayat).
class KartuAlatRingkas extends StatelessWidget {
  const KartuAlatRingkas({super.key, required this.alat, this.saatTekan});

  final AlatRingkas alat;
  final VoidCallback? saatTekan;

  /// "10 Feb 2027 · 14 hari lagi" / "· terlambat 12 hari". Hari dihitung
  /// SERVER (`hari_ke_jatuh_tempo`), bukan di sini.
  String _jadwal(BuildContext context, AppLocalizations l10n) {
    if (alat.jatuhTempo == null) return l10n.saAlatTanpaJadwal;
    final tanggal = l10n.saAlatJadwal(tanggalSa(context, alat.jatuhTempo));
    final hari = alat.hariKeJatuhTempo;
    if (hari == null) return tanggal;
    final sisa = hari == 0
        ? l10n.saAlatHariIni
        : (hari > 0 ? l10n.saAlatHariLagi(hari) : l10n.saAlatTerlambat(-hari));
    return '$tanggal · $sisa';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final redup = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    final merkModel = [
      if (alat.merk.trim().isNotEmpty) alat.merk.trim(),
      if (alat.model.trim().isNotEmpty) alat.model.trim(),
    ].join(' · ');
    final terbaru = alat.sertifikatTerbaru;

    final isi = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alat.nama.trim().isEmpty ? '-' : alat.nama,
                      style: tema.textTheme.titleSmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (merkModel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        merkModel,
                        style: redup,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      alat.nomorSeri.trim().isEmpty
                          ? l10n.saAlatTanpaSeri
                          : l10n.saAlatSeri(alat.nomorSeri),
                      style: redup?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (saatTekan != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: Icon(
                    Icons.chevron_right,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LencanaStatusAlat(alat: alat),
              Text(
                l10n.saAlatJumlahSert(alat.jumlahSertifikat),
                style: tema.textTheme.labelMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_jadwal(context, l10n), style: redup),
          if (terbaru != null && terbaru.nomor.isNotEmpty)
            Text(
              l10n.saAlatTerbaru(terbaru.nomor),
              style: redup,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );

    return Card(
      key: Key('alat-${alat.id}'),
      child: saatTekan == null
          ? isi
          : MergeSemantics(
              child: Semantics(
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  onTap: saatTekan,
                  child: isi,
                ),
              ),
            ),
    );
  }
}
