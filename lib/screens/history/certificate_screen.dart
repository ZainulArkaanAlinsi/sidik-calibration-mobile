import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/buka_berkas.dart';

import '../../core/config/lab_profile.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/angka.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../models/calibration_detail.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/izin_provider.dart';
import '../../providers/history_provider.dart';
import '../../services/pdf_downloader.dart';
import '../../widgets/app_button.dart';
import '../../widgets/certificate_qr.dart';
import 'kirim_email_screen.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';

/// Detail sertifikat — dibuka dari tombol "Lihat Sertifikat" di
/// [CalibrationDetailScreen]. Ambil datanya lewat [calibrationDetailProvider]
/// (bukan endpoint sertifikat sendiri): backend nggak punya
/// `GET /api/certificates/{id}` JSON — yang ada cuma `GET /certificates`
/// (daftar) & `GET /certificates/{id}/download` (stream file PDF). Ringkasan
/// nomor/status/pdf_url udah nempel di `sertifikat` pada respons
/// `GET /api/calibrations/{id}`, jadi satu provider ini cukup buat
/// nampilin semuanya — nggak ada request kedua.
class CertificateScreen extends ConsumerWidget {
  const CertificateScreen({super.key, required this.calibrationId});

  final int calibrationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(calibrationDetailProvider(calibrationId));
    final l10n = AppLocalizations.of(context);

    // Data dulu, baru error, baru loading — sama urutannya kayak
    // dashboard_screen.dart, biar retry otomatis Riverpod yang jalan di
    // belakang layar nggak nyangkutin skeleton selamanya.
    final data = detail.value;

    final Widget isi;
    if (data != null) {
      isi = _Isi(detail: data);
    } else if (detail.hasError) {
      isi = _Gagal(
        onCobaLagi: () => ref.invalidate(calibrationDetailProvider(calibrationId)),
      );
    } else {
      isi = const _Skeleton();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.certTitle)),
      body: isi,
    );
  }
}

class _Isi extends ConsumerStatefulWidget {
  const _Isi({required this.detail});

  final CalibrationDetail detail;

  @override
  ConsumerState<_Isi> createState() => _IsiState();
}

class _IsiState extends ConsumerState<_Isi> {
  bool _busy = false;

  Future<void> _retryGenerate() async {
    final sertifikat = widget.detail.sertifikat;
    if (sertifikat == null) return;

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(approvalServiceProvider).retryGenerate(token, sertifikat.id);
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(calibrationDetailProvider(widget.detail.id));
    }
  }

  Future<void> _lihatPdf() async {
    final l10n = AppLocalizations.of(context);
    final sertifikat = widget.detail.sertifikat;
    final pdfUrl = sertifikat?.pdfUrl;
    if (sertifikat == null || pdfUrl == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final path = await ref
          .read(pdfDownloaderProvider)
          .unduh(token, pdfUrl, namaFile: '${sertifikat.nomor}.pdf');

      final gagal = await bukaBerkas(path);
      if (gagal != null && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.certOpenFailed(gagal))),
        );
      }
    } on PdfDownloadException catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final detail = widget.detail;
    final sertifikat = detail.sertifikat;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: Icon(
            Icons.workspace_premium_outlined,
            size: 72,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          sertifikat?.nomor ?? l10n.certBelumTerbit,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Ringkasan(detail: detail),
        const SizedBox(height: AppSpacing.lg),

        // Isi sertifikat, disusun ngikutin urutan formulir asli
        // (`SIDIK-FM-CAL-2403`). Gunanya buat DICOCOKIN sebelum di-approve —
        // begitu sertifikat terbit dan dipegang pelanggan, angkanya nggak bisa
        // diubah lagi (`docs/kontrak-api.md` §4: sesi `disetujui` ditolak 422).
        _IdentitasSesi(detail: detail),
        const SizedBox(height: AppSpacing.lg),
        _TabelLaporan(titik: detail.titik, desimal: detail.desimal),
        const SizedBox(height: AppSpacing.lg),
        _StandarDipakai(titik: detail.titik),
        const SizedBox(height: AppSpacing.lg),

        if (sertifikat == null) ...[
          _StatusBanner(
            icon: Icons.hourglass_empty,
            warna: AppColors.info,
            pesan: l10n.certStatusMenungguGenerate,
          ),
        ] else if (sertifikat.status == 'menunggu_generate') ...[
          _StatusBanner(
            icon: Icons.hourglass_empty,
            warna: AppColors.info,
            pesan: l10n.certStatusMenungguGenerate,
          ),
        ] else if (sertifikat.status == 'gagal') ...[
          _StatusBanner(
            icon: Icons.error_outline,
            warna: theme.colorScheme.error,
            pesan: l10n.certStatusGagal,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.certRetry,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            isLoading: _busy,
            onPressed: _busy ? null : _retryGenerate,
          ),
        ] else ...[
          if (sertifikat.pdfUrl != null)
            AppButton(
              label: l10n.certOpenPdf,
              icon: Icons.picture_as_pdf_outlined,
              isLoading: _busy,
              onPressed: _busy ? null : _lihatPdf,
            ),
          // QR cuma dirender buat sertifikat yang BENERAN udah terbit. Sesi
          // yang masih nunggu generate atau gagal nggak punya apa-apa buat
          // diverifikasi — QR yang nunjuk ke halaman kosong lebih bikin ragu
          // daripada nggak ada QR sama sekali.
          // Cuma admin: backend nolak `403` buat role lain, jadi tombolnya
          // jangan dipajang ke teknisi biar nggak nyoba lalu ditolak.
          if (ref.bolehkah(
            NamaIzin.sertifikatKirim,
            cadangan: ref.watch(authProvider).value?.role.adminSaja ?? false,
          )) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.certKirimEmail,
              icon: Icons.mail_outline,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => KirimEmailScreen(
                    certificateId: sertifikat.id,
                    nomorSertifikat: sertifikat.nomor,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          CertificateQr(token: sertifikat.qrToken, url: sertifikat.qrUrl),
        ],
      ],
    );
  }
}

String _angka(double? v, {int desimal = 2}) =>
    v == null ? '—' : v.toStringAsFixed(desimal);

/// "21,0 °C ± 1,7 °C". Kalau U95%-nya belum ada (sesi yang cuma ngirim satu
/// angka suhu), bagian "±" dibuang — bukan ditulis "± —", yang kebaca kayak
/// ketidakpastiannya nol.
String _besaran(BesaranLingkungan b, {int desimal = 2}) {
  final nilai = '${_angka(b.rataRata, desimal: desimal)} ${b.satuan}';
  if (b.u95 == null) return nilai;

  return '$nilai ± ${_angka(b.u95, desimal: 1)} ${b.satuan}';
}

/// Blok identitas sesi — bagian kepala sertifikat.
///
/// **Sengaja nggak nampilin Owner/Alamat/Merk/Model/Nomor Seri.** Bukan
/// kelewat: `GET /api/calibrations/{id}` cuma ngirim `equipment: {id,
/// nama_alat}` (`docs/kontrak-api.md` §4), jadi datanya emang nggak nyampe ke
/// HP. Nampilin kolom kosong di layar yang dipakai buat nyocokin sertifikat
/// malah bikin orang ngira datanya hilang di sertifikat juga — padahal PDF-nya
/// digenerate backend yang punya data lengkapnya.
class _IdentitasSesi extends StatelessWidget {
  const _IdentitasSesi({required this.detail});

  final CalibrationDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lingkungan = detail.kondisiLingkungan;

    // Metode nempel di titik, bukan di sesi — tapi satu sesi selalu satu
    // metode, jadi diambil dari titik pertama yang punya.
    final metode = detail.titik
        .map((t) => t.metode)
        .whereType<String>()
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.certIdentitasTitle.toUpperCase(),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _RingkasanRow(
                  label: l10n.certTanggalKalibrasi,
                  value: DateFormat('d MMM yyyy').format(detail.tanggalKalibrasi),
                ),
                _RingkasanRow(
                  label: l10n.certTeknisi,
                  value: detail.namaTeknisi,
                ),
                if (detail.lokasi != null)
                  _RingkasanRow(label: l10n.certLokasi, value: detail.lokasi!),
                if (metode != null)
                  _RingkasanRow(label: l10n.certMetode, value: metode),
                // Format "21,0 °C ± 1,7 °C" — sama kayak baris Env. Condition
                // di formulir asli. Suhu & kelembaban dicek sendiri-sendiri:
                // sesi lama bisa punya salah satunya aja.
                if (lingkungan?.suhu != null)
                  _RingkasanRow(
                    label: 'T',
                    value: _besaran(lingkungan!.suhu!, desimal: 1),
                  ),
                if (lingkungan?.kelembaban != null)
                  _RingkasanRow(
                    label: '%RH',
                    value: _besaran(lingkungan!.kelembaban!),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tabel **Calibration Report** — empat kolom persis formulir asli:
/// Standard Value · Unit Under Test · Correction · U95% (±).
///
/// Kolom "Correction" pakai `koreksi` (standar − pembacaan), **bukan** `error`
/// (pembacaan − standar). Dua-duanya dikirim backend dan cuma beda tanda —
/// yang masuk sertifikat itu `koreksi`, sesuai formulir. Ketuker berarti
/// tanda koreksi di sertifikat pelanggan kebalik.
///
/// Angkanya ditulis lewat [formatSertifikat] dengan desimal per titik — jalur
/// yang sama dipakai layar sertifikat & `pdf.blade.php`. Dulu di sini dipatok
/// dua desimal, dan itu bikin layar riwayat beda dari sertifikatnya sendiri
/// buat dua alat: Refractometer `1,33935` kebaca `1,34` (U95% `0,00053` malah
/// jadi `0,00`, seolah nggak ada ketidakpastian), dan titik 1.000 NTU
/// Turbidimeter kebaca `1000,60` — dua digit yang alatnya nggak bisa tampilkan.
class _TabelLaporan extends StatelessWidget {
  const _TabelLaporan({required this.titik, required this.desimal});

  final List<MeasurementResult> titik;

  /// Desimal tingkat-sesi; tiap titik boleh nimpa lewat
  /// [MeasurementResult.desimalEfektif].
  final int desimal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (titik.isEmpty) {
      return Text(l10n.certBelumDihitung, style: theme.textTheme.bodySmall);
    }

    final gayaJudul = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final gayaAngka = AppTypography.measurement.copyWith(fontSize: 13);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.certReportTitle.toUpperCase(),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            // Empat kolom angka nggak muat di layar HP sempit. Digeser
            // sendiri, bukan dikecilin fontnya — angka sertifikat harus tetap
            // kebaca jelas.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: AppSpacing.md,
                headingRowHeight: 36,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 40,
                columns: [
                  DataColumn(label: Text(l10n.certColStandard, style: gayaJudul)),
                  DataColumn(label: Text(l10n.certColUut, style: gayaJudul)),
                  DataColumn(label: Text(l10n.certColKoreksi, style: gayaJudul)),
                  DataColumn(label: Text(l10n.certColU95, style: gayaJudul)),
                ],
                rows: [
                  for (final t in titik)
                    () {
                      final d = t.desimalEfektif(desimal);

                      return DataRow(
                        cells: [
                          DataCell(Text(formatNilaiStandar(t.titikUkur, d), style: gayaAngka)),
                          DataCell(Text(formatSertifikat(t.rataRata, d), style: gayaAngka)),
                          DataCell(Text(formatSertifikat(t.koreksi, d), style: gayaAngka)),
                          DataCell(
                            Text(
                              formatSertifikat(t.ketidakpastianDiperluas, d),
                              style: gayaAngka,
                            ),
                          ),
                        ],
                      );
                    }(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Kalimat k=2 & tingkat kepercayaan diambil dari profil lab, bukan
        // ditulis ulang di sini — angka ini dinyatakan di lampiran akreditasi.
        Text(
          LabProfile.catatanKetidakpastian,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.certDisclaimer,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// Tabel **Standard used**.
///
/// Formulir aslinya punya empat kolom (Name · Merk/Type · Serial Number ·
/// Traceable to SI through); yang nyampe ke HP cuma nama & nomor sertifikat —
/// `standar_acuan` di respons titik isinya `{id, nama, no_sertifikat}` doang.
class _StandarDipakai extends StatelessWidget {
  const _StandarDipakai({required this.titik});

  final List<MeasurementResult> titik;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Satu standar bisa kepakai di beberapa titik — ditampilin sekali aja,
    // sama kayak di formulir.
    final unik = <int, StandardRef>{};
    for (final t in titik) {
      final s = t.standarAcuan;
      if (s != null) unik[s.id] = s;
    }
    if (unik.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.certStandarDipakai.toUpperCase(),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                for (final s in unik.values)
                  _RingkasanRow(
                    label: s.nama,
                    value: s.noSertifikat ?? '—',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ringkasan hasil (alat, standar dipakai, kondisi lingkungan, keputusan) —
/// dari objek `detail` yang sama, bukan request kedua.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({required this.detail});

  final CalibrationDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.certRingkasanTitle.toUpperCase(), style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        detail.namaAlat,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: detail.keputusan == Keputusan.fail
                          ? l10n.historyStatusFail
                          : l10n.historyStatusPass,
                      tone: detail.keputusan == Keputusan.fail
                          ? BadgeTone.danger
                          : BadgeTone.success,
                      icon: detail.keputusan == Keputusan.fail
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (detail.standarAcuan != null)
                  _RingkasanRow(
                    label: l10n.detailStandarAcuan,
                    value: detail.standarAcuan!.nama,
                  ),
                if (detail.suhuRuang != null && detail.kelembaban != null)
                  _RingkasanRow(
                    label: l10n.detailKondisiLingkungan,
                    value:
                        '${detail.suhuRuang!.toStringAsFixed(1)} °C · '
                        '${detail.kelembaban!.toStringAsFixed(1)} %RH',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RingkasanRow extends StatelessWidget {
  const _RingkasanRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.warna,
    required this.pesan,
  });

  final IconData icon;
  final Color warna;
  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: warna.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: warna),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(pesan)),
        ],
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
          l10n.certLoadFailed,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.historyRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Center(child: SkeletonBox(height: 72, width: 72)),
        const SizedBox(height: AppSpacing.md),
        const Center(child: SkeletonBox(height: 22, width: 180)),
      ],
    );
  }
}
