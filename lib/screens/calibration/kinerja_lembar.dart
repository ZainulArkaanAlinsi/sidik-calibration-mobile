
/// Penghitung kerja lembar kerja — HANYA hidup di mode debug (`assert`), jadi
/// build rilis tidak membayar apa pun.
///
/// Dipakai `test/lembar_kerja_kinerja_test.dart` untuk mengukur sebelum/
/// sesudah: berapa kali seluruh formulir dibangun ulang selama teknisi
/// mengetik, berapa kali daftar baris tabel disusun, berapa kali keunikan
/// titik dihitung. Angka itu yang membedakan "lembar kerja terasa berat" dari
/// "lembar kerja memang berat", tanpa menebak dari profil perangkat.
abstract final class KinerjaLembar {
  static int bangunForm = 0;
  static int susunBaris = 0;
  static int hitungTitikUnik = 0;

  static void nolkan() {
    bangunForm = 0;
    susunBaris = 0;
    hitungTitikUnik = 0;
  }

  /// `assert(KinerjaLembar.catat(() => KinerjaLembar.bangunForm++))` — selalu
  /// `true`, jadi di mode rilis seluruh pernyataan hilang.
  static bool catat(void Function() tambah) {
    tambah();
    return true;
  }
}
