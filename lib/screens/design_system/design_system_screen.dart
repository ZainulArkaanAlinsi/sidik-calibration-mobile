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

    final brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Section(
            title: 'Palet inti',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [
                _Swatch(color: AppColors.crimson, name: 'Crimson Red'),
                _Swatch(color: AppColors.ink, name: 'Jet Black'),
                _Swatch(color: AppColors.mint, name: 'Arctic Mint'),
                _Swatch(color: AppColors.ivory, name: 'Bright Ivory'),
                _Swatch(color: AppColors.cobalt, name: 'Cobalt Blue'),
              ],
            ),
          ),

          _Section(
            title: 'Turunan',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [
                _Swatch(color: AppColors.cobaltDeep, name: 'Cobalt Deep'),
                _Swatch(color: AppColors.cobaltSoft, name: 'Cobalt Soft'),
                _Swatch(color: AppColors.mintDeep, name: 'Mint Deep'),
                _Swatch(color: AppColors.crimsonSoft, name: 'Crimson Soft'),
                _Swatch(color: AppColors.hairline, name: 'Hairline'),
              ],
            ),
          ),

          _Section(
            title: 'Status',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Swatch(
                  color: AppColors.statusSukses(brightness),
                  name: 'Success',
                ),
                _Swatch(
                  color: AppColors.statusBahaya(brightness),
                  name: 'Danger',
                ),
                _Swatch(
                  color: AppColors.statusPeringatan(brightness),
                  name: 'Warning',
                ),
                _Swatch(color: AppColors.statusInfo(brightness), name: 'Info'),
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
