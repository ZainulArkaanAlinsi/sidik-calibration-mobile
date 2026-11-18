import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart' show TokenHilangException;
import '../../providers/order_kelola_provider.dart';
import 'widgets/dialog_konfirmasi_crud.dart';
import 'widgets/pesan_galat_crud.dart';

/// Hapus satu order lewat dialog konfirmasi tegas. `true` bila terhapus.
///
/// Server menolak (`422`, tanpa kode) order yang alatnya sudah punya sesi
/// kalibrasi — jejak itu yang dicari asesor — dan kalimatnya dijelaskan di
/// dalam dialog. Sukses → daftar diambil ulang dari server.
Future<bool> hapusOrderCrud(
  BuildContext context,
  WidgetRef ref,
  OrderKalibrasi order,
) async {
  final l10n = AppLocalizations.of(context);
  final ok = await tampilkanDialogKonfirmasiCrud(
    context,
    judul: l10n.crudOrderHapusJudul(order.nomor),
    isi: l10n.crudOrderHapusIsi,
    labelAksi: l10n.crudOrderHapusAksi,
    ditolak422: l10n.crudOrderHapusDitolak,
    aksi: () async {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) throw const TokenHilangException();
      await ref.read(orderKelolaServiceProvider).hapus(token, order.id);
    },
    saatGalat: (e) {
      if (perluMuatUlangCrud(e)) {
        ref.read(orderKelolaProvider.notifier).muatUlang();
      }
    },
  );
  if (ok) ref.read(orderKelolaProvider.notifier).muatUlang();
  return ok;
}
