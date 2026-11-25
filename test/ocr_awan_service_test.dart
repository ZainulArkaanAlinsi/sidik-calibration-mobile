import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Method `ocrAwan` di service. Respons PALSU, tanpa jaringan; tidak ada satu
/// pun panggilan ke Google. Yang dibuktikan: bentuk permintaan, pemetaan galat,
/// dan bahwa 429/502 TIDAK diulang otomatis.
void main() {
  group('permintaan', () {
    test('POST ke /worksheet-scans/{id}/ocr-awan, body hanya kunci', () async {
      final client = _Client(200, _respons);
      final service = _service(client);

      final h = await service.ocrAwan(
        'token-uji',
        392,
        kunci: ['tabel_a|1|1|pembacaan', 'tabel_a|2|1|pembacaan'],
      );

      expect(client.permintaan, hasLength(1));

      final p = client.permintaan.single;
      expect(p.method, 'POST');
      expect(p.url.path, '/api/worksheet-scans/392/ocr-awan');
      expect(p.headers['Authorization'], 'Bearer token-uji');
      expect(p.body, {
        'kunci': ['tabel_a|1|1|pembacaan', 'tabel_a|2|1|pembacaan'],
      });

      // Tidak ada gambar, kotak, foto, maupun kunci idempotensi di body.
      expect(p.body.keys, ['kunci']);
      expect(p.body.containsKey('client_request_id'), isFalse);

      expect(h.hasil.single.teksNormal, '4,01');
    });

    test('kunci null = badan kosong, server memilih sendiri selnya', () async {
      final client = _Client(200, _respons);

      await _service(client).ocrAwan('t', 1);

      expect(client.permintaan.single.body, isEmpty);
    });

    test('satu permintaan memuat banyak kunci (tidak per sel)', () async {
      final client = _Client(200, _respons);
      final banyak = [for (var i = 1; i <= maksKunciOcrAwan; i++) 't|$i|1|a'];

      await _service(client).ocrAwan('t', 1, kunci: banyak);

      expect(client.permintaan, hasLength(1));
      expect((client.permintaan.single.body['kunci'] as List), hasLength(48));
    });

    test('kunci salah ditolak SEBELUM jaringan', () async {
      final client = _Client(200, _respons);
      final service = _service(client);

      await expectLater(service.ocrAwan('t', 1, kunci: const []), throwsArgumentError);
      await expectLater(
        service.ocrAwan('t', 1, kunci: ['isian|suhu_awal']),
        throwsArgumentError,
      );
      await expectLater(
        service.ocrAwan('t', 1, kunci: [for (var i = 0; i < 49; i++) 't|$i|1|a']),
        throwsArgumentError,
      );

      expect(client.permintaan, isEmpty, reason: 'tidak memakai jatah server');
    });
  });

  group('galat jatuh ke jalur lama, tidak diulang otomatis', () {
    Future<GalatOcrAwan> panggil(_Client client) async {
      try {
        await _service(client).ocrAwan('t', 1, kunci: ['t|1|1|a']);
      } on GalatOcrAwan catch (e) {
        return e;
      }
      fail('seharusnya melempar GalatOcrAwan');
    }

    final kasus = <(int, Map<String, dynamic>, JenisGalatOcrAwan)>[
      (503, _galat('fitur_dimatikan'), JenisGalatOcrAwan.fiturMati),
      (503, _galat('ocr_cloud_belum_aktif'), JenisGalatOcrAwan.awanBelumSiap),
      (422, _galat('citra_rusak'), JenisGalatOcrAwan.citraBermasalah),
      (422, _galat('gambar_tidak_terbaca'), JenisGalatOcrAwan.tidakTerbaca),
      (429, _galat('batas_per_lembar'), JenisGalatOcrAwan.jatahHabis),
      (429, _galat('gagal_berulang_per_lembar'), JenisGalatOcrAwan.jatahHabis),
      (
        429,
        {'message': 'Terlalu sering.', 'fallback_manual': true},
        JenisGalatOcrAwan.terlaluSering,
      ),
      (502, _galat('ocr_cloud_gagal'), JenisGalatOcrAwan.awanGagal),
    ];

    for (final k in kasus) {
      test('${k.$1} ${k.$2['kode'] ?? 'tanpa kode'} -> ${k.$3.name}, satu kali kirim', () async {
        final client = _Client(k.$1, k.$2);

        final g = await panggil(client);

        expect(g.jenis, k.$3);
        expect(g.fallbackManual, isTrue);
        expect(g.bolehUlangOtomatis, isFalse);
        // Bukti ulang-otomatis TIDAK terjadi: persis satu permintaan sampai
        // ke server walau statusnya 429/502/503.
        expect(client.permintaan, hasLength(1));
      });
    }

    test('429 dan 502 tidak diulang walau diberi waktu', () async {
      for (final status in [429, 502]) {
        final client = _Client(status, _galat('ocr_cloud_gagal'));

        await panggil(client);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(client.permintaan, hasLength(1), reason: 'status $status');
      }
    });

    test('422 validasi tanpa kode tetap ApiException, bukan "pindai ulang"', () async {
      final client = _Client(422, {
        'message': 'Data yang dikirim nggak valid.',
        'errors': {
          'kunci': ['harus larik'],
        },
      });

      await expectLater(
        _service(client).ocrAwan('t', 1, kunci: ['t|1|1|a']),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
      );
      expect(client.permintaan, hasLength(1));
    });

    test('404 (hasil pindai lab/teknisi lain) tetap ApiException', () async {
      final client = _Client(404, {'message': 'Tidak ditemukan.'});

      await expectLater(
        _service(client).ocrAwan('t', 1, kunci: ['t|1|1|a']),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('403 tetap ApiException', () async {
      final client = _Client(403, {'message': 'Dilarang.'});

      await expectLater(
        _service(client).ocrAwan('t', 1),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
    });
  });

  group('MockWorksheetScanService', () {
    test('bawaan meniru produksi: OCR awan belum aktif -> GalatOcrAwan', () async {
      final mock = MockWorksheetScanService();

      await expectLater(
        mock.ocrAwan('t', 1, kunci: ['t|1|1|a']),
        throwsA(
          isA<GalatOcrAwan>().having(
            (e) => e.jenis,
            'jenis',
            JenisGalatOcrAwan.awanBelumSiap,
          ),
        ),
      );
      expect(mock.permintaanOcrAwan, [
        ['t|1|1|a'],
      ]);
    });

    test('hasilOcrAwan dikembalikan, galatOcrAwan menang bila diisi', () async {
      final hasil = HasilOcrAwan.fromJson(_respons);

      expect(
        await MockWorksheetScanService(hasilOcrAwan: hasil).ocrAwan('t', 1),
        same(hasil),
      );

      const galat = GalatOcrAwan(
        status: 502,
        kode: 'ocr_cloud_gagal',
        jenis: JenisGalatOcrAwan.awanGagal,
        pesan: 'x',
      );

      await expectLater(
        MockWorksheetScanService(hasilOcrAwan: hasil, galatOcrAwan: galat).ocrAwan('t', 1),
        throwsA(same(galat)),
      );
    });

    test('mock memakai pemeriksaan kunci yang sama dengan service asli', () async {
      final mock = MockWorksheetScanService();

      await expectLater(
        mock.ocrAwan('t', 1, kunci: ['centang|lulus']),
        throwsArgumentError,
      );
      expect(mock.permintaanOcrAwan, isEmpty);
    });
  });
}

ApiWorksheetScanService _service(_Client client) => ApiWorksheetScanService(
  ApiClient(client: client, baseUrl: 'http://contoh.test/api'),
);

Map<String, dynamic> _galat(String kode) => {
  'message': 'Kalimat tetap dari server.',
  'kode': kode,
  'fallback_manual': true,
};

const _respons = <String, dynamic>{
  'hasil': [
    {
      'kunci': 'tabel_a|1|1|pembacaan',
      'teks_awan': '4.01',
      'keyakinan': 0.93,
      'status': 'kuning',
      'teks_normal': '4,01',
      'nilai_awan': 4.01,
      'dinormalkan': true,
      'alasan': <String>[],
    },
  ],
  'dilewati': <Map<String, dynamic>>[],
  'meta': {'sumber': 'google_vision', 'usulan': true, 'sebagian': false},
};

class _Permintaan {
  _Permintaan(this.method, this.url, this.headers, this.body);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Map<String, dynamic> body;
}

/// Mencatat tiap permintaan yang SAMPAI ke "server", jadi tes bisa menghitung
/// apakah `ApiClient` mengulang.
class _Client extends http.BaseClient {
  _Client(this.status, this.balasan);

  final int status;
  final Map<String, dynamic> balasan;
  final List<_Permintaan> permintaan = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final byte = await request.finalize().toBytes();
    final teks = utf8.decode(byte);

    permintaan.add(
      _Permintaan(
        request.method,
        request.url,
        request.headers,
        teks.isEmpty ? <String, dynamic>{} : jsonDecode(teks) as Map<String, dynamic>,
      ),
    );

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(balasan))),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }
}
