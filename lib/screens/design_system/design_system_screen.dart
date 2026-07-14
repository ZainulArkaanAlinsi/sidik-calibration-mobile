import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/status_badge.dart';

/// Katalog design system — semua warna & komponen dasar dikumpulin di satu
/// layar biar gampang direview (dan gampang ditunjukin ke atasan).
///
/// Bukan bagian dari alur user; dibuka dari tab Profil.
class DesignSystemScreen extends StatelessWidget {
  const DesignSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Section(
            title: 'Warna',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [
                _Swatch(color: AppColors.primary, name: 'Primary'),
                _Swatch(color: AppColors.secondary, name: 'Secondary'),
                _Swatch(color: AppColors.navy, name: 'Navy'),
                _Swatch(color: AppColors.accent, name: 'Accent'),
                _Swatch(color: AppColors.success, name: 'Success'),
                _Swatch(color: AppColors.danger, name: 'Danger'),
                _Swatch(color: AppColors.warning, name: 'Warning'),
                _Swatch(color: AppColors.info, name: 'Info'),
              ],
            ),
          ),

          _Section(
            title: 'Tipografi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Headline Small', style: theme.textTheme.headlineSmall),
                Text('Title Medium', style: theme.textTheme.titleMedium),
                Text('Body Medium — teks isi biasa', style: theme.textTheme.bodyMedium),
                Text('Body Small — keterangan', style: theme.textTheme.bodySmall),
              ],
            ),
          ),

          _Section(
            title: 'Status Badge',
            subtitle:
                'Selalu ikon + teks, nggak cuma warna — biar tetap kebaca sama '
                'yang buta warna.',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatusBadge.fromApi('PASS'),
                StatusBadge.fromApi('FAIL'),
                StatusBadge.fromApi('aktif'),
                StatusBadge.fromApi('overdue'),
                StatusBadge.fromApi('menunggu_approval'),
                StatusBadge.fromApi('disetujui'),
                StatusBadge.fromApi('perlu_revisi'),
                StatusBadge.fromApi('draft'),
              ],
            ),
          ),

          _Section(
            title: 'Tombol',
            child: Column(
              children: [
                AppButton(label: 'Simpan Kalibrasi', onPressed: () {}),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Scan Kamera',
                  icon: Icons.photo_camera_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppButton(
                  label: 'Lagi menyimpan…',
                  isLoading: true,
                  onPressed: null,
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppButton(label: 'Nonaktif', onPressed: null),
              ],
            ),
          ),

          _Section(
            title: 'Input',
            child: Column(
              children: [
                const AppTextField(
                  label: 'Nama Alat',
                  hint: 'mis. Jangka Sorong Mitutoyo',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField.measurement(
                  label: 'Pembacaan',
                  hint: '0.00',
                  satuan: 'mm',
                ),
                const SizedBox(height: AppSpacing.md),
                const AppTextField(
                  label: 'Nomor Seri',
                  errorText: 'Nomor seri sudah dipakai alat lain.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.name});

  final Color color;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 48,
          width: 64,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(name, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
