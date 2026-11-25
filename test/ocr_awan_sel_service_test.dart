import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/ocr_awan_sel_service.dart';

import 'support/potongan_sel_contoh.dart';

/// Klien `POST /ocr/sel-awan` (kontrak 22B). Respons PALSU, tanpa jaringan dan
/// tanpa Google. Yang dibuktikan: bentuk permintaan multipart, pemetaan galat,
/// dan bahwa 429/502/503 TIDAK diulang otomatis.
void main() {
  const konteks = KonteksOcrAwanSel(
    templateId: 'ph_meter_0515',
    kodeDokumen: 'F-0515',
  );

  PotonganSelAwan sel(int i, {int lebar = 120}) => PotonganSelAwan(
    kunci: 'tabel_ph|$i|1|pembacaan',
    isi: potonganHeader(lebar: lebar),
  );

  group('permintaan', () {
    test('POST multipart ke /api/ocr/sel-awan dengan kolom kontrak', () async {
      final client = _Client(200, _respons);

      final h = await _service(
        client,
      ).bacaSel('token-uji', konteks: konteks, sel: [sel(1), sel(2)]);

      expect(client.permintaan, hasLength(1));

      final p = client.permintaan.single;
      expect(p.method, 'POST');
      expect(p.url.path, '/api/ocr/sel-awan');
      expect(p.headers['Authorization'], 'Bearer token-uji');
      expect(p.fields, {
        'template_id': 'ph_meter_0515',
        'kertas': 'asli',
        'kode_dokumen': 'F-0515',
        'sel[0][kunci]': 'tabel_ph|1|1|pembacaan',
        'sel[1][kunci]': 'tabel_ph|2|1|pembacaan',
      });
      expect(p.berkas, ['sel[0][gambar]', 'sel[1][gambar]']);

      // Tidak ada kunci idempotensi, foto utuh, atau kotak.
      expect(p.fields.containsKey('client_request_id'), isFalse);
      expect(p.fields.keys.where((k) => k.contains('kotak')), isEmpty);

      expect(h.hasil.single.teksNormal, '4,01');
      expect(h.meta.sisaSelLembar, 120);
    });

    test('kolom opsional hanya dikirim bila ada', () async {
      final client = _Client(200, _respons);

      await _service(client).bacaSel(
        't',
        konteks: const KonteksOcrAwanSel(
          templateId: 'x',
          kertas: 'cetak',
          equipmentId: 9,
          jumlahPengulangan: 3,
          calibrationSessionId: 77,
        ),
        sel: [sel(1)],
      );

      final f = client.permintaan.single.fields;
      expect(f['kertas'], 'cetak');
      expect(f['equipment_id'], '9');
      expect(f['jumlah_pengulangan'], '3');
      expect(f['calibration_session_id'], '77');
      expect(f.containsKey('kode_dokumen'), isFalse);
    });

    test('batas 20 sel per permintaan: 21 ditolak sebelum jaringan', () async {
      final client = _Client(200, _respons);
      final service = _service(client);

      await service.bacaSel(
        't',
        konteks: konteks,
        sel: [for (var i = 1; i <= maksSelPerPermintaanUnggah; i++) sel(i)],
      );
      expect(client.permintaan, hasLength(1));

      await expectLater(
        service.bacaSel(
          't',
          konteks: konteks,
          sel: [
            for (var i = 1; i <= maksSelPerPermintaanUnggah + 1; i++) sel(i),
          ],
        ),
        throwsArgumentError,
      );
      expect(client.permintaan, hasLength(1), reason: 'tidak memakai jatah');
    });

    test('masukan salah ditolak SEBELUM jaringan', () async {
      final client = _Client(200, _respons);
      final service = _service(client);

      Future<void> tolak(List<PotonganSelAwan> isi) => expectLater(
        service.bacaSel('t', konteks: konteks, sel: isi),
        throwsArgumentError,
      );

      await tolak(const []);
      await tolak([
        PotonganSelAwan(kunci: 'isian|suhu', isi: potonganHeader()),
      ]);
      await tolak([
        PotonganSelAwan(kunci: 'centang|lulus', isi: potonganHeader()),
      ]);
      await tolak([sel(1), sel(1)]);
      await tolak([
        PotonganSelAwan(
          kunci: 'tabel_ph|1|1|pembacaan',
          isi: potonganHeader(tambahanByte: maksByteSelUnggah),
        ),
      ]);
      await tolak([
        PotonganSelAwan(
          kunci: 'tabel_ph|1|1|pembacaan',
          isi: potonganHeader(lebar: 1000, tinggi: 1000),
        ),
      ]);

      expect(client.permintaan, isEmpty);
    });

    test('batas tunggu 60 detik (server membaca sampai 20 potongan)', () {
      expect(ApiOcrAwanSelService.batasTunggu, const Duration(seconds: 60));
    });
  });

  group('SETIAP non-2xx: satu kali kirim, tanpa ulang', () {
    final kasus = <(int, Map<String, dynamic>, JenisGalatOcrAwan)>[
      (503, _galat('fitur_dimatikan'), JenisGalatOcrAwan.fiturMati),
      (503, _galat('ocr_cloud_belum_aktif'), JenisGalatOcrAwan.awanBelumSiap),
      (503, _galat('ocr_cloud_belum_disetel'), JenisGalatOcrAwan.awanBelumSiap),
      (429, _galat('batas_sel_per_lembar'), JenisGalatOcrAwan.jatahHabis),
      (
        429,
        {'message': 'Terlalu sering.', 'fallback_manual': true},
        JenisGalatOcrAwan.terlaluSering,
      ),
      (
        422,
        _galat('permintaan_tidak_valid'),
        JenisGalatOcrAwan.permintaanDitolak,
      ),
      (
        422,
        _galat('templat_tidak_dikenal'),
        JenisGalatOcrAwan.permintaanDitolak,
      ),
      (
        422,
        _galat('tidak_ada_potongan_valid'),
        JenisGalatOcrAwan.tidakAdaPotongan,
      ),
      (404, _galat('sesi_tidak_ditemukan'), JenisGalatOcrAwan.sesiBermasalah),
      (403, _galat('bukan_sesi_anda'), JenisGalatOcrAwan.sesiBermasalah),
      (502, _galat('ocr_cloud_gagal'), JenisGalatOcrAwan.awanGagal),
    ];

    for (final k in kasus) {
      test('${k.$1} ${k.$2['kode'] ?? 'tanpa kode'} -> ${k.$3.name}', () async {
        final client = _Client(k.$1, k.$2);

        final g = await _tangkap(_service(client), sel(1), konteks);

        expect(g, isA<GalatOcrAwan>());
        expect((g as GalatOcrAwan).jenis, k.$3);
        expect(g.fallbackManual, isTrue);
        expect(g.bolehUlangOtomatis, isFalse);
        expect(client.permintaan, hasLength(1));
      });
    }

    for (final status in [401, 403, 404, 422, 500]) {
      test(
        '$status tanpa kode kontrak tetap ApiException (bukan crash)',
        () async {
          final client = _Client(status, {'message': 'Ditolak.'});

          final g = await _tangkap(_service(client), sel(1), konteks);

          expect(g, isA<ApiException>());
          expect((g as ApiException).status, status);
          expect(client.permintaan, hasLength(1));
        },
      );
    }

    test('429 dan 502 tidak diulang walau diberi waktu', () async {
      for (final status in [429, 502]) {
        final client = _Client(status, _galat('ocr_cloud_gagal'));

        await _tangkap(_service(client), sel(1), konteks);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(client.permintaan, hasLength(1), reason: 'status $status');
      }
    });

    test('waktu habis dan tanpa jaringan menjadi KoneksiException', () async {
      for (final galat in <Object>[
        TimeoutException('lama'),
        const SocketException('putus'),
      ]) {
        final client = _Client(200, _respons, lempar: galat);

        final g = await _tangkap(_service(client), sel(1), konteks);

        expect(g, isA<KoneksiException>(), reason: '$galat');
        expect(client.permintaan, hasLength(1));
      }
    });
  });

  group('MockOcrAwanSelService', () {
    test('bawaan meniru produksi sekarang: awan belum aktif', () async {
      final mock = MockOcrAwanSelService();

      await expectLater(
        mock.bacaSel('t', konteks: konteks, sel: [sel(1)]),
        throwsA(
          isA<GalatOcrAwan>().having(
            (e) => e.jenis,
            'jenis',
            JenisGalatOcrAwan.awanBelumSiap,
          ),
        ),
      );
      expect(mock.permintaan, [
        ['tabel_ph|1|1|pembacaan'],
      ]);
    });

    test('memakai pemeriksaan masukan yang sama dengan klien asli', () async {
      final mock = MockOcrAwanSelService();

      await expectLater(
        mock.bacaSel('t', konteks: konteks, sel: const []),
        throwsArgumentError,
      );
      expect(mock.permintaan, isEmpty);
    });
  });
}

Future<Object?> _tangkap(
  ApiOcrAwanSelService service,
  PotonganSelAwan sel,
  KonteksOcrAwanSel konteks,
) async {
  try {
    await service.bacaSel('t', konteks: konteks, sel: [sel]);
  } catch (e) {
    return e;
  }
  fail('seharusnya melempar');
}

ApiOcrAwanSelService _service(_Client client) => ApiOcrAwanSelService(
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
      'kunci': 'tabel_ph|1|1|pembacaan',
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
  'meta': {
    'sumber': 'google_vision',
    'usulan': true,
    'sebagian': false,
    'sisa_sel_lembar': 120,
  },
};

class _Permintaan {
  _Permintaan(this.method, this.url, this.headers, this.fields, this.berkas);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Map<String, String> fields;
  final List<String> berkas;
}

/// Mencatat tiap permintaan multipart yang SAMPAI ke "server", jadi tes bisa
/// menghitung apakah `ApiClient` mengulang.
class _Client extends http.BaseClient {
  _Client(this.status, this.balasan, {this.lempar});

  final int status;
  final Map<String, dynamic> balasan;
  final Object? lempar;
  final List<_Permintaan> permintaan = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().toBytes();

    final r = request as http.MultipartRequest;
    permintaan.add(
      _Permintaan(r.method, r.url, r.headers, Map.of(r.fields), [
        for (final f in r.files) f.field,
      ]),
    );

    final g = lempar;
    if (g != null) throw g;

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(balasan))),
      status,
      headers: const {'content-type': 'application/json'},
    );
  }
}
