import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/dokumen_generik_service.dart';

/// Sebab gagal DIBEDAKAN karena tindakan lanjutannya berlawanan: yang "layanan
/// sibuk" nggak boleh nyuruh teknisi foto ulang, dan yang "dimatikan" nggak
/// boleh bikin dia nunggu.
void main() {
  late File foto;

  setUp(() {
    foto = File('${Directory.systemTemp.path}/lembar-uji.jpg')
      ..writeAsBytesSync(List<int>.filled(64, 7));
  });

  tearDown(() {
    if (foto.existsSync()) foto.deleteSync();
  });

  /// [jawab] dikasih BADAN multipart mentahnya, bukan objek request-nya:
  /// `MockClient` sudah memfinalkan request jadi byte sebelum sampai ke sini,
  /// jadi `MultipartRequest.fields` nggak bisa dilihat lagi. Memeriksa bentuk
  /// kawatnya juga lebih jujur — itu yang benar-benar sampai ke server.
  DokumenGenerikService layanan(http.Response Function(String badan) jawab) {
    return DokumenGenerikService(
      ApiClient(
        baseUrl: 'https://uji.test/api',
        client: MockClient((req) async {
          // `latin1` bukan `utf8`: badannya memuat byte gambar mentah yang
          // bukan UTF-8 sah, dan decode utf8 bakal melempar.
          return jawab(latin1.decode(req.bodyBytes, allowInvalid: true));
        }),
      ),
    );
  }

  http.Response ok(Map<String, dynamic> data) => http.Response(
    jsonEncode({'ok': true, 'data': data}),
    200,
    headers: {'content-type': 'application/json'},
  );

  http.Response gagal(int kode, Map<String, dynamic> body) => http.Response(
    jsonEncode(body),
    kode,
    headers: {'content-type': 'application/json'},
  );

  test('lembar asing kebaca jadi skema', () async {
    final s = layanan(
      (_) => ok({
        'dokumen': {'equipment_name': 'Viscometer Rotasi'},
        'bagian': [
          {
            'kunci': 'bagian-0',
            'nama': 'Spindle',
            'field': const [],
            'tabel': const [],
          },
        ],
        'peringatan': const [],
        'ringkasan': {'jumlah_field': 0, 'jumlah_sel': 0, 'perlu_review': 0},
      }),
    );

    final hasil = await s.baca(foto: foto, namaAlat: 'Viscometer');

    expect(hasil.berhasil, isTrue);
    expect(hasil.skema!.dokumen.namaAlat, 'Viscometer Rotasi');
    expect(hasil.skema!.bagian.single.nama, 'Spindle');
  });

  test('jalur ditutup lab -> `dimatikan`, bukan disuruh foto ulang', () async {
    final s = layanan(
      (_) => gagal(503, {
        'ok': false,
        'status': 'dimatikan',
        'pesan': 'Baca dokumen dimatikan di server (`VISION_AKTIF=false`).',
      }),
    );

    final hasil = await s.baca(foto: foto);

    expect(hasil.berhasil, isFalse);
    expect(hasil.gagal, GagalBacaDokumen.dimatikan);
  });

  test(
    'kunci API kosong -> `salahSetup`, urusan admin bukan teknisi',
    () async {
      final s = layanan(
        (_) => gagal(503, {
          'ok': false,
          'status': 'salah_setup',
          'pesan': 'ANTHROPIC_API_KEY belum diisi di server.',
        }),
      );

      expect((await s.baca(foto: foto)).gagal, GagalBacaDokumen.salahSetup);
    },
  );

  test('layanan sibuk dibedakan dari foto yang emang nggak kebaca', () async {
    final sibuk = layanan(
      (_) => gagal(422, {
        'ok': false,
        'status': 'gagal',
        'pesan':
            'Layanan AI lagi sibuk. Tunggu beberapa menit lalu coba lagi — '
            'fotonya nggak perlu diulang.',
      }),
    );

    final buram = layanan(
      (_) => gagal(422, {
        'ok': false,
        'status': 'tak_terbaca',
        'pesan': 'Jawaban AI nggak bisa dibaca sebagai JSON.',
      }),
    );

    expect(
      (await sibuk.baca(foto: foto)).gagal,
      GagalBacaDokumen.layananBermasalah,
    );
    expect((await buram.baca(foto: foto)).gagal, GagalBacaDokumen.takTerbaca);
  });

  test('nama alat dikirim sebagai kolom, dan boleh nggak ada', () async {
    var punyaNama = false;

    final s = layanan((badan) {
      punyaNama = badan.contains('name="nama_alat"');
      return ok(const {
        'dokumen': {},
        'bagian': [],
        'peringatan': [],
        'ringkasan': {},
      });
    });

    await s.baca(foto: foto, namaAlat: 'pH Meter');
    expect(punyaNama, isTrue);

    await s.baca(foto: foto);
    expect(punyaNama, isFalse, reason: 'nama alat itu opsional');

    await s.baca(foto: foto, namaAlat: '');
    expect(punyaNama, isFalse, reason: 'nama kosong jangan ikut dikirim');
  });

  test('bodi tanpa `data` nggak dianggap berhasil', () async {
    final s = layanan(
      (_) => http.Response(
        jsonEncode({'ok': true}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final hasil = await s.baca(foto: foto);

    expect(hasil.berhasil, isFalse);
    expect(hasil.gagal, GagalBacaDokumen.takTerbaca);
  });
}
