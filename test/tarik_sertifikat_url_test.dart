import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/certificate_service.dart';

/// Mencatat permintaan yang benar-benar keluar dari `ApiCertificateService`.
class _Perekam extends http.BaseClient {
  final permintaan = <http.BaseRequest>[];
  final isi = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    permintaan.add(request);
    isi.add(request is http.Request ? request.body : '');
    return http.StreamedResponse(
      Stream.value(
        utf8.encode('{"data":{"id":42,"nomor":"X/1","status":"ditarik"}}'),
      ),
      200,
    );
  }
}

void main() {
  group('Tarik sertifikat: jalur request', () {
    test('POST ke /certificates/<id>/tarik (ID terisi, bukan kosong)', () async {
      final klien = _Perekam();
      final svc = ApiCertificateService(
        ApiClient(client: klien, baseUrl: 'https://api.test/api'),
        baseUrl: 'https://api.test/api',
      );

      final hasil = await svc.tarik(
        'tok',
        42,
        alasan: '  salah input  ',
        password: 'rahasia',
      );

      expect(klien.permintaan, hasLength(1));
      final r = klien.permintaan.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/api/certificates/42/tarik');
      expect(r.url.path, isNot(contains('//')));
      expect(r.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(klien.isi.single), {
        'alasan': 'salah input',
        'password': 'rahasia',
      });
      expect(hasil.id, 42);
    });
  });
}
