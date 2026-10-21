import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/services/pengunduh_apk.dart';
import 'package:sidik_calibration/services/penyiap_update.dart';

/// Pemanggil kedua `siapkan` selama unduhan latar berjalan ikut menunggu
/// unduhan itu — bukan langsung `false`, yang membuat banner kembali ke
/// "PASANG (68 MB)" padahal berkasnya hampir siap.
class _WifiSelalu implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PengunduhTertahan implements PengunduhApk {
  _PengunduhTertahan(this.dir);

  final Directory dir;
  final tahan = Completer<void>();
  int panggilan = 0;

  @override
  Future<File?> unduh(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
    panggilan++;
    await tahan.future;
    return File('${dir.path}/$namaBerkas')..writeAsBytesSync([1, 2, 3]);
  }

  @override
  Future<HasilPasang> pasang(File berkas) async => HasilPasang.pemasangDibuka;

  @override
  Future<HasilPasang> unduhDanPasang(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async => HasilPasang.pemasangDibuka;
}

VersiAplikasi _rilis(String versi) =>
    VersiAplikasi(versi: versi, urlUnduh: 'https://x/$versi.apk');

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('penyiap_gabung');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test(
    'panggilan kedua versi sama ikut menunggu unduhan yang berjalan',
    () async {
      final pengunduh = _PengunduhTertahan(dir);
      final penyiap = PenyiapUpdateAsli(
        pengunduh: pengunduh,
        konektivitas: _WifiSelalu(),
        direktori: () async => dir,
      );

      final pertama = penyiap.siapkan(_rilis('1.0.60'));
      // Beri kesempatan unduhan pertama benar-benar mulai.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final kedua = penyiap.siapkan(_rilis('1.0.60'));

      var keduaSelesai = false;
      unawaited(kedua.then((_) => keduaSelesai = true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(keduaSelesai, isFalse, reason: 'tidak boleh langsung false');

      pengunduh.tahan.complete();
      expect(await pertama, isTrue);
      expect(await kedua, isTrue);
      expect(pengunduh.panggilan, 1, reason: 'tetap satu unduhan');
    },
  );

  test(
    'versi LAIN selama unduhan berjalan: false, tanpa unduhan kedua',
    () async {
      final pengunduh = _PengunduhTertahan(dir);
      final penyiap = PenyiapUpdateAsli(
        pengunduh: pengunduh,
        konektivitas: _WifiSelalu(),
        direktori: () async => dir,
      );

      final pertama = penyiap.siapkan(_rilis('1.0.60'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await penyiap.siapkan(_rilis('1.0.61')), isFalse);

      pengunduh.tahan.complete();
      expect(await pertama, isTrue);
      expect(pengunduh.panggilan, 1);

      // Sesudah selesai, panggilan baru jalan normal (berkas sudah ada).
      expect(await penyiap.siapkan(_rilis('1.0.60')), isTrue);
      expect(pengunduh.panggilan, 1);
    },
  );
}
