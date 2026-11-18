import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Tanggal pendek ("10 Nov 2026") dalam bahasa yang sedang berlaku; `-` bila
/// kosong. Satu tempat supaya semua layar Super Admin menulis tanggal sama.
String tanggalSa(BuildContext context, DateTime? t) {
  if (t == null) return '-';
  final locale = Localizations.localeOf(context).toString();
  return DateFormat('d MMM yyyy', locale).format(t);
}

/// Nama bulan penuh ("November") untuk judul kelompok riwayat.
String namaBulanSa(BuildContext context, int tahun, int bulan) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat('MMMM', locale).format(DateTime(tahun, bulan));
}
