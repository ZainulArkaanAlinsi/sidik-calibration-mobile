import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/klien_http_beridentitas.dart';

/// Titik sambung header identitas klien (dipasang Sidik Studio, ST-T-012).
///
/// Dua hal yang dijaga:
///  1. Klien yang MEMASANG pembungkus ini mengirim header-nya di SEMUA jalur
///     `ApiClient` (JSON, multipart, byte, GET bersyarat) tanpa mengubah
///     header lain.
///  2. App lapangan — `apiClientProvider` bawaan — TIDAK ikut mengirimnya.
void main() {
  const identitas = {'X-Klien': 'klien-uji', 'X-Versi-Klien': '9.9.9+9'};

  late List<http.BaseRequest> masuk;
  late int statusJawab;

  MockClient palsu() => MockClient((req) async {
    masuk.add(req);
    return http.Response(
      statusJawab == 200 ? '{"data":{"ok":true}}' : '{"message":"ditolak"}',
      statusJawab,
      headers: const {'content-type': 'application/json'},
    );
  });

  setUp(() {
    masuk = [];
    statusJawab = 200;
  });

  group('pembungkus terpasang', () {
    test(
      'header identitas ikut di semua jalur ApiClient, header lain utuh',
      () async {
        final api = ApiClient(
          baseUrl: 'http://uji/api',
          client: KlienHttpBeridentitas(header: identitas, dalam: palsu()),
        );

        await api.get('/a', token: 't1');
        await api.post('/b', token: 't1', body: {'x': 1});
        await api.put('/c', token: 't1');
        await api.patch('/d', token: 't1');
        await api.delete('/e', token: 't1');
        await api.getBersyarat('/f', token: 't1', etag: '"abc"');
        await api.ambilBytes('/g', token: 't1');
        await api.unggahBanyak(
          '/h',
          token: 't1',
          body: {'sel': 1},
          berkas: {'citra': (namaBerkas: 'a.png', isi: Uint8List(3))},
        );

        expect(masuk, hasLength(8));
        for (final r in masuk) {
          expect(r.headers['x-klien'], 'klien-uji', reason: r.url.path);
          expect(r.headers['x-versi-klien'], '9.9.9+9', reason: r.url.path);
          expect(r.headers['authorization'], 'Bearer t1', reason: r.url.path);
        }
        // Header khusus jalur tidak tergeser.
        expect(masuk[0].headers['content-type'], 'application/json');
        expect(masuk[5].headers['if-none-match'], '"abc"');
        expect(masuk[7].headers['content-type'], startsWith('multipart/'));
      },
    );

    test('pengamat menerima status + apakah request bertoken; galat tetap '
        'dilempar seperti biasa', () async {
      final teramati = <ResponsTeramati>[];
      final api = ApiClient(
        baseUrl: 'http://uji/api',
        client: KlienHttpBeridentitas(
          header: identitas,
          pengamat: teramati.add,
          dalam: palsu(),
        ),
      );

      statusJawab = 401;
      await expectLater(
        api.get('/me', token: 'kedaluwarsa'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
      // Login salah sandi juga 401 — tapi berangkat tanpa token.
      await expectLater(
        api.post('/login', body: {'identifier': 'x', 'password': 'y'}),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );

      expect(teramati.map((r) => (r.status, r.berToken)), [
        (401, true),
        (401, false),
      ]);
      // Token MANA yang dibawa — sidiknya, bukan tokennya.
      expect(teramati[0].sidikToken, sidikTokenBearer('kedaluwarsa'));
      expect(teramati[0].sidikToken, isNot(sidikTokenBearer('baru')));
      expect(teramati[1].sidikToken, isNull);
    });

    test('sidik dari header Authorization = sidik token mentahnya', () {
      expect(sidikDariOtorisasi('Bearer t1'), sidikTokenBearer('t1'));
      expect(sidikDariOtorisasi('bearer t1'), sidikTokenBearer('t1'));
      expect(sidikDariOtorisasi(null), isNull);
    });

    test('pengamat yang melempar tidak merusak jawaban server', () async {
      final api = ApiClient(
        baseUrl: 'http://uji/api',
        client: KlienHttpBeridentitas(
          header: identitas,
          pengamat: (_) => throw StateError('pengamat rusak'),
          dalam: palsu(),
        ),
      );

      expect(await api.get('/a'), {
        'data': {'ok': true},
      });
    });

    test('header pemanggil bernama sama ditimpa nilai identitas', () async {
      final klien = KlienHttpBeridentitas(header: identitas, dalam: palsu());
      await klien.get(Uri.parse('http://uji/x'), headers: {'x-klien': 'palsu'});
      expect(masuk.single.headers['x-klien'], 'klien-uji');
    });
  });

  test('app lapangan (apiClientProvider bawaan) TIDAK mengirim header '
      'identitas apa pun', () async {
    // `runWithClient`: `http.Client()` yang dibangun `ApiClient()` bawaan di
    // dalam zona ini = client palsu, jadi request-nya bisa diperiksa tanpa
    // menyentuh `apiClientProvider` sama sekali.
    await http.runWithClient(() async {
      final wadah = ProviderContainer();
      addTearDown(wadah.dispose);

      await wadah.read(apiClientProvider).get('/me', token: 't1');
    }, palsu);

    final r = masuk.single;
    expect(r.headers['authorization'], 'Bearer t1');
    expect(
      r.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('x-klien')),
    );
    expect(
      r.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('x-versi-klien')),
    );
    expect(jsonEncode(r.headers), isNot(contains('sidik-studio')));
  });
}
