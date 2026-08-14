import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  /// Kiriman hasil pindai lembar kerja: bodinya array bersarang + citra.
  ///
  /// `multipart` nggak kenal JSON, jadi bodinya diratakan jadi kolom bertanda
  /// kurung — bentuk yang Laravel rakit balik jadi array yang sama persis, dan
  /// aturan validasinya (`sel.*.kotak.x`) tetap kena.
  group('ratakan bodi buat multipart', () {
    test('array bersarang jadi kolom bertanda kurung', () {
      final hasil = ApiClient.ratakanUntukMultipart({
        'template_id': 'ph_meter',
        'template_versi': 1,
        'qr': {'terbaca': true, 'isi': 'ph_meter|v1'},
        'sel': [
          {
            'tabel_id': 'sebelum_adjustment',
            'kotak': {'x': 413, 'y': 940.5},
          },
        ],
      });

      expect(hasil['template_id'], 'ph_meter');
      expect(hasil['template_versi'], '1');
      expect(hasil['sel[0][tabel_id]'], 'sebelum_adjustment');
      expect(hasil['sel[0][kotak][x]'], '413');
      expect(hasil['sel[0][kotak][y]'], '940.5');
      expect(hasil['qr[isi]'], 'ph_meter|v1');
    });

    test('boolean jadi 1/0, bukan "true"/"false"', () {
      // Aturan `boolean` Laravel nerima `"1"`/`"0"` di semua versi; `"true"`
      // cuma di sebagian. `qr.terbaca` yang ditolak bikin SELURUH lembar
      // ditolak di lapisan bentuk, sebelum satu sel pun dilihat.
      final hasil = ApiClient.ratakanUntukMultipart({
        'qr': {'terbaca': true},
        'geometri': {'grid_tersnap': false},
      });

      expect(hasil['qr[terbaca]'], '1');
      expect(hasil['geometri[grid_tersnap]'], '0');
    });

    test('null DIBUANG, bukan dikirim string "null"', () {
      // Sel yang memang KOSONG di kertasnya nggak boleh berubah jadi sel
      // berisi teks empat huruf.
      final hasil = ApiClient.ratakanUntukMultipart({
        'sel': [
          {'teks_mentah': null, 'field_id': 'pembacaan'},
        ],
      });

      expect(hasil.containsKey('sel[0][teks_mentah]'), isFalse);
      expect(hasil['sel[0][field_id]'], 'pembacaan');
    });
  });

  test('unggah banyak: bodi jadi kolom, citra jadi berkas', () async {
    final client = _ClientPalsu();
    final api = ApiClient(client: client, baseUrl: 'http://contoh.test/api');

    await api.unggahBanyak(
      '/worksheet-scans',
      body: {
        'template_id': 'ph_meter',
        'sel': [
          {'field_id': 'pembacaan', 'teks_mentah': '4,01'},
        ],
      },
      berkas: {
        'citra_warp': (namaBerkas: 'warp.png', isi: Uint8List.fromList([1, 2])),
      },
      token: 'token-abc',
    );

    final request = client.terakhir! as http.MultipartRequest;

    expect(request.fields['template_id'], 'ph_meter');
    expect(request.fields['sel[0][teks_mentah]'], '4,01');
    expect(request.files.single.field, 'citra_warp');
    expect(request.headers['Authorization'], 'Bearer token-abc');
  });
}
