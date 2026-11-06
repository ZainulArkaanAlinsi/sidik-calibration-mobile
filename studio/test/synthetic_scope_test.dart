import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../integration_test/synthetic_scope.dart';

Map<String, dynamic> _manifest() => {
  'schema_version': 1,
  'run_id': 'guard-run',
  'api_sha': List.filled(40, 'a').join(),
  'mobile_sha': List.filled(40, 'b').join(),
  'api_base_url': 'http://127.0.0.1:18761/api',
  'organization_id': 1,
  'user_email': 'studio@synthetic.test',
  'baseline': <String, dynamic>{},
  'workbook': {
    'id': 4,
    'name': 'E2E_SYNTHETIC_guard-run',
    'sheets': [
      {
        'id': 8,
        'name': 'INPUT_SYNTHETIC',
        'expected_cells': [
          {'address': 'A1', 'text': 'E2E INPUT guard-run'},
          {'address': 'B2', 'text': '3', 'formula': '=1+2'},
        ],
      },
      {
        'id': 9,
        'name': 'DISPLAY_SYNTHETIC',
        'expected_cells': [
          {'address': 'A1', 'text': 'E2E DISPLAY guard-run'},
          {'address': 'B2', 'text': '2.5'},
        ],
      },
    ],
  },
};

/// Spy only for transport guard tests; the integration scope uses IOClient.
class _Spy extends http.BaseClient {
  _Spy({this.status = 200});
  final int status;
  int calls = 0;
  bool? followedRedirects;
  int? maxRedirects;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    followedRedirects = request.followRedirects;
    maxRedirects = request.maxRedirects;
    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
      status,
      headers: {'location': 'https://outside.invalid/never-follow'},
    );
  }
}

void main() {
  final endpoint = SyntheticEndpoint('http://127.0.0.1:18761/api');

  for (final (index, bad) in [
    'https://127.0.0.1:18761/api',
    'http://outside.invalid:18761/api',
    'http://localhost:18761/api',
    'http://127.0.0.1:18762/api',
    'http://user:password@127.0.0.1:18761/api',
    'http://127.0.0.1:18761/api#fragment',
  ].indexed) {
    test('reject target case $index before delegate', () async {
      final spy = _Spy();
      final audit = SyntheticTransportAudit(endpoint);
      final client = SyntheticLoopbackClient(endpoint, spy, audit: audit);
      addTearDown(client.close);
      await expectLater(
        client.get(Uri.parse(bad)),
        throwsA(isA<HttpException>()),
      );
      expect(spy.calls, 0);
      expect(audit.failures, hasLength(1));
    });
  }

  for (final status in [301, 302, 303, 307, 308, 403, 500]) {
    test('reject HTTP $status without following redirects', () async {
      final spy = _Spy(status: status);
      final client = SyntheticLoopbackClient(endpoint, spy);
      addTearDown(client.close);
      await expectLater(
        client.get(endpoint.marker),
        throwsA(isA<HttpException>()),
      );
      expect(spy.calls, 1);
      expect(spy.followedRedirects, isFalse);
      expect(spy.maxRedirects, 0);
    });
  }

  test('allowed target uses delegate with redirects disabled', () async {
    final spy = _Spy();
    final client = SyntheticLoopbackClient(endpoint, spy);
    addTearDown(client.close);
    expect((await client.get(endpoint.marker)).statusCode, 200);
    expect(spy.calls, 1);
    expect(spy.followedRedirects, isFalse);
    expect(spy.maxRedirects, 0);
  });

  test(
    'marker binds all identities, environment, driver and manifest bytes',
    () {
      final manifest = SyntheticManifest(
        _manifest(),
        expectedRunId: 'guard-run',
      );
      final hash = List.filled(64, 'c').join();
      final marker = {
        for (final key in ['schema_version', 'run_id', 'api_sha', 'mobile_sha'])
          key: manifest.json[key],
        'app_env': 'testing',
        'db_driver': 'sqlite',
        'manifest_sha256': hash,
      };
      manifest.checkMarker(marker, hash);
      for (final key in marker.keys) {
        expect(
          () => manifest.checkMarker({...marker, key: 'wrong'}, hash),
          throwsFormatException,
          reason: 'Mismatched $key must fail before login.',
        );
      }
    },
  );

  test('manifest rejects schema/run-id and missing stored formula oracle', () {
    final invalid = _manifest()..['schema_version'] = 2;
    expect(
      () => SyntheticManifest(invalid, expectedRunId: 'guard-run'),
      throwsFormatException,
    );
    expect(
      () => SyntheticManifest(_manifest(), expectedRunId: 'another-run'),
      throwsFormatException,
    );
    final missing = _manifest();
    final workbook = missing['workbook'] as Map;
    final sheets = workbook['sheets'] as List;
    final cells = (sheets.first as Map)['expected_cells'] as List;
    (cells.last as Map).remove('formula');
    expect(
      () => SyntheticManifest(missing, expectedRunId: 'guard-run'),
      throwsFormatException,
    );
  });
}
