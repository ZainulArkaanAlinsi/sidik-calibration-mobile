import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/izin.dart';
import '../../models/permintaan_pelanggan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/izin_provider.dart';
import '../../providers/jam_provider.dart';
import '../../providers/permintaan_provider.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_status.dart';
import '../../widgets/sidik/sidik_tombol.dart';
import '../../widgets/skeleton.dart';
import 'detail_permintaan_screen.dart';

/// Antrean permintaan kalibrasi dari pelanggan (keputusan 30 Sep 2026, §41).
///
/// Dua pemilik, satu layar — sama seperti gerbang pengesahan:
/// - **Admin** membukanya, lalu menerima/menolak/membalas di layar detail.
/// - **Super admin** hanya membaca (server menjawab 403 untuk semua tulis
///   sampai K4 turun), jadi layar detail menyembunyikan tombolnya.
///
/// Tab `Baru` dibuka dulu dan diurut dari yang PALING LAMA menunggu (disortir
/// server) — permintaan yang menggantung berhari-hari itu yang paling perlu
/// terlihat, dan urutan "terbaru dulu" justru menenggelamkannya.
class AntreanPermintaanScreen extends ConsumerStatefulWidget {
  const AntreanPermintaanScreen({super.key});

  @override
  ConsumerState<AntreanPermintaanScreen> createState() =>
      _AntreanPermintaanScreenState();
}

class _AntreanPermintaanScreenState
    extends ConsumerState<AntreanPermintaanScreen> {
  late final TextEditingController _cari;
  Timer? _jeda;

  @override
  void initState() {
    super.initState();
    // Kata cari hidup di provider (lolos dari invalidate realtime); kotaknya
    // dimulai dari situ supaya tidak kosong-tapi-tersaring.
    _cari = TextEditingController(text: ref.read(cariPermintaanProvider));
  }

  @override
  void dispose() {
    _cari.dispose();
    _jeda?.cancel();
    super.dispose();
  }

  void _ketik(String q) {
    _jeda?.cancel();
    _jeda = Timer(const Duration(milliseconds: 400), () {
      ref.read(antreanPermintaanProvider.notifier).cari(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(antreanPermintaanProvider);
    final status = ref.watch(statusPermintaanProvider);
    final kata = ref.watch(cariPermintaanProvider);
    final notifier = ref.read(antreanPermintaanProvider.notifier);
    final halaman = async.value;

    final Widget isi;
    if (halaman != null) {
      isi = halaman.items.isEmpty
          ? _Pesan(
              ikon: Icons.inbox_outlined,
              teks: kata.trim().isNotEmpty
                  ? l10n.permintaanKosongCari
                  : status == 'baru'
                  ? l10n.permintaanKosongBaru
                  : l10n.permintaanKosong,
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
                  _KartuPermintaan(permintaan: halaman.items[i]),
            );
    } else if (async.hasError) {
      isi = _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: async.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.permintaanGagalMuat,
        onCobaLagi: notifier.muatUlang,
      );
    } else {
      isi = const _Kerangka();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.permintaanJudul)),
      body: ReadableWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _cari,
                onChanged: _ketik,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.permintaanCari,
                ),
              ),
            ),
            _BarisSaringan(
              terpilih: status,
              jumlahBaru: halaman?.jumlahBaru,
              onPilih: notifier.saring,
            ),
            if (halaman != null && halaman.items.isNotEmpty)
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
                    l10n.permintaanRingkas(halaman.total),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
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

/// Tab status sebagai deretan chip yang bisa digeser: lima tab tidak muat
/// dalam satu baris di HP 360 px, dan `TabBar` yang memadatkannya memotong
/// "Dibatalkan".
class _BarisSaringan extends StatelessWidget {
  const _BarisSaringan({
    required this.terpilih,
    required this.jumlahBaru,
    required this.onPilih,
  });

  final String terpilih;
  final int? jumlahBaru;
  final ValueChanged<String> onPilih;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);

    final tab = <(String, String)>[
      ('baru', l10n.permintaanStatusBaru),
      ('diterima', l10n.permintaanStatusDiterima),
      ('ditolak', l10n.permintaanStatusDitolak),
      ('dibatalkan', l10n.permintaanStatusDibatalkan),
      ('', l10n.permintaanTabSemua),
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
              key: ValueKey('tab-permintaan-${kode.isEmpty ? 'semua' : kode}'),
              selected: terpilih == kode,
              onSelected: (_) => onPilih(kode),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  // Hitungan "Baru" = badge yang sama dengan menu samping,
                  // dari `meta.jumlah_baru`: tidak ikut menyusut waktu tab lain
                  // atau kata cari sedang terbuka.
                  if (kode == 'baru' && (jumlahBaru ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${jumlahBaru!}',
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

/// Lencana status permintaan. Ikon + teks, tidak pernah warna saja, dan tidak
/// lewat `StatusSidik.dariApi`: kode `baru`/`diterima` di sana bisa berarti hal
/// lain di layar lain, dan label di sini harus ikut bahasa app.
StatusSidik statusPermintaan(AppLocalizations l10n, StatusPermintaan s) =>
    switch (s) {
      StatusPermintaan.baru => StatusSidik(
        l10n.permintaanStatusBaru,
        NadaStatus.tunggu,
        Icons.mark_email_unread_outlined,
      ),
      StatusPermintaan.diterima => StatusSidik(
        l10n.permintaanStatusDiterima,
        NadaStatus.lulus,
        Icons.check_circle_outline,
      ),
      StatusPermintaan.ditolak => StatusSidik(
        l10n.permintaanStatusDitolak,
        NadaStatus.gagal,
        Icons.cancel_outlined,
      ),
      StatusPermintaan.dibatalkan => StatusSidik(
        l10n.permintaanStatusDibatalkan,
        NadaStatus.draf,
        Icons.remove_circle_outline,
      ),
      StatusPermintaan.lainnya => const StatusSidik(
        '—',
        NadaStatus.draf,
        Icons.help_outline,
      ),
    };

class _KartuPermintaan extends ConsumerWidget {
  const _KartuPermintaan({required this.permintaan});

  final PermintaanPelanggan permintaan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final p = permintaan;
    final hari = p.status == StatusPermintaan.baru
        ? p.menungguHari(ref.read(jamProvider)())
        : null;

    return Kertas(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailPermintaanScreen(permintaanId: p.id),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.nomor,
                  style: SidikTheme.gayaAngka(ukuran: 12, warna: m.tinta2),
                ),
              ),
              SidikLencana(statusPermintaan(l10n, p.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            p.pelangganNama ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _Meta(
                ikon: Icons.straighten_outlined,
                teks: l10n.permintaanJumlahAlat(p.jumlahAlat),
              ),
              if (p.metode != null)
                _Meta(
                  ikon: p.metode == MetodePengantaran.diantarSendiri
                      ? Icons.local_shipping_outlined
                      : Icons.storefront_outlined,
                  teks: p.metode == MetodePengantaran.diantarSendiri
                      ? l10n.permintaanDiantarSendiri
                      : l10n.permintaanDiambilLab,
                ),
              if (p.pemohonNama != null)
                _Meta(ikon: Icons.person_outline, teks: p.pemohonNama!),
              if (hari != null)
                _Meta(
                  ikon: Icons.schedule,
                  teks: hari <= 0
                      ? l10n.permintaanMasukHariIni
                      : l10n.permintaanMenungguHari(hari),
                  // Dua hari tanpa jawaban = pelanggan mulai bertanya-tanya.
                  warna: hari >= 2 ? m.awas : null,
                ),
              if (p.jumlahPesan > 0)
                _Meta(
                  ikon: Icons.chat_bubble_outline,
                  teks: '${p.jumlahPesan}',
                ),
            ],
          ),
        ],
      ),
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
    // `Flexible` + elipsis: keterangan panjang di dalam `Wrap` dulu meluap di
    // HP 400 px (lihat `_Meta` di antrean pengesahan).
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

/// Izin menulis (terima/tolak/balas) sisi lab. Super admin tidak punya satu pun
/// sampai K4 turun; nama izin dijaga `nama_izin_test`.
///
/// Dipakai layar detail. Cadangannya aturan peran: bila `/me/permissions`
/// belum menjawab, admin tetap boleh dan peran lain tidak.
({bool putuskan, bool balas}) izinPermintaan(WidgetRef ref) {
  final peran = ref.watch(authProvider).value?.role;
  return (
    putuskan: ref.bolehkah(
      NamaIzin.permintaanPutuskan,
      cadangan: peran.adminSaja,
    ),
    balas: ref.bolehkah(NamaIzin.permintaanBalas, cadangan: peran.adminSaja),
  );
}
