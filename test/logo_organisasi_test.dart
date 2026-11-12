import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/logo_organisasi.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/logo_organisasi_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/screens/settings/logo_organisasi_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/logo_organisasi_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Client palsu yang mencatat request (termasuk multipart) dan menjawab sesuai
/// [jawab]. `MultipartRequest.send()` membuat client sendiri, jadi unggahan
/// hanya bisa dites lewat client yang disuntik ke `ApiClient`.
class _ClientPalsu extends http.BaseClient {
  _ClientPalsu(this.jawab);

  final (int, Object) Function(http.BaseRequest) jawab;
  final permintaan = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    permintaan.add(request);
    await request.finalize().toBytes();
    final (status, body) = jawab(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }
}

/// Logo berbeda per token — untuk membuktikan ganti akun menarik ulang.
class _LogoPerAkun implements LogoOrganisasiService {
  final tokenDipakai = <String>[];

  @override
  Future<LogoOrganisasi> ambil(String token) async {
    tokenDipakai.add(token);
    return LogoOrganisasi(url: 'https://contoh.test/logo-$token.png');
  }

  @override
  Future<LogoOrganisasi> unggah(String token, String filePath) =>
      throw UnimplementedError();

  @override
  Future<void> hapus(String token) => throw UnimplementedError();
}

/// Unggahan ditolak server dengan 422 (WEBP). Pesan aslinya harus sampai ke layar.
class _TolakUnggah extends MockLogoOrganisasiService {
  @override
  Future<LogoOrganisasi> unggah(String token, String filePath) async {
    throw const ApiException(
      'Format logo harus PNG atau JPG — WEBP nggak bisa dicetak di PDF sertifikat.',
      status: 422,
    );
  }
}

/// Unggahan gagal dengan galat teknis (bukan pesan untuk user).
class _GalatTeknis extends MockLogoOrganisasiService {
  @override
  Future<LogoOrganisasi> unggah(String token, String filePath) async {
    throw StateError('detail internal yang tidak boleh bocor');
  }
}

Widget _app(
  LogoOrganisasiService service, {
  String token = 'mock-token-1',
  Izin izin = Izin.kosong,
  PemilihBerkasLogo? pilih,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
      logoOrganisasiServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LogoOrganisasiScreen(pilihBerkas: pilih),
    ),
  );
}

Future<void> _pasang(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

Future<BerkasLogo?> _pilihKecil() async =>
    (path: '/tmp/logo.png', ukuran: 80 * 1024);

void main() {
  group('LogoOrganisasi', () {
    test('logo_url terbaca; null dan string kosong = belum ada logo', () {
      final ada = LogoOrganisasi.fromJson({
        'logo_url': 'https://lab.test/storage/logo-organisasi/1/abc.png',
      });
      expect(ada.ada, isTrue);
      expect(ada.url, 'https://lab.test/storage/logo-organisasi/1/abc.png');

      expect(LogoOrganisasi.fromJson({'logo_url': null}).ada, isFalse);
      expect(LogoOrganisasi.fromJson({'logo_url': ''}).ada, isFalse);
      expect(LogoOrganisasi.fromJson(const {}).ada, isFalse);
    });
  });

  group('ApiLogoOrganisasiService', () {
    late Directory dir;
    late File logo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('sidik-logo');
      logo = File('${dir.path}/logo.png')..writeAsBytesSync([1, 2, 3, 4]);
    });

    tearDown(() => dir.deleteSync(recursive: true));

    ApiLogoOrganisasiService layanan(_ClientPalsu c) =>
        ApiLogoOrganisasiService(
          ApiClient(client: c, baseUrl: 'http://contoh.test/api'),
        );

    test('ambil: GET /organization, logo_url dibaca dari data', () async {
      final c = _ClientPalsu(
        (_) => (
          200,
          {
            'data': {'nama': 'PT Sidik', 'logo_url': 'https://lab.test/l.png'},
          },
        ),
      );

      final hasil = await layanan(c).ambil('tkn');

      expect(c.permintaan.single.method, 'GET');
      expect(c.permintaan.single.url.path, '/api/organization');
      expect(c.permintaan.single.headers['Authorization'], 'Bearer tkn');
      expect(hasil.url, 'https://lab.test/l.png');
    });

    test('unggah: multipart POST /organization/logo, field `logo`', () async {
      final c = _ClientPalsu(
        (_) => (
          200,
          {
            'data': {'logo_url': 'https://lab.test/baru.png'},
          },
        ),
      );

      final hasil = await layanan(c).unggah('tkn', logo.path);

      final req = c.permintaan.single as http.MultipartRequest;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/organization/logo');
      expect(req.headers['Authorization'], 'Bearer tkn');
      expect(req.files.single.field, 'logo');
      expect(hasil.url, 'https://lab.test/baru.png');
    });

    test('hapus: DELETE /organization/logo', () async {
      final c = _ClientPalsu((_) => (200, {'data': {}}));

      await layanan(c).hapus('tkn');

      expect(c.permintaan.single.method, 'DELETE');
      expect(c.permintaan.single.url.path, '/api/organization/logo');
    });

    test('422 server (WEBP/ukuran): pesan aslinya yang sampai', () async {
      final c = _ClientPalsu(
        (_) => (
          422,
          {
            'message':
                'Format logo harus PNG atau JPG — WEBP nggak bisa dicetak di PDF sertifikat.',
          },
        ),
      );

      await expectLater(
        layanan(c).unggah('tkn', logo.path),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 422)
              .having((e) => e.message, 'message', contains('WEBP')),
        ),
      );
    });

    test('403 (bukan admin) dan 404 dilempar sebagai ApiException', () async {
      for (final status in [403, 404]) {
        final c = _ClientPalsu((_) => (status, <String, dynamic>{}));
        await expectLater(
          layanan(c).hapus('tkn'),
          throwsA(
            isA<ApiException>().having((e) => e.status, 'status', status),
          ),
        );
      }
    });
  });

  group('Provider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'GANTI AKUN: logo lab sebelumnya tidak ikut, server ditanya ulang',
      () async {
        final service = _LogoPerAkun();
        final w = ProviderContainer(
          overrides: [
            tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
            authServiceProvider.overrideWithValue(
              MockAuthService(jeda: Duration.zero),
            ),
            sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
            logoOrganisasiServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(w.dispose);

        await w
            .read(authProvider.notifier)
            .login(identifier: 'SDK-0001', password: 'rahasia123');
        final langganan = w.listen(logoOrganisasiProvider, (_, _) {});
        addTearDown(langganan.close);
        expect(
          (await w.read(logoOrganisasiProvider.future)).url,
          'https://contoh.test/logo-mock-token-1.png',
        );

        await w.read(authProvider.notifier).logout();
        await w
            .read(authProvider.notifier)
            .login(identifier: 'SDK-0002', password: 'rahasia123');

        expect(
          (await w.read(logoOrganisasiProvider.future)).url,
          'https://contoh.test/logo-mock-token-2.png',
        );
        // Token A dipakai untuk A, token B untuk B. Jumlah tarikan untuk A tidak
        // dipatok: perubahan status auth bisa membangun ulang provider lebih
        // dari sekali. Yang wajib: tarikan TERAKHIR memakai token B.
        expect(service.tokenDipakai.first, 'mock-token-1');
        expect(service.tokenDipakai.last, 'mock-token-2');
      },
    );
  });

  group('Layar Logo kop sertifikat', () {
    testWidgets('belum ada logo: penjelasan + hanya tombol Unggah', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(MockLogoOrganisasiService(), pilih: _pilihKecil),
      );

      expect(find.text('Logo kop sertifikat'), findsOneWidget);
      expect(find.textContaining('Belum ada logo khusus'), findsOneWidget);
      expect(find.textContaining('maksimal 2 MB'), findsOneWidget);
      expect(find.text('Unggah logo'), findsOneWidget);
      expect(find.text('Hapus logo'), findsNothing);
    });

    testWidgets(
      'unggah: berkas pilihan dikirim ke service, tombol berubah jadi Ganti/Hapus',
      (tester) async {
        final service = MockLogoOrganisasiService();
        await _pasang(tester, _app(service, pilih: _pilihKecil));

        await tester.tap(find.text('Unggah logo'));
        await tester.pumpAndSettle();

        expect(service.berkasTerakhir, '/tmp/logo.png');
        expect(find.text('Logo diunggah.'), findsOneWidget);
        expect(find.text('Ganti logo'), findsOneWidget);
        expect(find.text('Hapus logo'), findsOneWidget);
      },
    );

    testWidgets('berkas lebih dari 2 MB ditolak di layar, TIDAK dikirim', (
      tester,
    ) async {
      final service = MockLogoOrganisasiService();
      await _pasang(
        tester,
        _app(
          service,
          pilih: () async =>
              (path: '/tmp/besar.jpg', ukuran: 2 * 1024 * 1024 + 1),
        ),
      );

      await tester.tap(find.text('Unggah logo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('lebih dari 2 MB'), findsOneWidget);
      expect(service.berkasTerakhir, isNull);
    });

    testWidgets('tepat 2 MB masih boleh (batas server `max:2048` KB)', (
      tester,
    ) async {
      final service = MockLogoOrganisasiService();
      await _pasang(
        tester,
        _app(
          service,
          pilih: () async => (path: '/tmp/pas.png', ukuran: 2 * 1024 * 1024),
        ),
      );

      await tester.tap(find.text('Unggah logo'));
      await tester.pumpAndSettle();

      expect(service.berkasTerakhir, '/tmp/pas.png');
    });

    testWidgets('picker dibatalkan: tidak ada yang terkirim', (tester) async {
      final service = MockLogoOrganisasiService();
      await _pasang(tester, _app(service, pilih: () async => null));

      await tester.tap(find.text('Unggah logo'));
      await tester.pumpAndSettle();

      expect(service.berkasTerakhir, isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('422 server (WEBP): pesan server ditampilkan apa adanya', (
      tester,
    ) async {
      await _pasang(tester, _app(_TolakUnggah(), pilih: _pilihKecil));

      await tester.tap(find.text('Unggah logo'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Format logo harus PNG atau JPG — WEBP nggak bisa dicetak di PDF sertifikat.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('galat teknis tidak bocor ke layar', (tester) async {
      await _pasang(tester, _app(_GalatTeknis(), pilih: _pilihKecil));

      await tester.tap(find.text('Unggah logo'));
      await tester.pumpAndSettle();

      expect(find.text('Aksi logo gagal. Coba lagi.'), findsOneWidget);
      expect(find.textContaining('detail internal'), findsNothing);
    });

    testWidgets('hapus: wajib konfirmasi; batal tidak menghapus', (
      tester,
    ) async {
      final service = MockLogoOrganisasiService(
        urlAwal: 'https://contoh.test/l.png',
      );
      await _pasang(tester, _app(service, pilih: _pilihKecil));
      expect(find.text('Hapus logo'), findsOneWidget);

      await tester.tap(find.text('Hapus logo'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus logo?'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect((await service.ambil('t')).ada, isTrue);
      expect(find.text('Hapus logo'), findsOneWidget);

      await tester.tap(find.text('Hapus logo'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Hapus logo'),
        ),
      );
      await tester.pumpAndSettle();

      expect((await service.ambil('t')).ada, isFalse);
      expect(
        find.text('Logo dihapus. Kop memakai logo bawaan.'),
        findsOneWidget,
      );
      expect(find.text('Unggah logo'), findsOneWidget);
    });

    testWidgets(
      'server gagal waktu memuat: pesan + Coba lagi yang menarik ulang',
      (tester) async {
        final service = MockLogoOrganisasiService(gagal: true);
        await _pasang(tester, _app(service));

        expect(find.text('Logo belum bisa dimuat.'), findsOneWidget);
        final sebelum = service.jumlahAmbil;

        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();

        expect(service.jumlahAmbil, greaterThan(sebelum));
      },
    );

    testWidgets('teknisi ditolak di layar dan server TIDAK ditanya', (
      tester,
    ) async {
      final service = MockLogoOrganisasiService();
      await _pasang(tester, _app(service, token: 'mock-token-2'));

      expect(find.text('Cuma admin yang bisa atur logo.'), findsOneWidget);
      expect(find.text('Unggah logo'), findsNothing);
      expect(service.jumlahAmbil, 0);
    });

    testWidgets('super admin boleh (K-49-14)', (tester) async {
      await _pasang(
        tester,
        _app(MockLogoOrganisasiService(), token: 'mock-token-5'),
      );

      expect(find.text('Unggah logo'), findsOneWidget);
    });

    testWidgets(
      'gerbang mengikuti /me/permissions: izin organisasi.logo membuka layar',
      (tester) async {
        await _pasang(
          tester,
          _app(
            MockLogoOrganisasiService(),
            token: 'mock-token-2',
            izin: const Izin(
              role: UserRole.teknisi,
              boleh: {NamaIzin.organisasiLogo},
            ),
          ),
        );

        expect(find.text('Unggah logo'), findsOneWidget);
      },
    );
  });
}
