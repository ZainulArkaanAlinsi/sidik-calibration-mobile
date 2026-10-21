import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../core/utils/waktu_tampil.dart';
import '../../l10n/app_localizations.dart';
import '../../models/data_acuan.dart';
import '../../providers/data_acuan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import 'widgets/grid_acuan.dart';
import 'widgets/keadaan_acuan.dart';

/// S7 — riwayat SATU sel: nilainya di tiap versi paket + jejak suntingannya
/// (siapa, kapan, lama → baru, alasan). FR-03 / FR-28.
///
/// Bukan untuk teknisi: server menjawab 404 (`DataAcuanController::riwayatSel`
/// → `bolehLihatSemua`). Rute yang dibuka langsung oleh teknisi tidak
/// memanggil server sama sekali dan menjelaskan kenapa.
class RiwayatSelAcuanScreen extends ConsumerWidget {
  const RiwayatSelAcuanScreen({super.key, required this.sel, this.labelLembar});

  final KunciSelAcuan sel;

  /// Label lembar dari skema, bila pemanggil sudah memegangnya. Respons
  /// riwayat cuma membawa kode lembar.
  final String? labelLembar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boleh = bolehLihatSemuaVersiAcuan(peranDataAcuan(ref));

    return GerbangDataAcuan(
      judul: l10n.acuanSelRiwayat,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.acuanSelRiwayat)),
        body: boleh
            ? _IsiRiwayat(sel: sel, labelLembar: labelLembar)
            : KeadaanAcuan(
                ikon: Icons.lock_outline,
                judul: l10n.acuanRiwayatTidakTersedia,
              ),
      ),
    );
  }
}

class _IsiRiwayat extends ConsumerWidget {
  const _IsiRiwayat({required this.sel, this.labelLembar});

  final KunciSelAcuan sel;
  final String? labelLembar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final riwayat = ref.watch(riwayatSelAcuanProvider(sel));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(riwayatSelAcuanProvider(sel).future),
      child: riwayat.when(
        loading: () => const KerangkaDaftarAcuan(),
        error: (e, _) => GalatAcuan(
          galat: e,
          onCobaLagi: () => ref.invalidate(riwayatSelAcuanProvider(sel)),
        ),
        data: (r) => ReadableWidth(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _KepalaSel(riwayat: r, labelLembar: labelLembar),
              const SizedBox(height: AppSpacing.lg),
              _JudulBagian(l10n.acuanRiwayatPerVersi),
              for (final n in r.riwayat)
                _NilaiPerVersi(
                  entri: n,
                  kolom: r.kolom,
                  dilihat: n.versi?.id == sel.versiId,
                ),
              const SizedBox(height: AppSpacing.lg),
              _JudulBagian(l10n.acuanRiwayatSuntingan),
              if (r.suntingan.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    l10n.acuanRiwayatSuntinganKosong,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SidikMaterial.of(context).tinta2,
                    ),
                  ),
                )
              else
                for (final s in r.suntingan) _Suntingan(suntingan: s),
            ],
          ),
        ),
      ),
    );
  }
}

class _JudulBagian extends StatelessWidget {
  const _JudulBagian(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      teks.toUpperCase(),
      style: SidikMaterial.of(context).gayaEtsa(ukuran: 12),
    ),
  );
}

class _KepalaSel extends StatelessWidget {
  const _KepalaSel({required this.riwayat, this.labelLembar});

  final RiwayatSelAcuan riwayat;
  final String? labelLembar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final kolom = riwayat.kolom;
    final mono = SidikTheme.gayaAngka(
      ukuran: 14,
      berat: FontWeight.w500,
      warna: m.tinta,
    );

    return Kertas(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelLembar ?? riwayat.lembar,
            style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
          ),
          const SizedBox(height: 2),
          Text(
            [kolom?.label ?? '', ?kolom?.satuan].join(' · '),
            style: theme.textTheme.titleMedium?.copyWith(color: m.tinta),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.acuanSelKunci, style: theme.textTheme.labelMedium),
          SelectableText(riwayat.kunci, style: mono),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.acuanSelNilai, style: theme.textTheme.labelMedium),
          riwayat.ada && riwayat.nilai != null
              ? SelectableText(
                  teksNilaiAcuan(riwayat.nilai)!,
                  style: mono.copyWith(fontSize: 20),
                )
              : TeksSelAcuan(
                  ada: riwayat.ada,
                  nilai: riwayat.nilai,
                  kolom: kolom,
                  ukuran: 20,
                ),
          if (kolom?.asal != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.acuanSelAsal, style: theme.textTheme.labelMedium),
            SelectableText(kolom!.asal!, style: mono),
          ],
          if (kolom?.perluKonfirmasi ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: m.awas),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.acuanSelPerluKonfirmasiKet,
                    style: theme.textTheme.bodySmall?.copyWith(color: m.tinta),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NilaiPerVersi extends StatelessWidget {
  const _NilaiPerVersi({
    required this.entri,
    required this.kolom,
    required this.dilihat,
  });

  final NilaiSelPerVersi entri;
  final KolomSkemaAcuan? kolom;

  /// Versi yang sedang dibuka di Studio.
  final bool dilihat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final versi = entri.versi;

    return Kertas(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      warna: dilihat ? m.biruTipis : null,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                versi == null ? '—' : l10n.acuanVersiNomor(versi.nomor),
                style: SidikTheme.gayaAngka(ukuran: 15, warna: m.tinta),
              ),
              if (versi != null) ...[
                const SizedBox(width: AppSpacing.sm),
                LencanaVersiAcuan(versi.kodeStatus),
              ],
            ],
          ),
          TeksSelAcuan(
            ada: entri.ada,
            nilai: entri.nilai,
            kolom: kolom,
            rataKanan: true,
          ),
        ],
      ),
    );
  }
}

class _Suntingan extends StatelessWidget {
  const _Suntingan({required this.suntingan});

  final SuntinganSelAcuan suntingan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final s = suntingan;
    final mono = SidikTheme.gayaAngka(
      ukuran: 14,
      berat: FontWeight.w500,
      warna: m.tinta,
    );

    final sumber = switch (s.sumber) {
      'ketik' => l10n.acuanSumberKetik,
      'tempel' => l10n.acuanSumberTempel,
      'impor' => l10n.acuanSumberImpor,
      'ambil_alih' => l10n.acuanSumberAmbilAlih,
      _ => s.sumber,
    };

    final pelaku = [
      if (s.nomorVersi != null) l10n.acuanVersiNomor(s.nomorVersi!),
      s.pengguna?.nama ?? l10n.acuanPenggunaTerhapus,
      if (s.dibuatPada != null) waktuLengkap(s.dibuatPada!.toLocal(), locale),
      ?sumber,
    ].join(' · ');

    return Kertas(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pelaku,
            style: theme.textTheme.bodySmall?.copyWith(color: m.tinta2),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                teksNilaiAcuan(s.nilaiLama) ?? l10n.acuanNilaiKosong,
                style: mono.copyWith(
                  color: m.tinta2,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Icon(Icons.arrow_forward, size: 16, color: m.tinta2),
              Text(
                teksNilaiAcuan(s.nilaiBaru) ?? l10n.acuanNilaiKosong,
                style: mono,
              ),
            ],
          ),
          if (s.alasan != null && s.alasan!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.alasan!,
              style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta),
            ),
          ],
        ],
      ),
    );
  }
}
