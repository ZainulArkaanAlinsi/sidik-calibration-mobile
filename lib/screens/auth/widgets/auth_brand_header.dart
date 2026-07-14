import 'package:flutter/material.dart';

import '../../../core/config/lab_profile.dart';
import '../../../core/theme/app_spacing.dart';

/// Kepala layar auth: logo mark + judul + subjudul.
/// Dipakai bareng-bareng sama Login & Register biar dua layar itu kelihatan
/// satu keluarga (di desain aslinya beda tema, dan itu keliatan janggal).
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Logo mark sementara. Ganti pakai logo resmi PT Sidik begitu asetnya
        // dikasih — cukup ubah di sini, dua layar ikut.
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(
            Icons.precision_manufacturing_outlined,
            size: 32,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Footer identitas lab.
///
/// Nyebut **lab yang terakreditasi KAN** (PT Sidik, LK-285-IDN) — bukan nama
/// lain. Ini yang bakal muncul juga di sertifikat: sertifikat kalibrasi wajib
/// atas nama lab yang beneran punya akreditasi.
class AuthPoweredBy extends StatelessWidget {
  const AuthPoweredBy({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gaya = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    );

    return Column(
      children: [
        Text(
          LabProfile.namaSingkat.toUpperCase(),
          textAlign: TextAlign.center,
          style: gaya?.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Terakreditasi KAN ${LabProfile.nomorAkreditasi} · '
          '${LabProfile.standar}',
          textAlign: TextAlign.center,
          style: gaya,
        ),
      ],
    );
  }
}
