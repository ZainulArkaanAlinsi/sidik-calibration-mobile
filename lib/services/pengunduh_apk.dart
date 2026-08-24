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
/// APK-nya ~50 MB dan teknisi mengunduhnya lewat data seluler di lokasi
/// pelanggan. Tanpa angka yang bergerak, unduhan yang lambat tidak bisa
/// dibedakan dari unduhan yang menggantung — dan yang dilakukan orang waktu
/// ragu adalah menekan tombolnya lagi, yang justru memulai unduhan kedua.
///
/// ## Kenapa disimpan di direktori sementara aplikasi
///
/// Bukan folder Download bersama. Dua alasan: berkas di direktori aplikasi
/// tidak butuh izin penyimpanan sama sekali di Android modern, dan sistem
/// membersihkannya sendiri — APK 50 MB per rilis yang menumpuk di folder
/// Download itu sampah yang tidak pernah ada yang membereskan.
abstract class PengunduhApk {
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
  Future<HasilPasang> unduhDanPasang(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
    final File berkas;
    try {
      berkas = await _unduh(url, namaBerkas, onProgres);
    } on UnduhGagal {
      return HasilPasang.gagalUnduh;
    } catch (_) {
      return HasilPasang.gagalUnduh;
    }

    final hasil = await OpenFilex.open(
      berkas.path,
      type: 'application/vnd.android.package-archive',
    );

    return hasil.type == ResultType.done
        ? HasilPasang.pemasangDibuka
        : HasilPasang.ditolakSistem;
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
