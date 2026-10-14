import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/data_acuan.dart';
import '../../providers/data_acuan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import 'banding_acuan_screen.dart';
import 'studio_acuan_screen.dart';
import 'widgets/keadaan_acuan.dart';

/// S7 — garis waktu versi satu paket (FR-28), urut jenis lalu nomor.
///
/// Server menyaring isinya per peran (`DataAcuanController::garisWaktu`):
/// teknisi cuma mendapat versi `aktif`, peran lain semua status. Layar ini
/// tidak menyaring ulang — yang datang, itu yang boleh dilihat.
///
/// Versi `data` bisa dibuka di Studio. Versi `bentuk` (lapis 3, lahir di P6)
/// ditampilkan tanpa aksi: skema Studio hanya membaca isi berjenis data.
class GarisWaktuAcuanScreen extends StatelessWidget {
  const GarisWaktuAcuanScreen({super.key, required this.kode, this.nama});

  final String kode;
  final String? nama;

  @override
  Widget build(BuildContext context) => GerbangDataAcuan(
    judul: AppLocalizations.of(context).acuanGarisWaktu,
    child: _GarisWaktu(kode: kode, nama: nama),
  );
}

class _GarisWaktu extends ConsumerWidget {
  const _GarisWaktu({required this.kode, this.nama});

  final String kode;
  final String? nama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final garis = ref.watch(garisWaktuAcuanProvider(kode));
    final theme = Theme.of(context);

    final adaVersiData = (garis.value ?? const <VersiAcuan>[]).any(
      (v) => v.jenis == 'data',
    );
    // Banding: 404 untuk teknisi (`DataAcuanController::banding` →
    // `bolehLihatSemua`). Tanpa satu pun versi data tidak ada yang bisa
    // dibandingkan.
    final bolehBanding =
        bolehLihatSemuaVersiAcuan(peranDataAcuan(ref)) && adaVersiData;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.acuanGarisWaktu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              nama ?? kode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (bolehBanding)
            IconButton(
              tooltip: l10n.acuanBandingkan,
              icon: const Icon(Icons.compare_arrows),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BandingAcuanScreen(kode: kode, nama: nama),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(garisWaktuAcuanProvider(kode).future),
        child: garis.when(
          loading: () => const KerangkaDaftarAcuan(),
          error: (e, _) => GalatAcuan(
            galat: e,
            onCobaLagi: () => ref.invalidate(garisWaktuAcuanProvider(kode)),
          ),
          data: (versi) {
            if (versi.isEmpty) {
              return KeadaanAcuan(
                ikon: Icons.timeline,
                judul: l10n.acuanGarisWaktuKosong,
              );
            }

            return ReadableWidth(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: versi.length,
                itemBuilder: (context, i) => _BarisVersi(
                  versi: versi[i],
                  onBuka: versi[i].jenis == 'data'
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StudioAcuanScreen(
                              kode: kode,
                              nama: nama,
                              versiId: versi[i].id,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BarisVersi extends StatelessWidget {
  const _BarisVersi({required this.versi, this.onBuka});

  final VersiAcuan versi;
  final VoidCallback? onBuka;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final sha = versi.isiSha256;
    final mono = SidikTheme.gayaAngka(
      ukuran: 13,
      berat: FontWeight.w400,
      warna: m.tinta2,
    );

    return Kertas(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onBuka,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.acuanVersiNomor(versi.nomor),
                      style: SidikTheme.gayaAngka(ukuran: 16, warna: m.tinta),
                    ),
                    Text(
                      versi.jenis == 'bentuk'
                          ? l10n.acuanJenisBentuk
                          : l10n.acuanJenisData,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: m.tinta2,
                      ),
                    ),
                    LencanaVersiAcuan(versi.kodeStatus),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  teksBerlakuAcuan(
                    versi.berlakuMulai,
                    versi.berlakuSampai,
                    l10n,
                    locale,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta),
                ),
                if (sha != null)
                  Tooltip(
                    message: sha,
                    child: Text(shaPendekAcuan(sha), style: mono),
                  ),
                if (versi.alasan != null && versi.alasan!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      versi.alasan!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: m.tinta2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onBuka != null) Icon(Icons.chevron_right, color: m.tinta2),
        ],
      ),
    );
  }
}
