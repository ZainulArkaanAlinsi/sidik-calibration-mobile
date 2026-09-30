import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../core/theme/sidik_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/jatuh_tempo.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/jam_provider.dart';
import '../../providers/jatuh_tempo_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/skeleton.dart';
import '../equipment/equipment_form_screen.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;

/// Satu tab: label, isi, dan kalimat yang dipakai kalau kosong.
class TabJatuhTempo {
  const TabJatuhTempo({
    required this.label,
    required this.isi,
    required this.kosong,
    required this.urutan,
  });

  final String label;
  final List<AlatJatuhTempo> isi;
  final String kosong;
  final String urutan;
}

/// Kerangka bersama layar "Jatuh tempo" (dari kartu dashboard) dan "Jadwal
/// kalibrasi ulang" (menu super admin & admin). Keduanya menjawab pertanyaan
/// yang sama dari data yang sama ([jatuhTempoProvider]); yang beda cuma
/// judul, rentang yang ditawarkan, dan catatan di atas daftarnya — jadi
/// dua layar tipis di atas satu kerangka, bukan dua salinan yang bisa
/// menyimpang.
///
/// Tidak menulis apa pun: mengubah tanggal jatuh tempo lewat form alat (ketuk
/// barisnya). Sebelumnya tab "Alat" sudah punya jalur itu, dan menambah jalur
/// tulis kedua di layar baca hanya menggandakan tempat yang bisa salah.
class LayarJatuhTempo extends ConsumerStatefulWidget {
  const LayarJatuhTempo({
    super.key,
    required this.judul,
    required this.subjudul,
    required this.catatan,
    required this.ikonCatatan,
    required this.tab,
    this.penutup,
  });

  final String Function(AppLocalizations l10n) judul;
  final String Function(AppLocalizations l10n, RingkasanJatuhTempo? r) subjudul;
  final String Function(AppLocalizations l10n) catatan;
  final IconData ikonCatatan;
  final List<TabJatuhTempo> Function(
    AppLocalizations l10n,
    RingkasanJatuhTempo r,
  )
  tab;
  final String Function(AppLocalizations l10n)? penutup;

  @override
  ConsumerState<LayarJatuhTempo> createState() => _LayarJatuhTempoState();
}

class _LayarJatuhTempoState extends ConsumerState<LayarJatuhTempo> {
  // Pilihan tab cuma keadaan tampilan layar ini; datanya tetap dari server.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(jatuhTempoProvider);
    final data = async.value;
    final hariIni = ref.read(jamProvider)();

    final Widget isi;
    if (data != null) {
      isi = _Isi(
        l10n: l10n,
        hariIni: hariIni,
        tab: widget.tab(l10n, data),
        pilih: _tab,
        onPilih: (i) => setState(() => _tab = i),
        catatan: widget.catatan(l10n),
        ikonCatatan: widget.ikonCatatan,
        penutup: widget.penutup?.call(l10n),
        onRefresh: () async => ref.refresh(jatuhTempoProvider.future),
      );
    } else if (async.hasError) {
      isi = _Pesan(
        ikon: Icons.cloud_off_outlined,
        teks: async.error is TokenHilangException
            ? l10n.historySessionExpired
            : l10n.jatuhTempoGagal,
        onCobaLagi: () => ref.invalidate(jatuhTempoProvider),
      );
    } else {
      isi = const _Kerangka();
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.judul(l10n)),
            Text(
              widget.subjudul(l10n, data),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: ReadableWidth(child: isi),
    );
  }
}

class _Isi extends StatelessWidget {
  const _Isi({
    required this.l10n,
    required this.hariIni,
    required this.tab,
    required this.pilih,
    required this.onPilih,
    required this.catatan,
    required this.ikonCatatan,
    required this.onRefresh,
    this.penutup,
  });

  final AppLocalizations l10n;
  final DateTime hariIni;
  final List<TabJatuhTempo> tab;
  final int pilih;
  final ValueChanged<int> onPilih;
  final String catatan;
  final IconData ikonCatatan;
  final String? penutup;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = SidikMaterial.of(context);
    final aktif = tab[pilih.clamp(0, tab.length - 1)];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Kertas(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ikonCatatan, size: 20, color: m.tinta2),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(catatan, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < tab.length; i++)
                ChoiceChip(
                  label: Text('${tab[i].label} ${tab[i].isi.length}'),
                  selected: i == pilih,
                  onSelected: (_) => onPilih(i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  aktif.urutan.toUpperCase(),
                  style: m.gayaEtsa(ukuran: 11),
                ),
              ),
              Text(
                l10n
                    .jatuhTempoPer(tanggalPendek(context, hariIni))
                    .toUpperCase(),
                style: m.gayaEtsa(ukuran: 11),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (aktif.isi.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: [
                  Icon(Icons.task_alt, size: 48, color: m.tinta2),
                  const SizedBox(height: AppSpacing.md),
                  Text(aktif.kosong, textAlign: TextAlign.center),
                ],
              ),
            )
          else
            for (final item in aktif.isi) ...[
              BarisJatuhTempo(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
          if (penutup != null && aktif.isi.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              penutup!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris alat: nama + serial + pelanggan di kiri, jarak ke jatuh tempo
/// & tanggalnya di kanan. Dipakai juga oleh Detail pelanggan.
class BarisJatuhTempo extends ConsumerWidget {
  const BarisJatuhTempo({super.key, required this.item});

  final AlatJatuhTempo item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final alat = item.alat;
    final hari = item.hari;

    // Ikon + teks, bukan warna saja: lewat jadwal harus terbaca juga oleh yang
    // tidak membedakan merah dan hijau.
    final (String teksStatus, IconData ikon, Color warna) = item.lewat
        ? (
            hari == null
                ? l10n.jatuhTempoLewatJadwal
                : l10n.jatuhTempoLewatHari(-hari),
            Icons.schedule,
            AppColors.statusPeringatan(context),
          )
        : (
            hari == 0 ? l10n.jatuhTempoHariIni : l10n.jatuhTempoHariLagi(hari!),
            Icons.event_outlined,
            m.tinta,
          );

    return Kertas(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EquipmentFormScreen(existing: alat),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alat.namaAlat, style: theme.textTheme.titleSmall),
                if (alat.serialNumber.isNotEmpty)
                  Text(
                    l10n.jatuhTempoSn(alat.serialNumber),
                    style: SidikTheme.gayaAngka(
                      ukuran: 12,
                      berat: FontWeight.w400,
                      warna: m.tinta2,
                    ),
                  ),
                if (alat.pelangganNama != null)
                  Text(
                    alat.pelangganNama!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(ikon, size: 16, color: warna),
                  const SizedBox(width: 4),
                  Text(
                    teksStatus,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: warna,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Text(
                alat.tanggalJatuhTempo == null
                    ? l10n.jatuhTempoTanggalKosong
                    : tanggalPendek(context, alat.tanggalJatuhTempo),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Layar penuh dari kartu peringatan di dashboard.
class DaftarJatuhTempoScreen extends StatelessWidget {
  const DaftarJatuhTempoScreen({super.key});

  @override
  Widget build(BuildContext context) => LayarJatuhTempo(
    judul: (l10n) => l10n.jatuhTempoJudul,
    subjudul: (l10n, r) => r == null
        ? ''
        : l10n.jatuhTempoRingkas(r.lewat.length, r.dalam30.length),
    catatan: (l10n) => l10n.jatuhTempoPeringatan,
    ikonCatatan: Icons.warning_amber_rounded,
    tab: (l10n, r) => [
      TabJatuhTempo(
        label: l10n.jatuhTempoTabLewat,
        isi: r.lewat,
        kosong: l10n.jatuhTempoKosongLewat,
        urutan: l10n.jatuhTempoUrutLama,
      ),
      TabJatuhTempo(
        label: l10n.jatuhTempoTab30,
        isi: r.dalam30,
        kosong: l10n.jatuhTempoKosongDekat(30),
        urutan: l10n.jatuhTempoUrutDekat,
      ),
    ],
    penutup: (l10n) => l10n.jatuhTempoKetuk,
  );
}

/// Jadwal kalibrasi ulang untuk super admin & admin — rentangnya sampai 90
/// hari supaya lab sempat menghubungi pelanggan sebelum alatnya lewat.
class JadwalKalibrasiScreen extends StatelessWidget {
  const JadwalKalibrasiScreen({super.key});

  @override
  Widget build(BuildContext context) => LayarJatuhTempo(
    judul: (l10n) => l10n.jadwalJudul,
    subjudul: (l10n, r) => l10n.jadwalSub,
    catatan: (l10n) => l10n.jadwalInfo,
    ikonCatatan: Icons.info_outline,
    tab: (l10n, r) => [
      TabJatuhTempo(
        label: l10n.jadwalTabLewat,
        isi: r.lewat,
        kosong: l10n.jatuhTempoKosongLewat,
        urutan: l10n.jatuhTempoUrutLama,
      ),
      TabJatuhTempo(
        label: l10n.jadwalTab30,
        isi: r.dalam30,
        kosong: l10n.jatuhTempoKosongDekat(30),
        urutan: l10n.jatuhTempoUrutDekat,
      ),
      TabJatuhTempo(
        label: l10n.jadwalTab90,
        isi: r.dalam90,
        kosong: l10n.jatuhTempoKosongDekat(90),
        urutan: l10n.jatuhTempoUrutDekat,
      ),
    ],
  );
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
    padding: const EdgeInsets.all(AppSpacing.md),
    itemCount: 4,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (_, _) => const Kertas(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 14, width: 200),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 10, width: 120),
        ],
      ),
    ),
  );
}
