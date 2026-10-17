import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_studio/data/pemilih_berkas.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/data/workbook_service.dart';
import 'package:sidik_studio/inti/lingkungan_studio.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';

import 'pembantu/studio_uji.dart';

const _izin = Izin(
  role: UserRole.superAdmin,
  boleh: {NamaIzin.dataAcuanLihat, NamaIzin.workbookLihat},
);

void main() {
  group('alamat bawaan (K-50-12)', () {
    test('rilis non-dev tanpa define = produksi', () {
      expect(
        alamatBawaanStudio(define: '', rilis: true, env: ''),
        'https://sidik-calibration-api.onrender.com/api',
      );
    });
    test('define menang; dev dan debug tetap bawaan AppConfig', () {
      expect(
        alamatBawaanStudio(define: 'http://x/api', rilis: true, env: ''),
        'http://x/api',
      );
      expect(
        alamatBawaanStudio(define: '', rilis: true, env: 'dev'),
        isNot(alamatApiProduksiStudio),
      );
      expect(
        alamatBawaanStudio(define: '', rilis: false, env: ''),
        isNot(alamatApiProduksiStudio),
      );
    });
  });

  group('parse galat 422 dan hasil', () {
    test('kode dan pesan dikenali toleran', () {
      GalatUnggahMaster g(Map<String, dynamic> b, String m) =>
          GalatUnggahMaster.dari(b, m);
      expect(g({'kode': 'sandi_salah'}, ''), GalatUnggahMaster.sandiSalah);
      expect(g({}, 'Password salah.'), GalatUnggahMaster.sandiSalah);
      expect(g({'kode': 'perlu_sandi'}, ''), GalatUnggahMaster.sandiDiperlukan);
      expect(
        g({'kode': 'format_tidak_dikenal'}, ''),
        GalatUnggahMaster.formatTidakDikenal,
      );
      expect(g({}, 'Alasan wajib.'), GalatUnggahMaster.lain);
    });

    test('hasil diurai toleran (data, data.workbook, kosong)', () {
      expect(
        HasilUnggahMaster.fromJson({
          'data': {'id': 5},
        }).id,
        5,
      );
      expect(
        HasilUnggahMaster.fromJson({
          'data': {
            'workbook': {'id': 6, 'nama': 'A', 'versi': 3},
          },
        }).versi,
        3,
      );
      expect(HasilUnggahMaster.fromJson({}).id, isNull);
    });
  });

  test(
    'ApiWorkbookService mengirim multipart ke /studio/workbook/impor',
    () async {
      HttpOverrides.global = null;
      final dir = await Directory.systemTemp.createTemp('unggah_master');
      addTearDown(() => dir.delete(recursive: true));
      final berkas = File('${dir.path}${Platform.pathSeparator}Master.xlsm')
        ..writeAsBytesSync(utf8.encode('isi-berkas'));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      String? metode;
      String? jalur;
      String? auth;
      String? badan;
      server.listen((req) async {
        metode = req.method;
        jalur = req.uri.path;
        auth = req.headers.value('authorization');
        final bytes = await req.fold<List<int>>([], (a, b) => a..addAll(b));
        badan = latin1.decode(bytes);
        req.response
          ..statusCode = 201
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': {'id': 77, 'nama': 'Master'},
            }),
          );
        await req.response.close();
      });
      final layanan = ApiWorkbookService(
        ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api'),
      );
      final hasil = await layanan.unggahMaster(
        'tkn',
        jalurBerkas: berkas.path,
        alasan: 'Ganti ke master 2027',
        sandi: 'rahasia',
        gantikanId: 12,
      );
      expect(hasil.id, 77);
      expect(metode, 'POST');
      expect(jalur, '/api/studio/workbook/impor');
      expect(auth, 'Bearer tkn');
      expect(badan, contains('name="berkas"'));
      expect(badan, contains('filename="Master.xlsm"'));
      expect(badan, contains('isi-berkas'));
      expect(badan, contains('name="sandi"'));
      expect(badan, contains('name="alasan"'));
      expect(badan, contains('name="gantikan"'));
    },
  );

  group('layar Unggah master', () {
    Future<MockWorkbookService> buka(
      WidgetTester tester, {
      String nama = 'Master Baru.xlsm',
      Object? galat,
    }) async {
      final mock = MockWorkbookService()..galatUnggah = galat;
      await pasangUkuran(tester, const Size(1440, 900));
      await tester.pumpWidget(
        studioUji(
          meja: true,
          token: 'mock-token-1',
          izin: _izin,
          workbook: mock,
          tambahan: [
            pemilihBerkasMasterProvider.overrideWithValue(
              () async => (jalur: '/tmp/$nama', nama: nama),
            ),
          ],
        ),
      );
      await tenang(tester);
      await bukaSeksi(tester, SeksiStudio.workbookAlat);
      await tester.tap(find.byKey(const ValueKey('tombol-unggah-master')));
      await tenang(tester);
      return mock;
    }

    Future<void> isiDanKirim(WidgetTester tester, {String sandi = ''}) async {
      await tester.tap(find.byKey(const ValueKey('unggah-pilih')));
      await tenang(tester);
      if (sandi.isNotEmpty) {
        await tester.enterText(
          find.byKey(const ValueKey('unggah-sandi')),
          sandi,
        );
      }
      await tester.enterText(
        find.byKey(const ValueKey('unggah-alasan')),
        'Master revisi 2027',
      );
      await tester.tap(find.byKey(const ValueKey('unggah-kirim')));
      await tenang(tester);
    }

    String isianSandi(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const ValueKey('unggah-sandi')))
        .controller!
        .text;

    testWidgets('berhasil: kirim berkas, alasan, sandi; daftar disegarkan; '
        'sandi dikosongkan', (tester) async {
      final mock = await buka(tester);
      final daftarAwal = mock.panggilanDaftar;
      await isiDanKirim(tester, sandi: 'rahasia');

      expect(mock.panggilanUnggah, hasLength(1));
      final p = mock.panggilanUnggah.single;
      expect(p.alasan, 'Master revisi 2027');
      expect(p.sandi, 'rahasia');
      expect(p.gantikanId, isNull);
      expect(find.byKey(const ValueKey('unggah-sukses')), findsOneWidget);
      expect(isianSandi(tester), isEmpty);
      expect(mock.panggilanDaftar, greaterThan(daftarAwal));
    });

    testWidgets('alasan kosong tidak mengirim', (tester) async {
      final mock = await buka(tester);
      await tester.tap(find.byKey(const ValueKey('unggah-pilih')));
      await tenang(tester);
      await tester.tap(find.byKey(const ValueKey('unggah-kirim')));
      await tenang(tester);
      expect(mock.panggilanUnggah, isEmpty);
      expect(find.text('Alasan wajib diisi.'), findsOneWidget);
    });

    testWidgets('ekstensi di luar xlsm/xlsx/csv ditolak di klien', (
      tester,
    ) async {
      final mock = await buka(tester, nama: 'Master.pdf');
      await isiDanKirim(tester);
      expect(mock.panggilanUnggah, isEmpty);
      expect(find.byKey(const ValueKey('unggah-galat-berkas')), findsOneWidget);
    });

    testWidgets('422 sandi salah: pesan di isian sandi, sandi dikosongkan', (
      tester,
    ) async {
      await buka(
        tester,
        galat: const ApiException(
          'Sandi berkas salah.',
          status: 422,
          body: {'kode': 'sandi_salah'},
        ),
      );
      await isiDanKirim(tester, sandi: 'salah');
      expect(find.text('Sandi berkas salah.'), findsWidgets);
      expect(isianSandi(tester), isEmpty);
    });

    testWidgets('422 format: pesan di bawah pemilih berkas', (tester) async {
      await buka(
        tester,
        galat: const ApiException(
          'Format tidak dikenal.',
          status: 422,
          body: {'kode': 'format_tidak_dikenal'},
        ),
      );
      await isiDanKirim(tester);
      expect(
        find.text('Server tidak mengenali format berkas ini.'),
        findsOneWidget,
      );
    });
  });
}
