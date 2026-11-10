import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/foto_kompres.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

import 'foto_kompres_test.dart' show fotoDerau;

/// Kompresi `citra_warp` di satu-satunya titik unggah foto
/// (`ApiWorksheetScanService.kirim`). Server dijawab 422 supaya hasilnya tak
/// perlu JSON panjang; yang diperiksa adalah BERKAS yang dikirim.
void main() {
  late Uint8List citra; // PNG hasil warp berderau, jauh di atas 500 KB

  setUpAll(() {
    final jpeg = fotoDerau(1100, 1560, seed: 11);
    citra = Uint8List.fromList(img.encodePng(img.decodeJpg(jpeg)!, level: 1));
  });

  ({ApiWorksheetScanService service, List<http.MultipartFile> berkas}) bikin({
    FotoKompres? kompres,
    List<MetrikKompres>? metrik,
  }) {
    final berkas = <http.MultipartFile>[];
    final klien = MockClient.streaming((req, _) async {
      berkas.addAll((req as http.MultipartRequest).files);

      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({'status': 'ditolak_kualitas', 'message': 'x'}),
          ),
        ),
        422,
        headers: {'content-type': 'application/json'},
      );
    });

    return (
      service: ApiWorksheetScanService(
        ApiClient(client: klien, baseUrl: 'http://contoh.test/api'),
        kompres: kompres,
        padaKompresi: metrik?.add,
      ),
      berkas: berkas,
    );
  }

  Future<void> kirim(
    ApiWorksheetScanService s,
    Map<String, dynamic> body,
  ) async {
    try {
      await s.kirim('token', body, citraWarp: citra);
    } on PindaiDitolak {
      // dijawab 422 oleh klien palsu
    }
  }

  test('tanpa pemampat: PNG asli naik apa adanya (perilaku lama)', () async {
    final t = bikin();
    await kirim(t.service, {'template_id': 'ph_meter'});

    expect(t.berkas.single.filename, 'warp.png');
    expect(t.berkas.single.length, citra.length);
  });

  test('formulir ASLI: <= 500 KB, <= 1080x1920, metrik dilaporkan', () async {
    final metrik = <MetrikKompres>[];
    final t = bikin(
      kompres: FotoKompres(mesin: const [PemampatDartMurni()]),
      metrik: metrik,
    );
    await kirim(t.service, {'kertas': 'asli', 'template_id': 'ph_meter'});

    final f = t.berkas.single;
    expect(f.field, 'citra_warp');
    expect(f.filename, 'warp.jpg');
    expect(f.length, lessThanOrEqualTo(500 * 1024));
    expect(f.length, lessThan(citra.length));

    expect(metrik.single.asliByte, citra.length);
    expect(metrik.single.akhirByte, f.length);
    expect(metrik.single.lebarAkhir, lessThanOrEqualTo(1080));
    expect(metrik.single.tinggiAkhir, lessThanOrEqualTo(1920));

    final dekode = img.decodeJpg(await f.finalize().toBytes())!;
    // Rasio sisi terjaga: server memotong formulir asli dengan kotak
    // ternormal x ukuran citra, dan menolak rasio yang melenceng > 2%.
    expect(dekode.width / dekode.height, closeTo(1100 / 1560, 0.01));
  });

  test(
    'lembar CETAK: piksel DIPERTAHANKAN (server memotong dengan koordinat piksel)',
    () async {
      final metrik = <MetrikKompres>[];
      final t = bikin(
        kompres: FotoKompres(mesin: const [PemampatDartMurni()]),
        metrik: metrik,
      );
      // Tanpa `kertas` = lembar cetak bermarker.
      await kirim(t.service, {'template_id': 'ph_meter'});

      expect(metrik.single.lebarAkhir, 1100);
      expect(metrik.single.tinggiAkhir, 1560);
      final dekode = img.decodeJpg(await t.berkas.single.finalize().toBytes())!;
      expect((dekode.width, dekode.height), (1100, 1560));
    },
  );

  test(
    'cetak yang sulit dikompres: mutu turun sampai lantai, piksel TETAP',
    () async {
      final metrik = <MetrikKompres>[];
      final cetak = bikin(
        kompres: FotoKompres(mesin: [_MesinKonstan(300 * 1024 * 3)]),
        metrik: metrik,
      );
      await kirim(cetak.service, {'template_id': 'ph_meter'});
      final asli = bikin(
        kompres: FotoKompres(mesin: [_MesinKonstan(300 * 1024 * 3)]),
        metrik: metrik,
      );
      await kirim(asli.service, {'kertas': 'asli', 'template_id': 'ph_meter'});

      // Cetak: tidak pernah disusutkan walau target tak tercapai.
      expect(metrik[0].capaiTarget, isFalse);
      expect((metrik[0].lebarAkhir, metrik[0].tinggiAkhir), (1100, 1560));
      // Asli: boleh disusutkan (server memotong dengan kotak ternormal).
      expect(metrik[1].lebarAkhir, lessThan(metrik[1].lebarAsli));
    },
  );

  test(
    'kompresi gagal -> yang naik berkas ASLI, kiriman tidak dibatalkan',
    () async {
      final t = bikin(kompres: FotoKompres(mesin: [_MesinRusak()]));
      await kirim(t.service, {'kertas': 'asli'});

      expect(t.berkas.single.filename, 'warp.png');
      expect(t.berkas.single.length, citra.length);
    },
  );

  test(
    'hasil kompresi tidak lebih kecil dari aslinya -> pakai aslinya',
    () async {
      final t = bikin(
        kompres: FotoKompres(mesin: [_MesinBesar(citra.length * 2)]),
      );
      await kirim(t.service, {'kertas': 'asli'});

      expect(t.berkas.single.filename, 'warp.png');
      expect(t.berkas.single.length, citra.length);
    },
  );

  test('tanpa citra: tidak ada lampiran', () async {
    final t = bikin(kompres: FotoKompres(mesin: const [PemampatDartMurni()]));
    try {
      await t.service.kirim('token', {'kertas': 'asli'});
    } on PindaiDitolak {
      // 422
    }

    expect(t.berkas, isEmpty);
  });
}

class _MesinRusak implements PemampatGambar {
  @override
  String get nama => 'rusak';

  @override
  bool dukung(FormatFoto format) => true;

  @override
  Future<Uint8List> kodekan(CitraSiap citra, FormatFoto format, int kualitas) =>
      Future.error(StateError('plugin tidak ada'));
}

class _MesinBesar implements PemampatGambar {
  _MesinBesar(this.byte);

  final int byte;

  @override
  String get nama => 'besar';

  @override
  bool dukung(FormatFoto format) => format == FormatFoto.jpeg;

  @override
  Future<Uint8List> kodekan(
    CitraSiap citra,
    FormatFoto format,
    int kualitas,
  ) async => Uint8List(byte);
}

class _MesinKonstan implements PemampatGambar {
  _MesinKonstan(this.byte);

  final int byte;

  @override
  String get nama => 'konstan';

  @override
  bool dukung(FormatFoto format) => format == FormatFoto.jpeg;

  @override
  Future<Uint8List> kodekan(
    CitraSiap citra,
    FormatFoto format,
    int kualitas,
  ) async => Uint8List(byte);
}
