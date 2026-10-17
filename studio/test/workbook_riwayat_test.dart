import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_studio/data/simulasi_provider.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/data/workbook_provider.dart';
import 'package:sidik_studio/data/workbook_service.dart';
import 'package:sidik_studio/inti/sesi_studio.dart';
import 'package:sidik_studio/layar/seksi_studio.dart';
import 'package:sidik_studio/layar/workbook/daftar_workbook_screen.dart';
import 'package:sidik_studio/layar/workbook/riwayat_workbook_screen.dart';
import 'package:sidik_studio/layar/workbook/workbook_screen.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

import 'pembantu/studio_uji.dart';

/// Satu master aktif per jenis (K-49-13, keputusan pemilik 15 Okt 2026).
///
/// Bentuk JSON = `docs/kontrak-api.md` §16 repo API ("Satu master aktif per
/// jenis", tabel field jenis, `GET …/{workbook}/riwayat`, 404 arsip di semua
/// rute termasuk `/hitung`) + tweak orkestrator 15 Okt: riwayat = master
/// aktif dulu lalu riwayat; `versi` = URUTAN IMPOR (riwayat bisa bernomor
/// lebih besar dari master aktif) — aktif/lama hanya dari `status` /
/// `digantikan_oleh_id`, tidak diurut ulang klien.
void main() {
  group('kontrak (HTTP loopback)', () {
    late HttpServer server;
    late List<Uri> masuk;
    late Map<String, Object?> jawaban;
    late ApiWorkbookService layanan;

    setUp(() async {
      HttpOverrides.global = null;
      masuk = [];
      jawaban = {};
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        await req.drain<void>();
        masuk.add(req.uri);
        final badan = jawaban[req.uri.path.replaceFirst('/api', '')];
        req.response
          ..statusCode = badan == null ? 404 : 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(badan ?? {'message': 'Not Found'}));
        await req.response.close();
      });
      layanan = ApiWorkbookService(
        ApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api'),
      );
    });

    tearDown(() => server.close(force: true));

    test('daftar: field jenis terbaca (contoh kontrak §16 PERSIS)', () async {
      jawaban['/studio/workbook'] = {
        'data': [
          {
            'id': 14,
            'nama': 'Master_Olah_Data_Micrometer_0-25mm',
            'kode_profil': 'micrometer',
            'keluarga': null,
            'sumber': 'csv',
            'sha256': '3f0c',
            'ukuran': 48213,
            'jumlah_lembar': 8,
            'berkas_asli_tersimpan': false,
            'berkas_asli_terenkripsi': null,
            'ada_versi_xlsm': true,
            'versi_xlsm_id': 61,
            'kunci_jenis': 'micrometer:micrometer-0-25mm',
            'aktif': true,
            'status': 'aktif',
            'versi': 2,
            'digantikan_oleh_id': null,
            'jumlah_riwayat': 1,
            'diimpor_pada': '2026-10-13T08:12:30+00:00',
          },
        ],
      };
      final [w] = await layanan.daftar('tkn');
      expect(w.kunciJenis, 'micrometer:micrometer-0-25mm');
      expect(w.aktif, isTrue);
      expect(w.status, StatusWorkbook.aktif);
      expect(w.versi, 2);
      expect(w.digantikanOlehId, isNull);
      expect(w.jumlahRiwayat, 1);
      expect(w.riwayat, isFalse);
    });

    test('server lama (tanpa satu pun field jenis) = master biasa, tanpa '
        'riwayat', () {
      final w = WorkbookRingkas.fromJson({
        'id': 7,
        'nama': 'Master Olah Data Micrometer 0-25mm',
        'sumber': 'xlsm',
      });
      expect(w.kunciJenis, isNull);
      expect(w.aktif, isNull);
      expect(w.status, StatusWorkbook.tidakDiketahui);
      expect(w.versi, isNull);
      expect(w.digantikanOlehId, isNull);
      expect(w.jumlahRiwayat, 0);
      expect(w.riwayat, isFalse);
    });

    test('toleran: tipe salah dibaca "tidak diketahui", bukan ditebak; '
        'riwayat dari status/digantikan_oleh_id, TIDAK dari nomor versi', () {
      WorkbookRingkas wb(Map<String, dynamic> j) => WorkbookRingkas.fromJson({
        'id': 1,
        'nama': 'x',
        'sumber': 'xlsm',
        ...j,
      });

      expect(wb({'versi': '3'}).versi, 3);
      expect(wb({'versi': 0}).versi, isNull);
      expect(wb({'versi': 'baru'}).versi, isNull);
      expect(wb({'jumlah_riwayat': -2}).jumlahRiwayat, 0);
      expect(wb({'jumlah_riwayat': 'dua'}).jumlahRiwayat, 0);
      expect(wb({'aktif': 'ya'}).aktif, isNull);
      expect(wb({'digantikan_oleh_id': 0}).digantikanOlehId, isNull);

      // `status` menang.
      expect(wb({'status': 'riwayat', 'aktif': true}).riwayat, isTrue);
      expect(
        wb({'status': 'aktif', 'versi': 1, 'jumlah_riwayat': 3}).riwayat,
        isFalse,
      );
      // Status tak dikenal: dari penunjuk pengganti / aktif:false.
      expect(wb({'status': 'lain', 'digantikan_oleh_id': 9}).riwayat, isTrue);
      expect(wb({'aktif': false}).riwayat, isTrue);
      expect(wb({'status': 'lain', 'aktif': true}).riwayat, isFalse);
      // Nomor impor besar tidak menjadikannya aktif.
      expect(
        wb({'status': 'riwayat', 'versi': 9, 'digantikan_oleh_id': 2}).riwayat,
        isTrue,
      );
    });

    test(
      'GET …/riwayat: urutan server dipertahankan (aktif dulu, walau '
      'riwayat bernomor impor lebih besar); data = larik + kunci_jenis',
      () async {
        jawaban['/studio/workbook/139/riwayat'] = {
          'data': [
            {
              'id': 139,
              'nama': '1. 1 Anak Timbangan F1',
              'sumber': 'xlsm',
              'status': 'aktif',
              'aktif': true,
              'versi': 2,
              'digantikan_oleh_id': null,
              'jumlah_riwayat': 2,
            },
            // Admin mengaktifkan ulang impor #2: impor #3 jadi riwayat.
            {
              'id': 150,
              'nama': '1. 1 Anak Timbangan F1 (rev)',
              'sumber': 'xlsm',
              'status': 'riwayat',
              'aktif': false,
              'versi': 3,
              'digantikan_oleh_id': 139,
              'jumlah_riwayat': 2,
            },
            {
              'id': 102,
              'nama': '1__1_Anak_Timbangan_F1',
              'sumber': 'csv',
              'status': 'riwayat',
              'aktif': false,
              'versi': 1,
              'digantikan_oleh_id': 139,
              'jumlah_riwayat': 2,
            },
            'bukan objek',
          ],
          'kunci_jenis':
              'anak_timbangan:anak-timbangan-f1-1mg-500-g-202501022-imp',
        };
        final r = await layanan.riwayat('tkn', 139);
        expect(masuk.single.path, '/api/studio/workbook/139/riwayat');
        expect(
          r.kunciJenis,
          'anak_timbangan:anak-timbangan-f1-1mg-500-g-202501022-imp',
        );
        expect(r.versi.map((v) => v.id), [139, 150, 102]);
        expect(r.aktif.map((v) => v.id), [139]);
        expect(r.riwayat.map((v) => v.id), [150, 102]);
        expect(r.riwayat.first.digantikanOlehId, 139);
      },
    );

    test('GET …/riwayat 404 (arsip / lab lain / server lama) → ApiException '
        'apa adanya', () {
      expect(
        layanan.riwayat('tkn', 5),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });
  });

  group('mock = server K-49-13', () {
    test(
      'daftar hanya master aktif; riwayat = aktif lalu riwayat; arsip 404 '
      'di semua rute & hilang dari daftar; server lama tanpa rute riwayat',
      () async {
        final mock = MockWorkbookService();
        expect((await mock.daftar('t')).map((w) => w.id), [
          MockWorkbookService.idMicrometer,
          MockWorkbookService.idHeightGauge,
        ]);

        final r = await mock.riwayat('t', MockWorkbookService.idMicrometerCsv);
        expect(r.kunciJenis, 'dimensi:micrometer-0-25mm');
        expect(r.versi.map((v) => (v.id, v.versi, v.riwayat)), [
          (MockWorkbookService.idMicrometer, 2, false),
          (MockWorkbookService.idMicrometerCsv, 1, true),
        ]);
        // Detail riwayat tetap 200, berstatus riwayat.
        final csv = await mock.detail('t', MockWorkbookService.idMicrometerCsv);
        expect(csv.meta.riwayat, isTrue);
        expect(csv.meta.digantikanOlehId, MockWorkbookService.idMicrometer);

        mock.diarsipkan.add(MockWorkbookService.idMicrometer);
        final tidakAda = throwsA(
          isA<ApiException>().having((e) => e.status, 'status', 404),
        );
        expect(mock.detail('t', MockWorkbookService.idMicrometer), tidakAda);
        expect(mock.riwayat('t', MockWorkbookService.idMicrometer), tidakAda);
        expect(
          mock.hitung(
            't',
            workbookId: MockWorkbookService.idMicrometer,
            edit: [],
          ),
          tidakAda,
        );
        expect(
          mock.sel(
            't',
            workbookId: MockWorkbookService.idMicrometer,
            lembarId: MockWorkbookService.idLembarU95,
            barisDari: 1,
            barisSampai: 200,
          ),
          tidakAda,
        );
        expect((await mock.daftar('t')).map((w) => w.id), [
          MockWorkbookService.idHeightGauge,
        ]);
        expect(
          (await mock.riwayat(
            't',
            MockWorkbookService.idMicrometerCsv,
          )).versi.map((v) => v.id),
          [MockWorkbookService.idMicrometerCsv],
        );

        final lama = MockWorkbookService(serverLama: true);
        expect(lama.riwayat('t', MockWorkbookService.idMicrometer), tidakAda);
        final d = await lama.detail('t', MockWorkbookService.idMicrometer);
        expect(d.meta.versi, isNull);
        expect(d.meta.jumlahRiwayat, 0);
      },
    );
  });

  group('layar', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('daftar: "Impor #n" + "Riwayat (1)" di master aktif; CSV '
        'kembaran (riwayat) tidak ada di daftar, tanpa "Sumber lain"', (
      tester,
    ) async {
      await _bukaDaftar(tester, MockWorkbookService());

      expect(
        find.byKey(
          const ValueKey('workbook-${MockWorkbookService.idMicrometerCsv}'),
        ),
        findsNothing,
      );
      expect(find.textContaining('Sumber lain'), findsNothing);
      expect(
        _teks(tester, 'impor-${MockWorkbookService.idMicrometer}'),
        'Impor #2',
      );
      expect(
        _teks(tester, 'impor-${MockWorkbookService.idHeightGauge}'),
        'Impor #1',
      );
      final riwayat = find.byKey(
        const ValueKey('riwayat-${MockWorkbookService.idMicrometer}'),
      );
      expect(
        find.descendant(of: riwayat, matching: find.text('Riwayat (1)')),
        findsOneWidget,
      );
      // Height Gauge tanpa riwayat: tidak ada tombolnya.
      expect(
        find.byKey(
          const ValueKey('riwayat-${MockWorkbookService.idHeightGauge}'),
        ),
        findsNothing,
      );
    });

    testWidgets('Riwayat (1) → layar riwayat (nama, impor #, sumber, tanggal '
        'impor, status); master aktif tidak bisa diketuk; riwayat dibuka di '
        'penampil yang sama, BACA SAJA + spanduk; kembali berurutan', (
      tester,
    ) async {
      final mock = MockWorkbookService();
      await _bukaDaftar(tester, mock);
      await tester.tap(
        find.byKey(
          const ValueKey('riwayat-${MockWorkbookService.idMicrometer}'),
        ),
      );
      await tenang(tester);

      expect(find.byType(RiwayatWorkbookScreen), findsOneWidget);
      expect(
        find.text('Riwayat — Master Olah Data Micrometer 0-25mm'),
        findsOneWidget,
      );
      expect(mock.panggilanRiwayat, 1);

      final aktif = find.byKey(
        const ValueKey('versi-${MockWorkbookService.idMicrometer}'),
      );
      final lama = find.byKey(
        const ValueKey('versi-${MockWorkbookService.idMicrometerCsv}'),
      );
      // Urutan server: master aktif dulu.
      expect(tester.getTopLeft(aktif).dy, lessThan(tester.getTopLeft(lama).dy));
      expect(
        find.descendant(of: aktif, matching: find.text('Master aktif')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: aktif, matching: find.text('Impor #2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: aktif, matching: find.byType(InkWell)),
        findsNothing,
      );
      for (final t in [
        'Master_Olah_Data_Micrometer_0-25mm',
        'Riwayat',
        'Impor #1',
        'CSV',
      ]) {
        expect(
          find.descendant(of: lama, matching: find.text(t)),
          findsOneWidget,
          reason: t,
        );
      }
      expect(
        find.descendant(
          of: lama,
          matching: find.textContaining(
            RegExp(r'^Diimpor .+ · digantikan #1$'),
          ),
        ),
        findsOneWidget,
      );

      // Master aktif: mengetuk tidak membuka apa pun.
      await tester.tap(aktif);
      await tenang(tester);
      expect(find.byType(WorkbookScreen), findsNothing);

      await tester.tap(lama);
      await tenang(tester);
      expect(find.byType(WorkbookScreen), findsOneWidget);
      expect(
        _teks(tester, 'teks-spanduk-riwayat'),
        'Riwayat — bukan master aktif · Impor #1 · digantikan #1',
      );
      expect(find.byKey(const ValueKey('penanda-baca')), findsOneWidget);
      // Riwayat tidak menawarkan riwayat lagi (tanpa putaran layar).
      expect(find.byKey(const ValueKey('tombol-riwayat')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('chip-lebar-perkiraan')),
          matching: find.text('Lebar perkiraan'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Kembali'));
      await tenang(tester);
      expect(find.byType(WorkbookScreen), findsNothing);
      expect(find.byType(RiwayatWorkbookScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali'));
      await tenang(tester);
      expect(find.byType(RiwayatWorkbookScreen), findsNothing);
      expect(find.byType(DaftarWorkbookScreen), findsOneWidget);
    });

    testWidgets('layar riwayat: urutan SERVER apa adanya — riwayat bernomor '
        'impor lebih besar tetap di bawah master aktif dan tetap "Riwayat"', (
      tester,
    ) async {
      await _bukaDaftar(tester, _MockRiwayatImporBesar());
      await tester.tap(
        find.byKey(
          const ValueKey('riwayat-${MockWorkbookService.idMicrometer}'),
        ),
      );
      await tenang(tester);
      final aktif = find.byKey(
        const ValueKey('versi-${MockWorkbookService.idMicrometer}'),
      );
      final lama = find.byKey(const ValueKey('versi-77'));
      expect(tester.getTopLeft(aktif).dy, lessThan(tester.getTopLeft(lama).dy));
      expect(
        find.descendant(of: aktif, matching: find.text('Master aktif')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lama, matching: find.text('Riwayat')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lama, matching: find.text('Impor #3')),
        findsOneWidget,
      );
    });

    testWidgets('bilah master aktif: "Impor #2" + "Riwayat (1)" membuka '
        'layar riwayat', (tester) async {
      await _bukaWorkbook(tester, MockWorkbookService());
      expect(
        _teks(tester, 'impor-${MockWorkbookService.idMicrometer}'),
        'Impor #2',
      );
      expect(find.byKey(const ValueKey('spanduk-riwayat')), findsNothing);
      final tombol = find.byKey(const ValueKey('tombol-riwayat'));
      expect(
        find.descendant(of: tombol, matching: find.text('Riwayat (1)')),
        findsOneWidget,
      );
      await tester.tap(tombol);
      await tenang(tester);
      expect(find.byType(RiwayatWorkbookScreen), findsOneWidget);
    });

    testWidgets('RIWAYAT .xlsm ber-berkas asli, admin: tetap BACA SAJA — '
        'tanpa simulasi/urung/✕✓, ketikan tidak membuka editor, /hitung '
        'tidak pernah dikirim', (tester) async {
      // Kontrol: master aktif yang sama di peran yang sama = simulasi.
      await _bukaWorkbook(tester, MockWorkbookService());
      expect(find.byKey(const ValueKey('penanda-simulasi')), findsOneWidget);

      final mock = _MockMicrometerRiwayat();
      await _bukaWorkbook(tester, mock);
      expect(find.byKey(const ValueKey('penanda-baca')), findsOneWidget);
      expect(find.byKey(const ValueKey('penanda-simulasi')), findsNothing);
      expect(find.byKey(const ValueKey('spanduk-riwayat')), findsOneWidget);
      expect(
        _teks(tester, 'teks-spanduk-riwayat'),
        'Riwayat — bukan master aktif · Impor #2 · digantikan #42',
      );
      expect(find.byKey(const ValueKey('tombol-urungkan')), findsNothing);
      expect(find.byKey(const ValueKey('tombol-simpan-edit')), findsNothing);
      expect(find.byKey(const ValueKey('ketuk-bilah-rumus')), findsNothing);

      await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai('K6')!)));
      await tenang(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump(
        jedaKirimHitung +
            jarakMinKirimHitung +
            const Duration(milliseconds: 50),
      );
      await tenang(tester);
      expect(find.byKey(kunciEditorSel), findsNothing);
      expect(mock.panggilanHitung, isEmpty);
    });

    testWidgets('diarsipkan SAAT dibuka → muat ulang 404: pesan "Master ini '
        'sudah diarsipkan/diganti.", kembali ke daftar yang ditarik ulang; '
        'tanpa galat', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock);
      final daftarSebelum = mock.panggilanDaftar;

      mock.diarsipkan.add(MockWorkbookService.idMicrometer);
      await tester.tap(find.byTooltip('Muat ulang'));
      await tenang(tester);

      expect(find.byType(WorkbookScreen), findsNothing);
      expect(find.byType(DaftarWorkbookScreen), findsOneWidget);
      expect(find.text('Master ini sudah diarsipkan/diganti.'), findsOneWidget);
      expect(mock.panggilanDaftar, greaterThan(daftarSebelum));
      expect(
        find.byKey(
          const ValueKey('workbook-${MockWorkbookService.idMicrometer}'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('diarsipkan SAAT dibuka → /hitung 404: pesan sama, kembali '
        'ke daftar (bukan galat simulasi biasa)', (tester) async {
      final mock = MockWorkbookService();
      await _bukaWorkbook(tester, mock);
      expect(find.byKey(const ValueKey('penanda-simulasi')), findsOneWidget);

      mock.diarsipkan.add(MockWorkbookService.idMicrometer);
      await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai('K6')!)));
      await tenang(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(
        jedaKirimHitung +
            jarakMinKirimHitung +
            const Duration(milliseconds: 50),
      );
      await tenang(tester);

      expect(mock.panggilanHitung, hasLength(1));
      expect(find.byType(WorkbookScreen), findsNothing);
      expect(find.byType(DaftarWorkbookScreen), findsOneWidget);
      expect(find.text('Master ini sudah diarsipkan/diganti.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('baris daftar BASI (diarsipkan / id berganti sesudah '
        'ekstrak ulang) → 404 saat pertama dibuka: pesan tetap di tempat, '
        'daftar di bawahnya ditarik ulang', (tester) async {
      final mock = MockWorkbookService();
      await _bukaDaftar(tester, mock);
      final daftarSebelum = mock.panggilanDaftar;

      mock.diarsipkan.add(MockWorkbookService.idMicrometer);
      await tester.tap(
        find.byKey(
          const ValueKey('workbook-${MockWorkbookService.idMicrometer}'),
        ),
      );
      await tenang(tester);
      expect(find.byType(WorkbookScreen), findsOneWidget);
      expect(
        find.text('Workbook tidak ditemukan, atau bukan milik lab ini.'),
        findsOneWidget,
      );
      expect(mock.panggilanDaftar, greaterThan(daftarSebelum));

      await tester.tap(find.byTooltip('Kembali'));
      await tenang(tester);
      expect(
        find.byKey(
          const ValueKey('workbook-${MockWorkbookService.idMicrometer}'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('layar riwayat: master diarsipkan → 404 → pesan + "Kembali '
        'ke daftar"', (tester) async {
      final mock = MockWorkbookService();
      await _bukaDaftar(tester, mock);
      await tester.tap(
        find.byKey(
          const ValueKey('riwayat-${MockWorkbookService.idMicrometer}'),
        ),
      );
      await tenang(tester);

      mock.diarsipkan.add(MockWorkbookService.idMicrometer);
      await tester.tap(find.byTooltip('Muat ulang'));
      await tenang(tester);
      expect(find.text('Master ini sudah diarsipkan/diganti.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('riwayat-kembali')));
      await tenang(tester);
      expect(find.byType(RiwayatWorkbookScreen), findsNothing);
      expect(find.byType(DaftarWorkbookScreen), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('workbook-${MockWorkbookService.idMicrometer}'),
        ),
        findsNothing,
      );
    });

    testWidgets('digantikan SAAT dibuka → muat ulang berstatus riwayat: '
        'spanduk riwayat, baca saja, edit simulasi yang ada dibuang', (
      tester,
    ) async {
      final mock = _MockMicrometerRiwayat(jadiRiwayat: false);
      await _bukaWorkbook(tester, mock);
      await tester.tap(find.byKey(kunciSelGrid(AlamatSel.urai('K6')!)));
      await tenang(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(
        jedaKirimHitung +
            jarakMinKirimHitung +
            const Duration(milliseconds: 50),
      );
      await tenang(tester);
      expect(find.byKey(const ValueKey('spanduk-simulasi')), findsOneWidget);
      expect(mock.panggilanHitung, hasLength(1));

      mock.jadiRiwayat = true;
      await tester.tap(find.byTooltip('Muat ulang'));
      await tenang(tester);
      await tester.pump(
        jedaKirimHitung +
            jarakMinKirimHitung +
            const Duration(milliseconds: 50),
      );
      await tenang(tester);

      expect(find.byType(WorkbookScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('spanduk-riwayat')), findsOneWidget);
      expect(find.byKey(const ValueKey('penanda-baca')), findsOneWidget);
      expect(find.byKey(const ValueKey('spanduk-simulasi')), findsNothing);
      expect(find.byKey(const ValueKey('tombol-riwayat')), findsNothing);
      expect(mock.panggilanHitung, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keluar akun saat layar riwayat terbuka: rute akar itu ikut '
        'tertutup', (tester) async {
      await _bukaDaftar(tester, MockWorkbookService());
      await tester.tap(
        find.byKey(
          const ValueKey('riwayat-${MockWorkbookService.idMicrometer}'),
        ),
      );
      await tenang(tester);
      final keluar = keluarStudio(wadahDari(tester));
      await tenang(tester);
      await keluar;
      await tenang(tester);
      expect(find.byType(RiwayatWorkbookScreen), findsNothing);
      expect(find.text('Masuk ke Studio'), findsOneWidget);
    });
  });
}

// ─────────────────────────────────────────────────────────────── pembantu

const _izin = Izin(
  role: UserRole.admin,
  boleh: {NamaIzin.dataAcuanLihat, izinWorkbookLihat},
);

Future<void> _bukaDaftar(WidgetTester tester, MockWorkbookService mock) async {
  await pasangUkuran(tester, const Size(1440, 900));
  await tester.pumpWidget(
    studioUji(meja: true, token: 'mock-token-1', izin: _izin, workbook: mock),
  );
  await tenang(tester);
  await bukaSeksi(tester, SeksiStudio.workbookAlat);
  expect(find.byType(DaftarWorkbookScreen), findsOneWidget);
}

/// Micrometer `.xlsm` (berkas asli tersimpan) dari daftar.
Future<void> _bukaWorkbook(
  WidgetTester tester,
  MockWorkbookService mock,
) async {
  await _bukaDaftar(tester, mock);
  await tester.tap(
    find.byKey(const ValueKey('workbook-${MockWorkbookService.idMicrometer}')),
  );
  await tenang(tester);
  expect(find.byType(WorkbookScreen), findsOneWidget);
}

String? _teks(WidgetTester tester, String kunci) =>
    tester.widget<Text>(find.byKey(ValueKey(kunci))).data;

/// Detail Micrometer `.xlsm` (berkas asli tersimpan, simulasi biasanya
/// boleh) dijawab berstatus RIWAYAT — yang menahan edit HANYA status itu.
class _MockMicrometerRiwayat extends MockWorkbookService {
  _MockMicrometerRiwayat({this.jadiRiwayat = true});

  /// `false` = jawaban biasa (master aktif) sampai dibalik test — meniru
  /// master yang DIGANTIKAN selagi layarnya terbuka.
  bool jadiRiwayat;

  @override
  Future<WorkbookDetail> detail(String token, int workbookId) async {
    final d = await super.detail(token, workbookId);
    if (!jadiRiwayat) return d;
    final m = d.meta;
    expect(m.sumber, SumberWorkbook.xlsm);
    expect(m.berkasAsliTersimpan, isTrue);
    return WorkbookDetail(
      meta: WorkbookRingkas(
        id: m.id,
        nama: m.nama,
        sumber: m.sumber,
        sumberMentah: m.sumberMentah,
        sha256: m.sha256,
        ukuran: m.ukuran,
        jumlahLembar: m.jumlahLembar,
        berkasAsliTersimpan: m.berkasAsliTersimpan,
        kodeProfil: m.kodeProfil,
        keluarga: m.keluarga,
        diimporPada: m.diimporPada,
        kunciJenis: m.kunciJenis,
        aktif: false,
        status: StatusWorkbook.riwayat,
        versi: 2,
        digantikanOlehId: 42,
        jumlahRiwayat: 1,
      ),
      lembar: d.lembar,
    );
  }
}

/// Jawaban riwayat dengan riwayat bernomor impor LEBIH BESAR dari master
/// aktif (admin mengaktifkan ulang versi lama) — bentuk tweak kontrak.
class _MockRiwayatImporBesar extends MockWorkbookService {
  @override
  Future<RiwayatWorkbook> riwayat(String token, int workbookId) async =>
      RiwayatWorkbook.fromJson(
        jsonDecode(
              jsonEncode({
                'data': [
                  {
                    'id': MockWorkbookService.idMicrometer,
                    'nama': 'Master Olah Data Micrometer 0-25mm',
                    'sumber': 'xlsm',
                    'status': 'aktif',
                    'aktif': true,
                    'versi': 2,
                    'jumlah_riwayat': 1,
                  },
                  {
                    'id': 77,
                    'nama': 'Master Olah Data Micrometer 0-25mm (rev)',
                    'sumber': 'xlsm',
                    'status': 'riwayat',
                    'aktif': false,
                    'versi': 3,
                    'digantikan_oleh_id': MockWorkbookService.idMicrometer,
                    'jumlah_riwayat': 1,
                  },
                ],
                'kunci_jenis': 'dimensi:micrometer-0-25mm',
              }),
            )
            as Map<String, dynamic>,
      );
}
