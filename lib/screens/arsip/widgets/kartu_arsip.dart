import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_ukuran.dart';
import '../../../core/theme/sidik_material.dart';
import '../../../core/utils/susun_daftar_arsip.dart';
import '../../../core/utils/tanggal_pendek.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/calibration_history_item.dart';
import '../../../models/garis_waktu_arsip.dart';
import '../../../widgets/status_badge.dart';

/// Lencana status SERTIFIKAT (`terbit`, `dibatalkan`, `ditarik`, …).
///
/// Status yang belum dikenal APK ini tampil apa adanya dengan nada netral:
/// sertifikat batal yang kebaca "Terbit" jauh lebih mahal daripada lencana
/// bertulisan kode mentah. Tiap lencana membawa ikon DAN kata, jadi tidak
/// bergantung pada warna.
StatusBadge lencanaStatusSertifikat(AppLocalizations l10n, String status) =>
    switch (status) {
      'terbit' => StatusBadge(
        label: l10n.riwayatSertifikatTerbit,
        tone: BadgeTone.success,
        icon: Icons.workspace_premium_outlined,
      ),
      'dibatalkan' => StatusBadge(
        label: l10n.riwayatSertifikatDibatalkan,
        tone: BadgeTone.danger,
        icon: Icons.block,
      ),
      'ditarik' => StatusBadge(
        label: l10n.statusDitarik,
        tone: BadgeTone.warning,
        icon: Icons.undo,
      ),
      'menunggu_generate' => StatusBadge(
        label: l10n.riwayatSertifikatDiproses,
        tone: BadgeTone.info,
        icon: Icons.hourglass_empty,
      ),
      'gagal' => StatusBadge(
        label: l10n.riwayatSertifikatGagal,
        tone: BadgeTone.danger,
        icon: Icons.error_outline,
      ),
      final lain => StatusBadge(
        label: lain,
        tone: BadgeTone.neutral,
        icon: Icons.help_outline,
      ),
    };

String _kodeStatusSesi(CalibrationStatus status) => switch (status) {
  CalibrationStatus.draft => 'draft',
  CalibrationStatus.menungguApproval => 'menunggu_approval',
  CalibrationStatus.disetujui => 'disetujui',
  CalibrationStatus.perluRevisi => 'perlu_revisi',
};

/// Tepi aksen untuk baris yang detailnya sedang terbuka di panel kanan.
///
/// Bentuk (tepi tebal) DAN `Semantics(selected)` — bukan warna saja. Warnanya
/// `biruTinta`: biru untuk tepi/teks di atas permukaan (di tema gelap biru
/// tombol hanya 2,4:1).
BorderSide _tepiSorot(BuildContext context, bool disorot) => disorot
    ? BorderSide(
        color: SidikMaterial.of(context).biruTinta,
        width: AppUkuran.garisTebal,
      )
    : BorderSide.none;

/// Judul satu PT. Tebal dan berwarna aksen, dengan garis di bawahnya, supaya
/// batas antar-PT terbaca sekali lihat, bukan tersamar di antara kartu-kartu
/// yang mirip.
class JudulPtArsip extends StatelessWidget {
  const JudulPtArsip({super.key, required this.nama});

  /// Null = baris tanpa pelanggan.
  final String? nama;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final aksen = SidikMaterial.of(context).biruTinta;

    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.apartment_outlined,
                    size: AppUkuran.ikonSebaris,
                    color: aksen,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    nama ?? l10n.gwTanpaPt,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: aksen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Divider(
              height: AppUkuran.garisTebal,
              thickness: AppUkuran.garisTebal,
              color: aksen,
            ),
          ],
        ),
      ),
    );
  }
}

/// Judul satu hari di tingkat `hari`; label dan jumlah dari server.
class JudulHariArsip extends StatelessWidget {
  const JudulHariArsip({super.key, required this.kelompok});

  final KelompokGarisWaktu kelompok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                kelompok.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              l10n.gwJumlahDokumen(kelompok.jumlah),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu tahun/bulan/pekan di garis waktu. Ketuk = buka tingkat di bawahnya.
class KartuKelompokWaktu extends StatelessWidget {
  const KartuKelompokWaktu({
    super.key,
    required this.kelompok,
    required this.onTap,
  });

  final KelompokGarisWaktu kelompok;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppUkuran.sasaranSentuh),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    kelompok.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.gwJumlahDokumen(kelompok.jumlah),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (onTap != null)
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu sertifikat di tingkat `hari`.
class KartuSertifikatWaktu extends StatelessWidget {
  const KartuSertifikatWaktu({
    super.key,
    required this.item,
    required this.disorot,
    required this.onTap,
  });

  final ItemGarisWaktu item;
  final bool disorot;

  /// Null kalau dokumen tidak punya sesi asal untuk dibuka.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final redup = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Semantics(
      selected: disorot,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: _tepiSorot(context, disorot),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nomor,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    // Nomor yang dibatalkan tetap terbaca (untuk dicocokkan
                    // ke arsip), tapi dicoret DAN berlencana — bukan warna
                    // saja.
                    decoration: item.status == 'dibatalkan'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.status.isNotEmpty)
                      lencanaStatusSertifikat(l10n, item.status),
                  ],
                ),
                if (item.namaAlat != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(item.namaAlat!, style: theme.textTheme.bodyMedium),
                ],
                if (item.nomorSeri != null)
                  Text(l10n.gwNoSeri(item.nomorSeri!), style: redup),
                if (item.nomorOrder != null)
                  Text(l10n.gwOrder(item.nomorOrder!), style: redup),
                if (item.tanggal != null)
                  Text(
                    l10n.gwTglTerbit(tanggalPendek(context, item.tanggal)),
                    style: redup,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu alat di hasil cari: sesi wakil, dan (bila ada) sesi lain alat yang
/// sama dilipat di bawahnya.
class KartuInstrumenArsip extends StatelessWidget {
  const KartuInstrumenArsip({
    super.key,
    required this.instrumen,
    required this.terbuka,
    required this.terpilihId,
    required this.onToggle,
    required this.onPilih,
  });

  final KelompokInstrumen instrumen;

  /// Sesi lain sedang dibentangkan.
  final bool terbuka;

  /// Sesi yang detailnya sedang tampil di panel kanan.
  final int? terpilihId;
  final VoidCallback onToggle;
  final void Function(CalibrationHistoryItem sesi) onPilih;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lainnya = instrumen.lainnya;

    return Semantics(
      selected: terpilihId == instrumen.wakil.id,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: _tepiSorot(context, terpilihId == instrumen.wakil.id),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IsiSesi(
              sesi: instrumen.wakil,
              onTap: () => onPilih(instrumen.wakil),
            ),
            if (lainnya.isNotEmpty) ...[
              const Divider(height: AppUkuran.garis),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppUkuran.sasaranSentuh),
                ),
                onPressed: onToggle,
                icon: Icon(terbuka ? Icons.expand_less : Icons.expand_more),
                label: Text(
                  terbuka
                      ? l10n.gwTutupRiwayatLain
                      : l10n.gwSesiLain(lainnya.length),
                ),
              ),
              if (terbuka)
                for (final sesi in lainnya)
                  _BarisSesiLain(
                    sesi: sesi,
                    disorot: sesi.id == terpilihId,
                    onTap: () => onPilih(sesi),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Isi lengkap satu sesi: alat, nomor, seri, order, tanggal, lencana.
class _IsiSesi extends StatelessWidget {
  const _IsiSesi({required this.sesi, required this.onTap});

  final CalibrationHistoryItem sesi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final redup = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final nomor = sesi.nomorSertifikat ?? sesi.nomorSesi;
    final batal = sesi.statusSertifikat == 'dibatalkan';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sesi.namaAlat,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (nomor != null)
              Text(
                nomor,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: batal ? TextDecoration.lineThrough : null,
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            // Wrap, bukan Row: lencana "Menunggu approval" tidak muat di
            // samping judul pada HP 320 dp.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _lencanaStatus(l10n, sesi),
                ..._lencanaKeputusan(sesi),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (sesi.nomorSeri != null)
              Text(l10n.gwNoSeri(sesi.nomorSeri!), style: redup),
            if (sesi.nomorOrder != null)
              Text(l10n.gwOrder(sesi.nomorOrder!), style: redup),
            Text(
              [
                if (sesi.tanggalKalibrasi != null)
                  l10n.gwTglKalibrasi(
                    tanggalPendek(context, sesi.tanggalKalibrasi),
                  ),
                sesi.namaTeknisi,
              ].join(' · '),
              style: redup,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sesi lain alat yang sama, versi ringkas.
class _BarisSesiLain extends StatelessWidget {
  const _BarisSesiLain({
    required this.sesi,
    required this.disorot,
    required this.onTap,
  });

  final CalibrationHistoryItem sesi;
  final bool disorot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final nomor = sesi.nomorSertifikat ?? sesi.nomorSesi ?? sesi.namaAlat;
    final batal = sesi.statusSertifikat == 'dibatalkan';

    return Semantics(
      selected: disorot,
      child: Container(
        decoration: BoxDecoration(
          border: disorot
              ? Border.fromBorderSide(_tepiSorot(context, true))
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppUkuran.sasaranSentuh,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nomor,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: batal ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _lencanaStatus(l10n, sesi),
                      if (sesi.tanggalKalibrasi != null)
                        Text(
                          l10n.gwTglKalibrasi(
                            tanggalPendek(context, sesi.tanggalKalibrasi),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status sertifikat kalau sudah ada, selain itu status sesi.
Widget _lencanaStatus(AppLocalizations l10n, CalibrationHistoryItem sesi) {
  final sertifikat = sesi.statusSertifikat;
  if (sertifikat != null) return lencanaStatusSertifikat(l10n, sertifikat);
  return StatusBadge.fromApi(_kodeStatusSesi(sesi.status));
}

/// PASS/FAIL hanya untuk sesi yang disetujui dan punya keputusan. Sesi tanpa
/// keputusan (mis. Conductivity) tidak diberi lencana apa pun.
List<Widget> _lencanaKeputusan(CalibrationHistoryItem sesi) {
  if (sesi.status != CalibrationStatus.disetujui) return const [];
  return switch (sesi.keputusan) {
    Keputusan.pass => [const StatusBadge.fromApi('PASS')],
    Keputusan.fail => [const StatusBadge.fromApi('FAIL')],
    null => const [],
  };
}
