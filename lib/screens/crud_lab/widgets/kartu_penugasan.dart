import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/bentuk_lab.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/order_kelola.dart' show tanggalDariServer;
import '../../../models/penugasan.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/status_badge.dart';
import '../../super_admin/widgets/format_sa.dart';

/// Kartu satu penugasan di papan kelola: judul, status, tim (ketua dulu),
/// progres, target, dan jejak pembatalan. Menu ⋮ memuat hanya aksi yang BOLEH
/// ([saatUbah]/[saatBatalkan] null = tidak digambar), dan hanya untuk
/// penugasan aktif (server menolak sisanya `422 penugasan_tidak_aktif`).
///
/// Dua aksi penutup (PR #284) sengaja DITAMPILKAN sebagai tombol, bukan
/// disembunyikan di menu: "Selesaikan" muncul hanya untuk penugasan yang siap
/// ditutup ([Penugasan.siapDitutup]) dan "Buka lagi" hanya untuk yang sudah
/// selesai — keduanya keputusan orang yang menunggu dipencet, bukan aksi langka.
class KartuPenugasan extends StatelessWidget {
  const KartuPenugasan({
    super.key,
    required this.penugasan,
    this.saatUbah,
    this.saatBatalkan,
    this.saatSelesaikan,
    this.saatBukaLagi,
  });

  final Penugasan penugasan;
  final VoidCallback? saatUbah;
  final VoidCallback? saatBatalkan;

  /// null = tidak ada izin `penugasan.selesaikan`: tombol tidak digambar.
  final VoidCallback? saatSelesaikan;

  /// null = bukan super admin (`penugasan.buka-lagi`): tombol tidak digambar.
  final VoidCallback? saatBukaLagi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tema = Theme.of(context);
    final p = penugasan;

    final menu = <(String, String)>[
      if (p.aktif && saatUbah != null) ('ubah', l10n.crudAksiUbah),
      if (p.aktif && saatBatalkan != null)
        ('batalkan', l10n.crudPenugasanAksiBatalkan),
    ];
    final nama = p.judul.trim().isEmpty ? '-' : p.judul.trim();
    final tim = p.teknisi.map((t) => t.nama).join(', ');
    final target = p.tanggalTarget;
    final batal = p.batal;
    final batalTanggal = tanggalDariServer(batal?.pada);
    final selesaiTanggal = p.selesai
        ? tanggalDariServer(p.diselesaikanPada)
        : null;
    final redup = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );

    String? jejakBatal;
    if (batal != null) {
      final oleh = (batal.oleh ?? '').trim();
      final tgl = batalTanggal == null ? null : tanggalSa(context, batalTanggal);
      jejakBatal = oleh.isNotEmpty && tgl != null
          ? l10n.crudPenugasanBatalOlehPada(oleh, tgl)
          : oleh.isNotEmpty
          ? l10n.crudPenugasanBatalOleh(oleh)
          : tgl != null
          ? l10n.crudPenugasanBatalPada(tgl)
          : null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    nama,
                    style: tema.textTheme.titleSmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (menu.isNotEmpty)
                  PopupMenuButton<String>(
                    key: Key('menu-penugasan-${p.id}'),
                    tooltip: l10n.saAksiUntuk(nama),
                    icon: const Icon(Icons.more_vert),
                    onSelected: (kode) {
                      if (kode == 'ubah') saatUbah?.call();
                      if (kode == 'batalkan') saatBatalkan?.call();
                    },
                    itemBuilder: (_) => [
                      for (final (kode, label) in menu)
                        PopupMenuItem<String>(value: kode, child: Text(label)),
                    ],
                  )
                else
                  const SizedBox(width: AppSpacing.sm),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  StatusBadge.fromApi(p.status),
                  StatusBadge(
                    label: p.grup
                        ? l10n.crudPenugasanTipeGrup
                        : l10n.crudPenugasanTipePersonal,
                    tone: BadgeTone.neutral,
                    icon: p.grup ? Icons.groups_outlined : Icons.person_outline,
                  ),
                  if (p.terlambat && p.aktif)
                    StatusBadge(
                      label: l10n.crudPenugasanTerlambat,
                      tone: BadgeTone.warning,
                      icon: Icons.schedule,
                    ),
                  if (p.siapDitutup)
                    StatusBadge(
                      label: l10n.crudPenugasanSiapDitutup,
                      tone: BadgeTone.success,
                      icon: Icons.task_alt,
                    ),
                ],
              ),
            ),
            if (tim.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  l10n.crudPenugasanTim(tim),
                  style: tema.textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              // Bilah hanya hiasan: angkanya dibacakan dari teks di bawahnya.
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BentukLab.sel),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: (p.persenTuntas.clamp(0, 100)) / 100,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                [
                  l10n.crudPenugasanProgres(p.persenTuntas),
                  l10n.crudPenugasanBaris(p.baris.length),
                  if (target != null)
                    l10n.crudPenugasanTarget(tanggalSa(context, target)),
                  if (selesaiTanggal != null)
                    l10n.crudPenugasanSelesaiPada(
                      tanggalSa(context, selesaiTanggal),
                    ),
                ].join(' · '),
                style: redup,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (batal != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((batal.alasan ?? '').trim().isNotEmpty)
                      Text(
                        l10n.crudPenugasanBatalAlasan(batal.alasan!.trim()),
                        style: tema.textTheme.bodySmall,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (jejakBatal != null) Text(jejakBatal, style: redup),
                  ],
                ),
              ),
            ],
            if (p.siapDitutup && saatSelesaikan != null)
              _AksiBawah(
                child: AppButton(
                  key: Key('selesaikan-penugasan-${p.id}'),
                  label: l10n.crudPenugasanAksiSelesaikan,
                  icon: Icons.task_alt,
                  ringkas: true,
                  onPressed: saatSelesaikan,
                ),
              ),
            if (p.selesai && saatBukaLagi != null)
              _AksiBawah(
                child: AppButton(
                  key: Key('buka-lagi-penugasan-${p.id}'),
                  label: l10n.crudPenugasanAksiBukaLagi,
                  icon: Icons.replay,
                  variant: AppButtonVariant.secondary,
                  ringkas: true,
                  onPressed: saatBukaLagi,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tombol penutup di dasar kartu, rata ke ujung supaya tidak berlomba dengan
/// teks kartu di layar sempit.
class _AksiBawah extends StatelessWidget {
  const _AksiBawah({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, right: AppSpacing.sm),
      child: Align(alignment: AlignmentDirectional.centerEnd, child: child),
    );
  }
}
