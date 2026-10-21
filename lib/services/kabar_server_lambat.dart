import 'dart:async';

/// Ambang sebelum teknisi diberi tahu "server sedang dinyalakan".
///
/// Jawaban server yang bangun normal datang di bawah beberapa detik; server
/// Render gratis yang tertidur butuh 30–90 detik. Di atas ~9 detik layar yang
/// diam terlihat beku — saat itulah kabarnya muncul.
const ambangKabarServerLambat = Duration(seconds: 9);

/// Tunggu [kerja]; kalau belum selesai setelah [setelah], panggil [lambat]
/// SEKALI. Hasil/galat [kerja] diteruskan apa adanya — fungsi ini tidak
/// mengulang, tidak membatalkan, dan tidak mengubah batas waktu apa pun.
Future<T> kabariBilaLambat<T>(
  Future<T> kerja, {
  required void Function() lambat,
  Duration setelah = ambangKabarServerLambat,
}) async {
  final jam = Timer(setelah, lambat);
  try {
    return await kerja;
  } finally {
    jam.cancel();
  }
}
