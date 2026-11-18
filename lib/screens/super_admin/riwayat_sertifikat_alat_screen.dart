import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/alat_pelanggan.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/riwayat_alat_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/status_badge.dart';
import '../certificate/sertifikat_screen.dart';
import 'hak_super_admin.dart';
import 'widgets/format_sa.dart';
import 'widgets/kartu_alat.dart';
import 'widgets/kerangka_kursor.dart';
import 'widgets/lencana_sertifikat.dart';
import 'widgets/pemicu_gulir.dart';
import 'widgets/pesan_layar.dart';

/// Riwayat sertifikat satu alat: TERBARU dulu, dikelompokkan tahun lalu bulan.
///
/// Sertifikat lama tetap terlihat — yang digantikan, ditarik, dibatalkan, atau
/// gagal terbit adalah jejak yang dicari asesor, bukan sampah. Mengetuk baris
/// membuka pratinjau sertifikat yang SUDAH ada (`SertifikatScreen`); layar ini
/// tidak punya penampil sendiri dan tidak menyimpan PDF ke disk (unduh hanya
/// atas perintah pengguna di pratinjau).
///
/// Dimuat per halaman kursor saat gulir mendekati ujung; daftar hidup di
/// provider auto-dispose, jadi keluar dari layar membuangnya.
class RiwayatSertifikatAlatScreen extends ConsumerWidget {
  const RiwayatSertifikatAlatScreen({super.key, required this.alat});

  final AlatRingkas alat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Tanpa izin: terkunci dan server TIDAK ditanya (provider tidak dibuat).
    if (!ref.bolehLihatRiwayatSertifikat) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.saRiwayatJudul)),
        body: PesanLayar(ikon: Icons.lock_outline, teks: l10n.saTanpaIzin),
      );
    }
    final provider = sertifikatAlatProvider(alat.id);
    final async = ref.watch(provider);
    final ctl = ref.read(provider.notifier);
    final daftar = async.value;

    final Widget isi;
    if (daftar != null) {
      isi = _Riwayat(alat: alat, daftar: daftar);
    } else if (async.hasError) {
      final galat = async.error!;
      isi = PesanLayar(
        ikon: Icons.cloud_off_outlined,
        galat: true,
        teks: galat is TokenHilangException
            ? l10n.historySessionExpired
            : pesanDaftarKursor(l10n, galat, l10n.saRiwayatGagal),
        aksi: AppButton(
          label: l10n.saCobaLagi,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: ctl.muatUlang,
        ),
      );
    } else {
      isi = ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          KartuAlatRingkas(alat: alat),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: KerangkaKartuKursor(),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.saRiwayatJudul)),
      body: SafeArea(
        top: false,
        child: ReadableWidth(maksimum: 720, child: isi),
      ),
    );
  }
}

class _Riwayat extends ConsumerWidget {
  const _Riwayat({required this.alat, required this.daftar});

  final AlatRingkas alat;
  final DaftarKursor<SertifikatRingkas> daftar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final provider = sertifikatAlatProvider(alat.id);
    final ctl = ref.read(provider.notifier);
    final baris = susunRiwayat(daftar.items);

    return RefreshIndicator(
      onRefresh: ctl.muatUlang,
      child: PemicuGulir(
        saatDekatAkhir: ctl.muatLebihBanyak,
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          physics: const AlwaysScrollableScrollPhysics(),
          // kepala alat + (kosong | baris) + kaki
          itemCount: 1 + (baris.isEmpty ? 1 : baris.length) + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: KartuAlatRingkas(alat: alat),
              );
            }
            if (baris.isEmpty) {
              if (i == 1) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    l10n.saRiwayatKosong,
                    key: const Key('riwayat-kosong'),
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
            } else if (i - 1 < baris.length) {
              return _BarisRiwayat(baris: baris[i - 1]);
            }
            return KakiDaftarKursor(
              memuatLagi: daftar.memuatLagi,
              galat: daftar.galatLanjut == null
                  ? null
                  : pesanDaftarKursor(
                      l10n,
                      daftar.galatLanjut!,
                      l10n.saRiwayatLanjutGagal,
                    ),
              adaLagi: daftar.adaLagi,
              saatMuat: () => ctl.muatLebihBanyak(paksa: true),
            );
          },
        ),
      ),
    );
  }
}

class _BarisRiwayat extends StatelessWidget {
  const _BarisRiwayat({required this.baris});

  final BarisRiwayat baris;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);

    switch (baris) {
      case JudulTahun(:final tahun):
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 2),
          child: Semantics(
            header: true,
            child: Text(
              tahun == null ? l10n.saRiwayatTanpaTanggal : '$tahun',
              key: Key('tahun-${tahun ?? 'kosong'}'),
              style: tema.textTheme.titleMedium,
            ),
          ),
        );
      case JudulBulan(:final tahun, :final bulan):
        return Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              namaBulanSa(context, tahun, bulan),
              key: Key('bulan-$tahun-$bulan'),
              style: tema.textTheme.labelLarge?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      case BarisSertifikat(:final sertifikat):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _KartuSertifikat(sertifikat: sertifikat),
        );
    }
  }
}

class _KartuSertifikat extends StatelessWidget {
  const _KartuSertifikat({required this.sertifikat});

  final SertifikatRingkas sertifikat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final redup = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    final nomor = sertifikat.nomor.trim().isEmpty ? '-' : sertifikat.nomor;

    return Card(
      key: Key('sertifikat-${sertifikat.id}'),
      child: MergeSemantics(
        child: Semantics(
          button: true,
          hint: l10n.saSertBuka,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            // Pratinjau yang sudah ada; layar ini tidak membuat penampil baru.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SertifikatScreen(certificateId: sertifikat.id),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          nomor,
                          style: tema.textTheme.titleSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      LencanaSertifikat(keadaan: sertifikat.keadaan),
                      if (sertifikat.keputusan != null)
                        StatusBadge.fromApi(sertifikat.keputusan!),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    sertifikat.diterbitkanPada == null
                        ? l10n.saRiwayatTanpaTanggal
                        : l10n.saRiwayatTerbit(
                            tanggalSa(context, sertifikat.diterbitkanPada),
                          ),
                    style: redup,
                  ),
                  if (sertifikat.berlakuSampai != null)
                    Text(
                      l10n.saUndanganBerlaku(
                        tanggalSa(context, sertifikat.berlakuSampai),
                      ),
                      style: redup,
                    ),
                  // Jejak revisi: sertifikat lama TIDAK tertimpa; yang lama
                  // menunjuk penggantinya, yang baru menunjuk asalnya.
                  if (sertifikat.digantikanOleh != null)
                    Text(
                      l10n.saSertDigantikanOleh(
                        sertifikat.digantikanOleh!.nomor,
                      ),
                      style: redup,
                    ),
                  if (sertifikat.revisiDari != null)
                    Text(
                      l10n.saSertRevisiDari(sertifikat.revisiDari!.nomor),
                      style: redup,
                    ),
                  if (sertifikat.ditarikPada != null)
                    Text(
                      l10n.saSertDitarikPada(
                        tanggalSa(context, sertifikat.ditarikPada),
                      ),
                      style: redup,
                    ),
                  if (sertifikat.dibatalkanPada != null)
                    Text(
                      l10n.saSertDibatalkanPada(
                        tanggalSa(context, sertifikat.dibatalkanPada),
                      ),
                      style: redup,
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
