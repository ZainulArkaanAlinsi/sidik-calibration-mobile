import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../screens/notification/notification_screen.dart';

/// Kunci navigator aplikasi — satu-satunya cara berpindah layar dari LUAR
/// pohon widget.
///
/// Dibutuhkan karena notifikasi diketuk di tempat yang nggak punya
/// `BuildContext`: bilah notifikasi sistem operasi, dan pesan Firebase yang
/// membuka aplikasi dari keadaan mati. Dua-duanya masuk lewat callback biasa,
/// bukan lewat widget.
///
/// Dipakai SEMPIT — cuma buat itu. Navigasi di dalam layar tetap lewat
/// `Navigator.of(context)`, karena yang lewat kunci global nggak kelihatan di
/// pohon widget dan lebih susah dilacak waktu ada yang salah.
final navigatorKey = GlobalKey<NavigatorState>();

/// Buka layar tujuan notifikasi dari luar pohon widget.
///
/// Diam kalau navigatornya belum terpasang — itu keadaan nyata, bukan
/// kemungkinan: pesan yang membuka aplikasi dari keadaan mati sampai duluan
/// sebelum `MaterialApp` selesai dibangun. Yang salah bukan tautannya; cuma
/// belum ada layar buat mendarat.
void bukaTautanDariLuar(NotifTautan? tautan) {
  if (tautan == null) return;

  final context = navigatorKey.currentContext;
  if (context == null) return;

  bukaTautanNotifikasi(context, tautan);
}

/// Bentuk tautan yang dibawa notifikasi sistem: `tipe:id`.
///
/// Satu bentuk buat dua jalur — muatan `payload` notifikasi lokal (yang
/// dinyalakan Reverb) dan `data` pesan Firebase. Kalau dibedakan, cepat atau
/// lambat satu jalur ikut berubah dan yang lain ketinggalan, dan gejalanya
/// cuma "ketukannya nggak ngapa-ngapain" — nggak ada error sama sekali.
String? sandiTautan(NotifTautan? tautan) =>
    tautan == null ? null : '${tautan.tipe}:${tautan.id}';

/// Kebalikan [sandiTautan]. `null` kalau bentuknya nggak dikenal — lebih baik
/// diam daripada mendarat di layar yang salah.
NotifTautan? bacaTautan(String? sandi) {
  if (sandi == null || sandi.isEmpty) return null;

  final potong = sandi.split(':');
  if (potong.length != 2) return null;

  final id = int.tryParse(potong[1]);
  if (id == null) return null;

  return NotifTautan(tipe: potong[0], id: id);
}
