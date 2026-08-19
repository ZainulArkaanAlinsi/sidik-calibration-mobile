import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/buka_berkas.dart';

import '../../core/utils/angka.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/certificate_snapshot.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/autoclave_hasil_panel.dart';
import '../../providers/certificate_provider.dart';
import '../../providers/history_provider.dart';
import '../../services/pdf_downloader.dart';
import '../../widgets/app_button.dart';
import '../../widgets/sidik_loader.dart';

/// Pratinjau sertifikat (spesifikasi poin 9), plus unduh PDF/Excel & QR
/// (poin 10 & 13).
///
/// **Yang dirender cuma `snapshot`** — isi yang dibekukan waktu sertifikat
/// terbit. Nggak ada satu pun field tambahan di luar strukturnya, dan nggak
/// ada angka yang dihitung di sini. Itu yang bikin PDF, Excel, halaman
/// verifikasi QR, dan layar ini mustahil beda isi.
class SertifikatScreen extends ConsumerWidget {
  const SertifikatScreen({super.key, required this.certificateId});

  final int certificateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(certificateDetailProvider(certificateId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sertPratinjau)),
      body: switch (async) {
        AsyncData(:final value) => _Isi(sertifikat: value),
        AsyncError() => _Gagal(
          onCobaLagi: () =>
              ref.invalidate(certificateDetailProvider(certificateId)),
        ),
        _ => const Center(child: SidikLoader(size: 88)),
      },
      bottomNavigationBar: async.value?.siap ?? false
          ? _BilahUnduh(sertifikat: async.value!)
          : null,
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({required this.sertifikat});

  final CertificateDetail sertifikat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snap = sertifikat.snapshot;

    if (snap == null) {
      // PDF-nya belum jadi = snapshot-nya juga belum ada. Isinya dibekukan
      // waktu terbit, jadi nggak ada yang bisa ditampilin selain statusnya.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.sertBelumTerbit, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (snap.gagal) ...[
          _PitaFail(),
          const SizedBox(height: AppSpacing.md),
        ],

        // Header — 16 field, urutannya persis sertifikat cetak.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, nilai) in snap.header.baris())
                  _BarisHeader(label: label, nilai: nilai),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Autoklaf: hasilnya Section A/B/C, bukan tabel empat kolom. `hasil`-nya
        // memang kosong buat Autoklaf, jadi tanpa cabang ini sesi Autoklaf
        // tampil sebagai tabel kosong di HP padahal PDF-nya penuh.
        if (snap.autoclave != null)
          AutoclaveHasilPanel(hasil: snap.autoclave!)
        else
          _TabelHasil(snapshot: snap),
        const SizedBox(height: AppSpacing.md),

        // Dua catatan baku — datang dari backend, bukan ditulis ulang di sini.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in snap.catatan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '• $c',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _TabelStandar(standar: snap.standarDigunakan),
        const SizedBox(height: AppSpacing.md),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BarisHeader(
                  label: l10n.sertFooterTerbit,
                  nilai: snap.footer.issuanceDate,
                ),
                _BarisHeader(
                  label: l10n.sertFooterTtd,
                  nilai: snap.footer.penandatangan,
                ),
                _BarisHeader(
                  label: l10n.sertFooterJabatan,
                  nilai: snap.footer.jabatan,
                ),
                _BarisHeader(
                  label: l10n.sertFooterKode,
                  nilai: snap.footer.kodeDokumen,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Text(
          l10n.sertCorrectionCatatan,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _PitaFail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, size: 20, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // Sesi FAIL tetap terbit sertifikatnya — isinya "tidak laik
              // pakai". Yang beda keputusannya, bukan boleh/nggaknya terbit.
              'FAIL — alat tidak laik pakai',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisHeader extends StatelessWidget {
  const _BarisHeader({required this.label, required this.nilai});

  final String label;
  final String? nilai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: theme.textTheme.labelSmall),
          ),
          Text(': ', style: theme.textTheme.labelSmall),
          Expanded(
            child: Text(
              (nilai == null || nilai!.isEmpty) ? '—' : nilai!,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tabel hasil — **empat kolom, nggak lebih** (spesifikasi poin 9).
class _TabelHasil extends StatelessWidget {
  const _TabelHasil({required this.snapshot});

  final CertificateSnapshot snapshot;

  /// Baris hasil dikelompokkan pakai `remark`, urut ngikut urutan sertifikat.
  /// Alat tanpa keterangan titik jadi SATU kelompok berkunci kosong.
  Map<String, List<BarisHasilSertifikat>> get _kelompok {
    final hasil = <String, List<BarisHasilSertifikat>>{};
    for (final b in snapshot.hasil) {
      hasil.putIfAbsent(b.remark ?? '', () => []).add(b);
    }

    return hasil;
  }

  /// Kepala kolom bawa satuan kelompoknya (`Standard (nm)`), persis lembar
  /// master. Satu kelompok selalu satu satuan; alat bersatuan seragam ngirim
  /// null dan kepalanya tetap kayak dulu.
  static String _kepala(String label, List<BarisHasilSertifikat> baris) {
    final satuan = baris.first.satuan;

    return satuan == null ? label : '$label ($satuan)';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = snapshot.desimal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sertHasilJudul,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Dikelompokkan pakai `remark`, persis PDF-nya: satu tabel per
            // kelompok, dan `Uncertainty U95% = ±` di bawah tiap tabel.
            //
            // Buat alat yang U95-nya lahir per KELOMPOK (Spectrophotometer),
            // sepuluh baris Holmium bawa angka yang sama persis — di tabel
            // datar 24 baris itu kebaca kayak muncul acak, dan `0,4 nm` nggak
            // punya cara dibedain punya Didynium apa Holmium.
            //
            // Alat tanpa keterangan titik lewat jalur yang SAMA sebagai satu
            // kelompok tanpa judul: tampilannya nggak berubah sama sekali.
            for (final e in _kelompok.entries) ...[
              if (e.key.isNotEmpty) ...[
                Text(
                  e.key,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Table(
                columnWidths: snapshot.u95PerTitik
                    ? const {
                        0: FlexColumnWidth(1.1),
                        1: FlexColumnWidth(1.1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                      }
                    : const {
                        0: FlexColumnWidth(1.1),
                        1: FlexColumnWidth(1.1),
                        2: FlexColumnWidth(1),
                      },
                children: [
                  TableRow(
                    children: [
                      _sel(context, _kepala(l10n.sertKolStandard, e.value), tebal: true),
                      _sel(context, _kepala(l10n.sertKolUut, e.value), tebal: true),
                      _sel(context, _kepala(l10n.sertKolCorrection, e.value), tebal: true),
                      // Judulnya nyebut `k=2` persis kayak master — angka
                      // ketidakpastian tanpa faktor cakupannya nggak berarti
                      // apa-apa.
                      if (snapshot.u95PerTitik)
                        _sel(context, _kepala(l10n.sertKolU95, e.value), tebal: true),
                    ],
                  ),
                  // Desimal diambil PER BARIS (`b.desimal`) dulu, baru jatuh ke
                  // `desimal` sertifikat. Alat yang resolusinya berubah menurut
                  // rentang (Turbidimeter: 0,01 / 0,1 / 1 NTU) nggak bisa
                  // diwakili satu angka — dipaksa satu, titik 100 NTU kecetak
                  // `101,00`, dua digit yang alatnya nggak bisa tampilkan.
                  //
                  // Formatternya sama persis sama `pdf.blade.php`: layar ini
                  // dipakai buat nyocokin sama PDF sebelum dikirim ke
                  // pelanggan, jadi beda sedikit pun bikin orang ragu mana yang
                  // resmi.
                  for (final b in e.value)
                    TableRow(
                      children: [
                        _sel(
                          context,
                          formatNilaiStandar(b.standardValue, b.desimalEfektif(d)),
                        ),
                        _sel(
                          context,
                          formatSertifikat(
                            b.unitUnderTest,
                            b.desimalEfektif(d),
                            tandaNol: b.tandaNol,
                          ),
                        ),
                        _sel(
                          context,
                          formatSertifikat(
                            b.correction,
                            b.desimalEfektif(d),
                            tandaNol: b.tandaNol,
                          ),
                        ),
                        // Desimal U95 lewat jalurnya sendiri (`desimalU95`),
                        // bukan desimal baris — master nyetak `0,50 %T`
                        // sementara kolom lain di blok yang sama tiga desimal.
                        if (snapshot.u95PerTitik)
                          _sel(
                            context,
                            formatSertifikat(
                              b.u95,
                              b.desimalU95 ?? b.desimalEfektif(d),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // U95 satu kelompok — diambil dari baris pertama, BUKAN dihitung
              // ulang. Tiap titik sekelompok emang bawa angka yang sama; kalau
              // suatu saat beda, yang salah datanya, dan ngerata-ratain di sini
              // cuma nyembunyiin itu.
              //
              // Dilewat buat alat yang U95-nya udah jadi kolom per baris —
              // kalau dua-duanya dirender, angka titik pertama muncul dobel dan
              // yang kedua kebaca kayak U95 buat SELURUH tabel.
              if (!snapshot.u95PerTitik)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${l10n.sertU95Baris} '
                  // Desimal U95 punya jalurnya sendiri — lihat
                  // [BarisHasilSertifikat.desimalU95].
                  '${formatSertifikat(e.value.first.u95, e.value.first.desimalU95 ?? e.value.first.desimalEfektif(d))}'
                  '${e.value.first.satuan == null ? '' : ' ${e.value.first.satuan}'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (e.value.first.faktorCakupanK != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.sertFaktorCakupan(
                      formatNilai(e.value.first.faktorCakupanK!, desimalMaks: 2),
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _sel(BuildContext context, String teks, {bool tebal = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: Text(
        teks,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: tebal ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _TabelStandar extends StatelessWidget {
  const _TabelStandar({required this.standar});

  final List<StandarDigunakan> standar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (standar.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sertStandarJudul,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final s in standar)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name ?? '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        s.merkType,
                        s.serialNumber,
                        s.traceableTo,
                      ].whereType<String>().join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tiga bentuk unduhan dari sertifikat yang sama: PDF (kirim resmi ke klien),
/// Excel (arsip/rekap), QR (akses cepat) — spesifikasi poin 10 & 13.
class _BilahUnduh extends ConsumerStatefulWidget {
  const _BilahUnduh({required this.sertifikat});

  final CertificateDetail sertifikat;

  @override
  ConsumerState<_BilahUnduh> createState() => _BilahUnduhState();
}

class _BilahUnduhState extends ConsumerState<_BilahUnduh> {
  bool _sibuk = false;

  Future<void> _unduh(String url, String namaFile, {bool buka = true}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null || !mounted) return;

    setState(() => _sibuk = true);
    try {
      // File-nya di disk privat backend dan butuh header Authorization —
      // nggak bisa dibuka langsung di browser HP.
      final path = await ref
          .read(pdfDownloaderProvider)
          .unduh(token, url, namaFile: namaFile);

      if (!buka) {
        _tampilkanQr(path);
        return;
      }

      final gagal = await bukaBerkas(path);
      if (gagal != null && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.sertUnduhGagal(gagal))),
        );
      }
    } on PdfDownloadException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.sertUnduhGagal(e.message))),
        );
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  void _tampilkanQr(String path) {
    final l10n = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sertQrJudul),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QR-nya digambar BACKEND — mobile cuma nampilin PNG-nya, jadi
            // isi yang di-encode nggak mungkin beda dari halaman verifikasi.
            Image.file(File(path), width: 200, height: 200),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.sertQrBody, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.folderBatal),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final svc = ref.read(certificateServiceProvider);
    final id = widget.sertifikat.id;
    final nomor = widget.sertifikat.nomor;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.sertUnduhPdf,
                  icon: Icons.picture_as_pdf_outlined,
                  isLoading: _sibuk,
                  onPressed: () => _unduh(svc.urlPdf(id), '$nomor.pdf'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: l10n.sertUnduhExcel,
                  icon: Icons.table_chart_outlined,
                  variant: AppButtonVariant.secondary,
                  isLoading: _sibuk,
                  onPressed: () => _unduh(svc.urlExcel(id), '$nomor.xlsx'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: l10n.sertLihatQr,
                  icon: Icons.qr_code_2,
                  variant: AppButtonVariant.secondary,
                  isLoading: _sibuk,
                  onPressed: () =>
                      _unduh(svc.urlQr(id), '$nomor-qr.png', buka: false),
                ),
              ),
            ],
          ),
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
          l10n.sertGagalMuat,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.folderRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
