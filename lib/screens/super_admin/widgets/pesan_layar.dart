import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Keadaan kosong / galat / terkunci satu layar: ikon + kalimat (+ aksi).
///
/// Bentuknya sama dengan `_Pesan` di Data Teknisi (yang privat di berkasnya,
/// jadi tidak bisa dipakai ulang). Isinya digulir (`ListView`) supaya tetap
/// terbaca di layar pendek/landscape dan bisa ditarik-segarkan.
class PesanLayar extends StatelessWidget {
  const PesanLayar({
    super.key,
    required this.ikon,
    required this.teks,
    this.aksi,
    this.galat = false,
  });

  final IconData ikon;
  final String teks;
  final Widget? aksi;

  /// Ikon berwarna galat (cloud off) dan bukan netral (daftar kosong).
  final bool galat;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                ikon,
                size: 48,
                color: galat
                    ? tema.colorScheme.error
                    : tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                teks,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (aksi != null) ...[const SizedBox(height: AppSpacing.lg), aksi!],
          ],
        ),
      ),
    );
  }
}
