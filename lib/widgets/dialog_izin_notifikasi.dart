import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigasi_global.dart';
import '../l10n/app_localizations.dart';

const _kunciSudahDitanya = 'izin_notifikasi_sudah_dijelaskan';

/// Penjelasan singkat sebelum dialog izin sistem Android 13+.
///
/// Dipanggil dari `LocalNotifikasiPerangkat` SESUDAH login (bukan saat aplikasi
/// dibuka pertama kali) dan HANYA bila izin belum diberikan. Cuma sekali per
/// pemasangan: yang menjawab "Nanti saja" tidak ditagih lagi — lonceng dan
/// daftar notifikasi tetap jalan, dan izinnya bisa dinyalakan dari setelan HP.
Future<bool> tanyaIzinNotifikasi() async {
  final context = navigatorKey.currentContext;
  if (context == null) return false;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kunciSudahDitanya) ?? false) return false;
  if (!context.mounted) return false;

  final l10n = AppLocalizations.of(context);
  final setuju = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.notifications_active_outlined),
      title: Text(l10n.izinNotifJudul),
      content: Text(l10n.izinNotifIsi),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.izinNotifNanti),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.izinNotifLanjut),
        ),
      ],
    ),
  );

  await prefs.setBool(_kunciSudahDitanya, true);
  return setuju ?? false;
}
