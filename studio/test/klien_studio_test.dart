import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_studio/inti/lingkungan_studio.dart';
import 'package:sidik_studio/inti/penimpaan.dart';
import 'package:sidik_studio/inti/sesi_studio.dart';

/// FR-STU-003/004 ujung ke ujung: `ApiClient` yang dipakai Studio (penimpaan
/// PRODUKSI `penimpaanStudio`) menembak server HTTP sungguhan di loopback.
///
/// Yang dibuktikan di sini, bukan di widget test:
///  - header `X-Klien` & `X-Versi-Klien` benar-benar sampai di server, di
///    jalur JSON, pemanasan `/health`, maupun multipart;
///  - `401` pada request BERTOKEN → keadaan sesi berakhir; `401` login (tanpa
///    token) tidak;
///  - `426` → klien kedaluwarsa, walau ST-T-013 server belum mengirimnya.
void main() {
  test('versiStudio = version di pubspec.yaml Studio', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final versi = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    expect(versiStudio, versi);
    expect(headerKlienStudio, {
      'X-Klien': 'sidik-studio',
      'X-Versi-Klien': versi,
    });
  });

  test('hostServer menampilkan host:port', () {
    expect(hostServer('http://127.0.0.1:8000/api'), '127.0.0.1:8000');
    expect(
      hostServer('https://sidik-calibration-api.onrender.com/api'),
      'sidik-calibration-api.onrender.com',
    );
    expect(hostServer('bukan url'), 'bukan url');
  });

  group('server loopback', () {
    late HttpServer server;
    late List<({String jalur, HttpHeaders header})> masuk;
    late ProviderContainer wadah;

    setUp(() async {
      // Widget test di file lain memasang HttpOverrides tiruan (semua 400);
      // file ini sengaja memakai klien HTTP asli.
      HttpOverrides.global = null;

      masuk = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        await req.drain<void>();
        final jalur = req.uri.path.replaceFirst('/api', '');
        masuk.add((jalur: jalur, header: req.headers));

        final (status, badan) = switch (jalur) {
          '/health' => (200, {'status': 'ok'}),
          '/me/permissions' => (200, {'role': 'admin', 'boleh': <String>[]}),
          '/unggah' => (200, {'data': {}}),
          '/login' => (401, {'message': 'Salah sandi.'}),
          '/token-basi' => (401, {'message': 'Unauthenticated.'}),
          '/versi-lama' => (
            426,
            {'kode': 'klien_kedaluwarsa', 'message': 'Perbarui Studio.'},
          ),
          _ => (404, {'message': 'Tidak ada.'}),
        };
        req.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(badan));
        await req.response.close();
      });

      wadah = ProviderContainer(
        overrides: [
          ...penimpaanStudio,
          alamatServerStudioProvider.overrideWithValue(
            'http://127.0.0.1:${server.port}/api',
          ),
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
        ],
      );
      // Ada akun yang masuk (Budi, admin) — 401 bertoken berarti sesinya.
      await wadah.read(authProvider.future);
    });

    tearDown(() async {
      wadah.dispose();
      await server.close(force: true);
    });

    test('X-Klien & X-Versi-Klien sampai di server di semua jalur', () async {
      final api = wadah.read(apiClientProvider);

      // POST tanpa client_request_id dari client yang belum pernah
      // tersambung: didahului pemanasan GET /health (`_pastikanBangun`).
      await expectLater(
        api.post('/login', body: {'identifier': 'x', 'password': 'y'}),
        throwsA(isA<ApiException>()),
      );
      await api.get('/me/permissions', token: 'mock-token-1');
      await api.unggahBanyak(
        '/unggah',
        token: 'mock-token-1',
        body: {'a': 1},
        berkas: {'f': (namaBerkas: 'a.bin', isi: Uint8List(2))},
      );

      expect(masuk.map((r) => r.jalur), [
        '/health',
        '/login',
        '/me/permissions',
        '/unggah',
      ]);
      for (final r in masuk) {
        expect(r.header.value('x-klien'), 'sidik-studio', reason: r.jalur);
        expect(r.header.value('x-versi-klien'), versiStudio, reason: r.jalur);
      }
      expect(masuk[2].header.value('authorization'), 'Bearer mock-token-1');
      expect(masuk[1].header.value('authorization'), isNull);
    });

    test(
      '401 login (tanpa token) BUKAN sesi berakhir; 401 bertoken ya',
      () async {
        final api = wadah.read(apiClientProvider);

        await expectLater(
          api.post('/login', body: {'identifier': 'x', 'password': 'y'}),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
        );
        expect(wadah.read(sesiStudioProvider), KeadaanSesiStudio.aktif);

        await expectLater(
          api.get('/token-basi', token: 'mock-token-1'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
        );
        expect(wadah.read(sesiStudioProvider), KeadaanSesiStudio.berakhir);
      },
    );

    test('masuk ulang: 401 atas token lama yang baru berangkat sesudahnya '
        'TIDAK memunculkan dialog kedua; 401 atas token baru ya', () async {
      final api = wadah.read(apiClientProvider);
      final sesi = wadah.read(sesiStudioProvider.notifier);

      await expectLater(
        api.get('/token-basi', token: 'mock-token-1'),
        throwsA(isA<ApiException>()),
      );
      expect(wadah.read(sesiStudioProvider), KeadaanSesiStudio.berakhir);

      sesi.pulih(tokenBaru: 'token-baru-2');

      // Header token LAMA, berangkat SESUDAH masuk ulang.
      await expectLater(
        api.get('/token-basi', token: 'mock-token-1'),
        throwsA(isA<ApiException>()),
      );
      expect(wadah.read(sesiStudioProvider), KeadaanSesiStudio.aktif);

      await expectLater(
        api.get('/token-basi', token: 'token-baru-2'),
        throwsA(isA<ApiException>()),
      );
      expect(wadah.read(sesiStudioProvider), KeadaanSesiStudio.berakhir);
    });

    test('426 → klien kedaluwarsa', () async {
      final api = wadah.read(apiClientProvider);
      expect(wadah.read(klienKedaluwarsaProvider), isFalse);

      await expectLater(
        api.get('/versi-lama', token: 'mock-token-1'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 426)),
      );
      expect(wadah.read(klienKedaluwarsaProvider), isTrue);
    });
  });
}
