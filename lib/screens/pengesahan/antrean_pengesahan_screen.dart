import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/pengesahan.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/pengendalian_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../history/calibration_detail_screen.dart';

/// Gerbang sertifikat — antrean yang menunggu disahkan.
///
/// Satu layar, dua pemilik (keputusan 26 Sep 2026):
/// - **Super admin** mengesahkan (sertifikat baru lahir di sini, nomornya baru
///   dialokasikan di sini) atau mengembalikan ke admin dengan alasan.
/// - **Admin** melihat pengajuannya masih mengantre, dan boleh MENARIKNYA
///   selama belum disahkan — janji "masih bisa dibalik" tanpa urusan ISO/IEC
///   17025 §7.8.8, karena sertifikatnya memang belum pernah ada.
///
/// Urutannya dari yang PALING LAMA menunggu (disortir server). Layar ini ada
/// supaya tidak ada sertifikat yang tertahan berhari-hari; urutan "terbaru
/// dulu" justru menyembunyikan yang paling perlu dilihat di dasar daftar.
class AntreanPengesahanScreen extends ConsumerStatefulWidget {
  const AntreanPengesahanScreen({super.key});

  @override
  ConsumerState<AntreanPengesahanScreen> createState() =>
      _AntreanPengesahanScreenState();
}

class _AntreanPengesahanScreenState
    extends ConsumerState<AntreanPengesahanScreen> {
  final _cari = TextEditingController();
  Timer? _jeda;

  @override
  void dispose() {
    _cari.dispose();
    _jeda?.cancel();
    super.dispose();
  }

  void _ketik(String q) {
    _jeda?.cancel();
    _jeda = Timer(const Duration(milliseconds: 400), () {
      ref.read(antreanPengesahanProvider.notifier).cari(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(antreanPengesahanProvider);
    final peran = ref.watch(authProvider).value?.role;
    final pengesah = peran == UserRole.superAdmin;

    final data = async.value;
    final Widget isi;
    if (data != null) {
      isi = data.isEmpty
          ? _Kosong(pengesah: pengesah)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              itemCount: data.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _KartuPengajuan(item: data[i], pengesah: pengesah),
            );
    } else if (async.hasError) {
      isi = _Gagal(
        pesan: async.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.pengesahanGagalMuat,
        onCobaLagi: () =>
            ref.read(antreanPengesahanProvider.notifier).muatUlang(),
      );
    } else {
      isi = const _Kerangka();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pengesahanJudul)),
      body: ReadableWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _cari,
                onChanged: _ketik,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.pengesahanCari,
                ),
              ),
            ),
            if (data != null && data.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.pengesahanRingkas(data.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(antreanPengesahanProvider.notifier).muatUlang(),
                child: isi,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuPengajuan extends ConsumerWidget {
  const _KartuPengajuan({required this.item, required this.pengesah});

  final ItemPengesahan item;
  final bool pengesah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hari = item.menungguHari;

    return Card(
      child: InkWell(
        onTap: () => _bukaTindakan(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.nomorSesi,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (item.keputusan != null)
                    StatusBadge.fromApi(item.keputusan!),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  item.alatNama,
                  if (item.alatMerk != null) item.alatMerk!,
                ].join(' · '),
                style: theme.textTheme.titleSmall,
              ),
              if (item.pelanggan != null)
                Text(
                  item.pelanggan!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  if (item.teknisiKode != null)
                    _Meta(ikon: Icons.badge_outlined, teks: item.teknisiKode!),
                  if (item.diajukanOleh != null)
                    _Meta(
                      ikon: Icons.person_outline,
                      teks: l10n.pengesahanDiajukanOleh(item.diajukanOleh!),
                    ),
                  if (hari != null)
                    _Meta(
                      ikon: Icons.schedule,
                      teks: hari == 0
                          ? l10n.pengesahanHariIni
                          : l10n.pengesahanMenungguHari(hari),
                      // Lebih dari dua hari menunggu = perlu dilihat.
                      warna: hari >= 2
                          ? AppColors.statusPeringatan(context)
                          : null,
                    ),
                ],
              ),
              if (item.catatanPengajuan != null &&
                  item.catatanPengajuan!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '“${item.catatanPengajuan!}”',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bukaTindakan(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (lembar) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.nomorSesi,
                style: Theme.of(lembar).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (pengesah) ...[
                // Satu-satunya tombol berwarna di lembar ini: aksi yang
                // melahirkan nomor sertifikat.
                AppButton(
                  label: l10n.pengesahanSahkan,
                  icon: Icons.verified_outlined,
                  onPressed: () {
                    Navigator.of(lembar).pop();
                    _sahkan(context, ref);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: l10n.pengesahanKembalikan,
                  icon: Icons.undo,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    Navigator.of(lembar).pop();
                    _denganAlasan(context, ref, kembalikan: true);
                  },
                ),
              ] else
                AppButton(
                  label: l10n.pengesahanTarik,
                  icon: Icons.undo,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    Navigator.of(lembar).pop();
                    _denganAlasan(context, ref, kembalikan: false);
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.pengesahanLihatDetail),
                onPressed: () {
                  Navigator.of(lembar).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          CalibrationDetailScreen(calibrationId: item.id),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sahkan(
    BuildContext context,
    WidgetRef ref, {
    bool abaikan = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pesan = await ref
          .read(antreanPengesahanProvider.notifier)
          .sahkan(item.id, abaikanPeringatan: abaikan);
      messenger.showSnackBar(
        SnackBar(
          content: Text(pesan.isEmpty ? l10n.pengesahanBerhasil : pesan),
        ),
      );
    } on PengesahanButuhKonfirmasi catch (e) {
      if (!context.mounted) return;
      // Peringatan pemisahan wewenang: DIBACA dulu, baru boleh lanjut.
      // Pelanggarannya tetap tercatat di riwayat server walau dilanjutkan.
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: AppColors.statusPeringatan(d),
          ),
          title: Text(l10n.pengesahanWewenangJudul),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in e.temuan) ...[
                Text('• ${t.pesan}'),
                const SizedBox(height: AppSpacing.xs),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.pengesahanWewenangCatat,
                style: Theme.of(d).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: Text(l10n.custCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: Text(l10n.pengesahanTetapSahkan),
            ),
          ],
        ),
      );
      if (lanjut == true && context.mounted) {
        await _sahkan(context, ref, abaikan: true);
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _denganAlasan(
    BuildContext context,
    WidgetRef ref, {
    required bool kembalikan,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final alasan = await showDialog<String>(
      context: context,
      builder: (_) => _DialogAlasan(
        judul: kembalikan ? l10n.pengesahanKembalikan : l10n.pengesahanTarik,
        petunjuk: kembalikan
            ? l10n.pengesahanAlasanKembalikan
            : l10n.pengesahanAlasanTarik,
        // Sama dengan aturan server: 10 karakter untuk pesan ke ORANG LAIN
        // (dia harus bisa mengerjakannya tanpa balik bertanya), 5 untuk
        // catatan diri sendiri.
        minimal: kembalikan ? 10 : 5,
      ),
    );
    if (alasan == null) return;
    try {
      final notifier = ref.read(antreanPengesahanProvider.notifier);
      final pesan = kembalikan
          ? await notifier.kembalikan(item.id, alasan)
          : await notifier.tarik(item.id, alasan);
      messenger.showSnackBar(SnackBar(content: Text(pesan)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _DialogAlasan extends StatefulWidget {
  const _DialogAlasan({
    required this.judul,
    required this.petunjuk,
    required this.minimal,
  });

  final String judul;
  final String petunjuk;
  final int minimal;

  @override
  State<_DialogAlasan> createState() => _DialogAlasanState();
}

class _DialogAlasanState extends State<_DialogAlasan> {
  final _teks = TextEditingController();

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  bool get _cukup => _teks.text.trim().length >= widget.minimal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.judul),
      content: TextField(
        controller: _teks,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: widget.petunjuk,
          helperText: l10n.pengesahanAlasanMinimal(widget.minimal),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.custCancel),
        ),
        TextButton(
          onPressed: _cukup
              ? () => Navigator.of(context).pop(_teks.text.trim())
              : null,
          child: Text(l10n.pengesahanKirim),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.ikon, required this.teks, this.warna});

  final IconData ikon;
  final String teks;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = warna ?? theme.colorScheme.onSurfaceVariant;
    // `Flexible` + elipsis: di dalam `Wrap`, satu keterangan yang lebih panjang
    // dari lebar kartu ("Diajukan oleh <nama panjang>") dulu meluap 46 px di
    // HP 400 px — garis kuning-hitam, bukan teks terpotong.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 16, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            teks,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.pengesah});

  final bool pengesah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Icon(
          Icons.verified_outlined,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.pengesahanKosong,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          pengesah ? l10n.pengesahanKosongPengesah : l10n.pengesahanKosongAdmin,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Gagal extends StatelessWidget {
  const _Gagal({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(pesan, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: AppLocalizations.of(context).custRetry,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}

class _Kerangka extends StatelessWidget {
  const _Kerangka();

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    itemCount: 3,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (_, _) => const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 12, width: 140),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 16, width: 200),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 12, width: 160),
          ],
        ),
      ),
    ),
  );
}

/// Format tanggal pendek — dipakai di beberapa layar pengendalian.
/// Tanggal pendek mengikuti bahasa app ("2 Okt 2026" / "2 Oct 2026").
///
/// Locale-nya diambil dari `context`, bukan dibiarkan kosong: `Intl.defaultLocale`
/// tidak pernah disetel di app ini, jadi `DateFormat` tanpa locale selalu
/// mencetak nama bulan Inggris — "Target 2 Oct 2026" di layar berbahasa
/// Indonesia. Polanya sama dengan riwayat & antrean approval.
String tanggalPendek(BuildContext context, DateTime? t) => t == null
    ? '—'
    : DateFormat(
        'd MMM yyyy',
        Localizations.localeOf(context).languageCode,
      ).format(t);
