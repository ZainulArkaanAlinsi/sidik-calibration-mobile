import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Hasil akhir usaha memasang pemutakhiran.
enum HasilPasang {
  /// Pemasang Android terbuka. Yang menekan "Install" tetap penggunanya —
  /// aplikasi ini tidak pernah tahu dia jadi memasang atau membatalkan.
  pemasangDibuka,

  /// Android menolak membuka pemasang. Hampir selalu karena izin
  /// "Install unknown apps" belum diberikan buat aplikasi ini — layar itu
  /// yang harus dituju pengguna, bukan mencoba ulang.
  ditolakSistem,

  /// Berkasnya gagal diunduh: sinyal putus, server tidak menjawab, atau
  /// penyimpanan penuh.
  gagalUnduh,
}

class UnduhGagal implements Exception {
  const UnduhGagal(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

/// Mengunduh APK pemutakhiran lalu menyerahkannya ke pemasang Android.
///
/// ## Kenapa progres wajib ada, bukan pemanis
///
/// APK-nya ~68 MB (diukur dari rilis v1.0.37, bukan tebakan — komentar lama di
/// workflow menyebut ~50 MB dan itu sudah tidak akurat) dan teknisi
/// mengunduhnya lewat data seluler di lokasi
/// pelanggan. Tanpa angka yang bergerak, unduhan yang lambat tidak bisa
/// dibedakan dari unduhan yang menggantung — dan yang dilakukan orang waktu
/// ragu adalah menekan tombolnya lagi, yang justru memulai unduhan kedua.
///
/// ## Kenapa disimpan di direktori sementara aplikasi
///
/// Bukan folder Download bersama. Dua alasan: berkas di direktori aplikasi
/// tidak butuh izin penyimpanan sama sekali di Android modern, dan sistem
/// membersihkannya sendiri — APK 68 MB per rilis yang menumpuk di folder
/// Download itu sampah yang tidak pernah ada yang membereskan.
abstract class PengunduhApk {
  /// Unduh saja, tanpa memasang. `null` = gagal.
  ///
  /// Dipisah dari [unduhDanPasang] supaya penyiap latar bisa memakainya:
  /// yang diunduh di latar TIDAK boleh langsung membuka pemasang — teknisi
  /// yang tiba-tiba dilempar ke layar pemasang di tengah mengisi lembar kerja
  /// akan kehilangan konteks, dan itu persis gangguan yang mau dihindari.
  ///
  /// **Sejak 4 Sep 2026 pemasangnya memang bisa terbuka sendiri — dan aturan
  /// di atas tetap berlaku utuh.** Yang membukanya `PemasangOtomatis`, di
  /// waktu yang sama sekali lain: waktu aplikasi baru dibuka dan dashboard
  /// jadi layar yang sedang dilihat, buat berkas yang unduhannya SUDAH
  /// selesai entah kapan sebelumnya. Bukan di sini, dan bukan waktu
  /// unduhannya kelar. Selesainya unduhan tidak pernah jadi alasan
  /// memindahkan layar siapa pun.
  Future<File?> unduh(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  });

  /// Serahkan berkas yang SUDAH ada ke pemasang Android.
  Future<HasilPasang> pasang(File berkas);

  /// [onProgres] dipanggil dengan 0..1, atau `null` kalau server tidak
  /// mengirim `Content-Length` (panjang total tidak diketahui).
  Future<HasilPasang> unduhDanPasang(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  });
}

class PengunduhApkAsli implements PengunduhApk {
  PengunduhApkAsli({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<File?> unduh(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
    try {
      return await _unduh(url, namaBerkas, onProgres);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<HasilPasang> pasang(File berkas) async {
    final hasil = await OpenFilex.open(
      berkas.path,
      type: 'application/vnd.android.package-archive',
    );

    return hasil.type == ResultType.done
        ? HasilPasang.pemasangDibuka
        : HasilPasang.ditolakSistem;
  }

  @override
  Future<HasilPasang> unduhDanPasang(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
    final berkas = await unduh(url, namaBerkas: namaBerkas, onProgres: onProgres);
    if (berkas == null) return HasilPasang.gagalUnduh;

    return pasang(berkas);
  }

  Future<File> _unduh(
    String url,
    String namaBerkas,
    void Function(double? progres)? onProgres,
  ) async {
    final dir = await getTemporaryDirectory();
    final berkas = File('${dir.path}/$namaBerkas');

    // Sisa unduhan sebelumnya yang gagal di tengah TIDAK boleh dipakai ulang:
    // APK setengah jadi tetap punya nama yang benar, dan pemasang Android
    // menolaknya dengan pesan "There was a problem parsing the package" —
    // pesan yang membuat teknisi mengira rilisnya yang rusak.
    if (berkas.existsSync()) {
      await berkas.delete();
    }

    final permintaan = http.Request('GET', Uri.parse(url));
    final respons = await _client.send(permintaan);

    if (respons.statusCode != 200) {
      throw UnduhGagal('Server menjawab ${respons.statusCode}.');
    }

    final total = respons.contentLength;
    var terunduh = 0;
    final tulis = berkas.openWrite();

    try {
      await for (final potongan in respons.stream) {
        tulis.add(potongan);
        terunduh += potongan.length;

        // `total` null waktu server tidak mengirim Content-Length. Progresnya
        // dilaporkan null, BUKAN 0 — layar yang menerima null menampilkan
        // bilah tak tentu, sedangkan 0 terus-menerus terbaca sebagai macet.
        onProgres?.call(total == null || total <= 0 ? null : terunduh / total);
      }
    } catch (e) {
      await tulis.close();
      if (berkas.existsSync()) await berkas.delete();
      throw UnduhGagal('Unduhan terputus: $e');
    }

    await tulis.close();

    // Server yang memutus di tengah tetap menutup stream tanpa melempar, jadi
    // panjang berkas harus diadu sendiri ke Content-Length. Tanpa ini, APK
    // yang kurang beberapa MB diserahkan ke pemasang dan gagalnya muncul
    // sebagai "paket rusak".
    if (total != null && total > 0 && terunduh != total) {
      if (berkas.existsSync()) await berkas.delete();
      throw UnduhGagal('Unduhan tidak utuh ($terunduh dari $total byte).');
    }

    return berkas;
  }
}
