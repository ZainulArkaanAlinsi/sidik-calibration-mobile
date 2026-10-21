import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/jatuh_tempo.dart';
import '../../models/pelacakan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jam_provider.dart';
import '../../providers/jatuh_tempo_provider.dart';
import '../../providers/pengendalian_provider.dart' show paketBerjalanProvider;
import '../../widgets/app_button.dart';
import '../../widgets/sidik/sidik_lembar.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/skeleton.dart';
import '../admin/antrean_approval_screen.dart';
import '../calibration/category_picker_screen.dart';
import '../jatuh_tempo/layar_jatuh_tempo.dart';
import '../pelacakan/pelacakan_screen.dart';
import '../penugasan/penugasan_buat_screen.dart';

/// Muat ulang semua sumber Beranda super admin (tarik-untuk-segarkan).
Future<void> segarkanBerandaSuperAdmin(WidgetRef ref) async {
  ref
    ..invalidate(paketBerjalanProvider)
    ..invalidate(jatuhTempoProvider);
  // Ditunggu semua supaya spinner tarik-segarkan berhenti setelah datanya
  // benar-benar datang, bukan begitu dijadwalkan. Satu yang gagal tidak boleh
  // menahan yang lain, jadi galatnya ditelan di sini — tiap bagian layar
  // sudah menampilkan galatnya sendiri.
  await Future.wait([
    ref.read(paketBerjalanProvider.future).then((_) {}, onError: (_) {}),
    ref.read(jatuhTempoProvider.future).then((_) {}, onError: (_) {}),
  ]);
}

/// Beranda super admin — pengawas (artboard SA_Beranda). Gerbang pengesahan
/// dicabut 15 Okt 2026 (K-50-07): Setujui langsung menerbitkan.
///
/// Susunannya mengikuti urutan pekerjaannya: yang MENUNGGU DIA dulu
/// (Antrean Approval ada di panel aksi), lalu paket yang
/// sedang berjalan, lalu apa yang perlu dilihat. Sejak K-49-14 (15 Okt 2026)
/// super admin juga memegang semua aksi admin & teknisi, jadi panel aksinya
/// memuat Antrean Approval dan "Mulai kalibrasi" — sesi yang dia isi sendiri
/// tetap disetujui orang lain (server menahan `pemisahan_wewenang`).
///
/// Semua angka dari data yang sama dengan layar tujuannya (antrean, paket,
/// jatuh tempo), jadi "3 menunggu" di sini tidak pernah beda dari panjang
/// daftar yang terbuka begitu tombolnya ditekan. Tiap bagian memuat & gagal
/// sendiri-sendiri.
class BerandaSuperAdmin extends ConsumerWidget {
  const BerandaSuperAdmin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const _Sapaan(),
        const SizedBox(height: AppSpacing.md),
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
          label: l10n.antreanTitle,
          icon: Icons.inbox_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => buka(const AntreanApprovalScreen()),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.dashStartCalibration,
          icon: Icons.add_task,
          variant: AppButtonVariant.secondary,
          onPressed: () => buka(const CategoryPickerScreen()),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.berandaSaTugaskan,
          icon: Icons.assignment_ind_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => buka(const PenugasanBuatScreen()),
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
