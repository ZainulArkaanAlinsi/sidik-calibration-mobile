import '../models/versi_aplikasi.dart';
import 'pengunduh_apk.dart';
import 'penyiap_update.dart';

/// Satu-satunya jalur "tombol pembaruan ditekan → pemasang Android terbuka".
///
/// Dipakai dua tombol: "Pasang" di `BannerUpdate` dan "Update" di
/// `DialogUpdate`. Dua tombol yang mengerjakan hal yang sama dengan dua
/// salinan logika akan menyimpang diam-diam — satu ikut dibetulkan, satu
/// tidak — dan teknisi mendapat perilaku berbeda tergantung tombol mana yang
/// kebetulan dia tekan.
///
/// Kalau penyiap latar sudah menyelesaikan unduhannya, langsung ke pemasang —
/// tidak ada 68 MB yang perlu ditunggu lagi. Inilah gunanya seluruh mekanisme
/// latar itu: dari ketukan ke layar pemasang, tanpa jeda. Kalau belum, diunduh
/// sekarang dengan progres.
///
/// [onMulaiUnduh] dipanggil tepat sebelum unduhan dimulai dan TIDAK dipanggil
/// kalau berkasnya sudah siap — buat layar yang cuma mau menggambar bilah
/// progres waktu memang ada yang diunduh.
///
/// **Tidak pernah melempar.** `pasang` menembus platform channel dan bisa
/// melempar (mis. `OpenFilex.open`); lemparan apa pun dipulangkan sebagai
/// [HasilPasang.ditolakSistem]. Tanpa ini layar pemanggilnya macet di keadaan
/// "sedang memproses" — banner tertahan di "Mengunduh…" tanpa tombol, dan
/// dialog yang tidak bisa ditutup selama memproses jadi aplikasi yang
/// terkunci. Penangkapnya di sini, bukan di tiap pemanggil, supaya dua tombol
/// itu tidak bisa berbeda perilaku.
Future<HasilPasang> pasangPembaruan(
  VersiAplikasi rilis, {
  required PenyiapUpdate penyiap,
  required PengunduhApk pengunduh,
  void Function()? onMulaiUnduh,
  void Function(double? progres)? onProgres,
}) async {
  try {
    final siap = await penyiap.apkSiap(rilis.versi);
    if (siap != null) return await pengunduh.pasang(siap);

    onMulaiUnduh?.call();

    return await pengunduh.unduhDanPasang(
      rilis.urlUnduh,
      // Nama yang SAMA dengan unduhan latar — `apkSiap` mencari berkas dengan
      // nama ini, jadi unduhan dari tombol pun kepakai ulang kalau pemasangnya
      // dibatalkan lalu dibuka lagi.
      namaBerkas: PenyiapUpdateAsli.namaBerkas(rilis.versi),
      onProgres: onProgres,
    );
  } catch (_) {
    return HasilPasang.ditolakSistem;
  }
}

/// Pesan buat [hasil], atau `null` kalau pemasangnya terbuka.
///
/// Pesannya menyebut LAYAR yang harus dituju, bukan "coba lagi": mencoba
/// ulang tanpa memberi izin selalu berujung sama, dan teknisi yang menekan
/// tombol itu tiga kali akan menyimpulkan aplikasinya rusak.
///
/// [namaTombol] = label tombol yang harus ditekan lagi sesudah izinnya
/// diberikan. Banner menyebut "Pasang", dialog menyebut "Update" — menyuruh
/// menekan tombol yang tidak ada di layar sama saja dengan tidak memberi
/// petunjuk.
String? pesanHasilPasang(HasilPasang hasil, {String namaTombol = 'Pasang'}) {
  return switch (hasil) {
    HasilPasang.pemasangDibuka => null,
    HasilPasang.ditolakSistem =>
      'Android menolak membuka pemasang. Izinkan "Install unknown apps" '
          'buat aplikasi ini di Pengaturan, lalu tekan $namaTombol lagi.',
    HasilPasang.gagalUnduh =>
      'Unduhan gagal. Cek sinyal atau ruang penyimpanan, lalu coba lagi.',
  };
}
