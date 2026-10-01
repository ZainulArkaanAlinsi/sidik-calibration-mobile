import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/koreksi_pelanggan.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/koreksi_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_status.dart';
import '../../widgets/sidik/sidik_tombol.dart';
import '../../widgets/skeleton.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;
import 'detail_koreksi_screen.dart';

/// Antrean koreksi data dari pelanggan (§42 backend).
///
/// Dua pemilik, satu layar — sama seperti antrean permintaan:
/// - **Admin** membukanya, lalu menerima/menolak di layar detail.
/// - **Super admin** hanya membaca (server menjawab 403 untuk semua tulis),
///   jadi layar detail menyembunyikan tombolnya.
///
/// Tab `Menunggu` dibuka dulu: itu pekerjaan yang ditunggu pelanggan.
class AntreanKoreksiScreen extends ConsumerWidget {
  const AntreanKoreksiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(antreanKoreksiProvider);
    final status = ref.watch(statusKoreksiProvider);
    final notifier = ref.read(antreanKoreksiProvider.notifier);
    final halaman = async.value;

    final Widget isi;
    if (halaman != null) {
      isi = halaman.items.isEmpty
          ? _Pesan(
              ikon: Icons.inbox_outlined,
              teks: status == SaringanKoreksi.menunggu
                  ? l10n.koreksiKosongMenunggu
                  : l10n.koreksiKosong,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              itemCount: halaman.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _KartuKoreksi(koreksi: halaman.items[i]),
            );
    } else if (async.hasError) {
      isi = _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: async.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.koreksiGagalMuat,
        onCobaLagi: notifier.muatUlang,
      );
    } else {
      isi = const _Kerangka();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.koreksiJudul)),
      body: ReadableWidth(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            _BarisSaringan(
              terpilih: status,
              jumlahMenunggu: halaman?.jumlahMenunggu,
              onPilih: notifier.saring,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: notifier.muatUlang,
                child: isi,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab status sebagai deretan chip yang bisa digeser (sama polanya dengan
/// antrean permintaan): empat tab berlabel tidak selalu muat di HP 360 px.
class _BarisSaringan extends StatelessWidget {
  const _BarisSaringan({
    required this.terpilih,
    required this.jumlahMenunggu,
    required this.onPilih,
  });

  final String terpilih;
  final int? jumlahMenunggu;
  final ValueChanged<String> onPilih;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    final tab = <(String, String)>[
      (SaringanKoreksi.menunggu, l10n.koreksiTabMenunggu),
      (SaringanKoreksi.diterima, l10n.koreksiTabDiterima),
      (SaringanKoreksi.ditolak, l10n.koreksiTabDitolak),
      (SaringanKoreksi.semua, l10n.koreksiTabSemua),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: tab.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final (kode, label) = tab[i];
          return Center(
            child: ChoiceChip(
              key: ValueKey('tab-koreksi-$kode'),
              selected: terpilih == kode,
              onSelected: (_) => onPilih(kode),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  // Hitungan "Menunggu" = badge yang sama dengan menu samping,
                  // dari `meta.jumlah.menunggu`: tidak menyusut waktu tab lain
                  // sedang terbuka.
                  if (kode == SaringanKoreksi.menunggu &&
                      (jumlahMenunggu ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${jumlahMenunggu!}',
                      key: const ValueKey('jumlah-koreksi-menunggu'),
                      style: SidikTheme.gayaAngka(
                        ukuran: 12,
                        warna: terpilih == kode ? null : m.awas,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Lencana status koreksi. Ikon + teks, tidak pernah warna saja.
StatusSidik statusKoreksi(AppLocalizations l10n, StatusKoreksi s) =>
    switch (s) {
      StatusKoreksi.menunggu => StatusSidik(
        l10n.koreksiStatusMenunggu,
        NadaStatus.tunggu,
        Icons.hourglass_empty,
      ),
      StatusKoreksi.diterima => StatusSidik(
        l10n.koreksiStatusDiterima,
        NadaStatus.lulus,
        Icons.check_circle_outline,
      ),
      StatusKoreksi.ditolak => StatusSidik(
        l10n.koreksiStatusDitolak,
        NadaStatus.gagal,
        Icons.cancel_outlined,
      ),
      StatusKoreksi.lainnya => const StatusSidik(
        '—',
        NadaStatus.draf,
        Icons.help_outline,
      ),
    };

/// Hanya admin yang boleh memutuskan koreksi. Super admin membaca saja (server
/// menjawab 403), teknisi & viewer tidak punya pintunya.
bool bolehMemutuskanKoreksi(WidgetRef ref) =>
    ref.watch(authProvider).value?.role == UserRole.admin;

class _KartuKoreksi extends StatelessWidget {
  const _KartuKoreksi({required this.koreksi});

  final Koreksi koreksi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final k = koreksi;
    final sertifikat = k.jenis == JenisKoreksi.sertifikat;

    return Kertas(
      key: ValueKey('kartu-koreksi-${k.id}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailKoreksiScreen(koreksiId: k.id),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sertifikat
                    ? Icons.workspace_premium_outlined
                    : Icons.straighten_outlined,
                size: 16,
                color: m.tinta2,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  (sertifikat ? l10n.koreksiJenisSertifikat : l10n.koreksiJenisAlat)
                      .toUpperCase(),
                  style: m.gayaEtsa(ukuran: 11),
                ),
              ),
              SidikLencana(statusKoreksi(l10n, k.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            k.pelangganNama ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            sertifikat
                ? (k.sertifikatNomor ?? '—')
                : [
                    k.alatNama,
                    k.alatSerial,
                  ].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SidikTheme.gayaAngka(ukuran: 12, warna: m.tinta2),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _Meta(
                ikon: Icons.edit_note,
                teks: l10n.koreksiJumlahPerubahan(k.perubahan.length),
              ),
              if (k.diajukanOleh != null)
                _Meta(ikon: Icons.person_outline, teks: k.diajukanOleh!),
              if (k.diajukanPada != null)
                _Meta(
                  ikon: Icons.schedule,
                  teks: tanggalPendek(context, k.diajukanPada!.toLocal()),
                ),
              if (k.foto.isNotEmpty)
                _Meta(
                  ikon: Icons.photo_outlined,
                  teks: l10n.koreksiJumlahFoto(k.foto.length),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme.onSurfaceVariant;
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
          Center(
            child: SidikTombol(
              label: AppLocalizations.of(context).custRetry,
              ikon: Icons.refresh,
              onPressed: onCobaLagi,
            ),
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
          SkeletonBox(height: 12, width: 140),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 16, width: 200),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 12, width: 160),
        ],
      ),
    ),
  );
}
