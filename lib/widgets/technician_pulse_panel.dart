import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'liquid_glass.dart';
import 'scene3d/alat_3d.dart';
import 'scene3d/mesh3d.dart';
import 'scene3d/panggung3d.dart';
import 'scene3d/renderer3d.dart';

/// Panel pembuka dashboard teknisi — "meja kerja" pribadi: siapa dia, berapa
/// yang lagi jalan, dan satu tombol buat mulai.
///
/// Benda 3D di kanan bukan stok ilustrasi: dia anak timbangan (mass standard)
/// yang dirender dari mesh sungguhan lewat [Panggung3D], jadi bisa diputar
/// pakai jari. Alasannya sederhana — inilah benda yang paling langsung
/// ngomong "ini app kalibrasi", dan teknisi yang megang HP-nya bakal ngenalin
/// bentuknya dari jarak satu meter.
///
/// Animasinya cuma **sekali waktu muncul**. Bukan karena males: dashboard itu
/// layar yang paling lama nyala di HP teknisi, dan objek yang muter selamanya
/// bikin GPU kerja seharian buat hiasan yang udah nggak dilihat sesudah detik
/// ketiga. Lihat catatan panjangnya di `panggung3d.dart`.
class TechnicianPulsePanel extends StatelessWidget {
  const TechnicianPulsePanel({
    super.key,
    required this.name,
    required this.title,
    required this.startLabel,
    required this.draftLabel,
    required this.pendingLabel,
    required this.doneLabel,
    required this.activeLabel,
    required this.liveLabel,
    required this.draft,
    required this.pending,
    required this.done,
    required this.onStart,
    this.mesh,
  });

  final String name;
  final String title;
  final String startLabel;
  final String draftLabel;
  final String pendingLabel;
  final String doneLabel;

  /// Teks "{n} tugas aktif" yang udah jadi — panel nggak nyusun kalimat
  /// sendiri, biar terjemahannya tetap satu pintu di ARB.
  final String activeLabel;
  final String liveLabel;

  final int draft;
  final int pending;
  final int done;
  final VoidCallback onStart;

  /// Bisa ditukar buat pratinjau/tes. Default: anak timbangan.
  final Mesh3D? mesh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final namaDepan = name.trim().isEmpty ? '' : name.trim().split(' ').first;

    return RepaintBoundary(
      child: Semantics(
        label:
            '$title. $activeLabel. '
            '$draftLabel: $draft. $pendingLabel: $pending. '
            '$doneLabel: $done.',
        child: LiquidGlass(
          panelGelap: true,
          radius: 30,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned(
                right: 6,
                top: 2,
                bottom: 72,
                width: 190,
                child: Panggung3D(
                  mesh: mesh ?? Alat3D.anakTimbangan(),
                  kamera: const Kamera3D(
                    jarak: 4.3,
                    pitch: 0.28,
                    geser: Offset(0, 0.04),
                  ),
                  cahaya: const Cahaya3D(
                    warnaTepi: AppColors.cobalt,
                    kuatTepi: 0.62,
                  ),
                  yawAwal: -1.25,
                  yawAkhir: 0.48,
                  bayangan: 1.9,
                  // Gurat tepi tipis — fitur mesin gambarnya udah ada
                  // (`renderer3d.dart`) tapi belum dipasang di mana pun.
                  // Ini yang bikin bidang datarnya kebaca gambar teknik/panel
                  // instrumen, bukan cuma blok abu-abu polos.
                  garisTepi: 1.1,
                  semantics: null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Live(label: liveLabel),
                    const SizedBox(height: AppSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 210),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.60),
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            namaDepan.isEmpty ? title : 'Halo, $namaDepan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activeLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TombolMulai(label: startLabel, onTap: onStart),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _Metrik(
                          nilai: draft,
                          label: draftLabel,
                          warna: Colors.white,
                          icon: Icons.edit_note_rounded,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _Metrik(
                          nilai: pending,
                          label: pendingLabel,
                          warna: pending > 0 ? AppColors.cobalt : Colors.white,
                          icon: Icons.hourglass_top_rounded,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _Metrik(
                          nilai: done,
                          label: doneLabel,
                          warna: AppColors.mint,
                          icon: Icons.task_alt_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Live extends StatelessWidget {
  const _Live({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.mint,
            boxShadow: [
              BoxShadow(
                color: AppColors.mint.withValues(alpha: 0.9),
                blurRadius: 9,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Tombol utama panel. Diisi Cobalt pekat — di antara bidang gelap di panel
/// ini, tombol yang cuma bergaris kebaca sebagai dekorasi, bukan sebagai
/// satu-satunya aksi yang harus dipencet. Cobalt = warna interaktif di seluruh
/// app; di sini dipakai penuh karena ini SATU-SATUNYA tombol di panel.
class _TombolMulai extends StatelessWidget {
  const _TombolMulai({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppColors.cobalt,
            boxShadow: [
              BoxShadow(
                color: AppColors.cobalt.withValues(alpha: 0.38),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.white,
                size: 22,
              ),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 168),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    // Putih, bukan Jet Black: hitam di atas cobalt cuma
                    // nyampe 3,5:1 — di bawah ambang 4,5:1 buat teks
                    // sekecil label tombol.
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metrik extends StatelessWidget {
  const _Metrik({
    required this.nilai,
    required this.label,
    required this.warna,
    required this.icon,
  });

  final int nilai;
  final String label;
  final Color warna;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: warna.withValues(alpha: 0.85)),
            const SizedBox(height: 6),
            Text(
              '$nilai',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: warna,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 8.5,
                height: 1.25,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
