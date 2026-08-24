/// Format tanggal+jam buat DITAMPILIN di layar.
///
/// ## Kenapa ini ada
///
/// Layar antrean, riwayat, alur kerja, arsip & folder cuma nampilin tanggal
/// (`10 Agt 2026`). Begitu beberapa item masuk di hari yang sama — dan itu
/// normal di lab yang sibuk — daftarnya jadi tiga baris bertanggal identik,
/// dan nggak ada cara tahu mana yang paling baru. Padahal justru urutan itu
/// yang nentuin mana yang diperiksa duluan.
///
/// ## Kenapa satu berkas, bukan `DateFormat` di tiap layar
///
/// Sebelum ini tiap layar nulis pola sendiri (`d MMM yyyy`, `d MMMM yyyy`,
/// `d MMM, HH:mm`), jadi item yang sama kelihatan beda tergantung dibuka dari
/// mana. Yang dijaga di sini konsistensinya, bukan penghematan barisnya.
///
/// **Jangan dipakai buat tanggal kalender** (`tanggal_kalibrasi`,
/// `berlaku_sampai`) — kolom itu `date` di backend, nggak punya jam, dan
/// nempelin `00:00` di situ itu ngarang ketelitian yang datanya nggak punya.
/// Lihat `tanggal_api.dart`.
library;

import 'package:intl/intl.dart';

/// `10 Agt 2026 · 09.14` — tanggal + jam, buat titik waktu.
///
/// Pemisahnya `·` bukan koma: baris di layar udah pakai koma & titik buat hal
/// lain (`Teknisi · 10 Agt`), jadi satu pemisah yang konsisten lebih kebaca.
String waktuLengkap(DateTime waktu, String locale) =>
    DateFormat('d MMM yyyy · HH.mm', locale).format(waktu);

/// Jamnya doang (`09.14`) — buat baris yang tanggalnya udah kesebut di tempat
/// lain, mis. kepala grup per hari.
String jamSaja(DateTime waktu, String locale) =>
    DateFormat('HH.mm', locale).format(waktu);

/// Tanggal + jam, tapi tanggalnya diringkas jadi **"Hari ini"/"Kemarin"** kalau
/// masih baru.
///
/// Yang paling sering dicari itu kiriman hari ini, dan `10 Agt 2026 · 09.14`
/// bikin mata mesti mbandingin angka tanggal dulu sebelum sampai ke jamnya.
///
/// [sekarang] bisa dioper biar test nggak bergantung jam dinding.
String waktuRelatif(
  DateTime waktu,
  String locale, {
  required String hariIni,
  required String kemarin,
  DateTime? sekarang,
}) {
  final acuan = sekarang ?? DateTime.now();

  // Dibandingin per HARI KALENDER, bukan selisih 24 jam: jam 23.50 dan jam
  // 00.10 cuma beda 20 menit tapi beda hari, dan orang mikirnya per hari.
  final hariWaktu = DateTime(waktu.year, waktu.month, waktu.day);
  final hariAcuan = DateTime(acuan.year, acuan.month, acuan.day);
  final selisih = hariAcuan.difference(hariWaktu).inDays;

  final jam = jamSaja(waktu, locale);

  return switch (selisih) {
    0 => '$hariIni · $jam',
    1 => '$kemarin · $jam',
    _ => waktuLengkap(waktu, locale),
  };
}

/// `2 jam lalu` / `Kemarin` — JARAK dari sekarang, bukan titik waktunya.
///
/// Beda tujuan dari [waktuRelatif], yang tetap nyebut jam (`Hari ini · 09.14`):
/// di antrean approval yang dicari admin itu urutan periksa antar kiriman di
/// hari yang sama, jadi jamnya justru datanya. Di daftar draf pertanyaannya
/// lain — "mana yang paling lama saya tinggal" — dan `10 Agt 2026 · 09.14`
/// maksa mata ngurangin tanggal dulu sebelum jawabannya kebaca. Efeknya draf
/// yang ditinggal tiga minggu kelihatan sama mendesaknya sama yang ditinggal
/// sejam lalu.
///
/// Lewat seminggu balik ke tanggal penuh: "23 hari lalu" itu angka yang mesti
/// dihitung mundur lagi biar berguna, sementara tanggalnya langsung kepakai.
///
/// [sekarang] bisa dioper biar test nggak bergantung jam dinding.
String waktuLalu(
  DateTime waktu,
  String locale, {
  required String baruSaja,
  required String Function(int menit) menitLalu,
  required String Function(int jam) jamLalu,
  required String kemarin,
  required String Function(int hari) hariLalu,
  DateTime? sekarang,
}) {
  final acuan = sekarang ?? DateTime.now();
  final selisih = acuan.difference(waktu);

  // Jam HP yang meleset beberapa menit bikin `updated_at` dari server
  // kelihatan ada di MASA DEPAN, dan `inMinutes` jadi negatif. "-3 menit lalu"
  // itu tulisan yang nggak ada artinya; draf yang barusan disimpen memang
  // "baru saja".
  if (selisih.inMinutes < 1) return baruSaja;
  if (selisih.inMinutes < 60) return menitLalu(selisih.inMinutes);
  if (selisih.inHours < 24) return jamLalu(selisih.inHours);

  // Sesudah lewat sehari, hitungannya pindah ke HARI KALENDER — bukan
  // kelipatan 24 jam. Draf yang disimpen Senin malam dibuka Selasa pagi itu
  // "kemarin" buat teknisinya, walau selisihnya baru 11 jam (yang di atas
  // udah nangkep) atau justru 30 jam.
  final hariWaktu = DateTime(waktu.year, waktu.month, waktu.day);
  final hariAcuan = DateTime(acuan.year, acuan.month, acuan.day);
  final hari = hariAcuan.difference(hariWaktu).inDays;

  if (hari <= 1) return kemarin;
  if (hari <= 7) return hariLalu(hari);

  return waktuLengkap(waktu, locale);
}
