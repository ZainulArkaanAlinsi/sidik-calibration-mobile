import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/data_acuan.dart';
import '../../models/user.dart';
import '../../providers/data_acuan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_status.dart';
import 'studio_acuan_screen.dart';
import 'widgets/keadaan_acuan.dart';

/// S1 — daftar paket data acuan (FR-01, 04-UI-UX-Flow §1/§5).
///
/// Isi daftar & kunci yang dikirim ditentukan server per peran: teknisi tidak
/// menerima `jumlah_draf`/`versi_terjadwal` (kuncinya TIDAK ADA, bukan nol),
/// jadi layar ini cuma menulis angka draf bila servernya memang menyebutnya.
///
/// Paket `diimpor: false` tampil abu-abu "Belum diimpor" tanpa aksi —
/// detailnya 404 di server, jadi tidak ada yang bisa dibuka.
class DaftarPaketAcuanScreen extends StatelessWidget {
  const DaftarPaketAcuanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Provider di-`watch` di DALAM gerbang ([_DaftarPaket]): tanpa izin,
    // server tidak ditembak sama sekali.
    return GerbangDataAcuan(
      judul: l10n.acuanPaketJudul,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.acuanPaketJudul)),
        body: const _DaftarPaket(),
      ),
    );
  }
}

class _DaftarPaket extends ConsumerWidget {
  const _DaftarPaket();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final daftar = ref.watch(daftarPaketAcuanProvider);

    Future<void> segarkan() {
      ref.invalidate(detailPaketAcuanProvider);
      return ref.refresh(daftarPaketAcuanProvider.future);
    }

    return RefreshIndicator(
      onRefresh: segarkan,
      child: daftar.when(
        loading: () => const KerangkaDaftarAcuan(),
        error: (e, _) => GalatAcuan(
          galat: e,
          onCobaLagi: () => ref.invalidate(daftarPaketAcuanProvider),
        ),
        data: (paket) {
          if (paket.isEmpty) {
            // Petunjuk impor hanya untuk super admin (04 §5 S1): dia yang
            // memegang server; peran lain tidak bisa berbuat apa-apa
            // dengan perintah artisan.
            final sa = peranDataAcuan(ref) == UserRole.superAdmin;
            return KeadaanAcuan(
              ikon: Icons.inventory_2_outlined,
              judul: l10n.acuanPaketKosong,
              tambahan: sa ? l10n.acuanPaketKosongPetunjuk : null,
            );
          }

          return ReadableWidth(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: paket.length + 1,
              itemBuilder: (context, i) => i == 0
                  ? const _Pengantar()
                  : _BarisPaket(paket: paket[i - 1]),
            ),
          );
        },
      ),
    );
  }
}

class _Pengantar extends StatelessWidget {
  const _Pengantar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        AppLocalizations.of(context).acuanPaketKeterangan,
        style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta2),
      ),
    );
  }
}

class _BarisPaket extends StatelessWidget {
  const _BarisPaket({required this.paket});

  final PaketAcuan paket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final aktif = paket.versiAktif;
    final redup = theme.textTheme.bodySmall?.copyWith(color: m.tinta2);

    final keterangan = <Widget>[
      if (!paket.diimpor)
        SidikLencana(
          StatusSidik(
            l10n.acuanBelumDiimpor,
            NadaStatus.draf,
            Icons.cloud_off_outlined,
          ),
        )
      else if (aktif == null)
        SidikLencana(
          StatusSidik(
            l10n.acuanTanpaVersiAktif,
            NadaStatus.awas,
            Icons.event_busy_outlined,
          ),
        )
      else
        Text(
          aktif.berlakuMulai == null
              ? l10n.acuanVersiNomor(aktif.nomor)
              : l10n.acuanVersiBerlakuSejak(
                  aktif.nomor,
                  tanggalAcuan(aktif.berlakuMulai!, locale),
                ),
          style: theme.textTheme.bodyMedium?.copyWith(color: m.tinta),
        ),
      if (paket.diimpor) _JumlahLembar(kode: paket.kode),
      // `null` = server tidak menyebutnya (teknisi) — BUKAN nol.
      if ((paket.jumlahDraf ?? 0) > 0)
        Text(l10n.acuanJumlahDraf(paket.jumlahDraf!), style: redup),
      for (final t in paket.versiTerjadwal ?? const <RingkasanVersiAcuan>[])
        Text(
          l10n.acuanTerjadwal(
            t.nomor,
            t.berlakuMulai == null
                ? l10n.acuanBerlakuBelum
                : tanggalAcuan(t.berlakuMulai!, locale),
          ),
          style: redup,
        ),
    ];

    // Tanpa `Opacity`: teks redup di atas kertas sudah di batas kontras —
    // keadaan "belum diimpor" dibawa lencana + tidak adanya chevron.
    return Kertas(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: paket.diimpor
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    StudioAcuanScreen(kode: paket.kode, nama: paket.nama),
              ),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paket.nama,
                  style: theme.textTheme.titleSmall?.copyWith(color: m.tinta),
                ),
                Text(
                  paket.kode,
                  style: SidikTheme.gayaAngka(
                    ukuran: 12,
                    berat: FontWeight.w400,
                    warna: m.tinta2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: keterangan,
                ),
                if (!paket.diimpor) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.acuanBelumDiimporKet, style: redup),
                ],
              ],
            ),
          ),
          if (paket.diimpor) Icon(Icons.chevron_right, color: m.tinta2),
        ],
      ),
    );
  }
}

/// Jumlah lembar = panjang skema, yang cuma ada di DETAIL paket (daftar tidak
/// membawanya). Diambil per baris yang terlihat saja (`ListView.builder`), dan
/// detail yang sama langsung terpakai waktu Studio dibuka. Belum sampai /
/// gagal → tidak ditulis apa-apa, bukan "0 lembar".
class _JumlahLembar extends ConsumerWidget {
  const _JumlahLembar({required this.kode});

  final String kode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lembar = ref
        .watch(detailPaketAcuanProvider(kode))
        .value
        ?.skema
        ?.lembar;
    if (lembar == null) return const SizedBox.shrink();

    final m = SidikMaterial.of(context);
    return Text(
      AppLocalizations.of(context).acuanJumlahLembar(lembar.length),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: m.tinta2),
    );
  }
}
