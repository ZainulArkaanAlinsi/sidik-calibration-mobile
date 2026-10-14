import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/draf_lokal_provider.dart';
import '../services/draf_lokal.dart';

/// Keluar akun padahal masih ada draf yang belum sampai server di HP ini.
///
/// Keputusan 14 Okt 2026 (draf-offline, review ronde 1): draf yang sudah
/// antre (`belum_tersinkron`) atau ditolak server (`perlu_diperbaiki`) NGGAK
/// PERNAH dibuang gara-gara logout atau gara-gara akun lain masuk — itu data
/// lapangan. Yang dilakukan di sini:
///
///  1. coba kirim SEKALI (mungkin sinyalnya sudah balik);
///  2. kalau masih ada yang tersisa, bilang terus terang: drafnya tetap di
///     tablet ini dan dikirim waktu pemiliknya login lagi.
///
/// Logout-nya sendiri (`AuthController.logout`) nggak menyentuh draf sama
/// sekali. Balik `true` = boleh lanjut keluar.
Future<bool> konfirmasiKeluarDenganDrafTertunda(
  BuildContext context,
  WidgetRef ref,
) async {
  final userId = ref.read(authProvider).value?.id;
  if (userId == null) return true;

  final simpanan = ref.read(simpananDrafLokalProvider);
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  Future<int> hitungTertunda() async => (await simpanan.daftar(
    userId,
  )).where((d) => d.status != StatusDrafLokal.lokal).length;

  if (await hitungTertunda() == 0) return true;

  final sinkron = ref.read(sinkronDrafLokalProvider);
  if (sinkron != null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.drafTertundaMengirim)));
    try {
      // Dibatasi: teknisi yang mau keluar nggak boleh tertahan menunggu
      // server Render bangun. Yang belum selesai tetap antre.
      await sinkron.jalankan().timeout(const Duration(seconds: 20));
    } catch (_) {
      // Lihat di atas — yang gagal terkirim tetap di HP.
    }
    messenger.hideCurrentSnackBar();
  }

  final sisa = await hitungTertunda();
  if (sisa == 0) return true;
  if (!context.mounted) return false;

  final lanjut = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: Text(l10n.drafTertundaLogoutJudul),
      content: Text(l10n.drafTertundaLogoutIsi(sisa)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.drafTertundaLogoutBatal),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.drafTertundaLogoutLanjut),
        ),
      ],
    ),
  );

  return lanjut ?? false;
}
