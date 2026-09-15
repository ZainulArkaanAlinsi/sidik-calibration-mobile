import 'package:flutter/widgets.dart';

/// Apakah aplikasi sedang terlihat di layar depan.
///
/// Dipakai penyegaran berkala (dashboard, daftar sesi, notifikasi) supaya HP di
/// saku dan jendela laptop yang diminimalkan BERHENTI menarik data. Server
/// produksi Render gratis cuma sanggup mengerjakan satu-dua permintaan sekaligus
/// (diukur 15 Sep 2026: 12 permintaan bersamaan antre sampai 13,7 detik), jadi
/// tarikan dari perangkat yang tidak sedang dilihat siapa pun langsung
/// memperlambat tombol kirim di perangkat yang sedang dipakai.
///
/// `null` (belum ada siklus hidup — test, atau sebelum frame pertama) dianggap
/// di depan: lebih baik tetap menyegarkan daripada diam tanpa sebab.
bool aplikasiDiLayarDepan() {
  try {
    final keadaan = WidgetsBinding.instance.lifecycleState;
    return keadaan == null || keadaan == AppLifecycleState.resumed;
  } catch (_) {
    // Binding belum dinyalakan (test murni Dart tanpa widget).
    return true;
  }
}
