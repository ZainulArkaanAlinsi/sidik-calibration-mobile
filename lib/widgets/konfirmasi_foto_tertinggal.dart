import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Tanya teknisi: pakai foto yang dipulihkan, atau foto baru?
///
/// Pratinjaunya ikut ditampilkan supaya dia bisa melihat SENDIRI apakah foto
/// itu memang lembar yang sedang dibuka. Ditutup tanpa memilih = foto baru.
Future<bool> konfirmasiFotoTertinggal(BuildContext context, File foto) async {
  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context);

  final pakai = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('dialog-foto-tertinggal'),
      title: Text(l10n.lkFotoTertinggalJudul),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.lkFotoTertinggalIsi),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: Image.file(
              foto,
              fit: BoxFit.contain,
              cacheWidth: 600,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.lkFotoTertinggalBaru),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.lkFotoTertinggalPakai),
        ),
      ],
    ),
  );

  return pakai ?? false;
}
