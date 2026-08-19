import 'package:flutter/material.dart';

/// Satuan gerak app — durasi & kurva, di satu tempat.
///
/// Ditaruh sini karena animasi yang durasinya beda-beda per layar kebaca kayak
/// app yang dirakit dari beberapa app. Yang bikin gerak terasa "dibikin" bukan
/// gerakannya mahal, tapi konsisten: benda yang perannya sama bergerak dengan
/// tempo yang sama.
///
/// Semua angka di sini SENGAJA pendek. Transisi 400 ms terasa mewah waktu
/// dilihat sekali di video, dan terasa lambat waktu teknisi mbuka layar yang
/// sama enam puluh kali sehari.
abstract final class AppMotion {
  /// Perubahan kecil di tempat — tombol ditekan, ikon ganti, warna geser.
  static const Duration kilat = Duration(milliseconds: 120);

  /// Bawaan: kartu masuk, isi berganti, panel membuka.
  static const Duration sedang = Duration(milliseconds: 240);

  /// Pindah halaman — satu-satunya yang boleh selama ini.
  static const Duration halaman = Duration(milliseconds: 280);

  /// Masuk layar: cepat di awal, melambat di akhir. Benda yang datang
  /// kelihatan "mendarat", bukan direm mendadak.
  static const Curve masuk = Curves.easeOutCubic;

  /// Keluar layar: kebalikannya, biar nggak nahan pandangan orang yang udah
  /// mutusin pindah.
  static const Curve keluar = Curves.easeInCubic;

  /// Jeda antar kartu di satu daftar.
  ///
  /// Kecil banget dan DIBATASI ([maksTunda]): kartu ke-30 yang nunggu 30 x
  /// jeda bikin daftar panjang kelihatan macet, bukan hidup — dan lembar kerja
  /// di app ini rutin punya puluhan baris.
  static const Duration jedaBerurutan = Duration(milliseconds: 35);

  /// Batas atas tundaan berurutan, berapa pun panjang daftarnya.
  static const Duration maksTunda = Duration(milliseconds: 210);

  /// Durasi yang sudah menghormati setelan "kurangi gerak" di HP/laptop.
  ///
  /// Bukan basa-basi aksesibilitas: sebagian orang beneran mual sama gerak
  /// layar (vestibular), dan sistem operasinya udah nyediain saklarnya. Kalau
  /// saklar itu nyala, animasi kita jadi NOL — bukan diperlambat, bukan
  /// diperhalus. Splash screen app ini udah lama ngelakuin itu
  /// (`MediaQuery.disableAnimationsOf`); ini bikin aturannya berlaku buat
  /// semua gerak baru, bukan cuma satu layar.
  static Duration hormati(BuildContext context, Duration durasi) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : durasi;

  /// Tundaan berurutan buat kartu ke-[indeks], udah dibatasi & dihormati.
  static Duration tunda(BuildContext context, int indeks) {
    if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;

    final tunda = jedaBerurutan * indeks;
    return tunda > maksTunda ? maksTunda : tunda;
  }
}
