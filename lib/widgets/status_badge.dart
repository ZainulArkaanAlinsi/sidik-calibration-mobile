import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Nada warna badge. Nggak nyebut warna langsung ("hijau"), tapi maknanya —
/// biar kalau paletnya diganti, artinya tetap sama.
enum BadgeTone { success, danger, warning, info, neutral }

/// Badge status — dipakai buat hasil kalibrasi (PASS/FAIL), status alat
/// (aktif/overdue), dan status sesi (draft/menunggu approval/dst).
///
/// Selalu bawa **ikon + teks**, bukan cuma warna: teknisi yang buta warna
/// tetap harus bisa bedain PASS dan FAIL. Ini bukan hiasan — hasil kalibrasi
/// itu data yang dipertanggungjawabkan.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// Bikin badge langsung dari nilai yang dikirim API.
  /// Nilai enum-nya ngikutin `docs/kontrak-api.md` — kalau backend ganti,
  /// yang diubah cuma di sini.
  factory StatusBadge.fromApi(String value, {Key? key}) {
    return switch (value) {
      'PASS' => StatusBadge(
        key: key,
        label: 'PASS',
        tone: BadgeTone.success,
        icon: Icons.check_circle_outline,
      ),
      'FAIL' => StatusBadge(
        key: key,
        label: 'FAIL',
        tone: BadgeTone.danger,
        icon: Icons.cancel_outlined,
      ),
      'aktif' => StatusBadge(
        key: key,
        label: 'Aktif',
        tone: BadgeTone.success,
        icon: Icons.check_circle_outline,
      ),
      'overdue' => StatusBadge(
        key: key,
        label: 'Jatuh tempo',
        tone: BadgeTone.warning,
        icon: Icons.schedule,
      ),
      'nonaktif' => StatusBadge(
        key: key,
        label: 'Nonaktif',
        tone: BadgeTone.neutral,
        icon: Icons.remove_circle_outline,
      ),
      'draft' => StatusBadge(
        key: key,
        label: 'Draft',
        tone: BadgeTone.neutral,
        icon: Icons.edit_note,
      ),
      'menunggu_approval' => StatusBadge(
        key: key,
        label: 'Menunggu approval',
        tone: BadgeTone.info,
        icon: Icons.hourglass_empty,
      ),
      'disetujui' => StatusBadge(
        key: key,
        label: 'Disetujui',
        tone: BadgeTone.success,
        icon: Icons.verified_outlined,
      ),
      'perlu_revisi' => StatusBadge(
        key: key,
        label: 'Perlu revisi',
        tone: BadgeTone.warning,
        icon: Icons.edit_outlined,
      ),
      // Status yang belum dikenal tetap ditampilkan apa adanya, bukan bikin
      // app crash — kalau backend nambah status baru, kelihatan di UI.
      _ => StatusBadge(key: key, label: value, tone: BadgeTone.neutral),
    };
  }

  Color _color(ColorScheme scheme) => switch (tone) {
    BadgeTone.success => AppColors.success,
    BadgeTone.danger => AppColors.danger,
    BadgeTone.warning => AppColors.warning,
    BadgeTone.info => AppColors.info,
    BadgeTone.neutral => scheme.onSurfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(theme.colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
