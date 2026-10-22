import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/tanggal_pendek.dart';
import '../../l10n/app_localizations.dart';
import '../../models/bandingkan.dart';
import '../../providers/perhitungan_provider.dart';
import '../../widgets/readable_width.dart';

/// Layar Bandingkan (K-50-02): isian ASLI teknisi lawan isian sekarang, sel
/// yang berubah disorot beserta siapa, kapan, dan alasannya.
///
/// Nol perhitungan dan nol pembulatan di sini: nilai ditampilkan persis seperti
/// yang dikirim server. Isian asli dibekukan server dan tidak pernah hilang —
/// layar ini hanya membaca.
class BandingkanScreen extends ConsumerWidget {
  const BandingkanScreen({super.key, required this.calibrationId});

  final int calibrationId;

  /// `titik_1.-.sesudah_adjustment.sensor_-.pembacaan_1` → label terbaca.
  /// Kunci yang bentuknya lain (Autoklaf: `lembar.suhu.disk.0.0`) dipakai apa
  /// adanya.
  static String labelKunci(String kunci) {
    final bagian = kunci.split('.');
    if (bagian.length != 5 || !bagian[0].startsWith('titik_')) return kunci;

    String bersih(String s) => s.replaceAll('_', ' ');
    final titik = bagian[0].substring('titik_'.length);
    final peran = bagian[1];
    final tahap = bagian[2];
    final sensor = bagian[3].replaceFirst('sensor_', '');
    final baca = bagian[4].replaceFirst('pembacaan_', '');

    return [
      'Titik $titik',
      if (peran != '-' && peran.isNotEmpty) bersih(peran),
      if (tahap != '-' && tahap.isNotEmpty) bersih(tahap),
      if (sensor != '-' && sensor.isNotEmpty) 'sensor $sensor',
      'pembacaan $baca',
    ].join(' · ');
  }

  static String nilai(Object? v) =>
      v == null ? '—' : '$v'.replaceAll('.', ',');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(bandingkanProvider(calibrationId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bandingkanJudul)),
      body: switch (async) {
        AsyncData(:final value) => _Isi(data: value),
        AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.bandingkanGagal, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(bandingkanProvider(calibrationId)),
                  child: Text(l10n.folderRetry),
                ),
              ],
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.data});

  final Bandingkan data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (!data.adaAsli) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.bandingkanTanpaAsli,
            key: const ValueKey('bandingkan-tanpa-asli'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final berubah = data.sel.where((s) => s.berubah).toList();
    final sama = data.sel.where((s) => !s.berubah).toList();

    // Lembar besar bisa ratusan sel berubah — kartunya dibangun malas.
    final kepala = <Widget>[
      Text(
        l10n.bandingkanRingkas(data.jumlahBerubah, data.totalSel),
        key: const ValueKey('bandingkan-ringkas'),
        style: theme.textTheme.titleMedium,
      ),
      if (data.asliDibekukanPada != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            l10n.bandingkanDibekukan(
              tanggalPendek(context, data.asliDibekukanPada!.toLocal()),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      if (berubah.isEmpty) Text(l10n.bandingkanTidakAdaBerubah),
    ];
    final ekor = <Widget>[
      if (sama.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        ExpansionTile(
          key: const ValueKey('bandingkan-tidak-berubah'),
          tilePadding: EdgeInsets.zero,
          title: Text(
            l10n.bandingkanTidakBerubahJudul(sama.length),
            style: theme.textTheme.titleSmall,
          ),
          children: [for (final s in sama) _KartuSel(sel: s)],
        ),
      ],
    ];
    final n = berubah.length;

    return ReadableWidth(
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: kepala.length + n + ekor.length,
        itemBuilder: (context, i) {
          if (i < kepala.length) return kepala[i];
          final j = i - kepala.length;
          if (j >= n) return ekor[j - n];
          return _KartuSel(sel: berubah[j], sorot: true);
        },
      ),
    );
  }
}

class _KartuSel extends StatelessWidget {
  const _KartuSel({required this.sel, this.sorot = false});

  final SelBanding sel;
  final bool sorot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final warna = theme.colorScheme;

    return Card(
      key: ValueKey('sel-${sel.kunci}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: sorot ? warna.tertiaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              BandingkanScreen.labelKunci(sel.kunci),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _Nilai(
                    judul: l10n.bandingkanAsli,
                    nilai: BandingkanScreen.nilai(sel.asli),
                  ),
                ),
                if (sorot) const Icon(Icons.arrow_forward, size: 18),
                Expanded(
                  child: _Nilai(
                    judul: l10n.bandingkanSekarang,
                    nilai: BandingkanScreen.nilai(sel.sekarang),
                    tebal: sorot,
                  ),
                ),
              ],
            ),
            if (sorot && sel.diubahOleh?.nama != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  [
                    l10n.bandingkanDiubahOleh(sel.diubahOleh!.nama!),
                    if (sel.diubahPada != null)
                      tanggalPendek(context, sel.diubahPada!.toLocal()),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (sorot && sel.alasan != null)
              Text(
                l10n.bandingkanAlasan(sel.alasan!),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _Nilai extends StatelessWidget {
  const _Nilai({required this.judul, required this.nilai, this.tebal = false});

  final String judul;
  final String nilai;
  final bool tebal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          judul,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          nilai,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: tebal ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
