import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../../models/calibration_history_item.dart';
import '../../providers/history_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/notification_bell.dart';
import 'perhitungan_screen.dart';
import '../../widgets/sidik_loader.dart';

/// Antrean approval admin (spesifikasi poin 12A, rencana §2.1).
///
/// **Teknisi banyak, admin satu pintu**: semua kiriman dari semua akun teknisi
/// masuk ke sini, bukan cuma punya admin sendiri. Bedanya dari layar Riwayat
/// itu di query — Riwayat nggak nyaring status, ini `status=menunggu_approval`.
///
/// Tap satu baris → lembar PERHITUNGAN, tempat admin beneran mutusin.
class AntreanApprovalScreen extends ConsumerWidget {
  const AntreanApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final antrean = ref.watch(antreanApprovalProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.antreanTitle),
        actions: const [NotificationBell(), SizedBox(width: AppSpacing.sm)],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(antreanApprovalProvider.notifier).muatUlang(),
        child: switch (antrean) {
          AsyncData(:final value) =>
            value.isEmpty ? const _Kosong() : _Daftar(items: value),
          AsyncError() => _Gagal(
            onCobaLagi: () =>
                ref.read(antreanApprovalProvider.notifier).muatUlang(),
          ),
          _ => const Center(child: SidikLoader(size: 88)),
        },
      ),
    );
  }
}

/// Antrean dikelompokkan per PT.
///
/// Admin mikirnya per perusahaan — "beresin punya Maju Jaya dulu, sekalian
/// sertifikatnya sekali kirim" — bukan per teknisi atau per tanggal. Daftar
/// datar yang nyampur semua PT maksa dia nyisir tiap baris nyari yang
/// sekumpulan, dan itu yang bikin antrean kerasa ribet.
///
/// Penyaringnya cuma nongol kalau ada LEBIH DARI SATU PT: satu chip buat satu
/// pilihan itu kontrol yang nggak ngontrol apa-apa, cuma makan tempat.
class _Daftar extends StatefulWidget {
  const _Daftar({required this.items});

  final List<CalibrationHistoryItem> items;

  @override
  State<_Daftar> createState() => _DaftarState();
}

class _DaftarState extends State<_Daftar> {
  /// Null = semua PT.
  String? _pt;

  static const _tanpaNama = '—';

  String _namaPt(CalibrationHistoryItem i) => i.namaPelanggan ?? _tanpaNama;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Urut sesuai jumlah antrean, terbanyak duluan — PT yang paling numpuk
    // biasanya yang paling ditunggu.
    final jumlah = <String, int>{};
    for (final i in widget.items) {
      jumlah[_namaPt(i)] = (jumlah[_namaPt(i)] ?? 0) + 1;
    }
    final urutPt = jumlah.keys.toList()
      ..sort((a, b) {
        final selisih = jumlah[b]!.compareTo(jumlah[a]!);
        return selisih != 0 ? selisih : a.compareTo(b);
      });

    // PT yang lagi dipilih bisa ilang dari daftar (kiriman terakhirnya barusan
    // diproses). Jatuh balik ke "semua" daripada nampilin layar kosong yang
    // kelihatan kayak antreannya habis.
    final dipilih = urutPt.contains(_pt) ? _pt : null;

    final tampil = dipilih == null
        ? widget.items
        : widget.items.where((i) => _namaPt(i) == dipilih).toList();

    return Column(
      children: [
        if (urutPt.length > 1)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Center(
                    child: FilterChip(
                      label: Text(l10n.antreanSemuaPt(widget.items.length)),
                      selected: dipilih == null,
                      onSelected: (_) => setState(() => _pt = null),
                    ),
                  ),
                ),
                for (final pt in urutPt)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Center(
                      child: FilterChip(
                        label: Text('$pt (${jumlah[pt]})'),
                        selected: dipilih == pt,
                        // Ditekan lagi = balik ke semua. Tanpa itu, sekali
                        // nyaring admin kepaksa cari chip "Semua" buat keluar.
                        onSelected: (pilih) =>
                            setState(() => _pt = pilih ? pt : null),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: tampil.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => _Kartu(item: tampil[i]),
          ),
        ),
      ],
    );
  }
}

class _Kartu extends StatelessWidget {
  const _Kartu({required this.item});

  final CalibrationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.hourglass_top_outlined,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(item.namaAlat, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.namaPelanggan != null)
              Text(
                item.namaPelanggan!,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              '${l10n.antreanOleh(item.namaTeknisi)} · '
              '${DateFormat('d MMM yyyy', locale).format(item.tanggalKalibrasi)}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        isThreeLine: item.namaPelanggan != null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PerhitunganScreen(calibrationId: item.id),
          ),
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(
          Icons.inbox_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.antreanKosong,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.antreanKosongBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
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
          l10n.antreanGagal,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: l10n.perhitPeriksa,
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onPressed: onCobaLagi,
        ),
      ],
    );
  }
}
