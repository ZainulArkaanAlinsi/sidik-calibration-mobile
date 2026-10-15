import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/history_provider.dart';
import '../../providers/kalibrasi_teknisi_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/status_badge.dart';
import '../calibration/category_picker_screen.dart';
import '../calibration/instrument_picker_screen.dart' show profilLembarKerjaUntuk;
import '../calibration/lembar_kerja_screen.dart';

/// Tab "Kalibrasi" — SATU-SATUNYA tempat kerja teknisi (keputusan pemilik
/// 15 Okt 2026, K-50-14: teknisi hanya mengisi lembar kerja + profil).
///
/// Isinya urut pekerjaannya: mulai lembar baru, perbaiki yang dikembalikan,
/// lanjutkan draf, lalu lihat apa yang sudah terkirim. Tidak ada dashboard,
/// grafik, panel 3D, daftar alat, atau arsip — semuanya pernah dibangun untuk
/// teknisi dan tidak ada yang dipakai di lapangan; yang ada cuma membuat app
/// lambat dibuka.
///
/// Tiga daftar dimuat sendiri-sendiri (satu gagal tidak menjatuhkan yang
/// lain), masing-masing SATU permintaan halaman pertama.
class KalibrasiTeknisiScreen extends ConsumerWidget {
  const KalibrasiTeknisiScreen({super.key});

  static void segarkan(WidgetRef ref) {
    ref
      ..invalidate(perluRevisiTeknisiProvider)
      ..invalidate(drafProvider)
      ..invalidate(terkirimTerakhirProvider);
  }

  /// Buka lembar kerja, lalu segarkan ketiga daftar sesudah kembali — lembar
  /// yang barusan dikirim pindah dari Draf/Perlu revisi ke Terkirim.
  static Future<void> buka(
    BuildContext context,
    WidgetRef ref,
    Widget layar,
  ) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => layar));
    if (context.mounted) segarkan(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tekKalibrasiJudul),
        // Lonceng tetap: lembar yang dikembalikan & kabar lain datang lewat
        // notifikasi.
        actions: const [NotificationBell(), SizedBox(width: AppSpacing.sm)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          segarkan(ref);
          await Future.wait([
            ref.read(perluRevisiTeknisiProvider.future).then((_) {}, onError: (_) {}),
            ref.read(drafProvider.future).then((_) {}, onError: (_) {}),
            ref.read(terkirimTerakhirProvider.future).then((_) {}, onError: (_) {}),
          ]);
        },
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppButton(
                key: const ValueKey('tombol-mulai-kalibrasi'),
                label: l10n.dashStartCalibration,
                icon: Icons.add_task,
                onPressed: () =>
                    buka(context, ref, const CategoryPickerScreen()),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Bagian(
                kunci: 'bagian-perlu-revisi',
                sembunyiBilaKosong: true,
                judul: l10n.tekPerluRevisi,
                kosong: l10n.tekPerluRevisiKosong,
                isi: ref.watch(perluRevisiTeknisiProvider),
                onCobaLagi: () => ref.invalidate(perluRevisiTeknisiProvider),
                baris: (s) => _KartuSesi(sesi: s, bisaDibuka: true),
              ),
              _Bagian(
                kunci: 'bagian-draf',
                judul: l10n.drafTitle,
                kosong: l10n.tekDrafKosong,
                isi: ref.watch(drafProvider),
                onCobaLagi: () => ref.invalidate(drafProvider),
                baris: (s) => _KartuSesi(sesi: s, bisaDibuka: true),
              ),
              _Bagian(
                kunci: 'bagian-terkirim',
                judul: l10n.tekTerkirim,
                kosong: l10n.tekTerkirimKosong,
                isi: ref.watch(terkirimTerakhirProvider),
                onCobaLagi: () => ref.invalidate(terkirimTerakhirProvider),
                baris: (s) => _KartuSesi(sesi: s, bisaDibuka: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bagian extends StatelessWidget {
  const _Bagian({
    required this.kunci,
    required this.judul,
    required this.kosong,
    required this.isi,
    required this.onCobaLagi,
    required this.baris,
    this.sembunyiBilaKosong = false,
  });

  /// Bagian lama yang hanya muncul kalau ADA isinya (Perlu revisi: jalur Tolak
  /// dicabut 15 Okt 2026, tinggal sesi lama). Selama memuat pun tidak
  /// memajang apa-apa; galat tetap tampil dengan tombol coba lagi.
  final bool sembunyiBilaKosong;

  final String kunci;
  final String judul;
  final String kosong;
  final AsyncValue<List<CalibrationHistoryItem>> isi;
  final VoidCallback onCobaLagi;
  final Widget Function(CalibrationHistoryItem) baris;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final data = isi.value;

    if (sembunyiBilaKosong && !isi.hasError && (data == null || data.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: ValueKey(kunci),
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data == null ? judul : '$judul (${data.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data != null) ...[
            if (data.isEmpty)
              Text(
                kosong,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final s in data) baris(s),
          ] else if (isi.hasError)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.tekGagalMuat,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                TextButton(onPressed: onCobaLagi, child: Text(l10n.folderRetry)),
              ],
            )
          else
            const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class _KartuSesi extends ConsumerWidget {
  const _KartuSesi({required this.sesi, required this.bisaDibuka});

  final CalibrationHistoryItem sesi;

  /// Draf & perlu revisi dibuka langsung ke lembar kerjanya; yang sudah
  /// terkirim cuma dibaca statusnya.
  final bool bisaDibuka;

  static String _kodeStatus(CalibrationStatus s) => switch (s) {
    CalibrationStatus.draft => 'draft',
    CalibrationStatus.menungguApproval => 'menunggu_approval',
    CalibrationStatus.disetujui => 'disetujui',
    CalibrationStatus.perluRevisi => 'perlu_revisi',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final catatan = sesi.catatanRevisi;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        key: ValueKey('kartu-sesi-teknisi-${sesi.id}'),
        onTap: !bisaDibuka
            ? null
            : () => KalibrasiTeknisiScreen.buka(
                context,
                ref,
                LembarKerjaScreen(
                  sesiId: sesi.id,
                  // Profil dari server dulu; tebakan nama cuma cadangan.
                  profil:
                      sesi.profil ??
                      profilLembarKerjaUntuk(sesi.namaAlat) ??
                      'ph_meter',
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sesi.namaAlat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge.fromApi(_kodeStatus(sesi.status)),
                ],
              ),
              if (sesi.nomorSesi != null || sesi.namaPelanggan != null) ...[
                const SizedBox(height: 2),
                Text(
                  [?sesi.nomorSesi, ?sesi.namaPelanggan].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // Catatan Master Data ditulis UTUH di kartu: itu yang harus
              // dikerjakan, dan teknisi tidak perlu membuka layar lain untuk
              // membacanya.
              if (sesi.status == CalibrationStatus.perluRevisi &&
                  catatan != null &&
                  catatan.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  catatan,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
