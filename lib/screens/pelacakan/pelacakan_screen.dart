import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/pelacakan.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/pengendalian_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/skeleton.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;

/// Pelacakan paket alat — "kayak lacak paket di online shop, tapi lebih
/// detail" (poin 1 & 7).
///
/// Satu paket = satu order = satu batch alat dari satu pelanggan. Tahap paket
/// adalah tahap alat yang PALING TERTINGGAL (dihitung server): paket dengan 11
/// alat selesai dan 1 masih dikalibrasi belum selesai. Karena itu kartunya
/// menampilkan "2/3 selesai" di samping tahapnya — angka itu menjawab lebih
/// banyak daripada nama tahapnya sendiri.
class PelacakanScreen extends ConsumerStatefulWidget {
  const PelacakanScreen({super.key});

  @override
  ConsumerState<PelacakanScreen> createState() => _PelacakanScreenState();
}

class _PelacakanScreenState extends ConsumerState<PelacakanScreen> {
  final _cari = TextEditingController();
  Timer? _jeda;

  @override
  void dispose() {
    _cari.dispose();
    _jeda?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(daftarPaketProvider);
    final notifier = ref.read(daftarPaketProvider.notifier);
    final data = async.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty
          ? _Pesan(ikon: Icons.inventory_2_outlined, teks: l10n.pelacakanKosong)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              itemCount: data.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _KartuPaket(paket: data[i]),
            );
    } else if (async.hasError) {
      isi = _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: async.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.pelacakanGagalMuat,
        onCobaLagi: notifier.muatUlang,
      );
    } else {
      isi = const _Kerangka();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pelacakanJudul)),
      body: ReadableWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _cari,
                onChanged: (q) {
                  _jeda?.cancel();
                  _jeda = Timer(
                    const Duration(milliseconds: 400),
                    () => notifier.cari(q),
                  );
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.pelacakanCari,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(l10n.pelacakanCumaTerlambat),
                  selected: notifier.cumaTerlambat,
                  onSelected: notifier.saringTerlambat,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(onRefresh: notifier.muatUlang, child: isi),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuPaket extends StatelessWidget {
  const _KartuPaket({required this.paket});

  final PaketLacak paket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DetailPaketScreen(paketId: paket.id),
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
                    child: Text(paket.nomor, style: theme.textTheme.labelMedium),
                  ),
                  if (paket.terlambatHari != null)
                    Text(
                      l10n.pelacakanTerlambat(paket.terlambatHari!),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.statusPeringatan(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              if (paket.pelanggan != null)
                Text(
                  paket.pelanggan!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              const SizedBox(height: AppSpacing.sm),
              // Meteran kemajuan: bilah cekung di kertas, isinya satu warna.
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: paket.persenSelesai,
                  minHeight: 8,
                  backgroundColor: m.kertas2,
                  color: m.lulus,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      paket.tahapLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    l10n.pelacakanSelesaiDari(
                      paket.jumlahSelesai,
                      paket.jumlahAlat,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (paket.tanggalJanjiSelesai != null)
                Text(
                  l10n.pelacakanJanji(tanggalPendek(paket.tanggalJanjiSelesai)),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail satu paket: garis waktu + tahap tiap alat + serah terima.
class DetailPaketScreen extends ConsumerWidget {
  const DetailPaketScreen({super.key, required this.paketId});

  final int paketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(detailPaketProvider(paketId));
    final peran = ref.watch(authProvider).value?.role;
    // Serah terima = peristiwa fisik di meja depan. Server membolehkan admin
    // & super admin (grup `role:admin,super_admin`); tombolnya ikut aturan itu.
    final bolehSerahkan =
        peran == UserRole.admin || peran == UserRole.superAdmin;

    return Scaffold(
      appBar: AppBar(title: Text(async.value?.$1.nomor ?? l10n.pelacakanJudul)),
      body: switch (async) {
        AsyncData(value: (final paket, final garis)) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(detailPaketProvider(paketId)),
          child: ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (paket.pelanggan != null)
                  Text(
                    paket.pelanggan!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                const SizedBox(height: AppSpacing.md),
                _GarisWaktu(langkah: garis),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.pelacakanAlatDalamPaket(paket.jumlahAlat),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final a in paket.alat) ...[
                  _BarisAlat(
                    alat: a,
                    bolehSerahkan: bolehSerahkan,
                    onBerubah: () =>
                        ref.invalidate(detailPaketProvider(paketId)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
        AsyncError() => _Pesan(
          ikon: Icons.cloud_off_outlined,
          teks: l10n.pelacakanGagalMuat,
          onCobaLagi: () async => ref.invalidate(detailPaketProvider(paketId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _GarisWaktu extends StatelessWidget {
  const _GarisWaktu({required this.langkah});

  final List<LangkahGarisWaktu> langkah;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            for (var i = 0; i < langkah.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          // Tiga keadaan, masing-masing BENTUK berbeda (bukan
                          // cuma warna): lewat = centang, sekarang = cincin
                          // tebal, belum = cincin tipis.
                          Icon(
                            langkah[i].lewat
                                ? Icons.check_circle
                                : langkah[i].sekarang
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: langkah[i].lewat
                                ? m.lulus
                                : langkah[i].sekarang
                                ? m.biruTinta
                                : m.tinta2,
                          ),
                          if (i < langkah.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: langkah[i].lewat ? m.lulus : m.kertasTepi,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          langkah[i].label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: langkah[i].sekarang
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: langkah[i].lewat || langkah[i].sekarang
                                ? m.tinta
                                : m.tinta2,
                          ),
                        ),
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

class _BarisAlat extends ConsumerWidget {
  const _BarisAlat({
    required this.alat,
    required this.bolehSerahkan,
    required this.onBerubah,
  });

  final AlatDalamPaket alat;
  final bool bolehSerahkan;
  final VoidCallback onBerubah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [alat.nama, if (alat.merk != null) alat.merk!].join(' · '),
              style: theme.textTheme.titleSmall,
            ),
            Text(
              [
                if (alat.serialNumber != null) 'SN ${alat.serialNumber}',
                if (alat.teknisi != null) alat.teknisi!,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              alat.tahapLabel ?? alat.tahap,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (alat.nomorSertifikat != null)
              Text(
                alat.nomorSertifikat!,
                style: theme.textTheme.bodySmall,
              ),
            if (alat.diserahkanKepada != null)
              Text(
                l10n.pelacakanDiserahkanKepada(alat.diserahkanKepada!),
                style: theme.textTheme.bodySmall,
              ),
            if (bolehSerahkan && alat.bisaDiserahkan) ...[
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: l10n.pelacakanTandaiDiserahkan,
                icon: Icons.handshake_outlined,
                variant: AppButtonVariant.secondary,
                ringkas: true,
                onPressed: () => _serahkan(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _serahkan(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final teks = TextEditingController();
    // Nama penerima WAJIB: tanpa itu "sudah diserahkan" tidak bisa
    // dipertanggungjawabkan kalau pelanggan bilang alatnya belum sampai.
    final kepada = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setState) => AlertDialog(
          title: Text(l10n.pelacakanTandaiDiserahkan),
          content: TextField(
            controller: teks,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.pelacakanNamaPenerima,
              hintText: l10n.pelacakanNamaPenerimaContoh,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: Text(l10n.custCancel),
            ),
            TextButton(
              onPressed: teks.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(d).pop(teks.text.trim()),
              child: Text(l10n.pelacakanSimpanSerahTerima),
            ),
          ],
        ),
      ),
    );
    teks.dispose();
    if (kepada == null) return;
    try {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();
      await ref
          .read(pelacakanServiceProvider)
          .tandaiTahapFisik(
            token,
            alat.itemId,
            tahap: 'diserahkan',
            kepada: kepada,
          );
      onBerubah();
      ref.invalidate(daftarPaketProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({required this.ikon, required this.teks, this.onCobaLagi});

  final IconData ikon;
  final String teks;
  final Future<void> Function()? onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Icon(ikon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Text(teks, textAlign: TextAlign.center),
        if (onCobaLagi != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: AppLocalizations.of(context).custRetry,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: onCobaLagi,
          ),
        ],
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
            SkeletonBox(height: 12, width: 120),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 16, width: 220),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
