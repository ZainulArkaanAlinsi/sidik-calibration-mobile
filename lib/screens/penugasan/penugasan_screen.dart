import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/sidik_material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/penugasan.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/pengendalian_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/readable_width.dart';
import '../../widgets/sidik/sidik_lembar.dart';
import '../../widgets/sidik/sidik_permukaan.dart';
import '../../widgets/sidik/sidik_status.dart';
import '../pengesahan/antrean_pengesahan_screen.dart' show tanggalPendek;
import 'penugasan_buat_screen.dart';

/// Penugasan (poin 8). Satu layar untuk dua sudut pandang:
/// - **Teknisi**: "Tugas saya" — server cuma memulangkan penugasan yang
///   menyebut namanya.
/// - **Admin / super admin**: papan penugasan seluruh lab + tombol Tugaskan.
class PenugasanScreen extends ConsumerWidget {
  const PenugasanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(daftarPenugasanProvider);
    final peran = ref.watch(authProvider).value?.role;
    final bolehBagi = peran == UserRole.admin || peran == UserRole.superAdmin;
    final notifier = ref.read(daftarPenugasanProvider.notifier);

    final data = async.value;
    final Widget isi;
    if (data != null) {
      isi = data.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  bolehBagi
                      ? l10n.penugasanKosongPembagi
                      : l10n.penugasanKosongTeknisi,
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : ListView.separated(
              // Bawah 96: FAB "Tugaskan" tidak boleh menutupi kartu terakhir.
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                96,
              ),
              itemCount: data.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _KartuPenugasan(penugasan: data[i]),
            );
    } else if (async.hasError) {
      isi = ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            async.error is TokenHilangException
                ? l10n.historySessionExpired
                : l10n.penugasanGagalMuat,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.custRetry,
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            onPressed: notifier.muatUlang,
          ),
        ],
      );
    } else {
      isi = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(bolehBagi ? l10n.penugasanJudul : l10n.penugasanTugasSaya),
      ),
      floatingActionButton: bolehBagi
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(l10n.penugasanTugaskan),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PenugasanBuatScreen(),
                ),
              ),
            )
          : null,
      body: ReadableWidth(
        child: RefreshIndicator(onRefresh: notifier.muatUlang, child: isi),
      ),
    );
  }
}

class _KartuPenugasan extends StatelessWidget {
  const _KartuPenugasan({required this.penugasan});

  final Penugasan penugasan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final m = SidikMaterial.of(context);
    final p = penugasan;

    return Kertas(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetailPenugasanScreen(penugasanId: p.id),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                p.grup ? Icons.groups_outlined : Icons.person_outline,
                size: 18,
                color: m.tinta2,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(p.judul, style: theme.textTheme.titleSmall)),
              Text(
                '${p.persenTuntas}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SidikMeter(
            nilai: p.persenTuntas / 100,
            nada: m.lulus,
            label: '${p.judul}: ${p.persenTuntas}%',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            p.baris.map((b) => '${b.jumlah} ${b.jenisAlat}').join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (p.tanggalTarget != null)
                l10n.penugasanTarget(tanggalPendek(p.tanggalTarget)),
              p.teknisi.map((t) => t.kode ?? t.nama).join(', '),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: p.terlambat ? AppColors.statusPeringatan(context) : null,
              fontWeight: p.terlambat ? FontWeight.w700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail satu penugasan. Teknisi melaporkan progres per baris di sini.
class DetailPenugasanScreen extends ConsumerStatefulWidget {
  const DetailPenugasanScreen({super.key, required this.penugasanId});

  final int penugasanId;

  @override
  ConsumerState<DetailPenugasanScreen> createState() =>
      _DetailPenugasanScreenState();
}

class _DetailPenugasanScreenState extends ConsumerState<DetailPenugasanScreen> {
  @override
  void initState() {
    super.initState();
    // "Dia udah tau belum?" — dicatat server sekali, waktu PERTAMA dibuka.
    Future.microtask(
      () => ref
          .read(daftarPenugasanProvider.notifier)
          .tandaiDilihat(widget.penugasanId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final daftar = ref.watch(daftarPenugasanProvider).value ?? const [];
    final p = daftar.where((x) => x.id == widget.penugasanId).firstOrNull;
    final peran = ref.watch(authProvider).value?.role;
    final bolehLapor = peran == UserRole.teknisi || peran == UserRole.admin;

    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(p.judul)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (p.tanggalTarget != null)
              Text(
                l10n.penugasanTarget(tanggalPendek(p.tanggalTarget)),
                style: theme.textTheme.bodyMedium,
              ),
            if (p.catatan != null && p.catatan!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(p.catatan!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(l10n.penugasanTim, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            for (final t in p.teknisi)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    t.kode ?? (t.nama.isEmpty ? '?' : t.nama.substring(0, 1)),
                  ),
                ),
                title: Text(t.nama),
                subtitle: Text(
                  t.dilihatPada == null
                      ? l10n.penugasanBelumDilihat
                      : l10n.penugasanSudahDilihat(
                          tanggalPendek(t.dilihatPada),
                        ),
                ),
                trailing: t.peran == 'ketua'
                    ? SidikLencana(
                        StatusSidik(
                          l10n.penugasanKetua,
                          NadaStatus.draf,
                          Icons.flag_outlined,
                        ),
                      )
                    : null,
              ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.penugasanRincian, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            for (final b in p.baris)
              Kertas(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.jenisAlat, style: theme.textTheme.titleSmall),
                          Text(
                            l10n.penugasanSelesaiDari(
                              b.jumlahSelesai,
                              b.jumlah,
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          SidikMeter(
                            nilai: b.jumlah == 0
                                ? 0
                                : b.jumlahSelesai / b.jumlah,
                            tinggi: 6,
                            label: l10n.penugasanSelesaiDari(
                              b.jumlahSelesai,
                              b.jumlah,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pencacah −/+ bukan kolom ketik: teknisi melapor dengan
                    // sarung tangan di lab, dan dua tombol besar lebih jarang
                    // salah daripada papan ketik angka.
                    if (bolehLapor && p.aktif && b.id != null) ...[
                      IconButton(
                        tooltip: l10n.penugasanKurangi,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: b.jumlahSelesai == 0
                            ? null
                            : () => _lapor(b.id!, b.jumlahSelesai - 1),
                      ),
                      IconButton(
                        tooltip: l10n.penugasanTambah,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _lapor(b.id!, b.jumlahSelesai + 1),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _lapor(int barisId, int jumlah) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(daftarPenugasanProvider.notifier)
          .laporProgres(barisId, jumlah);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }
}
