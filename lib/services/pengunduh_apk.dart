import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'pemasang_sesi.dart';

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
  /// **Aturan di atas tetap berlaku utuh.** Yang menyapa teknisi soal
  /// pembaruan cuma `PemasangOtomatis` (sejak 8 Okt 2026 lewat pop-up, bukan
  /// lagi membuka pemasang sendiri), di waktu yang sama sekali lain: waktu
  /// aplikasi baru dibuka dan dashboard jadi layar yang sedang dilihat. Bukan
  /// di sini, dan bukan waktu unduhannya kelar. Selesainya unduhan tidak pernah
  /// jadi alasan memindahkan layar siapa pun.
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
  PengunduhApkAsli({
    http.Client? client,
    PemasangSesi? sesi,
    Future<Directory> Function()? direktori,
    Duration batasSambung = batasSambungBawaan,
    Duration batasDiam = batasDiamBawaan,
  }) : _client = client ?? http.Client(),
       _sesi = sesi ?? PemasangSesiAndroid(),
       _direktori = direktori ?? getTemporaryDirectory,
       _batasSambung = batasSambung,
       _batasDiam = batasDiam;

  /// Paling lama menunggu server MENJAWAB (kepala respons), sebelum satu
  /// byte pun berkasnya datang.
  static const batasSambungBawaan = Duration(seconds: 30);

  /// Paling lama menunggu byte BERIKUTNYA di tengah unduhan.
  ///
  /// Bukan batas total: 68 MB di seluler yang lambat memang bisa makan
  /// belasan menit, dan itu unduhan yang sehat. Yang dipotong cuma unduhan
  /// yang DIAM — sinyal hilang di tengah jalan, dan koneksinya menggantung
  /// tanpa pernah putus. Tanpa batas ini `http` menunggu selamanya, dan dialog
  /// pembaruan yang tidak bisa ditutup selama mengunduh ikut menggantung:
  /// aplikasinya terkunci sampai OS kebetulan memutus soketnya.
  static const batasDiamBawaan = Duration(seconds: 30);

  /// Pembeda nama `.part` di dalam satu proses. Lihat [_unduh].
  static int _urut = 0;

  final http.Client _client;
  final PemasangSesi _sesi;

  /// Direktori tempat APK ditulis. Disuntikkan di test; bawaannya direktori
  /// sementara aplikasi — direktori yang sama yang dibaca `PenyiapUpdateAsli`.
  final Future<Directory> Function() _direktori;
  final Duration _batasSambung;
  final Duration _batasDiam;

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
    // Lewat sesi PackageInstaller DULU. Ketukan "Install" di sini yang
    // mencatat aplikasi ini sebagai pemasangnya sendiri — syarat Android 12+
    // buat rilis berikutnya masuk tanpa ketukan (lihat `PemasangOtomatis`).
    final sesi = await _sesi.pasang(berkas.path, diam: false);
    if (sesi == 'dimulai') return HasilPasang.pemasangDibuka;
    if (sesi == 'izin') return HasilPasang.ditolakSistem;

    // `null` (kanal native tidak ada) atau gagal: jalur lama tetap dicoba,
    // supaya pemutakhiran tidak pernah lebih buruk dari sebelum sesi ada.
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
    final berkas = await unduh(
      url,
      namaBerkas: namaBerkas,
      onProgres: onProgres,
    );
    if (berkas == null) return HasilPasang.gagalUnduh;

    return pasang(berkas);
  }

  /// Unduh ke `<namaBerkas>.<unik>.part`, lalu rename ke [namaBerkas] HANYA
  /// kalau utuh.
  ///
  /// ## Kenapa lewat `.part`
  ///
  /// Dulu unduhan ditulis langsung ke nama akhirnya, sementara
  /// `PenyiapUpdateAsli.apkSiap` menganggap berkas apa pun yang ada dan tidak
  /// kosong sebagai "siap". Dua keadaan biasa menjadikannya jebakan: unduhan
  /// latar yang masih berjalan, dan unduhan yang prosesnya dimatikan Android
  /// di tengah jalan. Keduanya meninggalkan APK setengah jadi di nama yang
  /// benar, tombol "Update sekarang" menyerahkannya ke pemasang, dan Android
  /// menjawab "There was a problem parsing the package" — pesan yang membuat
  /// teknisi mengira rilisnya yang rusak. Sekarang nama akhir cuma lahir dari
  /// rename, dan rename di direktori yang sama itu atomik: berkas di nama itu
  /// selalu utuh atau tidak ada sama sekali.
  ///
  /// ## Kenapa `.part`-nya unik per unduhan
  ///
  /// Unduhan latar (`PenyiapUpdateAsli.siapkan`) dan unduhan dari tombol
  /// (`pasangPembaruan`) memakai nama akhir yang SAMA,
  /// `PenyiapUpdateAsli.namaBerkas(versi)`, di direktori yang sama — dan
  /// keduanya bisa jalan berbarengan: penjaga `_sedangJalan` di penyiap cuma
  /// menjaga panggilan ke penyiap itu sendiri, sedangkan tombol membuat
  /// pengunduh baru. Satu `.part` bersama berarti dua penulis di satu berkas.
  /// Dengan nama unik, masing-masing menulis berkasnya sendiri, dan yang
  /// selesai belakangan cuma mengganti berkas utuh dengan berkas utuh.
  Future<File> _unduh(
    String url,
    String namaBerkas,
    void Function(double? progres)? onProgres,
  ) async {
    final dir = await _direktori();
    final berkas = File('${dir.path}/$namaBerkas');

    // Nama akhir yang sudah ada TIDAK dihapus di sini: sejak lewat `.part`,
    // berkas di nama itu pasti utuh, dan rename di ujung menggantinya secara
    // atomik. Menghapusnya duluan cuma membuka jeda tempat APK utuh milik
    // unduhan lain hilang dari bawah pemasang.
    _bersihkanParsialBasi(dir, namaBerkas);

    final parsial = File(
      '${dir.path}/$namaBerkas.$pid-'
      '${DateTime.now().microsecondsSinceEpoch}-${_urut++}.part',
    );

    // Memutus koneksi yang ditinggalkan — tanpa ini soket yang menggantung
    // tetap terbuka sesudah unduhannya dinyatakan gagal.
    final batal = Completer<void>();
    void hentikan() {
      if (!batal.isCompleted) batal.complete();
    }

    final http.StreamedResponse respons;
    try {
      respons = await _client
          .send(
            http.AbortableRequest(
              'GET',
              Uri.parse(url),
              abortTrigger: batal.future,
            ),
          )
          .timeout(_batasSambung);
    } on TimeoutException {
      hentikan();
      throw UnduhGagal(
        'Server tidak menjawab dalam ${_batasSambung.inSeconds} detik.',
      );
    }

    if (respons.statusCode != 200) {
      hentikan();
      throw UnduhGagal('Server menjawab ${respons.statusCode}.');
    }

    final total = respons.contentLength;
    var terunduh = 0;
    final tulis = parsial.openWrite();

    try {
      // `Stream.timeout` mengukur jeda ANTAR potongan (termasuk sebelum
      // potongan pertama), bukan lama unduhan seluruhnya — lihat [_batasDiam].
      await for (final potongan in respons.stream.timeout(_batasDiam)) {
        tulis.add(potongan);
        terunduh += potongan.length;

        // `total` null waktu server tidak mengirim Content-Length. Progresnya
        // dilaporkan null, BUKAN 0 — layar yang menerima null menampilkan
        // bilah tak tentu, sedangkan 0 terus-menerus terbaca sebagai macet.
        onProgres?.call(total == null || total <= 0 ? null : terunduh / total);
      }
      await tulis.close();
    } catch (e) {
      hentikan();
      await _tutupDiam(tulis);
      await _hapusDiam(parsial);
      throw UnduhGagal(
        e is TimeoutException
            ? 'Unduhan macet: tidak ada data selama '
                  '${_batasDiam.inSeconds} detik.'
            : 'Unduhan terputus: $e',
      );
    }

    // Server yang memutus di tengah tetap menutup stream tanpa melempar, jadi
    // panjang berkas harus diadu sendiri ke Content-Length. Tanpa ini, APK
    // yang kurang beberapa MB diserahkan ke pemasang dan gagalnya muncul
    // sebagai "paket rusak". Nol byte ditolak juga: berkas kosong di nama
    // akhir sama saja dengan APK rusak.
    if (terunduh == 0 || (total != null && total > 0 && terunduh != total)) {
      await _hapusDiam(parsial);
      throw UnduhGagal(
        'Unduhan tidak utuh ($terunduh dari ${total ?? '?'} byte).',
      );
    }

    try {
      return await parsial.rename(berkas.path);
    } catch (e) {
      await _hapusDiam(parsial);
      throw UnduhGagal('Berkas unduhan gagal dipindahkan: $e');
    }
  }

  /// Buang `.part` milik [namaBerkas] yang ditinggal proses yang sudah mati.
  ///
  /// "Basi" = tidak tersentuh lebih dari dua kali [_batasDiam]. Unduhan yang
  /// masih hidup menulis paling lambat tiap [_batasDiam] atau membatalkan
  /// dirinya sendiri (dan menghapus `.part`-nya), jadi `.part` yang lebih lama
  /// dari itu pasti tidak punya penulis lagi. `.part` yang masih segar
  /// dibiarkan — bisa jadi milik unduhan lain yang sedang berjalan.
  void _bersihkanParsialBasi(Directory dir, String namaBerkas) {
    try {
      final batas = DateTime.now().subtract(_batasDiam * 2);
      for (final e in dir.listSync()) {
        if (e is! File) continue;
        final nama = e.uri.pathSegments.last;
        if (!nama.startsWith('$namaBerkas.') || !nama.endsWith('.part')) {
          continue;
        }
        if (e.lastModifiedSync().isBefore(batas)) e.deleteSync();
      }
    } catch (_) {
      // Gagal bersih-bersih tidak boleh menghalangi unduhannya.
    }
  }

  static Future<void> _tutupDiam(IOSink tulis) async {
    try {
      await tulis.close();
    } catch (_) {}
  }

  static Future<void> _hapusDiam(File berkas) async {
    try {
      if (berkas.existsSync()) await berkas.delete();
    } catch (_) {}
  }
}
