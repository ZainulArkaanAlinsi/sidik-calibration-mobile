import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/buka_berkas.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/certificate_snapshot.dart';
import '../../models/izin.dart';
import '../../models/revisi_sertifikat.dart' show StatusDokumen;
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/certificate_provider.dart';
import '../../providers/history_provider.dart';
import '../../services/pdf_downloader.dart';
import '../../widgets/app_button.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_tombol.dart';
import '../../widgets/sertifikat_pdf_view.dart';
import '../../widgets/lebar_dekode.dart';
import '../../widgets/sidik_loader.dart';
import 'batal_sertifikat_dialog.dart';
import 'info_dokumen_sertifikat.dart';
import 'revisi_sertifikat_screen.dart';
import 'tarik_sertifikat_dialog.dart';

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
        AsyncData(:final value) => _Isi(
          sertifikat: value,
          onBuka: (id) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SertifikatScreen(certificateId: id),
            ),
          ),
        ),
        AsyncError() => _Gagal(
          onCobaLagi: () =>
              ref.invalidate(certificateDetailProvider(certificateId)),
        ),
        _ => const Center(child: SidikLoader(size: 88)),
      },
      // Yang dibatalkan tetap bisa diunduh: arsip lab, bukan lembar pelanggan.
      bottomNavigationBar: async.value?.bisaUnduh ?? false
          ? _BilahUnduh(sertifikat: async.value!)
          : null,
    );
  }
}

class _Isi extends ConsumerWidget {
  const _Isi({required this.sertifikat, required this.onBuka});

  final CertificateDetail sertifikat;
  final ValueChanged<int> onBuka;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snap = sertifikat.snapshot;

    // Status dokumen + tombol admin di paling atas. Server lama (tanpa field
    // baru) menghasilkan kartu berlencana "Berlaku" tanpa tombol apa pun.
    final peran = ref.watch(authProvider).value?.role;
    final atas = <Widget>[
      InfoDokumenSertifikat(sertifikat: sertifikat, onBuka: onBuka),
      const SizedBox(height: AppSpacing.md),
      // Admin & super admin (K-49-14) yang boleh menulis; teknisi & viewer
      // tidak punya pintunya sama sekali. Server tetap penjaganya.
      if ((peran?.hakAdmin ?? false) &&
          (sertifikat.bisaDirevisi ||
              sertifikat.bisaDibatalkan ||
              _bisaTarik(ref, sertifikat))) ...[
        _TindakanAdmin(sertifikat: sertifikat),
        const SizedBox(height: AppSpacing.md),
      ],
    ];

    if (snap == null) {
      // PDF-nya belum jadi = snapshot-nya juga belum ada. Isinya dibekukan
      // waktu terbit, jadi nggak ada yang bisa ditampilin selain statusnya.
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ...atas,
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Icon(
              Icons.hourglass_empty,
              size: 56,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.sertBelumTerbit, textAlign: TextAlign.center),
        ],
      );
    }

    // Ringkasan Flutter di atas; badan sertifikat = PDF server (G4).
    return Column(
      children: [
        Flexible(
          flex: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              children: [
                ...atas,
                if (snap.gagal) ...[
                  _PitaFail(),
                  const SizedBox(height: AppSpacing.md),
                ],
                _Ringkasan(sertifikat: sertifikat),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
        Expanded(child: SertifikatPdfView(certificateId: sertifikat.id)),
      ],
    );
  }
}

/// Nomor, pelanggan, alat, dan masa berlaku. Status (ditarik / R-n / batal)
/// sudah di kartu `InfoDokumenSertifikat` di atasnya.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.sertifikat});

  final CertificateDetail sertifikat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final h = sertifikat.snapshot?.header;
    final baris = <(String, String?)>[
      (l10n.sertRingNomor, sertifikat.nomor),
      (l10n.sertRingPelanggan, h?.owner ?? sertifikat.pelangganNama),
      (l10n.sertRingAlat, h?.equipmentName),
      (l10n.sertRingBerlaku, sertifikat.berlakuSampai),
    ];
    return Card(
      key: const ValueKey('ringkasan-sertifikat'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, nilai) in baris)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 112,
                      child: Text(label, style: theme.textTheme.labelSmall),
                    ),
                    Expanded(
                      child: Text(
                        (nilai == null || nilai.isEmpty) ? '—' : nilai,
                        style: theme.textTheme.bodySmall,
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

/// Tombol admin di detail sertifikat: Revisi & Batalkan. Dipajang hanya kalau
/// server bilang boleh (`bisa_direvisi` / `bisa_dibatalkan`) DAN perannya admin
/// — keputusan itu ada di pemanggil; server tetap penjaganya (403).
class _TindakanAdmin extends ConsumerWidget {
  const _TindakanAdmin({required this.sertifikat});

  final CertificateDetail sertifikat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = sertifikat;
    // Sertifikat lama (snapshot kosong) tidak punya `data_cetak`: server
    // menolak revisinya, jadi tombolnya tidak ditawarkan.
    final bisaRevisi = s.bisaDirevisi && s.dataCetak != null;

    return Kertas(
      key: const ValueKey('tindakan-admin-sertifikat'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bisaRevisi)
            SidikTombol(
              key: const ValueKey('tombol-revisi-sertifikat'),
              label: l10n.sertRevisi,
              ikon: Icons.edit_document,
              ragam: RagamTombol.biasa,
              penuh: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RevisiSertifikatScreen(sertifikat: s),
                ),
              ),
            )
          else if (s.bisaDirevisi)
            Text(l10n.sertRevisiTanpaData, style: theme.textTheme.bodySmall),
          if (_bisaTarik(ref, s)) ...[
            if (bisaRevisi || s.bisaDirevisi)
              const SizedBox(height: AppSpacing.sm),
            SidikTombol(
              key: const ValueKey('tombol-tarik-sertifikat'),
              label: l10n.tarikAksi,
              ikon: Icons.undo,
              ragam: RagamTombol.biasa,
              penuh: true,
              onPressed: () => _tarik(context),
            ),
          ],
          if (s.bisaDibatalkan) ...[
            if (s.bisaDirevisi) const SizedBox(height: AppSpacing.sm),
            SidikTombol(
              key: const ValueKey('tombol-batal-sertifikat'),
              label: l10n.sertBatalkan,
              ikon: Icons.block,
              ragam: RagamTombol.bahayaGaris,
              penuh: true,
              onPressed: () => _batalkan(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _tarik(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => TarikSertifikatDialog(sertifikat: sertifikat),
    );
    if (ok == true) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.tarikBerhasil)));
    }
  }

  Future<void> _batalkan(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => BatalSertifikatDialog(sertifikat: sertifikat),
    );
    if (ok == true) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.batalBerhasil)));
    }
  }
}

class _PitaFail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.crimsonSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cancel_outlined,
            size: 20,
            color: AppColors.statusBahaya(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // Sesi FAIL tetap terbit sertifikatnya — isinya "tidak laik
              // pakai". Yang beda keputusannya, bukan boleh/nggaknya terbit.
              'FAIL — alat tidak laik pakai',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.statusBahaya(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
            Image.file(
              File(path),
              width: 200,
              height: 200,
              cacheWidth: lebarDekode(context, 200),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.sertQrBody,
              style: Theme.of(context).textTheme.labelSmall,
            ),
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

/// "Tarik ke lembar kerja" ditawarkan untuk sertifikat yang masih berlaku
/// (`terbit`) kepada pemegang izin `sertifikat.tarik` (admin & super admin,
/// dari `/me/permissions`).
/// Server tetap penjaganya: sudah punya revisi / bukan `disetujui` → 422.
bool _bisaTarik(WidgetRef ref, CertificateDetail s) =>
    s.status == 'terbit' &&
    s.statusDokumen == StatusDokumen.berlaku &&
    // Tanpa cadangan peran: server yang belum mengenal rute tarik (404) juga
    // belum mengirim izinnya — tombol tidak boleh muncul di situ.
    ref.bolehkah(NamaIzin.sertifikatTarik, cadangan: false);
