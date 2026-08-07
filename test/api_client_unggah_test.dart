import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';

/// Client palsu yang nyatet request yang masuk & bisa disuruh nunda jawabannya.
///
/// Dipakai buat nguji jalur UNGGAH, yang dulu nggak bisa diuji sama sekali:
/// `MultipartRequest.send()` bikin `http.Client()` sendiri di dalam, jadi client
/// yang disuntik ke [ApiClient] nggak pernah kena.
class _ClientPalsu extends http.BaseClient {
  _ClientPalsu({this.jeda = Duration.zero});

  final Duration jeda;

  static const body = '{"data":{"ok":true}}';

  http.BaseRequest? terakhir;
  int jumlahPanggilan = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    terakhir = request;
    jumlahPanggilan++;
    // Body-nya dibaca duluan biar `fields`/`files` beneran ke-encode — sama
    // kayak yang kejadian waktu request-nya dikirim beneran.
    await request.finalize().toBytes();
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  late Directory dir;
  late File foto;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sidik-unggah');
    foto = File('${dir.path}/tabel.png')..writeAsBytesSync([1, 2, 3, 4]);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('unggah lewat client yang disuntik, bukan client baru bikinan http', () async {
    final client = _ClientPalsu();
    final api = ApiClient(client: client, baseUrl: 'http://contoh.test/api');

    final hasil = await api.unggahFile(
      '/raw-measurements/extract-from-photo',
      field: 'foto',
      filePath: foto.path,
      fields: const {'jumlah_titik': '3'},
      token: 'token-abc',
    );

    // Kalau ini gagal, artinya unggahannya lewat client lain lagi — dan jalur
    // itu nggak keuji apa pun: unggah foto tabel & Import Excel dua-duanya
    // lewat sini.
    expect(client.jumlahPanggilan, 1);
    expect(hasil['data'], isNotNull);

    final req = client.terakhir! as http.MultipartRequest;
    expect(req.method, 'POST');
    expect(
      req.url.toString(),
      'http://contoh.test/api/raw-measurements/extract-from-photo',
    );
    expect(req.headers['Authorization'], 'Bearer token-abc');
    // Content-Type WAJIB dibiarin `http` yang nyusun (ada boundary-nya).
    expect(req.headers['Content-Type'], startsWith('multipart/form-data'));
    expect(req.fields['jumlah_titik'], '3');
    expect(req.files.single.field, 'foto');
  });

  test('batas waktu unggah yang diminta pemanggil beneran dipakai', () async {
    // Regresi: batas waktu dulu dipasang DI DALAM closure, sementara `_kirim`
    // membungkus closure-nya lagi dengan batas bawaan 20 detik — jadi yang
    // menang selalu 20 detik, dan unggahan besar di sinyal lapangan mati
    // duluan sebagai "Server nggak nyaut" walaupun batasnya disetel 60 detik.
    //
    // Yang diuji di sini: batas yang dioper pemanggil (300 ms) yang berlaku,
    // bukan batas bawaan. Kalau `timeout` nggak nyampe ke `_kirim`, unggahan
    // ini bakal nunggu 2 detik penuh, bukan nyerah di 300 ms.
    final client = _ClientPalsu(jeda: const Duration(seconds: 2));
    final api = ApiClient(client: client, baseUrl: 'http://contoh.test/api');

    final jam = Stopwatch()..start();

    await expectLater(
      api.unggahFile(
        '/import/excel',
        field: 'file',
        filePath: foto.path,
        token: 'token-abc',
        timeout: const Duration(milliseconds: 300),
      ),
      throwsA(isA<AuthException>()),
    );

    jam.stop();
    expect(
      jam.elapsed,
      lessThan(const Duration(seconds: 2)),
      reason: 'nyerahnya harus di batas yang diminta, bukan nunggu server',
    );
  });
}
