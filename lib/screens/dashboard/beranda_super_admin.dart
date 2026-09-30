import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/jatuh_tempo.dart';
import '../../models/pelacakan.dart';
import '../../models/pengesahan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jam_provider.dart';
import '../../providers/jatuh_tempo_provider.dart';
import '../../providers/pusat_pelanggan_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/sidik/sidik_lembar.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/skeleton.dart';
import '../jatuh_tempo/layar_jatuh_tempo.dart';
import '../pelacakan/pelacakan_screen.dart';
import '../pelanggan/pusat_pelanggan_screen.dart';
import '../pengesahan/antrean_pengesahan_screen.dart';
import '../penugasan/penugasan_buat_screen.dart';

/// Muat ulang semua sumber Beranda super admin (tarik-untuk-segarkan).
Future<void> segarkanBerandaSuperAdmin(WidgetRef ref) async {
  ref
    ..invalidate(antreanBerandaProvider)
    ..invalidate(paketBerjalanProvider)
    ..invalidate(jatuhTempoProvider);
  // Ditunggu semua supaya spinner tarik-segarkan berhenti setelah datanya
  // benar-benar datang, bukan begitu dijadwalkan. Satu yang gagal tidak boleh
  // menahan yang lain, jadi galatnya ditelan di sini — tiap bagian layar
  // sudah menampilkan galatnya sendiri.
  await Future.wait([
    ref.read(antreanBerandaProvider.future).then((_) {}, onError: (_) {}),
    ref.read(paketBerjalanProvider.future).then((_) {}, onError: (_) {}),
    ref.read(jatuhTempoProvider.future).then((_) {}, onError: (_) {}),
  ]);
}

/// Beranda super admin — pengawas & pengesah (artboard SA_Beranda).
///
/// Susunannya mengikuti urutan pekerjaannya: yang MENUNGGU DIA dulu
/// (pengesahan; nomor sertifikat baru lahir dari tombolnya), lalu paket yang
/// sedang berjalan, lalu apa yang perlu dilihat. Super admin tidak mengisi
/// lembar kerja, jadi tidak ada angka draf & tombol "mulai kalibrasi" seperti
/// di dashboard umum.
///
/// Semua angka dari data yang sama dengan layar tujuannya (antrean, paket,
/// jatuh tempo), jadi "3 menunggu" di sini tidak pernah beda dari panjang
/// daftar yang terbuka begitu tombolnya ditekan. Tiap bagian memuat & gagal
/// sendiri-sendiri: paket yang lambat tidak menahan angka pengesahan.
class BerandaSuperAdmin extends ConsumerWidget {
  const BerandaSuperAdmin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const _Sapaan(),
        const SizedBox(height: AppSpacing.md),
        const _PanelPengesahan(),
        const SizedBox(height: AppSpacing.lg),
        const _PanelPaket(),
        const SizedBox(height: AppSpacing.lg),
        const _PanelPerhatian(),
        const SizedBox(height: AppSpacing.lg),
        const _PanelAksi(),
      ],
    );
  }
}

class _Sapaan extends ConsumerWidget {
  const _Sapaan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final nama = ref.watch(authProvider).value?.nama ?? '';
    final hariIni = ref.read(jamProvider)();
    final tanggal = DateFormat(
      'EEEE, d MMMM',
      Localizations.localeOf(context).languageCode,
    ).format(hariIni);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tanggal.toUpperCase(), style: m.gayaEtsa(ukuran: 11)),
        const SizedBox(height: 2),
        Text(l10n.berandaSaSapaan(nama), style: theme.textTheme.headlineSmall),
        Text(l10n.berandaSaPeran, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Judul extends StatelessWidget {
  const _Judul(this.teks, {this.aksi, this.onAksi});

  final String teks;
  final String? aksi;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(teks, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (aksi != null) TextButton(onPressed: onAksi, child: Text(aksi!)),
      ],
    );
  }
}

/// Isi satu bagian yang gagal: kalimat pendek + coba lagi. Bagian lain tidak
/// ikut terganggu.
class _GagalBagian extends StatelessWidget {
  const _GagalBagian({required this.onCobaLagi});

  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Kertas(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.berandaSaGagalBagian,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onCobaLagi, child: Text(l10n.custRetry)),
        ],
      ),
    );
  }
}

class _PanelPengesahan extends ConsumerWidget {
  const _PanelPengesahan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final async = ref.watch(antreanBerandaProvider);
    final data = async.value;

    if (data == null) {
      return async.hasError
          ? _GagalBagian(
              onCobaLagi: () => ref.invalidate(antreanBerandaProvider),
            )
          : const SkeletonBox(height: 168, radius: SidikMaterial.sudutKertas);
    }

    // Server mengurutkan dari yang PALING LAMA menunggu; yang pertama = tertua.
    final ItemPengesahan? tertua = data.isEmpty ? null : data.first;

    return Kertas(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.berandaSaMenunggu.toUpperCase(),
            style: m.gayaEtsa(ukuran: 11),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.isEmpty)
            Text(l10n.berandaSaKosong, style: theme.textTheme.titleMedium)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${data.length}',
                  style: SidikTheme.gayaAngka(
                    ukuran: 44,
                    berat: FontWeight.w700,
                    warna: m.biruTinta,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.berandaSaSiapDisahkan,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
            if (tertua != null)
              Text(
                [
                  l10n.berandaSaTertua(
                    [
                      tertua.alatNama,
                      if (tertua.pelanggan != null) tertua.pelanggan!,
                    ].join(' · '),
                  ),
                  if (tertua.menungguHari != null)
                    l10n.berandaSaHariLalu(tertua.menungguHari!),
                ].join(', '),
                style: theme.textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l10n.berandaSaBukaGerbang,
            icon: Icons.verified_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AntreanPengesahanScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.berandaSaNomorCatatan, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PanelPaket extends ConsumerWidget {
  const _PanelPaket();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(paketBerjalanProvider);
    final data = async.value;

    final Widget isi;
    if (data != null) {
      isi = data.isEmpty
          ? Text(l10n.berandaSaPaketKosong, style: theme.textTheme.bodySmall)
          : Column(
              children: [
                // Tiga saja: ini pintu ke papan pelacakan, bukan gantinya.
                for (final p in data.take(3)) ...[
                  _BarisPaket(paket: p),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
    } else if (async.hasError) {
      isi = _GagalBagian(
        onCobaLagi: () => ref.invalidate(paketBerjalanProvider),
      );
    } else {
      isi = const SkeletonBox(height: 72, radius: SidikMaterial.sudutKertas);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Judul(
          l10n.berandaSaPaket,
          aksi: l10n.berandaSaSemuaPaket,
          onAksi: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PelacakanScreen()),
          ),
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paket.pelanggan ?? paket.nomor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            [
              paket.nomor,
              paket.tahapLabel,
            ].where((s) => s.isNotEmpty).join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SidikMeter(
            nilai: paket.persenSelesai,
            nada: m.lulus,
            label: l10n.pelacakanSelesaiDari(
              paket.jumlahSelesai,
              paket.jumlahAlat,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.pelacakanSelesaiDari(paket.jumlahSelesai, paket.jumlahAlat),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PanelPerhatian extends ConsumerWidget {
  const _PanelPerhatian();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final jatuhTempo = ref.watch(jatuhTempoProvider);
    final paket = ref.watch(paketBerjalanProvider);

    // Selama salah satu masih memuat, jangan menyimpulkan "aman": angka nol
    // yang belum datang bukan nol yang sebenarnya.
    final sedangMemuat =
        (jatuhTempo.value == null && !jatuhTempo.hasError) ||
        (paket.value == null && !paket.hasError);
    if (sedangMemuat) {
      return const SkeletonBox(height: 72, radius: SidikMaterial.sudutKertas);
    }

    final RingkasanJatuhTempo? r = jatuhTempo.value;
    final terlambat = (paket.value ?? const <PaketLacak>[])
        .where((p) => p.terlambatHari != null)
        .length;
    final lewat = r?.lewat.length ?? 0;
    final dekat = r?.dalam30.length ?? 0;
    final terlama = r?.terlamaLewatHari;

    void buka(Widget layar) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => layar));

    final baris = <Widget>[
      if (lewat > 0)
        _BarisPerhatian(
          ikon: Icons.schedule,
          bahaya: true,
          judul: l10n.berandaSaAlatLewat(lewat),
          sub: terlama == null ? null : l10n.berandaSaAlatLewatTerlama(terlama),
          onTap: () => buka(const DaftarJatuhTempoScreen()),
        ),
      if (dekat > 0)
        _BarisPerhatian(
          ikon: Icons.event_outlined,
          judul: l10n.berandaSaAlatDekat(dekat),
          onTap: () => buka(const JadwalKalibrasiScreen()),
        ),
      if (terlambat > 0)
        _BarisPerhatian(
          ikon: Icons.local_shipping_outlined,
          bahaya: true,
          judul: l10n.berandaSaPaketTerlambat(terlambat),
          onTap: () => buka(const PelacakanScreen()),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Judul(l10n.berandaSaPerhatian),
        const SizedBox(height: AppSpacing.sm),
        if (baris.isEmpty)
          Text(l10n.berandaSaAman, style: theme.textTheme.bodySmall)
        else
          for (final b in baris) ...[b, const SizedBox(height: AppSpacing.sm)],
        if (jatuhTempo.hasError)
          _GagalBagian(onCobaLagi: () => ref.invalidate(jatuhTempoProvider)),
      ],
    );
  }
}

class _BarisPerhatian extends StatelessWidget {
  const _BarisPerhatian({
    required this.ikon,
    required this.judul,
    required this.onTap,
    this.sub,
    this.bahaya = false,
  });

  final IconData ikon;
  final String judul;
  final String? sub;
  final bool bahaya;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final warna = bahaya ? AppColors.statusBahaya(context) : m.tinta2;

    return Kertas(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: warna, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null) Text(sub!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: m.tinta2),
        ],
      ),
    );
  }
}

class _PanelAksi extends StatelessWidget {
  const _PanelAksi();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    void buka(Widget layar) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => layar));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Judul(l10n.berandaSaAksi),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.berandaSaTugaskan,
          icon: Icons.assignment_ind_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => buka(const PenugasanBuatScreen()),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.pusatJudul,
          icon: Icons.apartment_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => buka(const PusatPelangganScreen()),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.jadwalJudul,
          icon: Icons.event_repeat_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => buka(const JadwalKalibrasiScreen()),
        ),
      ],
    );
  }
}
