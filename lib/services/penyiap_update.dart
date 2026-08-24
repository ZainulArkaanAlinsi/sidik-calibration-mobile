import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/versi_aplikasi.dart';
import 'pengunduh_apk.dart';

/// Menyiapkan pemutakhiran DI LATAR, supaya waktu teknisi memutuskan memasang,
/// tidak ada yang perlu ditunggu.
///
/// ## Kenapa ada, padahal tombol Pasang sudah jalan
///
/// Menekan tombol lalu menunggu 68 MB itu tetap gangguan — cuma pindah tempat.
/// Yang benar-benar tidak mengganggu: berkasnya sudah ada SEBELUM teknisi tahu
/// dia mau memasang, jadi yang tersisa cuma satu ketukan.
///
/// Android tidak pernah mengizinkan pemasangan diam-diam — layar konfirmasi
/// pemasang selalu muncul, dan tidak ada izin yang menghilangkannya. Jadi satu
/// ketukan itu batas terdekat yang bisa dicapai tanpa berpindah ke mekanisme
/// code-push (yang tidak memasang apa pun, tapi juga tidak bisa mengubah kode
/// native).
///
/// ## Kenapa cuma di jaringan tak-berbayar
///
/// Menghabiskan 68 MB kuota teknisi yang sedang di lokasi pelanggan, diam-diam,
/// tanpa dia tahu — itu LEBIH mengganggu daripada banner yang bisa dia tutup.
/// Di jaringan seluler unduhannya tidak jalan sendiri; tombol Pasang tetap ada,
/// jadi keputusannya kembali ke dia lengkap dengan ukurannya.
abstract class PenyiapUpdate {
  /// Berkas APK yang sudah siap pasang buat [versi], atau null kalau belum ada.
  Future<File?> apkSiap(String versi);

  /// Unduh di latar kalau kondisinya pas. **Tidak pernah melempar** — ini
  /// jalan tanpa diminta, jadi kegagalannya tidak boleh sampai ke layar.
  ///
  /// Mengembalikan `true` kalau sesudah ini berkasnya siap.
  Future<bool> siapkan(VersiAplikasi rilis);
}

class PenyiapUpdateAsli implements PenyiapUpdate {
  PenyiapUpdateAsli({
    PengunduhApk? pengunduh,
    Connectivity? konektivitas,
  }) : _pengunduh = pengunduh ?? PengunduhApkAsli(),
       _konektivitas = konektivitas ?? Connectivity();

  final PengunduhApk _pengunduh;
  final Connectivity _konektivitas;

  /// Menjaga dua pemanggilan berbarengan tidak mengunduh dua kali. Provider
  /// bisa dibaca ulang tiap layar dibuka, dan tanpa penjaga ini dua unduhan
  /// 68 MB jalan bersamaan ke berkas yang sama.
  bool _sedangJalan = false;

  static String namaBerkas(String versi) => 'sidik-kalibrasi-$versi.apk';

  @override
  Future<File?> apkSiap(String versi) async {
    try {
      final dir = await getTemporaryDirectory();
      final berkas = File('${dir.path}/${namaBerkas(versi)}');

      return berkas.existsSync() && await berkas.length() > 0 ? berkas : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> siapkan(VersiAplikasi rilis) async {
    if (_sedangJalan) return false;

    try {
      if (await apkSiap(rilis.versi) != null) return true;

      if (!await _tanpaKuota()) return false;

      _sedangJalan = true;
      await _bersihkanVersiLain(rilis.versi);

      final hasil = await _pengunduh.unduh(
        rilis.urlUnduh,
        namaBerkas: namaBerkas(rilis.versi),
      );

      return hasil != null;
    } catch (_) {
      // Unduhan latar yang gagal itu keadaan yang sah: sinyal putus,
      // penyimpanan penuh, server ngadat. Teknisi tidak perlu tahu — tombol
      // Pasang manual tetap ada kalau dia memang mau sekarang.
      return false;
    } finally {
      _sedangJalan = false;
    }
  }

  Future<bool> _tanpaKuota() async {
    try {
      final hasil = await _konektivitas.checkConnectivity();

      return hasil.contains(ConnectivityResult.wifi) ||
          hasil.contains(ConnectivityResult.ethernet);
    } catch (_) {
      // Tidak bisa memastikan jaringannya apa = JANGAN unduh. Menebak "mungkin
      // WiFi" lalu salah berarti menghabiskan kuota orang tanpa izin, dan itu
      // kesalahan yang tidak bisa ditarik kembali.
      return false;
    }
  }

  /// Buang APK versi lain yang masih menumpuk.
  ///
  /// Tanpa ini, tiap rilis meninggalkan 68 MB di penyimpanan. Direktori
  /// sementara memang dibersihkan sistem, tapi entah kapan — dan HP teknisi
  /// yang penyimpanannya tinggal sedikit justru yang paling butuh ruangnya.
  Future<void> _bersihkanVersiLain(String versiSekarang) async {
    try {
      final dir = await getTemporaryDirectory();
      final simpan = namaBerkas(versiSekarang);

      for (final e in dir.listSync()) {
        if (e is! File) continue;
        final nama = e.path.split('/').last;
        if (nama.startsWith('sidik-kalibrasi-') &&
            nama.endsWith('.apk') &&
            nama != simpan) {
          await e.delete();
        }
      }
    } catch (_) {
      // Gagal bersih-bersih tidak boleh menghalangi unduhannya.
    }
  }
}
