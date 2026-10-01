import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/certificate_snapshot.dart';
import 'package:sidik_calibration/models/koreksi_pelanggan.dart';
import 'package:sidik_calibration/models/notification_item.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/certificate_provider.dart';
import 'package:sidik_calibration/providers/koreksi_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/realtime_provider.dart';
import 'package:sidik_calibration/screens/koreksi/antrean_koreksi_screen.dart';
import 'package:sidik_calibration/screens/koreksi/detail_koreksi_screen.dart';
import 'package:sidik_calibration/screens/notification/notification_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/certificate_service.dart';
import 'package:sidik_calibration/services/koreksi_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/realtime_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Koreksi dari pelanggan, sisi LAB (kontrak A4, §42).
///
/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
///
/// ## Yang dijaga
///
/// - **Antrean**: tab Menunggu/Diterima/Ditolak/Semua dan badge dari
///   `meta.jumlah.menunggu` yang tidak ikut menyusut waktu tab berganti.
/// - **Detail**: tabel lama → baru, foto dimuat lewat header API, hasil
///   keputusan, dan tautan ke revisi sertifikat pengganti.
/// - **Siapa melihat tombol apa**: admin memutuskan, super admin hanya membaca
///   (dengan kalimat yang menjelaskannya).
/// - **Terima** mengirim HANYA nilai yang dibetulkan admin, dan 422 tampil di
///   bawah kolomnya; **Tolak** wajib bertanggapan.
const _admin = 'mock-token-1';
const _superAdmin = 'mock-token-5';

List<Override> _semua({
  required MockKoreksiService service,
  String token = _admin,
}) => [
  tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
  authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
  koreksiServiceProvider.overrideWithValue(service),
  certificateServiceProvider.overrideWithValue(MockCertificateService()),
];

Widget _app(
  Widget layar, {
  required MockKoreksiService service,
  String token = _admin,
}) => ProviderScope(
  overrides: _semua(service: service, token: token),
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: layar,
  ),
);

Future<void> _pasang(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(420, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// Chip tab digeser sendiri di HP sempit; tab di ujung perlu digulirkan dulu.
Future<void> _pilihTab(WidgetTester tester, String kode) async {
  final chip = find.byKey(ValueKey('tab-koreksi-$kode'));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// #7 alat (serial, 2 foto), #8 sertifikat (2 perubahan), #5/#4 diterima
/// (#4 dengan revisi), #3 ditolak.
const _alat = 7;
const _sertifikat = 8;
const _diterimaDenganRevisi = 4;
const _ditolak = 3;

void main() {
  group('model', () {
    test('fromJson membaca bentuk Koreksi kontrak A4', () {
      final k = Koreksi.fromJson(
        jsonDecode('''
{
  "id": 7, "jenis": "alat", "status": "menunggu",
  "pelanggan": {"id": 3, "nama": "PT Contoh Jaya"},
  "diajukan_oleh": {"id": 41, "nama": "Budi"},
  "diajukan_pada": "2026-10-01T02:15:00Z",
  "alat": {"id": 12, "nama": "pH Meter", "serial": "HI2211-0419"},
  "sertifikat": null,
  "perubahan": [
    {"field": "serial_number", "label": "Nomor seri", "lama": "HI2211-0491", "baru": "HI2211-0419"}
  ],
  "catatan": "Nomor seri tertukar dua digit",
  "foto": [{"id": 5, "url": "https://x/api/foto-pelanggan/5"}],
  "tanggapan": null, "ditinjau_oleh": null, "ditinjau_pada": null, "revisi": null
}''')
            as Map<String, dynamic>,
      );

      expect(k.jenis, JenisKoreksi.alat);
      expect(k.status.bisaDiputuskan, isTrue);
      expect(k.pelangganNama, 'PT Contoh Jaya');
      expect(k.diajukanOleh, 'Budi');
      expect(k.alatSerial, 'HI2211-0419');
      expect(k.sertifikatId, isNull);
      expect(k.perubahan.single.lama, 'HI2211-0491');
      expect(k.perubahan.single.baru, 'HI2211-0419');
      expect(k.foto.single.id, 5);
      expect(k.revisi, isNull);
    });

    test('jenis sertifikat: sertifikat & revisi terbaca', () {
      final k = Koreksi.fromJson(const {
        'id': 8,
        'jenis': 'sertifikat',
        'status': 'diterima',
        'alat': {'id': 12, 'nama': 'pH Meter', 'serial': 'X'},
        'sertifikat': {'id': 41, 'nomor': 'CAL/2026/09/0011'},
        'revisi': {
          'id': 51,
          'nomor': 'CAL/2026/09/0011-R1',
          'status': 'menunggu_generate',
        },
      });
      expect(k.jenis, JenisKoreksi.sertifikat);
      expect(k.sertifikatId, 41);
      expect(k.revisi!.nomor, 'CAL/2026/09/0011-R1');
      expect(k.status.bisaDiputuskan, isFalse);
    });

    test('status asing & field hilang tidak melempar', () {
      final k = Koreksi.fromJson(const {
        'id': 1,
        'status': 'dibatalkan',
        'perubahan': [
          {'field': 'merk'},
          'bukan objek',
        ],
        'foto': [
          {'url': 'tanpa id'},
        ],
      });
      expect(k.status, StatusKoreksi.lainnya);
      expect(k.status.bisaDiputuskan, isFalse);
      expect(k.perubahan.single.label, 'merk');
      expect(k.foto, isEmpty);
    });
  });

  group('ApiKoreksiService', () {
    (ApiKoreksiService, List<http.Request>) buat(
      http.Response Function(http.Request) jawab,
    ) {
      final rekam = <http.Request>[];
      final client = MockClient((r) async {
        rekam.add(r);
        return jawab(r);
      });
      return (
        ApiKoreksiService(ApiClient(client: client, baseUrl: 'http://x/api')),
        rekam,
      );
    }

    http.Response json(Object o, [int kode = 200]) => http.Response(
      jsonEncode(o),
      kode,
      headers: {'content-type': 'application/json'},
    );

    test('daftar mengirim status & membaca meta.jumlah.menunggu', () async {
      final (svc, rekam) = buat(
        (_) => json({
          'data': [
            {'id': 1, 'jenis': 'alat', 'status': 'menunggu'},
          ],
          'meta': {
            'total': 1,
            'per_page': 20,
            'jumlah': {'menunggu': 4},
          },
        }),
      );

      final h = await svc.daftar('t', status: 'diterima');

      expect(rekam.single.url.path, '/api/koreksi-pelanggan');
      expect(rekam.single.url.queryParameters['status'], 'diterima');
      expect(rekam.single.url.queryParameters['per_page'], '20');
      expect(h.items.single.id, 1);
      expect(h.jumlahMenunggu, 4);
    });

    test('terima hanya mengirim yang terisi; 422 jadi GalatAksi', () async {
      final (svc, rekam) = buat(
        (_) => json({
          'message': 'Data yang dikirim tidak valid.',
          'errors': {
            'perubahan.serial_number': ['Nomor seri sudah dipakai alat lain.'],
          },
        }, 422),
      );

      await expectLater(
        svc.terima(
          't',
          7,
          tanggapan: '  ',
          perubahan: {'serial_number': 'X-1'},
          alasan: null,
        ),
        throwsA(
          isA<GalatAksi>().having(
            (e) => e.untuk('perubahan.serial_number'),
            'pesan',
            'Nomor seri sudah dipakai alat lain.',
          ),
        ),
      );

      final badan = jsonDecode(rekam.single.body) as Map<String, dynamic>;
      expect(rekam.single.url.path, '/api/koreksi-pelanggan/7/terima');
      expect(badan, {
        'perubahan': {'serial_number': 'X-1'},
      });
    });

    test('tolak mengirim tanggapan; 403 tidak jadi galat validasi', () async {
      final (svc, rekam) = buat((_) => json({'message': 'Tidak boleh.'}, 403));

      await expectLater(
        svc.tolak('t', 7, '  Tidak sesuai. '),
        throwsA(isNot(isA<GalatAksi>())),
      );
      expect(rekam.single.url.path, '/api/koreksi-pelanggan/7/tolak');
      expect(
        (jsonDecode(rekam.single.body) as Map<String, dynamic>)['tanggapan'],
        'Tidak sesuai.',
      );
    });

    test('foto ditarik dari /foto-pelanggan/{id} dengan Bearer token', () async {
      final (svc, rekam) = buat((_) => http.Response.bytes([1, 2, 3], 200));

      final bytes = await svc.foto('rahasia', 5);

      expect(bytes, [1, 2, 3]);
      expect(rekam.single.url.path, '/api/foto-pelanggan/5');
      expect(rekam.single.headers['Authorization'], 'Bearer rahasia');
    });

    test('foto 404 → null, bukan galat', () async {
      final (svc, _) = buat((_) => http.Response('', 404));
      expect(await svc.foto('t', 99), isNull);
    });
  });

  group('antrean', () {
    testWidgets('tab Menunggu dulu, dengan hitungan dan dua kartu', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(const AntreanKoreksiScreen(), service: MockKoreksiService()),
      );

      expect(find.byKey(const ValueKey('kartu-koreksi-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('kartu-koreksi-8')), findsOneWidget);
      expect(find.byKey(const ValueKey('kartu-koreksi-5')), findsNothing);
      // Hitungan di tab = badge menu.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('jumlah-koreksi-menunggu')))
            .data,
        '2',
      );
      // Jenis tampil di kartu.
      expect(find.text('KOREKSI ALAT'), findsOneWidget);
      expect(find.text('KOREKSI SERTIFIKAT'), findsOneWidget);
    });

    testWidgets('tab Diterima / Ditolak / Semua menyaring, hitungan bertahan', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(const AntreanKoreksiScreen(), service: MockKoreksiService()),
      );

      await _pilihTab(tester, 'diterima');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kartu-koreksi-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('kartu-koreksi-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('kartu-koreksi-7')), findsNothing);
      // Hitungan Menunggu tidak ikut menyusut (chip-nya sudah tergulir keluar
      // layar, jadi dibaca dari datanya).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AntreanKoreksiScreen)),
      );
      expect(container.read(antreanKoreksiProvider).value!.jumlahMenunggu, 2);

      await _pilihTab(tester, 'ditolak');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kartu-koreksi-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('kartu-koreksi-4')), findsNothing);

      await _pilihTab(tester, 'semua');
      await tester.pumpAndSettle();
      for (final id in [7, 8, 5, 4, 3]) {
        expect(find.byKey(ValueKey('kartu-koreksi-$id')), findsOneWidget);
      }
    });

    testWidgets('antrean kosong: kalimat yang jelas', (tester) async {
      await _pasang(
        tester,
        _app(
          const AntreanKoreksiScreen(),
          service: MockKoreksiService(awal: const []),
        ),
      );
      expect(find.text('Tidak ada koreksi yang menunggu.'), findsOneWidget);
    });

    testWidgets('gagal memuat: pesan + coba lagi', (tester) async {
      await _pasang(
        tester,
        _app(
          const AntreanKoreksiScreen(),
          service: MockKoreksiService(gagal: true),
        ),
      );
      expect(find.text('Koreksi gagal dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('ketuk kartu membuka detail', (tester) async {
      await _pasang(
        tester,
        _app(const AntreanKoreksiScreen(), service: MockKoreksiService()),
      );
      await tester.tap(find.byKey(const ValueKey('kartu-koreksi-7')));
      await tester.pumpAndSettle();
      expect(find.byType(DetailKoreksiScreen), findsOneWidget);
      expect(find.text('Koreksi #7'), findsOneWidget);
    });
  });

  group('detail', () {
    testWidgets('alat: lama → baru, catatan, foto, dan dua tombol', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailKoreksiScreen(koreksiId: _alat),
          service: MockKoreksiService(),
        ),
      );

      expect(find.text('PT Contoh Jaya'), findsOneWidget);
      expect(find.byKey(const ValueKey('perubahan-serial_number')), findsOne);
      expect(find.text('HI2211-0491'), findsWidgets); // lama (juga di target)
      expect(find.text('HI2211-0419'), findsOneWidget); // baru
      expect(find.text('Nomor seri tertukar dua digit.'), findsOneWidget);
      // Foto dimuat lewat provider (header API), dua thumbnail.
      expect(find.byKey(const ValueKey('foto-pelanggan-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('foto-pelanggan-6')), findsOneWidget);
      expect(find.byKey(const ValueKey('tombol-terima-koreksi')), findsOne);
      expect(find.byKey(const ValueKey('tombol-tolak-koreksi')), findsOne);
    });

    testWidgets('ketuk thumbnail membuka foto penuh, bisa ditutup', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailKoreksiScreen(koreksiId: _alat),
          service: MockKoreksiService(),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('foto-pelanggan-5')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tutup-foto-pelanggan')));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets('super admin: tidak ada tombol, ada kalimat penjelas', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailKoreksiScreen(koreksiId: _alat),
          service: MockKoreksiService(),
          token: _superAdmin,
        ),
      );

      expect(find.byKey(const ValueKey('tombol-terima-koreksi')), findsNothing);
      expect(find.byKey(const ValueKey('tombol-tolak-koreksi')), findsNothing);
      expect(
        find.byKey(const ValueKey('catatan-baca-saja-koreksi')),
        findsOneWidget,
      );
    });

    testWidgets('teknisi tidak melihat tombol memutuskan', (tester) async {
      await _pasang(
        tester,
        _app(
          const DetailKoreksiScreen(koreksiId: _alat),
          service: MockKoreksiService(),
          token: 'mock-token-2',
        ),
      );
      expect(find.byKey(const ValueKey('tombol-terima-koreksi')), findsNothing);
      expect(find.byKey(const ValueKey('tombol-tolak-koreksi')), findsNothing);
    });

    testWidgets('sudah diputus: tanggapan & revisi pengganti, tanpa tombol', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailKoreksiScreen(koreksiId: _diterimaDenganRevisi),
          service: MockKoreksiService(),
        ),
      );

      expect(find.byKey(const ValueKey('keputusan-koreksi')), findsOneWidget);
      expect(
        find.text('Revisi sertifikat sudah diterbitkan.'),
        findsOneWidget,
      );
      expect(find.text('CAL/2026/09/0007-R1'), findsOneWidget);
      expect(find.byKey(const ValueKey('tombol-terima-koreksi')), findsNothing);
    });

    testWidgets('ditolak: tanggapan ditampilkan', (tester) async {
      await _pasang(
        tester,
        _app(
          const DetailKoreksiScreen(koreksiId: _ditolak),
          service: MockKoreksiService(),
        ),
      );
      expect(
        find.text('Rentang mengikuti spesifikasi pabrik, tidak bisa diubah.'),
        findsOneWidget,
      );
    });

    testWidgets('tautan nomor sertifikat membuka detail sertifikat', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailKoreksiScreen(koreksiId: _sertifikat),
          service: MockKoreksiService(),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tautan-koreksi-sertifikat')));
      await tester.pumpAndSettle();
      expect(find.text('Status dokumen'.toUpperCase()), findsOneWidget);
    });
  });

  group('terima', () {
    Future<MockKoreksiService> bukaLembar(
      WidgetTester tester,
      int id, {
      MockKoreksiService? service,
    }) async {
      final svc = service ?? MockKoreksiService();
      await _pasang(
        tester,
        _app(DetailKoreksiScreen(koreksiId: id), service: svc),
      );
      await tester.tap(find.byKey(const ValueKey('tombol-terima-koreksi')));
      await tester.pumpAndSettle();
      return svc;
    }

    testWidgets('tanpa membetulkan: terkirim tanpa perubahan, status diterima', (
      tester,
    ) async {
      final svc = await bukaLembar(tester, _alat);
      expect(find.byKey(const ValueKey('lembar-terima-koreksi')), findsOne);
      // Nilai yang diminta pelanggan jadi isian awal.
      expect(find.widgetWithText(TextField, 'HI2211-0419'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kirim-terima-koreksi')));
      await tester.pumpAndSettle();

      expect(svc.diterimaDengan.single.id, _alat);
      // Tidak ada nilai yang dibetulkan → `perubahan` kosong.
      expect(svc.diterimaDengan.single.perubahan, isEmpty);
      expect(find.byKey(const ValueKey('lembar-terima-koreksi')), findsNothing);
      expect(find.text('Koreksi diterima dan diterapkan.'), findsOneWidget);
      expect(find.byKey(const ValueKey('tombol-terima-koreksi')), findsNothing);
    });

    testWidgets('nilai yang dibetulkan + tanggapan dikirim; sisanya tidak', (
      tester,
    ) async {
      final svc = await bukaLembar(tester, _sertifikat);
      await tester.enterText(
        find.byKey(const ValueKey('isian-terima-alamat')),
        'Jl. Contoh Raya 12, Bandung',
      );
      await tester.enterText(
        find.byKey(const ValueKey('isian-terima-tanggapan')),
        'Sudah kami perbaiki.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('isian-terima-alasan')),
        'Alamat pindah',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-terima-koreksi')));
      await tester.pumpAndSettle();

      final k = svc.diterimaDengan.single;
      expect(k.perubahan, {'alamat': 'Jl. Contoh Raya 12, Bandung'});
      expect(k.tanggapan, 'Sudah kami perbaiki.');
      // Koreksi sertifikat: server menerbitkan revisi, nomornya diumumkan.
      expect(find.textContaining('CAL/2026/09/0011-R1'), findsWidgets);
    });

    testWidgets('alasan revisi hanya ada untuk koreksi sertifikat', (
      tester,
    ) async {
      await bukaLembar(tester, _alat);
      expect(find.byKey(const ValueKey('isian-terima-alasan')), findsNothing);
    });

    testWidgets('422 nomor seri bentrok tampil di bawah kolomnya, lembar tetap', (
      tester,
    ) async {
      final svc = await bukaLembar(tester, _alat);
      await tester.enterText(
        find.byKey(const ValueKey('isian-terima-serial_number')),
        'BENTROK-01',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-terima-koreksi')));
      await tester.pumpAndSettle();

      expect(
        find.text('Nomor seri sudah dipakai alat lain di lab ini.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('lembar-terima-koreksi')), findsOne);
      expect(svc.diterimaDengan, isEmpty);
      // Isian tidak hilang.
      expect(find.widgetWithText(TextField, 'BENTROK-01'), findsOneWidget);
    });

    testWidgets('isian yang dikosongkan ditolak sebelum ke server', (
      tester,
    ) async {
      final svc = await bukaLembar(tester, _alat);
      await tester.enterText(
        find.byKey(const ValueKey('isian-terima-serial_number')),
        '',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-terima-koreksi')));
      await tester.pumpAndSettle();

      expect(find.text('Nilai tidak boleh kosong.'), findsOneWidget);
      expect(svc.diterimaDengan, isEmpty);
    });

    testWidgets('sudah diputus admin lain: {message} tampil di lembar', (
      tester,
    ) async {
      final svc = MockKoreksiService();
      await bukaLembar(tester, _alat, service: svc);
      // Admin lain memutuskannya lebih dulu, diam-diam di server.
      await svc.tolak('t', _alat, 'Sudah ditolak admin lain.');

      await tester.tap(find.byKey(const ValueKey('kirim-terima-koreksi')));
      await tester.pumpAndSettle();

      expect(find.text('Koreksi ini sudah diputuskan.'), findsOneWidget);
      expect(find.byKey(const ValueKey('lembar-terima-koreksi')), findsOne);
    });
  });

  group('tolak', () {
    Future<MockKoreksiService> bukaDialog(WidgetTester tester) async {
      final svc = MockKoreksiService();
      await _pasang(
        tester,
        _app(const DetailKoreksiScreen(koreksiId: _alat), service: svc),
      );
      await tester.tap(find.byKey(const ValueKey('tombol-tolak-koreksi')));
      await tester.pumpAndSettle();
      return svc;
    }

    testWidgets('tanggapan wajib: kosong tidak terkirim', (tester) async {
      final svc = await bukaDialog(tester);
      await tester.tap(find.byKey(const ValueKey('kirim-tolak-koreksi')));
      await tester.pumpAndSettle();

      expect(find.text('Tanggapan wajib diisi.'), findsOneWidget);
      expect(svc.ditolakDengan, isEmpty);
      expect(find.byKey(const ValueKey('dialog-tolak-koreksi')), findsOne);
    });

    testWidgets('ditulis: ditolak, dialog menutup, tanggapan tampil', (
      tester,
    ) async {
      final svc = await bukaDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('isian-tolak-koreksi')),
        'Nomor seri sudah sesuai pelat nama.',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-tolak-koreksi')));
      await tester.pumpAndSettle();

      expect(
        svc.ditolakDengan.single.tanggapan,
        'Nomor seri sudah sesuai pelat nama.',
      );
      expect(find.byKey(const ValueKey('dialog-tolak-koreksi')), findsNothing);
      expect(find.text('Koreksi ditolak.'), findsOneWidget);
      expect(
        find.text('Nomor seri sudah sesuai pelat nama.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('tombol-tolak-koreksi')), findsNothing);
    });
  });

  group('notifikasi & realtime', () {
    testWidgets('tautan koreksi_pelanggan membuka detail koreksi', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => bukaTautanNotifikasi(
                  context,
                  const NotifTautan(tipe: 'koreksi_pelanggan', id: _alat),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
          service: MockKoreksiService(),
        ),
      );

      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      expect(find.byType(DetailKoreksiScreen), findsOneWidget);
      expect(find.text('Koreksi #7'), findsOneWidget);
    });

    test('data.berubah menarik ulang antrean, badge, dan detail koreksi', () async {
      final rt = MockRealtimeService();
      final svc = _HitungKoreksi();
      final container = ProviderContainer(
        overrides: [
          realtimeServiceProvider.overrideWithValue(rt),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_admin)),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          notificationServiceProvider.overrideWithValue(
            MockNotificationService(),
          ),
          koreksiServiceProvider.overrideWithValue(svc),
        ],
      );
      addTearDown(container.dispose);

      container.listen(realtimeSyncProvider, (_, _) {});
      container.listen(antreanKoreksiProvider, (_, _) {});
      container.listen(jumlahKoreksiMenungguProvider, (_, _) {});
      container.listen(detailKoreksiProvider(_alat), (_, _) {});

      await container.read(authProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.read(antreanKoreksiProvider.future);
      await container.read(jumlahKoreksiMenungguProvider.future);
      await container.read(detailKoreksiProvider(_alat).future);
      final daftar = svc.daftarDipanggil;
      final detail = svc.detailDipanggil;

      rt.pancarkan(
        const DataBerubah(jenis: 'koreksi_pelanggan', aksi: 'dibuat', id: 9),
      );
      await Future<void>.delayed(Duration.zero);
      await container.read(antreanKoreksiProvider.future);
      await container.read(jumlahKoreksiMenungguProvider.future);
      await container.read(detailKoreksiProvider(_alat).future);

      // Antrean + badge (dua `daftar`) dan detail yang terbuka.
      expect(svc.daftarDipanggil, daftar + 2);
      expect(svc.detailDipanggil, detail + 1);
    });

    test('jenis sertifikat menarik ulang detail sertifikat yang terbuka', () async {
      final rt = MockRealtimeService();
      final sert = _HitungSertifikat();
      final container = ProviderContainer(
        overrides: [
          realtimeServiceProvider.overrideWithValue(rt),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_admin)),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          notificationServiceProvider.overrideWithValue(
            MockNotificationService(),
          ),
          koreksiServiceProvider.overrideWithValue(MockKoreksiService()),
          certificateServiceProvider.overrideWithValue(sert),
        ],
      );
      addTearDown(container.dispose);

      container.listen(realtimeSyncProvider, (_, _) {});
      container.listen(certificateDetailProvider(1), (_, _) {});
      await container.read(authProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.read(certificateDetailProvider(1).future);
      final sebelum = sert.dipanggil;

      rt.pancarkan(
        const DataBerubah(jenis: 'sertifikat', aksi: 'direvisi', id: 1),
      );
      await Future<void>.delayed(Duration.zero);
      await container.read(certificateDetailProvider(1).future);

      expect(sert.dipanggil, sebelum + 1);
    });
  });
}

class _HitungKoreksi extends MockKoreksiService {
  int daftarDipanggil = 0;
  int detailDipanggil = 0;

  @override
  Future<HalamanKoreksi> daftar(
    String token, {
    String status = SaringanKoreksi.menunggu,
    int perPage = 20,
  }) {
    daftarDipanggil++;
    return super.daftar(token, status: status, perPage: perPage);
  }

  @override
  Future<Koreksi> detail(String token, int id) {
    detailDipanggil++;
    return super.detail(token, id);
  }
}

class _HitungSertifikat extends MockCertificateService {
  int dipanggil = 0;

  @override
  Future<CertificateDetail> detail(String token, int certificateId) {
    dipanggil++;
    return super.detail(token, certificateId);
  }
}
