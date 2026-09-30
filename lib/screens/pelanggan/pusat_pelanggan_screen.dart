import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/customer.dart';
import '../../models/jatuh_tempo.dart';
import '../../models/pelacakan.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/jatuh_tempo_provider.dart';
import '../../providers/pusat_pelanggan_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../jatuh_tempo/layar_jatuh_tempo.dart' show BarisJatuhTempo;
import '../pelacakan/pelacakan_screen.dart' show DetailPaketScreen;

/// Pusat pelanggan — "semua yang lab tahu tentang satu pelanggan", baca saja.
///
/// Untuk super admin (pengawas lintas pekerjaan) dan admin. Tidak ada tombol
/// tulis di sini: mengubah data pelanggan tetap lewat master data, yang punya
/// aturan sendiri (mis. pelanggan yang masih punya alat tidak bisa dihapus).
class PusatPelangganScreen extends ConsumerStatefulWidget {
  const PusatPelangganScreen({super.key});

  @override
  ConsumerState<PusatPelangganScreen> createState() =>
      _PusatPelangganScreenState();
}

class _PusatPelangganScreenState extends ConsumerState<PusatPelangganScreen> {
  // Diisi dari provider, bukan string kosong: layar ini bisa dibangun ulang
  // (tema/lokal berganti) sementara kata cari-nya tetap hidup di provider.
  late final _cari = TextEditingController(
    text: ref.read(kataCariPelangganProvider),
  );
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
    final theme = Theme.of(context);
    final async = ref.watch(pusatPelangganProvider);
    final kata = ref.watch(kataCariPelangganProvider);
    // Tidak di-`await`: kalau jatuh tempo gagal dimuat, kartu pelanggan tetap
    // tampil tanpa lencana "lewat jadwal" — lebih berguna daripada layar galat.
    final jatuhTempo = ref.watch(jatuhTempoProvider).value;
    final data = async.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty
          ? _Pesan(
              ikon: Icons.apartment_outlined,
              teks: kata.trim().isEmpty
                  ? l10n.pusatKosong
                  : l10n.pusatKosongCari,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.pusatHasil,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        l10n.pusatCocok(data.length),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                for (final c in data) ...[
                  _KartuPelanggan(
                    pelanggan: c,
                    lewat: jatuhTempo?.lewat
                        .where((a) => a.alat.pelangganId == c.id)
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
    } else if (async.hasError) {
      isi = _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: async.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.pusatGagal,
        onCobaLagi: () => ref.invalidate(pusatPelangganProvider),
      );
    } else {
      isi = const _Kerangka();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.pusatJudul),
            Text(l10n.pusatSub, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
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
                    () => ref.read(kataCariPelangganProvider.notifier).setel(q),
                  );
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.pusatCari,
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(pusatPelangganProvider.future),
                child: isi,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuPelanggan extends StatelessWidget {
  const _KartuPelanggan({required this.pelanggan, required this.lewat});

  final Customer pelanggan;

  /// `null` = jatuh tempo belum/tidak berhasil dimuat (lencana tidak dibuat).
  final List<AlatJatuhTempo>? lewat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final jumlahLewat = lewat?.length ?? 0;

    return Kertas(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailPelangganScreen(pelanggan: pelanggan),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(pelanggan.nama, style: theme.textTheme.titleMedium),
              ),
              Icon(Icons.chevron_right, color: m.tinta2),
            ],
          ),
          if (pelanggan.alamat.isNotEmpty)
            Text(
              pelanggan.alamat,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Pil(l10n.pusatAlat(pelanggan.jumlahAlat)),
              if (jumlahLewat > 0)
                StatusBadge(
                  label: l10n.pusatLewatJadwal(jumlahLewat),
                  tone: BadgeTone.danger,
                  icon: Icons.schedule,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            pelanggan.contactPerson.isEmpty
                ? l10n.pusatTanpaPic
                : l10n.pusatPic(pelanggan.contactPerson),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Pil extends StatelessWidget {
  const _Pil(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final m = SidikMaterial.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: m.kertas2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: m.kertasTepi),
      ),
      child: Text(teks, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

/// Satu pelanggan lengkap: identitas, alat yang perlu kalibrasi ulang, dan
/// paket yang sedang berjalan.
///
/// [pelanggan] dari daftar dipakai sebagai isi SEMENTARA sambil `GET
/// /customers/{id}` memuat, jadi layar tidak mulai dari kotak kosong; begitu
/// server menjawab, isi yang segar menggantikannya.
class DetailPelangganScreen extends ConsumerWidget {
  const DetailPelangganScreen({super.key, required this.pelanggan});

  final Customer pelanggan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(detailPelangganProvider(pelanggan.id));
    final c = async.value ?? pelanggan;
    final galat = async.hasError && async.value == null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pelangganDetailJudul)),
      body: ReadableWidth(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paketBerjalanProvider);
            ref.invalidate(jatuhTempoPelangganProvider(pelanggan.id));
            ref.invalidate(detailPelangganProvider(pelanggan.id));
            await ref.read(detailPelangganProvider(pelanggan.id).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (galat) ...[
                Kertas(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    async.error is TokenHilangException
                        ? l10n.historySessionExpired
                        : l10n.pelangganGagal,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _Identitas(pelanggan: c),
              const SizedBox(height: AppSpacing.lg),
              _BagianAlat(pelanggan: c),
              const SizedBox(height: AppSpacing.lg),
              _BagianPaket(pelanggan: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _Identitas extends StatelessWidget {
  const _Identitas({required this.pelanggan});

  final Customer pelanggan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    Widget baris(String label, String isi) => isi.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: m.gayaEtsa(ukuran: 11)),
                Text(isi, style: theme.textTheme.bodyMedium),
              ],
            ),
          );

    return Kertas(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pelanggan.nama, style: theme.textTheme.titleLarge),
          baris(l10n.pelangganAlamat, pelanggan.alamat),
          baris(l10n.pelangganPic, pelanggan.contactPerson),
          baris(l10n.pelangganTelepon, pelanggan.telepon),
          baris(l10n.pelangganEmail, pelanggan.email),
          const SizedBox(height: AppSpacing.md),
          _Pil(l10n.pusatAlat(pelanggan.jumlahAlat)),
        ],
      ),
    );
  }
}

/// Alat pelanggan ini yang lewat jadwal atau jatuh tempo dalam 90 hari.
///
/// Bukan seluruh alatnya, dan itu yang tepat untuk pertanyaan yang diajukan
/// layar ini ("mana yang perlu dikalibrasi ulang?"). Disaring di server lewat
/// `customer_id` ([jatuhTempoPelangganProvider]).
class _BagianAlat extends ConsumerWidget {
  const _BagianAlat({required this.pelanggan});

  final Customer pelanggan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(jatuhTempoPelangganProvider(pelanggan.id));
    final data = async.value;

    final Widget isi;
    if (data != null) {
      final milik = [...data.lewat, ...data.dalam90];
      isi = milik.isEmpty
          ? Text(l10n.pelangganAlatBersih, style: theme.textTheme.bodySmall)
          : Column(
              children: [
                for (final a in milik) ...[
                  BarisJatuhTempo(item: a),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
    } else if (async.hasError) {
      isi = Text(l10n.berandaSaGagalBagian, style: theme.textTheme.bodySmall);
    } else {
      isi = const SkeletonBox(height: 56);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pelangganAlatPerlu, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        isi,
      ],
    );
  }
}

class _BagianPaket extends ConsumerWidget {
  const _BagianPaket({required this.pelanggan});

  final Customer pelanggan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(paketPelangganProvider(pelanggan.nama));
    final data = async.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty
          ? Text(l10n.pelangganPaketKosong, style: theme.textTheme.bodySmall)
          : Column(
              children: [
                for (final p in data) ...[
                  _BarisPaket(paket: p),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
    } else if (async.hasError) {
      isi = Text(l10n.berandaSaGagalBagian, style: theme.textTheme.bodySmall);
    } else {
      isi = const SkeletonBox(height: 56);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pelangganPaket, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        isi,
      ],
    );
  }
}

class _BarisPaket extends StatelessWidget {
  const _BarisPaket({required this.paket});

  final PaketLacak paket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    return Kertas(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailPaketScreen(paketId: paket.id),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paket.nomor, style: theme.textTheme.titleSmall),
                Text(
                  '${paket.tahapLabel} · ${l10n.pelacakanSelesaiDari(paket.jumlahSelesai, paket.jumlahAlat)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: m.tinta2),
        ],
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({required this.ikon, required this.teks, this.onCobaLagi});

  final IconData ikon;
  final String teks;
  final VoidCallback? onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Icon(
          ikon,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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
    itemBuilder: (_, _) => const Kertas(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 16, width: 220),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 10, width: 160),
        ],
      ),
    ),
  );
}
