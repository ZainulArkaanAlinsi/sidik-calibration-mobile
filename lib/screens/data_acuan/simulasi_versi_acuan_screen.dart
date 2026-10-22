import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/alur_acuan.dart';
import '../../providers/data_acuan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import 'widgets/grid_acuan.dart' show teksNilaiAcuan;
import 'widgets/hak_alur_acuan.dart';
import 'widgets/keadaan_acuan.dart';

/// Laporan simulasi terakhir satu versi (`GET /data-acuan/versi/{v}/simulasi`)
/// — yang ditinjau pengaktif sebelum menekan Aktifkan.
///
/// Per sesi: kolom hitung yang berubah (lama/baru/selisih, APA ADANYA —
/// tidak dibulatkan), teks cetak sertifikat yang berubah, vonis, dan nomor
/// sertifikat TERBIT yang terdampak (disorot). Baca saja di dua aplikasi.
class SimulasiVersiAcuanScreen extends StatelessWidget {
  const SimulasiVersiAcuanScreen({
    super.key,
    required this.versiId,
    required this.nomor,
  });

  final int versiId;
  final int nomor;

  @override
  Widget build(BuildContext context) => GerbangDataAcuan(
    judul: AppLocalizations.of(context).simAcuanJudul(nomor),
    child: _Laporan(versiId: versiId, nomor: nomor),
  );
}

class _Laporan extends ConsumerStatefulWidget {
  const _Laporan({required this.versiId, required this.nomor});

  final int versiId;
  final int nomor;

  @override
  ConsumerState<_Laporan> createState() => _LaporanState();
}

class _LaporanState extends ConsumerState<_Laporan> {
  bool _hanyaBerubah = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final laporan = ref.watch(laporanSimulasiAcuanProvider(widget.versiId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.simAcuanJudul(widget.nomor))),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(laporanSimulasiAcuanProvider(widget.versiId).future),
        child: laporan.when(
          loading: () => const KerangkaDaftarAcuan(),
          error: (e, _) => GalatAcuan(
            galat: e,
            onCobaLagi: () =>
                ref.invalidate(laporanSimulasiAcuanProvider(widget.versiId)),
          ),
          data: (lap) {
            if (!lap.adaLaporan) {
              return KeadaanAcuan(
                ikon: Icons.table_chart_outlined,
                judul: l10n.simAcuanBelumAda,
              );
            }
            final sesi = _hanyaBerubah
                ? lap.sesi
                      .where((s) => s.berubah || s.cetakBerubah || s.gagal)
                      .toList()
                : lap.sesi;
            final bersama = lap.bersama;
            final adaBersama =
                bersama != null &&
                (bersama.berubah.isNotEmpty ||
                    bersama.masterLain.any(
                      (mm) => mm.beda.isNotEmpty || mm.galat != null,
                    ));

            return ReadableWidth(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _KepalaLaporan(sim: lap.simulasi),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.simAcuanSesiJudul,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      FilterChip(
                        key: const ValueKey('sim-hanya-berubah'),
                        label: Text(l10n.simAcuanHanyaBerubah),
                        selected: _hanyaBerubah,
                        onSelected: (v) => setState(() => _hanyaBerubah = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (sesi.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(l10n.simAcuanTidakAdaBerubah),
                    ),
                  for (final s in sesi) _KartuSesi(sesi: s),
                  if (adaBersama) _KartuBersama(bersama: bersama),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _KepalaLaporan extends StatelessWidget {
  const _KepalaLaporan({required this.sim});

  final SimulasiVersiAcuan sim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final r = sim.ringkasan;

    return Kertas(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.alurAcuanSimulasiJudul}: ${labelStatusSimulasi(sim, l10n)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: sim.status == StatusSimulasiAcuan.terbaru
                  ? m.lulus
                  : m.gagal,
            ),
          ),
          if (r != null)
            Text(
              l10n.alurAcuanRingkasan(
                r.sesiTotal ?? 0,
                r.sesiBerubah ?? 0,
                r.cetakBerubah ?? 0,
                r.terbitCetakBerubah ?? 0,
                r.vonisBerubah ?? 0,
                r.sesiGagal ?? 0,
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: m.tinta),
            ),
          if ((r?.bersamaAntarVarian ?? 0) > 0)
            Text(
              l10n.alurAcuanBersama(r!.bersamaAntarVarian!),
              style: theme.textTheme.bodySmall?.copyWith(color: m.awas),
            ),
          if (r?.catatanSumber != null)
            Text(
              r!.catatanSumber!,
              style: theme.textTheme.bodySmall?.copyWith(color: m.awas),
            ),
          for (final b in sim.wajibDiakui)
            Text(
              '• ${labelButirPengakuan(b, l10n)}',
              style: theme.textTheme.bodySmall?.copyWith(color: m.awas),
            ),
        ],
      ),
    );
  }
}

class _Lencana extends StatelessWidget {
  const _Lencana(this.teks, this.warna, this.latar);

  final String teks;
  final Color warna;
  final Color latar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: latar,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      teks,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: warna,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _KartuSesi extends StatelessWidget {
  const _KartuSesi({required this.sesi});

  final SesiSimulasiAcuan sesi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final s = sesi;
    final id = s.sesiId ?? 0;

    return Kertas(
      key: ValueKey('sim-sesi-$id'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                s.nomorSesi ?? '#$id',
                style: SidikTheme.gayaAngka(ukuran: 15, warna: m.tinta),
              ),
              if (s.tanggalKalibrasi != null)
                Text(
                  s.tanggalKalibrasi!,
                  style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
                ),
              if (s.statusSesi != null)
                Text(
                  s.statusSesi!,
                  style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
                ),
              if (s.gagal)
                _Lencana(l10n.simAcuanGagal, m.gagal, m.gagalTipis)
              else if (!s.berubah)
                _Lencana(l10n.simAcuanTidakBerubah, m.lulus, m.lulusTipis)
              else
                _Lencana(l10n.simAcuanBerubah, m.tunggu, m.tungguTipis),
              if (s.cetakBerubah)
                _Lencana(l10n.simAcuanCetakBerubah, m.gagal, m.gagalTipis),
              if (s.vonisBerubah)
                _Lencana(l10n.simAcuanVonisBerubah, m.gagal, m.gagalTipis),
            ],
          ),
          if (s.versiPembanding != null)
            Text(
              l10n.simAcuanPembanding(s.versiPembanding!),
              style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
            ),
          for (final nomor in s.nomorSertifikatTerbit)
            Container(
              key: ValueKey('sim-sertifikat-$nomor'),
              margin: const EdgeInsets.only(top: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: s.cetakBerubah ? m.gagalTipis : m.awasTipis,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: s.cetakBerubah ? m.gagal : m.awas),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_outlined,
                    size: 16,
                    color: s.cetakBerubah ? m.gagal : m.awas,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: SelectableText(
                      l10n.simAcuanSertifikatTerbit(nomor),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: m.tinta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (s.galat != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: SelectableText(
                s.galat!,
                style: theme.textTheme.bodySmall?.copyWith(color: m.gagal),
              ),
            ),
          for (final t in s.titikTidakTerhitung)
            Text(
              l10n.simAcuanTitikTidakTerhitung('${t.titik ?? '?'}'),
              style: theme.textTheme.bodySmall?.copyWith(color: m.awas),
            ),
          if (s.cetak.isNotEmpty)
            _Tabel(
              kunci: 'sim-cetak-$id',
              judul: l10n.simAcuanTabelCetak,
              sorot: true,
              kepala: [
                l10n.simAcuanKolomTitik,
                l10n.simAcuanKolomKolom,
                l10n.simAcuanKolomLama,
                l10n.simAcuanKolomBaru,
              ],
              baris: [
                for (final c in s.cetak)
                  ['${c.titik ?? ''}', c.kolom, c.lama ?? '—', c.baru ?? '—'],
              ],
            ),
          if (s.selisih.isNotEmpty)
            _Tabel(
              kunci: 'sim-selisih-$id',
              judul: l10n.simAcuanTabelSelisih,
              kepala: [
                l10n.simAcuanKolomTitik,
                l10n.simAcuanKolomKolom,
                l10n.simAcuanKolomLama,
                l10n.simAcuanKolomBaru,
                l10n.simAcuanKolomSelisih,
              ],
              baris: [
                for (final d in s.selisih)
                  [
                    '${d.titik ?? ''}',
                    d.kolom,
                    teksNilaiAcuan(d.lama) ?? '—',
                    teksNilaiAcuan(d.baru) ?? '—',
                    teksNilaiAcuan(d.selisih) ?? '—',
                  ],
              ],
            ),
        ],
      ),
    );
  }
}

class _KartuBersama extends StatelessWidget {
  const _KartuBersama({required this.bersama});

  final BersamaAntarVarianAcuan bersama;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kepala = [
      l10n.simAcuanKolomKolom,
      l10n.simAcuanKolomLama,
      l10n.simAcuanKolomBaru,
    ];
    List<List<String>> baris(List<DaunBersamaAcuan> daun) => [
      for (final d in daun)
        [d.jalur, teksNilaiAcuan(d.lama) ?? '—', teksNilaiAcuan(d.baru) ?? '—'],
    ];

    return Kertas(
      key: const ValueKey('sim-bersama'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.simAcuanBersamaJudul, style: theme.textTheme.titleSmall),
          if (bersama.berubah.isNotEmpty)
            _Tabel(
              kunci: 'sim-bersama-berubah',
              judul: null,
              sorot: true,
              kepala: kepala,
              baris: baris(bersama.berubah),
            ),
          for (final mm in bersama.masterLain)
            if (mm.beda.isNotEmpty || mm.galat != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.simAcuanMasterLain(
                  mm.nama ?? '#${mm.workbookMasterId ?? '?'}',
                ),
                style: theme.textTheme.bodyMedium,
              ),
              if (mm.galat != null)
                Text(
                  mm.galat!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              if (mm.beda.isNotEmpty)
                _Tabel(
                  kunci: 'sim-master-lain-${mm.workbookMasterId}',
                  judul: null,
                  kepala: kepala,
                  baris: baris(mm.beda),
                ),
            ],
        ],
      ),
    );
  }
}

/// Tabel sederhana, gulir mendatar; teks bisa dipilih (angka persis).
class _Tabel extends StatelessWidget {
  const _Tabel({
    required this.kunci,
    required this.judul,
    required this.kepala,
    required this.baris,
    this.sorot = false,
  });

  final String kunci;
  final String? judul;
  final List<String> kepala;
  final List<List<String>> baris;
  final bool sorot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final mono = SidikTheme.gayaAngka(
      ukuran: 12.5,
      berat: FontWeight.w400,
      warna: m.tinta,
    );

    Widget sel(String teks, {bool kepalaSel = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: kepalaSel
          ? Text(teks, style: theme.textTheme.labelMedium)
          : SelectableText(teks, style: mono),
    );

    return Padding(
      key: ValueKey(kunci),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (judul != null)
            Text(
              judul!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: sorot ? m.gagal : m.tinta,
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                color: sorot ? m.gagalTipis : null,
                border: Border.all(color: sorot ? m.gagal : m.garis),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: TableBorder(
                  horizontalInside: BorderSide(color: m.garis, width: 0.5),
                ),
                children: [
                  TableRow(
                    children: [for (final k in kepala) sel(k, kepalaSel: true)],
                  ),
                  for (final b in baris)
                    TableRow(children: [for (final t in b) sel(t)]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
