import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/arsip_draf.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/crud_lab/arsip_draf_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/pengelolaan_data_screen.dart';
import 'package:sidik_calibration/screens/draf/draf_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/arsip_draf_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/history_service.dart';

import 'support/crud_uji.dart';
import 'support/layar_sa_uji.dart' show ketukDi;
import 'support/super_admin_uji.dart' show aturLayar, selesaikan;

/// Arsip draf lembar kerja (kontrak `docs/perintah-frontend-crud-lengkap.md`
/// §3): daftar arsip + pulihkan (layar BARU) dan tombol Arsipkan pada kartu
/// Draf (layar LAMA, commit terpisah). Bentuk JSON disalin dari §3.1–§3.3.
const _dasar = 'https://api.test/api';

http.Response _json(Object badan, [int status = 200]) => http.Response(
  jsonEncode(badan),
  status,
  headers: {'content-type': 'application/json'},
);

ArsipDrafService _layanan(Future<http.Response> Function(http.Request) h) =>
    ApiArsipDrafService(ApiClient(client: MockClient(h), baseUrl: _dasar));

Map<String, dynamic> _badan(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

/// Item daftar arsip §3.2.
Map<String, dynamic> _item({int id = 412}) => {
  'id': id,
  'nomor_sesi': 'KAL/2026/11/0007',
  'status': 'draft',
  'tanggal_kalibrasi': '2026-11-18',
  'equipment': {'id': 88, 'nama_alat': 'Timbangan Analitik', 'serial_number': 'SN-123'},
  'pelanggan': {'id': 3, 'nama': 'PT Contoh'},
  'teknisi': {'id': 5, 'nama': 'Budi'},
  'arsip': {
    'alasan': 'Salah pilih alat, dibuat ulang.',
    'oleh': {'id': 5, 'nama': 'Budi'},
    'pada': '2026-11-18T10:20:00+07:00',
  },
};

void main() {
  group('model', () {
    test('DrafArsipan membaca ringkasan + jejak arsip (§3.2)', () {
      final d = DrafArsipan.fromJson(_item());

      expect(d.id, 412);
      expect(d.nomorSesi, 'KAL/2026/11/0007');
      expect(d.namaAlat, 'Timbangan Analitik');
      expect(d.nomorSeri, 'SN-123');
      expect(d.namaPelanggan, 'PT Contoh');
      expect(d.namaTeknisi, 'Budi');
      expect(d.arsip.alasan, 'Salah pilih alat, dibuat ulang.');
      expect(d.arsip.olehNama, 'Budi');
      expect(d.arsip.pada, isNotNull);
    });

    test('kolom opsional kosong tidak melempar', () {
      final d = DrafArsipan.fromJson({'id': 1, 'status': 'draft'});

      expect(d.namaAlat, '');
      expect(d.nomorSesi, isNull);
      expect(d.arsip.alasan, isNull);
    });

    test('HasilArsipDraf: arsipkan §3.1 dan pulihkan §3.3', () {
      final a = HasilArsipDraf.fromJson({
        'message': 'Draf diarsipkan.',
        'data': {
          'id': 412,
          'nomor_sesi': 'KAL/2026/11/0007',
          'status': 'draft',
          'diarsipkan': true,
          'arsip': _item()['arsip'],
        },
      });
      expect(a.diarsipkan, isTrue);
      expect(a.arsip!.olehNama, 'Budi');

      final p = HasilArsipDraf.fromJson({
        'message': 'Draf dipulihkan.',
        'data': {'id': 412, 'nomor_sesi': 'KAL/2026/11/0007', 'status': 'draft', 'diarsipkan': false},
      });
      expect(p.diarsipkan, isFalse);
      expect(p.arsip, isNull);
    });
  });

  group('service API', () {
    test('daftar: diarsipkan=1 + q + page; paginasi dari meta', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({
          'data': [_item()],
          'links': {},
          'meta': {'current_page': 2, 'per_page': 15, 'total': 17, 'last_page': 2},
        });
      });
      final h = await s.daftar('tkn', cari: ' timbangan ', halaman: 2);

      expect(terkirim.method, 'GET');
      expect(terkirim.url.path, '/api/calibrations');
      expect(terkirim.url.queryParameters, {
        'diarsipkan': '1',
        'q': 'timbangan',
        'page': '2',
      });
      expect(h.items.single.id, 412);
      expect(h.adaLagi, isFalse);
    });

    test('daftar tanpa cari: hanya diarsipkan=1', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({'data': [], 'meta': {'current_page': 1, 'last_page': 1}});
      });
      await s.daftar('t');

      expect(terkirim.url.queryParameters, {'diarsipkan': '1'});
    });

    test('arsipkan: POST /calibrations/{id}/arsipkan {alasan}', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({
          'message': 'Draf diarsipkan.',
          'data': {'id': 412, 'nomor_sesi': 'K', 'status': 'draft', 'diarsipkan': true, 'arsip': _item()['arsip']},
        });
      });
      final h = await s.arsipkan('tkn', 412, alasan: 'Salah pilih alat, dibuat ulang.');

      expect(terkirim.method, 'POST');
      expect(terkirim.url.path, '/api/calibrations/412/arsipkan');
      expect(_badan(terkirim), {'alasan': 'Salah pilih alat, dibuat ulang.'});
      expect(h.diarsipkan, isTrue);
    });

    test('pulihkan: alasan opsional hanya dikirim bila ada', () async {
      final badan = <Map<String, dynamic>>[];
      late http.Request terakhir;
      final s = _layanan((r) async {
        terakhir = r;
        badan.add(_badan(r));
        return _json({
          'message': 'Draf dipulihkan.',
          'data': {'id': 412, 'status': 'draft', 'diarsipkan': false},
        });
      });
      await s.pulihkan('t', 412);
      await s.pulihkan('t', 412, alasan: 'Salah arsip');

      expect(terakhir.url.path, '/api/calibrations/412/pulihkan');
      expect(badan.first, isEmpty);
      expect(badan.last, {'alasan': 'Salah arsip'});
    });

    // Badan galat disalin dari §3.1-§3.3 dan §7.
    final galat = <(String, int, Map<String, dynamic>)>[
      ('401', 401, {'message': 'Unauthenticated.'}),
      ('403 hanya_admin', 403, {'message': 'Hanya admin.', 'kode': 'hanya_admin'}),
      ('404 bukan milik', 404, {'message': 'No query results.'}),
      (
        '422 bukan_draf',
        422,
        {'message': 'Hanya draf.', 'kode': 'bukan_draf', 'status': 'menunggu_approval'},
      ),
      (
        '422 tidak_diarsipkan',
        422,
        {'message': 'Tidak diarsipkan.', 'kode': 'tidak_diarsipkan'},
      ),
      (
        '409 status_berubah',
        409,
        {'message': 'Berubah.', 'kode': 'status_berubah'},
      ),
      ('429 throttle', 429, {'message': 'Kebanyakan.'}),
      ('500', 500, {'message': 'Server Error'}),
    ];

    for (final (nama, status, badan) in galat) {
      test('arsipkan & pulihkan: $nama → ApiException berbadan asli', () async {
        final s = _layanan((_) async => _json(badan, status));
        for (final panggil in [
          () => s.arsipkan('t', 412, alasan: 'alasan sah'),
          () => s.pulihkan('t', 412),
        ]) {
          await expectLater(
            panggil(),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.status, 'status', status)
                  .having((e) => e.body['kode'], 'kode', badan['kode']),
            ),
          );
        }
      });
    }

    test('arsipkan: jaringan putus → KoneksiException, tidak diulang', () async {
      var n = 0;
      final s = _layanan((_) async {
        n++;
        throw const SocketException('putus');
      });
      await expectLater(
        s.arsipkan('t', 412, alasan: 'alasan sah'),
        throwsA(isA<KoneksiException>()),
      );
      expect(n, 1);
    });
  });

  group('layar Arsip draf', () {
    Future<MockArsipDrafService> buka(
      WidgetTester tester, {
      MockArsipDrafService? layanan,
      String token = tokenAdminCrud,
      Izin izin = izinAdminCrud,
      double lebar = 392,
    }) async {
      final l = layanan ?? MockArsipDrafService();
      aturLayar(tester, lebar, 852);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...LapisanUjiCrud(arsipDraf: l).overrides(token: token, izin: izin),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ArsipDrafScreen(),
          ),
        ),
      );
      await selesaikan(tester);
      return l;
    }

    testWidgets('admin: daftar dengan alasan dan siapa yang mengarsipkan', (
      tester,
    ) async {
      await buka(tester);

      expect(find.text('KAL/2026/11/0007'), findsOneWidget);
      expect(find.text('Timbangan Analitik · SN-123'), findsOneWidget);
      expect(find.text('Alasan: Salah pilih alat, dibuat ulang.'), findsOneWidget);
      expect(find.textContaining('Diarsipkan oleh Dedi Teknisi'), findsOneWidget);
      expect(find.byKey(const Key('pulihkan-412')), findsOneWidget);
    });

    for (final (nama, token, izin) in [
      ('teknisi', tokenTeknisiCrud, izinTeknisiCrud),
      ('viewer', 'mock-token-3', izinViewerCrud),
    ]) {
      testWidgets('$nama: terkunci, tanpa daftar dan tanpa Pulihkan', (tester) async {
        final l = await buka(tester, token: token, izin: izin);

        expect(
          find.text('Akun Anda tidak punya izin untuk bagian ini.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('pulihkan-412')), findsNothing);
        // Daftar tidak pernah diminta tanpa izin.
        expect(l.catatan, isEmpty);
      });
    }

    testWidgets('cari memakai kata kunci ke server', (tester) async {
      final l = await buka(tester);
      await tester.enterText(find.byKey(const Key('cari-arsip')), 'pH');
      await tester.pump(const Duration(milliseconds: 450));
      await selesaikan(tester);

      expect(l.catatan.last, contains('cari=pH'));
      expect(find.text('KAL/2026/11/0007'), findsNothing);
      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
    });

    testWidgets('kosong dan kosong-karena-cari memakai kalimat berbeda', (
      tester,
    ) async {
      await buka(tester, layanan: MockArsipDrafService(awal: const []));
      expect(find.text('Belum ada draf yang diarsipkan.'), findsOneWidget);
    });

    testWidgets('galat memuat: 403 hanya_admin memakai kalimat khusus', (tester) async {
      await buka(
        tester,
        layanan: MockArsipDrafService(
          galat: const ApiException(
            'x',
            status: 403,
            body: {'message': 'x', 'kode': 'hanya_admin'},
          ),
        ),
      );

      expect(
        find.text('Hanya Master Data atau Super Admin yang boleh membuka arsip draf.'),
        findsOneWidget,
      );
    });

    testWidgets('galat jaringan: kalimat + Coba lagi', (tester) async {
      await buka(
        tester,
        layanan: MockArsipDrafService(galat: const KoneksiException('x')),
      );
      expect(find.text('Tidak bisa terhubung ke server. Periksa koneksi lalu coba lagi.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('pulihkan: alasan opsional, daftar diambil ulang, kabar tampil', (
      tester,
    ) async {
      final l = await buka(tester);

      await ketukDi(tester, find.byKey(const Key('pulihkan-412')));
      await tester.pumpAndSettle();
      expect(find.text('Pulihkan draf KAL/2026/11/0007?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(l.catatan.any((c) => c.startsWith('pulihkan 412')), isTrue);
      expect(find.text('Draf dipulihkan.'), findsOneWidget);
      expect(find.text('KAL/2026/11/0007'), findsNothing);
    });

    testWidgets('pulihkan yang sudah tidak diarsipkan: kalimat kode, daftar dimuat ulang', (
      tester,
    ) async {
      final l = await buka(
        tester,
        layanan: _TidakDiarsipkan(),
      );

      await ketukDi(tester, find.byKey(const Key('pulihkan-412')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(
        find.text('Draf ini sudah tidak diarsipkan. Daftar dimuat ulang.'),
        findsOneWidget,
      );
      expect(l.catatan.where((c) => c.startsWith('daftar')).length, greaterThan(1));
    });

    testWidgets('hub: pintu Arsip draf hanya untuk yang boleh memulihkan', (
      tester,
    ) async {
      aturLayar(tester, 392, 852);
      await tester.pumpWidget(bungkusCrud(const PengelolaanDataScreen()));
      await selesaikan(tester);
      expect(find.byKey(const Key('pintu-arsip-draf')), findsOneWidget);

      // Akar diganti dulu supaya ProviderScope baru lahir bersih (overrides
      // satu scope tidak boleh berganti di tengah jalan).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        bungkusCrud(
          const PengelolaanDataScreen(),
          token: tokenTeknisiCrud,
          izin: izinTeknisiCrud,
        ),
      );
      await selesaikan(tester);
      expect(find.byKey(const Key('pintu-arsip-draf')), findsNothing);
    });
  });

  // LAYAR LAMA (commit terpisah): tombol Arsipkan pada kartu Draf.
  group('LAYAR LAMA: kartu Draf punya tombol Arsipkan', () {
    Future<MockArsipDrafService> buka(
      WidgetTester tester, {
      MockArsipDrafService? layanan,
      String token = tokenTeknisiCrud,
      Izin izin = izinTeknisiCrud,
    }) async {
      final l = layanan ?? MockArsipDrafService();
      aturLayar(tester, 600, 2400);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...LapisanUjiCrud(arsipDraf: l).overrides(token: token, izin: izin),
            historyServiceProvider.overrideWithValue(MockHistoryService()),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DrafScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
      return l;
    }

    /// Tombol Arsipkan pada kartu Draf (tooltip "Arsipkan draf <alat>").
    Finder tombol() => find.byWidgetPredicate(
      (w) => w is IconButton && (w.tooltip ?? '').startsWith('Arsipkan draf '),
    );

    testWidgets('berizin kalibrasi.arsipkan: tombol ada di tiap kartu', (
      tester,
    ) async {
      await buka(tester);

      expect(tombol(), findsWidgets);
    });

    testWidgets('viewer (tanpa izin): kartu persis seperti sebelumnya, tanpa tombol', (
      tester,
    ) async {
      await buka(tester, token: 'mock-token-3', izin: izinViewerCrud);

      expect(tombol(), findsNothing);
    });

    testWidgets('arsipkan: alasan wajib; sah → dikirim ke server, kabar tampil', (
      tester,
    ) async {
      final l = await buka(tester);
      final ikon = tombol().first;

      await tester.tap(ikon);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('isian-dialog')), 'abc');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Alasan minimal 5 karakter.'), findsOneWidget);
      expect(l.catatan.where((c) => c.startsWith('arsipkan')), isEmpty);

      await tester.enterText(
        find.byKey(const Key('isian-dialog')),
        'Salah pilih alat, dibuat ulang.',
      );
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(
        l.catatan.any((c) => c.contains('arsipkan') && c.contains('Salah pilih alat')),
        isTrue,
      );
      expect(find.text('Draf diarsipkan.'), findsOneWidget);
    });

    testWidgets('sesi sudah bukan draf: kalimat kode dengan status, dialog tetap', (
      tester,
    ) async {
      final l = await buka(
        tester,
        layanan: _BukanDraf(),
      );
      expect(l, isNotNull);

      await tester.tap(tombol().first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('isian-dialog')), 'alasan yang sah');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Hanya draf yang bisa diarsipkan'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('aksi-dialog')), findsOneWidget);
    });

    testWidgets('teknisi lain / lab lain (404): kalimat "mungkin sudah berubah"', (
      tester,
    ) async {
      await buka(tester, layanan: _Tiga404());

      await tester.tap(tombol().first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('isian-dialog')), 'alasan yang sah');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(find.textContaining('mungkin sudah berubah'), findsOneWidget);
    });
  });
}

class _TidakDiarsipkan extends MockArsipDrafService {
  @override
  Future<HasilArsipDraf> pulihkan(String token, int id, {String? alasan}) async =>
      throw const ApiException(
        'x',
        status: 422,
        body: {'message': 'x', 'kode': 'tidak_diarsipkan'},
      );
}

class _BukanDraf extends MockArsipDrafService {
  @override
  Future<HasilArsipDraf> arsipkan(String token, int id, {required String alasan}) async =>
      throw const ApiException(
        'x',
        status: 422,
        body: {'message': 'x', 'kode': 'bukan_draf', 'status': 'menunggu_approval'},
      );
}

class _Tiga404 extends MockArsipDrafService {
  @override
  Future<HasilArsipDraf> arsipkan(String token, int id, {required String alasan}) async =>
      throw const ApiException('x', status: 404);
}
