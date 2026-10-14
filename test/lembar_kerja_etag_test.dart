import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_panjang.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';

/// Lembar kerja BERSYARAT (CR-48 P4, FR-21, kontrak §4): salinan + `ETag` per
/// kunci lembar, `If-None-Match` di tarikan berikutnya, `304` → salinan.
///
/// ## Kenapa objeknya harus IDENTIK, bukan cuma isinya sama
///
/// Layar lembar kerja membangun ulang tabelnya (`gantiBentuk`) begitu menerima
/// objek bentuk yang lain. Lembar sekarang ditarik ulang tiap aplikasi kembali
/// ke depan dan tiap tarikan berkala 3 menit — kalau tarikan yang tidak
/// mengubah apa pun tetap melahirkan objek baru, formulir yang sedang diketik
/// teknisi dikocok ulang tiap tiga menit tanpa sebab.
///
/// Bentuk respons di sini diambil dari test API
/// `LembarKerjaVersiAcuanTest::test_etag_304`: `ETag` = `"` + sha256 badan +
/// `"`, `304` tanpa badan, `versi_acuan` `{paket, data: {nomor, sha256},
/// bentuk: null}`.
void main() {
  const sha =
      'ba1fa153808d125a2ff1e54ca3589e25c723b59ccb23a68df7372862ef56f585';
  const etag = '"6f1d0c2a9e"';

  String badanLembar({Object? versiAcuan = const _TanpaKunci()}) => jsonEncode({
    'data': {
      ...contohBentukLembarKerjaMicrometer(),
      if (versiAcuan is! _TanpaKunci) 'versi_acuan': versiAcuan,
    },
  });

  final versiV1 = {
    'paket': 'micrometer',
    'data': {'nomor': 1, 'sha256': sha},
    'bentuk': null,
  };

  /// Jawaban 200 seperti Laravel: `Content-Type: application/json` tanpa
  /// charset (package:http membacanya UTF-8).
  http.Response json200(String badan, {String? etag}) => http.Response(
    badan,
    200,
    headers: {'content-type': 'application/json', 'etag': ?etag},
  );

  /// Server palsu yang mencatat header tiap permintaan.
  ({ApiClient api, List<http.Request> diminta}) server(
    http.Response Function(http.Request r, int ke) jawab,
  ) {
    final diminta = <http.Request>[];
    final client = MockClient((r) async {
      diminta.add(r);
      return jawab(r, diminta.length);
    });

    return (
      api: ApiClient(client: client, baseUrl: 'http://uji.test/api'),
      diminta: diminta,
    );
  }

  group('ApiClient.getBersyarat', () {
    test(
      '304 tidak dilempar sebagai galat; ETag lama tetap dipegang',
      () async {
        final s = server((r, _) => http.Response('', 304));

        final res = await s.api.getBersyarat('/x', token: 't', etag: etag);

        expect(res.tidakBerubah, isTrue);
        expect(res.etag, etag);
        expect(res.json, isEmpty);
        expect(s.diminta.single.headers['If-None-Match'], etag);
      },
    );

    test(
      'tanpa etag → If-None-Match TIDAK dikirim; 200 membawa ETag',
      () async {
        final s = server((r, _) => json200('{"data":{}}', etag: etag));

        final res = await s.api.getBersyarat('/x', token: 't');

        expect(s.diminta.single.headers.containsKey('If-None-Match'), isFalse);
        expect(res.status, 200);
        expect(res.etag, etag);
      },
    );

    test('status gagal tetap ApiException dengan pesan server', () async {
      final s = server(
        (r, _) => http.Response(
          '{"message":"Alat belum punya varian."}',
          422,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        s.api.getBersyarat('/x', token: 't'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 422)
              .having((e) => e.message, 'message', 'Alat belum punya varian.'),
        ),
      );
    });

    test(
      'get() lama TIDAK berubah: tanpa If-None-Match, 304 tetap galat',
      () async {
        final s = server((r, _) => http.Response('', 304));

        await expectLater(
          s.api.get('/x', token: 't'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 304)),
        );
        expect(s.diminta.single.headers.containsKey('If-None-Match'), isFalse);
      },
    );
  });

  group('ApiLembarKerjaService — salinan + ETag per kunci lembar', () {
    test(
      'tarikan kedua mengirim If-None-Match; 304 → objek yang SAMA',
      () async {
        final s = server((r, ke) {
          if (ke == 1) {
            return json200(badanLembar(versiAcuan: versiV1), etag: etag);
          }
          return r.headers['If-None-Match'] == etag
              ? http.Response('', 304, headers: {'etag': etag})
              : json200(badanLembar(versiAcuan: versiV1));
        });
        final service = ApiLembarKerjaService(s.api);

        final pertama = await service.ambilBentuk(
          't',
          profil: 'micrometer',
          equipmentId: 25,
        );
        final kedua = await service.ambilBentuk(
          't',
          profil: 'micrometer',
          equipmentId: 25,
        );

        expect(s.diminta, hasLength(2));
        expect(s.diminta.first.headers.containsKey('If-None-Match'), isFalse);
        expect(s.diminta.last.headers['If-None-Match'], etag);
        expect(identical(pertama, kedua), isTrue, reason: '304 → salinan');

        // versi_acuan ikut tersimpan di salinan.
        expect(kedua.versiAcuan?.paket, 'micrometer');
        expect(kedua.versiAcuan?.data?.nomor, 1);
        expect(kedua.versiAcuan?.data?.sha256, sha);
        expect(kedua.versiAcuan?.bentuk, isNull);
        expect(
          service.salinanUntuk((
            profil: 'micrometer',
            pengulangan: null,
            equipmentId: 25,
          ))?.etag,
          etag,
        );
      },
    );

    test('salinan per KUNCI: alat lain tidak memakai ETag alat ini', () async {
      final s = server((r, _) => json200(badanLembar(), etag: etag));
      final service = ApiLembarKerjaService(s.api);

      await service.ambilBentuk('t', profil: 'micrometer', equipmentId: 25);
      await service.ambilBentuk('t', profil: 'micrometer', equipmentId: 26);
      await service.ambilBentuk(
        't',
        profil: 'micrometer',
        equipmentId: 25,
        pengulangan: 3,
      );

      expect(
        s.diminta.map((r) => r.headers.containsKey('If-None-Match')),
        everyElement(isFalse),
      );
      expect(s.diminta[1].url.queryParameters['equipment_id'], '26');
    });

    test('ETag lain (versi acuan berganti) → badan baru, objek baru', () async {
      final versiV2 = {
        'paket': 'micrometer',
        'data': {'nomor': 2, 'sha256': 'c0ffee'},
        'bentuk': null,
      };
      final s = server((r, ke) {
        return ke == 1
            ? json200(badanLembar(versiAcuan: versiV1), etag: etag)
            : json200(badanLembar(versiAcuan: versiV2), etag: '"lain"');
      });
      final service = ApiLembarKerjaService(s.api);

      final lama = await service.ambilBentuk('t', profil: 'micrometer');
      final baru = await service.ambilBentuk('t', profil: 'micrometer');

      expect(identical(lama, baru), isFalse);
      expect(baru.versiAcuan?.data?.nomor, 2);
      expect(
        service.salinanUntuk((
          profil: 'micrometer',
          pengulangan: null,
          equipmentId: null,
        ))?.etag,
        '"lain"',
      );
    });

    test(
      'backend lama tanpa ETag & tanpa versi_acuan → perilaku lama, tanpa galat',
      () async {
        final s = server((r, _) => json200(badanLembar()));
        final service = ApiLembarKerjaService(s.api);

        final pertama = await service.ambilBentuk('t', profil: 'micrometer');
        final kedua = await service.ambilBentuk('t', profil: 'micrometer');

        // Tanpa ETag tidak ada yang bisa disyaratkan.
        expect(
          s.diminta.map((r) => r.headers.containsKey('If-None-Match')),
          everyElement(isFalse),
        );
        expect(pertama.versiAcuan, isNull);
        expect(pertama.judul, isNotEmpty);
        expect(pertama.bagian, isNotEmpty);
        // Badan persis sama → objek yang sama, supaya tarikan ulang tidak
        // mengocok formulir.
        expect(identical(pertama, kedua), isTrue);
      },
    );

    test(
      'versi_acuan: null (profil tanpa data berversi) terbaca null',
      () async {
        final s = server((r, _) => json200(badanLembar(versiAcuan: null)));

        final lembar = await ApiLembarKerjaService(s.api).ambilBentuk('t');

        expect(lembar.versiAcuan, isNull);
      },
    );

    test(
      'versi_acuan.data null (sumber json / belum ada versi) tetap terbaca',
      () async {
        final s = server(
          (r, _) => json200(
            badanLembar(
              versiAcuan: {'paket': 'micrometer', 'data': null, 'bentuk': null},
            ),
          ),
        );

        final lembar = await ApiLembarKerjaService(s.api).ambilBentuk('t');

        expect(lembar.versiAcuan?.paket, 'micrometer');
        expect(lembar.versiAcuan?.data, isNull);
      },
    );

    test(
      '304 tanpa salinan (perantara salah) → galat jelas, bukan lembar kosong',
      () async {
        final s = server((r, _) => http.Response('', 304));

        await expectLater(
          ApiLembarKerjaService(s.api).ambilBentuk('t', profil: 'micrometer'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 304)),
        );
      },
    );
  });

  group('MockLembarKerjaService', () {
    test(
      'tanpa versi_acuan tetap jalan; bentuk sama → objek sama (niru 304)',
      () async {
        final mock = MockLembarKerjaService();

        final a = await mock.ambilBentuk('t', profil: 'micrometer');
        final b = await mock.ambilBentuk('t', profil: 'micrometer');

        expect(a.versiAcuan, isNull);
        expect(identical(a, b), isTrue);
        expect(mock.equipmentIdDiminta, [null, null], reason: 'tetap dicatat');
      },
    );

    test(
      'sakelar versiAcuan menyuntik kunci yang sama dengan server',
      () async {
        final mock = MockLembarKerjaService(versiAcuan: versiV1);

        final lembar = await mock.ambilBentuk('t', profil: 'micrometer');

        expect(lembar.versiAcuan?.data?.nomor, 1);
      },
    );
  });
}

/// Penanda "kunci `versi_acuan` tidak dikirim sama sekali" — beda dari
/// dikirim bernilai `null`.
class _TanpaKunci {
  const _TanpaKunci();
}
