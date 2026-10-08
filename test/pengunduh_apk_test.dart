import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/services/pemasang_sesi.dart';
import 'package:sidik_calibration/services/pengunduh_apk.dart';
import 'package:sidik_calibration/services/penyiap_update.dart';

/// Pengunduh APK sungguhan (`PengunduhApkAsli`) — yang dijaga di sini dua hal
/// yang dua-duanya gagal tanpa error dan berujung di depan teknisi:
///
///   - unduhan yang DIAM di tengah jalan tidak boleh menunggu selamanya —
///     dialog pembaruan tidak bisa ditutup selama mengunduh, jadi unduhan
///     yang menggantung = aplikasi terkunci;
///   - APK setengah jadi tidak boleh pernah ada di nama akhirnya — `apkSiap`
///     menganggap berkas apa pun di nama itu siap, dan pemasang Android
///     menolak paket rusak dengan pesan yang membuat rilisnya tampak rusak.
const _versi = '1.0.60';
const _url = 'https://github.com/x/y/releases/download/v1.0.60/app.apk';

class _SesiPalsu implements PemasangSesi {
  final dipasang = <String>[];

  @override
  Future<bool> bisaTanpaKetukan() async => false;

  @override
  Future<String?> pasang(String jalur, {required bool diam}) async {
    dipasang.add(jalur);

    return 'dimulai';
  }
}

class _WifiSelalu implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pengunduh yang "berhasil" tanpa jaringan — buat menguji penyiap saja.
class _PengunduhInstan implements PengunduhApk {
  _PengunduhInstan(this.dir);

  final Directory dir;

  @override
  Future<File?> unduh(
    String url, {
    required String namaBerkas,
    void Function(double? progres)? onProgres,
  }) async {
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

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pengunduh_apk_test_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final namaAkhir = PenyiapUpdateAsli.namaBerkas(_versi);

  List<String> isiDir() =>
      dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();

  /// Server palsu yang menyajikan isi [aliran] dengan Content-Length [total].
  http.Client server(Stream<List<int>> aliran, {int? total}) {
    return MockClient.streaming(
      (request, body) async =>
          http.StreamedResponse(aliran, 200, contentLength: total),
    );
  }

  PengunduhApkAsli pengunduh(
    http.Client client, {
    _SesiPalsu? sesi,
    Duration batasSambung = PengunduhApkAsli.batasSambungBawaan,
    Duration batasDiam = PengunduhApkAsli.batasDiamBawaan,
  }) {
    return PengunduhApkAsli(
      client: client,
      sesi: sesi ?? _SesiPalsu(),
      direktori: () async => dir,
      batasSambung: batasSambung,
      batasDiam: batasDiam,
    );
  }

  Future<void> tungguSampai(bool Function() syarat) async {
    for (var i = 0; i < 200 && !syarat(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(syarat(), isTrue, reason: 'keadaan yang ditunggu tidak tercapai');
  }

  group('unduhan yang macet', () {
    test('tidak ada byte baru melewati batas diam: gagalUnduh, tidak '
        'meninggalkan berkas, pemasang tidak dibuka', () async {
      // Sinyal hilang di tengah jalan: 10 byte datang, sisanya tidak pernah,
      // dan koneksinya tidak pernah putus.
      final aliran = StreamController<List<int>>();
      addTearDown(aliran.close);
      aliran.add(List<int>.filled(10, 7));
      final sesi = _SesiPalsu();

      final hasil = await pengunduh(
        server(aliran.stream, total: 100),
        sesi: sesi,
        batasDiam: const Duration(milliseconds: 100),
      ).unduhDanPasang(_url, namaBerkas: namaAkhir);

      expect(hasil, HasilPasang.gagalUnduh);
      expect(isiDir(), isEmpty);
      expect(sesi.dipasang, isEmpty);
    });

    test(
      'server tidak menjawab sama sekali: gagalUnduh lewat batas sambung',
      () async {
        final client = MockClient.streaming(
          (request, body) => Completer<http.StreamedResponse>().future,
        );

        final hasil = await pengunduh(
          client,
          batasSambung: const Duration(milliseconds: 100),
        ).unduhDanPasang(_url, namaBerkas: namaAkhir);

        expect(hasil, HasilPasang.gagalUnduh);
        expect(isiDir(), isEmpty);
      },
    );

    test('unduhan LAMBAT tapi terus bergerak tidak dipotong', () async {
      // Batasnya jeda antar potongan, bukan lama total — 68 MB di seluler
      // yang pelan memang makan waktu, dan itu unduhan yang sehat.
      Stream<List<int>> pelan() async* {
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
          yield [i];
        }
      }

      final berkas = await pengunduh(
        server(pelan(), total: 5),
        batasDiam: const Duration(milliseconds: 150),
      ).unduh(_url, namaBerkas: namaAkhir);

      expect(berkas, isNotNull);
      expect(berkas!.readAsBytesSync(), [0, 1, 2, 3, 4]);
    });
  });

  group('APK setengah jadi tidak pernah dianggap siap', () {
    test('selama mengunduh cuma ada .part; apkSiap null. Sesudah utuh, '
        'di-rename ke nama akhir', () async {
      final aliran = StreamController<List<int>>();
      final penyiap = PenyiapUpdateAsli(
        pengunduh: _PengunduhInstan(dir),
        direktori: () async => dir,
      );

      final jalan = pengunduh(
        server(aliran.stream, total: 20),
      ).unduh(_url, namaBerkas: namaAkhir);

      aliran.add(List<int>.filled(10, 1));
      await tungguSampai(() => isiDir().any((n) => n.endsWith('.part')));

      // Unduhan masih di tengah jalan — persis keadaan waktu teknisi menekan
      // "Update sekarang" saat unduhan latar belum selesai.
      expect(File('${dir.path}/$namaAkhir').existsSync(), isFalse);
      expect(await penyiap.apkSiap(_versi), isNull);
      expect(isiDir().single, startsWith('$namaAkhir.'));

      aliran.add(List<int>.filled(10, 2));
      await aliran.close();
      final berkas = await jalan;

      expect(berkas?.path, endsWith(namaAkhir));
      expect(isiDir(), [namaAkhir]);
      expect(berkas!.lengthSync(), 20);
      expect((await penyiap.apkSiap(_versi))?.lengthSync(), 20);
    });

    test(
      '.part sisa proses yang dimatikan: tidak pernah dianggap siap',
      () async {
        // Android mematikan proses di tengah unduhan latar — tidak ada kode
        // yang sempat menghapus apa pun.
        File('${dir.path}/$namaAkhir.999-1-0.part').writeAsBytesSync([1, 2, 3]);
        final penyiap = PenyiapUpdateAsli(
          pengunduh: _PengunduhInstan(dir),
          direktori: () async => dir,
        );

        expect(await penyiap.apkSiap(_versi), isNull);
      },
    );

    test(
      'Content-Length tidak terpenuhi: gagal, tidak ada berkas tersisa',
      () async {
        // Server memutus di tengah tapi menutup stream dengan rapi.
        final berkas = await pengunduh(
          server(Stream.value(List<int>.filled(10, 1)), total: 20),
        ).unduh(_url, namaBerkas: namaAkhir);

        expect(berkas, isNull);
        expect(isiDir(), isEmpty);
      },
    );

    test('dua unduhan bernama sama berbarengan tidak saling merusak', () async {
      // Unduhan latar penyiap dan unduhan dari tombol memakai nama akhir yang
      // sama, dan penjaga `_sedangJalan` penyiap tidak menjangkau pengunduh
      // milik tombol.
      final a = StreamController<List<int>>();
      final b = StreamController<List<int>>();

      final jalanA = pengunduh(
        server(a.stream, total: 6),
      ).unduh(_url, namaBerkas: namaAkhir);
      final jalanB = pengunduh(
        server(b.stream, total: 6),
      ).unduh(_url, namaBerkas: namaAkhir);

      a.add([1, 2, 3]);
      b.add([1, 2, 3]);
      await tungguSampai(
        () => isiDir().where((n) => n.endsWith('.part')).length == 2,
      );
      a.add([4, 5, 6]);
      b.add([4, 5, 6]);
      await a.close();
      await b.close();

      // Dua-duanya ditunggu DULU baru dibaca. Membaca hasil A selagi B masih
      // me-rename ke nama yang sama ditolak Windows (sharing violation) —
      // keadaan yang tidak ada di Android, tempat rename mengganti entri
      // direktori dan pembaca lama tetap memegang berkas lamanya.
      final hasil = await Future.wait([jalanA, jalanB]);

      expect(hasil, everyElement(isNotNull));
      expect(File('${dir.path}/$namaAkhir').readAsBytesSync(), [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      expect(isiDir(), [namaAkhir]);
    });

    test(
      '.part basi dibuang di unduhan berikutnya; .part segar dibiarkan',
      () async {
        final basi = File('${dir.path}/$namaAkhir.999-1-0.part')
          ..writeAsBytesSync([1])
          ..setLastModifiedSync(
            DateTime.now().subtract(const Duration(hours: 1)),
          );
        // Bisa jadi milik unduhan lain yang sedang berjalan.
        final segar = File('${dir.path}/$namaAkhir.999-2-0.part')
          ..writeAsBytesSync([2]);

        final berkas = await pengunduh(
          server(Stream.value([1, 2, 3]), total: 3),
        ).unduh(_url, namaBerkas: namaAkhir);

        expect(berkas, isNotNull);
        expect(basi.existsSync(), isFalse);
        expect(segar.existsSync(), isTrue);
      },
    );

    test('penyiap membuang APK dan .part versi lain, tapi tidak menyentuh '
        '.part versi sekarang', () async {
      for (final nama in [
        'sidik-kalibrasi-1.0.58.apk',
        'sidik-kalibrasi-1.0.59.apk.999-1-0.part',
        '$namaAkhir.999-3-0.part',
        'bukan-milik-kita.part',
      ]) {
        File('${dir.path}/$nama').writeAsBytesSync([1]);
      }

      final penyiap = PenyiapUpdateAsli(
        pengunduh: _PengunduhInstan(dir),
        konektivitas: _WifiSelalu(),
        direktori: () async => dir,
      );

      final siap = await penyiap.siapkan(
        const VersiAplikasi(versi: _versi, urlUnduh: _url),
      );

      expect(siap, isTrue);
      expect(isiDir(), [
        'bukan-milik-kita.part',
        namaAkhir,
        '$namaAkhir.999-3-0.part',
      ]);
    });
  });
}
