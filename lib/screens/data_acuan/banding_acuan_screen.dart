import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../core/utils/angka.dart';
import '../../l10n/app_localizations.dart';
import '../../models/data_acuan.dart';
import '../../providers/data_acuan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import 'widgets/grid_acuan.dart';
import 'widgets/keadaan_acuan.dart';

/// S3 — banding dua versi data acuan (FR-11).
///
/// Dua versi dipilih dari garis waktu, berjenis `data` saja: server menolak
/// banding beda jenis (`versi_beda_jenis`) dan versi bentuk
/// (`jenis_belum_didukung`) dengan 422, jadi pilihan itu tidak ditawarkan.
///
/// Bukan untuk teknisi — server menjawab 404 (`DataAcuanController::banding`
/// → `bolehLihatSemua`). Selama paket baru punya v1, satu-satunya pasangan
/// adalah v1 ↔ v1 dan jawabannya "Tidak ada perbedaan".
///
/// Selisih ditampilkan PERSIS seperti dikirim server (`0.0019999999999988916`,
/// bukan `0.002`) — membulatkannya menyembunyikan jenis selisih yang paling
/// mahal dicari.
class BandingAcuanScreen extends ConsumerWidget {
  const BandingAcuanScreen({
    super.key,
    required this.kode,
    this.nama,
    this.lamaId,
    this.baruId,
  });

  final String kode;
  final String? nama;

  /// Pilihan awal; `null` = dua versi data terakhir (atau versi terakhir
  /// dengan dirinya sendiri bila baru ada satu).
  final int? lamaId;
  final int? baruId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final boleh = bolehLihatSemuaVersiAcuan(peranDataAcuan(ref));

    return GerbangDataAcuan(
      judul: l10n.acuanBandingkan,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.acuanBandingkan,
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
        ),
        // Provider di-`watch` di [_Banding], yang cuma dibangun bila gerbang
        // izin lolos DAN peran ini boleh banding — teknisi tidak menembak
        // rute yang pasti 404.
        body: boleh
            ? _Banding(kode: kode, lamaId: lamaId, baruId: baruId)
            : KeadaanAcuan(
                ikon: Icons.lock_outline,
                judul: l10n.acuanBandingTidakTersedia,
              ),
      ),
    );
  }
}

class _Banding extends ConsumerStatefulWidget {
  const _Banding({required this.kode, this.lamaId, this.baruId});

  final String kode;
  final int? lamaId;
  final int? baruId;

  @override
  ConsumerState<_Banding> createState() => _BandingState();
}

class _BandingState extends ConsumerState<_Banding> {
  int? _lama;
  int? _baru;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final garis = ref.watch(garisWaktuAcuanProvider(widget.kode));

    return garis.when(
      loading: () => const KerangkaDaftarAcuan(),
      error: (e, _) => GalatAcuan(
        galat: e,
        onCobaLagi: () => ref.invalidate(garisWaktuAcuanProvider(widget.kode)),
      ),
      data: (semua) {
        final data = [
          for (final v in semua)
            if (v.jenis == 'data') v,
        ]..sort((a, b) => a.nomor.compareTo(b.nomor));

        if (data.isEmpty) {
          return KeadaanAcuan(
            ikon: Icons.compare_arrows,
            judul: l10n.acuanBandingTanpaVersiData,
          );
        }

        final ids = [for (final v in data) v.id];
        int? pilih(int? a, int? b) => a != null && ids.contains(a)
            ? a
            : (b != null && ids.contains(b) ? b : null);

        final baru = pilih(_baru, widget.baruId) ?? ids.last;
        final posisiBaru = ids.indexOf(baru);
        final lama =
            pilih(_lama, widget.lamaId) ??
            ids[posisiBaru > 0 ? posisiBaru - 1 : posisiBaru];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReadableWidth(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _Pemilih(
                  versi: data,
                  lama: lama,
                  baru: baru,
                  onLama: (id) => setState(() => _lama = id),
                  onBaru: (id) => setState(() => _baru = id),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _HasilBanding(kode: widget.kode, lama: lama, baru: baru),
            ),
          ],
        );
      },
    );
  }
}

class _Pemilih extends StatelessWidget {
  const _Pemilih({
    required this.versi,
    required this.lama,
    required this.baru,
    required this.onLama,
    required this.onBaru,
  });

  final List<VersiAcuan> versi;
  final int lama;
  final int baru;
  final ValueChanged<int> onLama;
  final ValueChanged<int> onBaru;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    List<DropdownMenuItem<int>> item() => [
      for (final v in versi)
        DropdownMenuItem(
          value: v.id,
          child: Text(
            '${l10n.acuanVersiNomor(v.nomor)} · '
            '${labelStatusVersiAcuan(v.kodeStatus, l10n)}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    final kiri = DropdownButtonFormField<int>(
      key: ValueKey('lama-$lama'),
      initialValue: lama,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.acuanBandingLama),
      items: item(),
      onChanged: (id) {
        if (id != null) onLama(id);
      },
    );
    final kanan = DropdownButtonFormField<int>(
      key: ValueKey('baru-$baru'),
      initialValue: baru,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.acuanBandingBaru),
      items: item(),
      onChanged: (id) {
        if (id != null) onBaru(id);
      },
    );

    return LayoutBuilder(
      builder: (context, batas) => batas.maxWidth < 520
          ? Column(
              children: [
                kiri,
                const SizedBox(height: AppSpacing.sm),
                kanan,
              ],
            )
          : Row(
              children: [
                Expanded(child: kiri),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: kanan),
              ],
            ),
    );
  }
}

class _HasilBanding extends ConsumerWidget {
  const _HasilBanding({
    required this.kode,
    required this.lama,
    required this.baru,
  });

  final String kode;
  final int lama;
  final int baru;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final hasil = ref.watch(bandingAcuanProvider((lama: lama, baru: baru)));

    // Label kolom diambil dari skema paket (banding cuma mengirim kodenya).
    // Skema belum sampai → kode kolom apa adanya, bukan menunggu.
    final skema = ref.watch(detailPaketAcuanProvider(kode)).value?.skema;
    final lembarSkema = {
      for (final l in skema?.lembar ?? const <LembarSkemaAcuan>[]) l.kode: l,
    };

    return hasil.when(
      loading: () => const KerangkaDaftarAcuan(),
      error: (e, _) => GalatAcuan(
        galat: e,
        onCobaLagi: () =>
            ref.invalidate(bandingAcuanProvider((lama: lama, baru: baru))),
      ),
      data: (b) {
        final r = b.ringkasan;
        final berubah = [
          for (final l in b.lembar)
            if (l.berubah) l,
        ];

        if (berubah.isEmpty &&
            r.selBerubah == 0 &&
            r.barisTambah == 0 &&
            r.barisHapus == 0) {
          return KeadaanAcuan(
            ikon: Icons.check_circle_outline,
            judul: l10n.acuanBandingTidakAdaBeda,
            keterangan: l10n.acuanBandingTidakAdaBedaKet(
              b.lama?.nomor ?? 0,
              b.baru?.nomor ?? 0,
            ),
          );
        }

        return ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                l10n.acuanBandingRingkasan(
                  r.lembarBerubah,
                  r.selBerubah,
                  r.barisTambah,
                  r.barisHapus,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta),
              ),
              for (final l in berubah) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(l.label.toUpperCase(), style: m.gayaEtsa(ukuran: 12)),
                const SizedBox(height: AppSpacing.sm),
                for (final s in l.selBerubah)
                  _SelBerubah(sel: s, lembar: lembarSkema[l.kode]),
                if (l.barisTambah.isNotEmpty)
                  _DaftarBaris(
                    judul: l10n.acuanBandingBarisTambah,
                    baris: l.barisTambah,
                    lembar: lembarSkema[l.kode],
                  ),
                if (l.barisHapus.isNotEmpty)
                  _DaftarBaris(
                    judul: l10n.acuanBandingBarisHapus,
                    baris: l.barisHapus,
                    lembar: lembarSkema[l.kode],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Selisih BERTANDA apa adanya; tanda `+` ditambahkan supaya arah perubahan
/// terbaca — digitnya tidak disentuh.
String _bertanda(num n) {
  final t = teksAngkaPersis(n);
  return n > 0 ? '+$t' : t;
}

KolomSkemaAcuan? _kolom(LembarSkemaAcuan? lembar, String kode) =>
    lembar?.kolom.where((k) => k.kode == kode).firstOrNull;

class _SelBerubah extends StatelessWidget {
  const _SelBerubah({required this.sel, this.lembar});

  final SelBerubahAcuan sel;
  final LembarSkemaAcuan? lembar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final kolom = _kolom(lembar, sel.kolom);
    final mono = SidikTheme.gayaAngka(
      ukuran: 14,
      berat: FontWeight.w500,
      warna: m.tinta,
    );
    final redup = theme.textTheme.bodySmall?.copyWith(color: m.tinta2);

    return Kertas(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [kolom?.label ?? sel.kolom, ?kolom?.satuan].join(' · '),
            style: theme.textTheme.titleSmall?.copyWith(color: m.tinta),
          ),
          Text(
            '${l10n.acuanSelKunci}: ${sel.kunci}',
            style: SidikTheme.gayaAngka(
              ukuran: 12,
              berat: FontWeight.w400,
              warna: m.tinta2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.acuanLama, style: redup),
              Text(
                teksNilaiAcuan(sel.lama) ?? l10n.acuanNilaiKosong,
                style: mono.copyWith(
                  color: m.tinta2,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Icon(Icons.arrow_forward, size: 16, color: m.tinta2),
              Text(l10n.acuanBaru, style: redup),
              Text(
                teksNilaiAcuan(sel.baru) ?? l10n.acuanNilaiKosong,
                style: mono,
              ),
            ],
          ),
          if (sel.punyaSelisih && sel.selisihAbsolut != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 2,
              children: [
                Text(l10n.acuanSelisih, style: redup),
                SelectableText(_bertanda(sel.selisihAbsolut!), style: mono),
                if (sel.selisihRelatif != null) ...[
                  Text(l10n.acuanSelisihRelatif, style: redup),
                  SelectableText(_bertanda(sel.selisihRelatif!), style: mono),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DaftarBaris extends StatelessWidget {
  const _DaftarBaris({required this.judul, required this.baris, this.lembar});

  final String judul;
  final List<BarisAcuan> baris;
  final LembarSkemaAcuan? lembar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final b in baris)
            Kertas(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.acuanSelKunci}: ${b.kunci}',
                    style: SidikTheme.gayaAngka(
                      ukuran: 12,
                      berat: FontWeight.w400,
                      warna: m.tinta2,
                    ),
                  ),
                  for (final MapEntry(key: kode, value: nilai) in b.sel.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          Text(
                            _kolom(lembar, kode)?.label ?? kode,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: m.tinta2,
                            ),
                          ),
                          TeksSelAcuan(
                            ada: true,
                            nilai: nilai,
                            kolom: _kolom(lembar, kode),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
