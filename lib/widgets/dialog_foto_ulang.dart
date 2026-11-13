import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../l10n/app_localizations.dart';

/// Foto lembar kerja tidak lolos (buram, gelap, terpotong, dst.): tampilkan
/// alasannya dan tawarkan memotret ulang. `true` = teknisi minta foto ulang;
/// `false` = ditutup (isi manual atau coba lagi nanti).
///
/// Dialog (bukan snackbar) karena tombolnya harus tetap ada selama teknisi
/// membaca alasannya dan mengatur ulang lembar — snackbar hilang sendiri.
///
/// [pesan] = alasan yang sudah ada (`pesanGagalAsli`). [halamanTerpotong]
/// menambahkan penjelasan bahwa SELURUH halaman harus masuk foto.
Future<bool> tawarkanFotoUlang(
  BuildContext context, {
  required String pesan,
  bool halamanTerpotong = false,
}) async {
  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context);

  final ulang = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('dialog-foto-ulang'),
      title: Text(l10n.lkFotoUlangJudul),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pesan, key: const ValueKey('pesan-foto-ulang')),
            if (halamanTerpotong) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.lkAsliHalamanTerpotong,
                key: const ValueKey('pesan-halaman-terpotong'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('foto-ulang-tutup'),
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.lkFotoUlangTutup),
        ),
        FilledButton.icon(
          key: const ValueKey('foto-ulang'),
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(l10n.lkFotoUlang),
        ),
      ],
    ),
  );

  return ulang ?? false;
}
