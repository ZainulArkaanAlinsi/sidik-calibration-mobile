import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';

/// Pengganti dropdown yang datanya gagal dimuat.
///
/// ## Kenapa bukan `SizedBox.shrink()`
///
/// Tiga dropdown di lembar kerja dulunya HILANG tanpa sepatah kata kalau
/// daftarnya gagal diambil — standar acuan sesi, standar per titik, dan
/// ruangan. Buat teknisi di lapangan, kolom yang nggak ada itu nggak bisa
/// dibedain dari kolom yang emang nggak diminta di lembar ini: dia lanjut
/// ngisi, ngirim, dan baru tahu ada yang kurang waktu admin ngembaliin
/// sesinya berhari-hari kemudian.
///
/// Dua yang standar acuan itu **ketertelusuran** — sesi tanpa standar yang
/// ketaut nggak bisa jadi sertifikat berakreditasi. Jadi diamnya bukan cuma
/// nggak enak dilihat, tapi ngumpetin syarat yang nggak bisa ditawar.
///
/// Sengaja ringkas (satu baris) — ini nyempil di tengah formulir panjang, bukan
/// layar error yang berdiri sendiri.
class DropdownGagal extends StatelessWidget {
  const DropdownGagal({
    super.key,
    required this.label,
    required this.pesan,
    required this.onCobaLagi,
  });

  /// Label kolomnya, biar teknisi tau YANG MANA yang lagi kosong — di lembar
  /// yang punya tiga dropdown standar, "gagal muat" doang nggak nunjuk apa-apa.
  final String label;

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: AppColors.statusPeringatan(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  pesan,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.statusPeringatan(context),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCobaLagi,
            child: Text(AppLocalizations.of(context).folderRetry),
          ),
        ],
      ),
    );
  }
}
