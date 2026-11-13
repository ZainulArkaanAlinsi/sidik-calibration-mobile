import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/models/garis_waktu_arsip.dart';
import 'package:sidik_calibration/models/pencarian_arsip.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/arsip_cari_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';

/// Service arsip: yang diuji adalah PERMINTAAN yang keluar (path, parameter,
/// header) dan cara jawabannya dibaca — bukan tiruan tanpa jaringan.
///
/// Aturan yang dijaga, dari kontrak API `docs/perintah-frontend-arsip-cari.md`:
/// `q` dikirim apa adanya dan hanya bila >= 2 karakter; `tanggal` polos
/// `YYYY-MM-DD`; `per_page` <= 50; `bentuk=ringan`; tanpa parameter kosong;
/// server lama (parameter diabaikan) dikenali dari `meta`.

const _basis = 'https://api.test/api';

class _Tangkap {
  final permintaan = <http.Request>[];

  Uri get uri => permintaan.single.url;
  Map<String, String> get param => uri.queryParameters;
}

ApiArsipCariService _service(
  _Tangkap tangkap,
  http.Response Function(http.Request) jawab,
) => ApiArsipCariService(
  ApiClient(
    baseUrl: _basis,
    client: MockClient((req) async {
      tangkap.permintaan.add(req);
      return jawab(req);
    }),
  ),
);

http.Response _json(Object badan, [int status = 200]) => http.Response(
  jsonEncode(badan),
  status,
  headers: {'content-type': 'application/json'},
);

// Satu baris dari contoh kontrak §2 (`bentuk=ringan`).
Map<String, dynamic> _baris(int id) => {
  'id': id,
  'nomor_sesi': 'KAL/2026/11/900$id',
  'nomor_order': 'PO-2026-0042',
  'status': 'disetujui',
  'keputusan': 'PASS',
  'hasil': {'keputusan': 'PASS'},
  'tanggal_kalibrasi': '2026-11-11',
  'equipment': {
    'id': 5,
    'nama_alat': 'Jangka Sorong',
    'serial_number': 'SN-0204',
  },
  'alat_serial_number': null,
  'pelanggan': {'id': 1, 'nama': 'PT Contoh Alfa'},
  'teknisi': {'id': 6, 'nama': 'Dr. Arch Schaefer'},
  'sertifikat': {'id': 5, 'nomor': 'CAL/2026/11/0004', 'status': 'terbit'},
  'tersembunyi': false,
};

Map<String, dynamic> _halamanRiwayat({
  int perHalaman = 50,
  int halaman = 1,
  int terakhir = 1,
  int total = 1,
  List<Map<String, dynamic>>? baris,
}) => {
  'data': baris ?? [_baris(5)],
  'meta': {
    'current_page': halaman,
    'last_page': terakhir,
    'per_page': perHalaman,
    'total': total,
  },
};

Map<String, dynamic> get _garisWaktuTahun => {
  'data': {
    'tingkat': 'tahun',
    'induk': <String, dynamic>{},
    'total_dokumen': 1,
    'kelompok': [
      {
        'kunci': '2026',
        'label': '2026',
        'jumlah': 1,
        'mulai': '2026-01-01',
        'selesai': '2026-12-31',
        'telusuri': {'tingkat': 'bulan', 'tahun': 2026},
      },
    ],
    'item': <dynamic>[],
  },
  'meta': {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 0},
};

void main() {
  group('cariRiwayat: permintaan', () {
    test('semua saringan terkirim dengan nama & format kontrak', () async {
      final t = _Tangkap();
      final service = _service(t, (_) => _json(_halamanRiwayat(halaman: 2)));

      await service.cariRiwayat(
        'tok-1',
        filter: FilterArsip.kosong
            .denganKata('CAL/2026/10/0001')
            .denganRentang(DateTime(2026, 11), DateTime(2026, 11, 15))
            .denganPelanggan(3, 'PT Contoh Alfa'),
        halaman: 2,
      );

      expect(t.uri.path, '/api/calibrations');
      expect(t.param, {
        'bentuk': 'ringan',
        'per_page': '50',
        'page': '2',
        'q': 'CAL/2026/10/0001',
        'dari': '2026-11-01',
        'sampai': '2026-11-15',
        'customer_id': '3',
      });
      expect(t.permintaan.single.headers['Authorization'], 'Bearer tok-1');
    });

    test(
      'garis miring di kata cari terkirim ter-encode, utuh di server',
      () async {
        final t = _Tangkap();
        await _service(t, (_) => _json(_halamanRiwayat())).cariRiwayat(
          'tok',
          filter: FilterArsip.kosong.denganKata('CAL/2026/10/0001'),
        );

        expect(t.uri.query, contains('q=CAL%2F2026%2F10%2F0001'));
      },
    );

    test(
      'kata dikirim apa adanya: tanda hubung, spasi dalam, huruf besar',
      () async {
        final t = _Tangkap();
        await _service(t, (_) => _json(_halamanRiwayat())).cariRiwayat(
          'tok',
          filter: FilterArsip.kosong.denganKata('  Cal 2026-10 0001  '),
        );

        // Hanya spasi di ujung yang dibuang; selebihnya urusan server.
        expect(t.param['q'], 'Cal 2026-10 0001');
      },
    );

    test('tanpa saringan: hanya bentuk, per_page, dan page', () async {
      final t = _Tangkap();
      await _service(
        t,
        (_) => _json(_halamanRiwayat()),
      ).cariRiwayat('tok', filter: FilterArsip.kosong);

      expect(t.param.keys.toSet(), {'bentuk', 'per_page', 'page'});
      expect(t.param['page'], '1');
    });

    test('kata satu huruf TIDAK dikirim (server menolak 422)', () async {
      final t = _Tangkap();
      await _service(t, (_) => _json(_halamanRiwayat())).cariRiwayat(
        'tok',
        filter: FilterArsip.kosong
            .denganKata(' a ')
            .denganPelanggan(3, 'PT Contoh Alfa'),
      );

      expect(t.param.containsKey('q'), isFalse);
      expect(t.param['customer_id'], '3');
    });

    test('tanggal polos: jam dan zona tidak ikut terkirim', () async {
      final t = _Tangkap();
      await _service(t, (_) => _json(_halamanRiwayat())).cariRiwayat(
        'tok',
        filter: FilterArsip.kosong.denganRentang(
          DateTime(2026, 11, 1, 23, 59),
          DateTime(2026, 11, 15, 0, 1),
        ),
      );

      expect(t.param['dari'], '2026-11-01');
      expect(t.param['sampai'], '2026-11-15');
    });

    test('per_page tidak melewati batas server (50)', () async {
      expect(ApiArsipCariService.perHalamanRiwayat, lessThanOrEqualTo(50));
    });
  });

  group('cariRiwayat: jawaban', () {
    test('baris, halaman, last_page, dan total dibaca dari meta', () async {
      final service = _service(
        _Tangkap(),
        (_) => _json(
          _halamanRiwayat(
            halaman: 2,
            terakhir: 3,
            total: 120,
            baris: [_baris(7), _baris(6)],
          ),
        ),
      );

      final h = await service.cariRiwayat(
        'tok',
        filter: FilterArsip.kosong.denganKata('SN-0204'),
        halaman: 2,
      );

      expect(h.baris.map((b) => b.id), [7, 6]);
      expect(h.baris.first.nomorSertifikat, 'CAL/2026/11/0004');
      expect(h.halaman, 2);
      expect(h.halamanTerakhir, 3);
      expect(h.total, 120);
    });

    test('server lama yang mengabaikan per_page (meta 15) ditolak, bukan '
        'ditampilkan sebagai hasil tersaring', () async {
      final service = _service(
        _Tangkap(),
        (_) => _json(_halamanRiwayat(perHalaman: 15)),
      );

      expect(
        () => service.cariRiwayat(
          'tok',
          filter: FilterArsip.kosong.denganKata('SN-0204'),
        ),
        throwsA(isA<ServerBelumMendukungArsipException>()),
      );
    });

    test('jawaban tanpa meta (server tanpa paginasi) juga ditolak', () async {
      final service = _service(
        _Tangkap(),
        (_) => _json({
          'data': [_baris(1)],
        }),
      );

      expect(
        () => service.cariRiwayat('tok', filter: FilterArsip.kosong),
        throwsA(isA<ServerBelumMendukungArsipException>()),
      );
    });

    test('403 diteruskan apa adanya sebagai ApiException', () async {
      final service = _service(
        _Tangkap(),
        (_) => _json({'message': 'Tidak diizinkan.'}, 403),
      );

      await expectLater(
        service.cariRiwayat('tok', filter: FilterArsip.kosong),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.message, 'message', 'Tidak diizinkan.'),
        ),
      );
    });
  });

  group('garisWaktu', () {
    test('akar: hanya tingkat=tahun, tanpa parameter kosong', () async {
      final t = _Tangkap();
      final h = await _service(
        t,
        (_) => _json(_garisWaktuTahun),
      ).garisWaktu('tok-2', posisi: PosisiGarisWaktu.akar);

      expect(t.uri.path, '/api/arsip/garis-waktu');
      expect(t.param, {'tingkat': 'tahun'});
      expect(t.permintaan.single.headers['Authorization'], 'Bearer tok-2');
      expect(h.kelompok.single.label, '2026');
    });

    test('telusuri kelompok dipakai persis, ditambah PT dan halaman', () async {
      final t = _Tangkap();
      final posisi = PosisiGarisWaktu.dariTelusuri({
        'tingkat': 'hari',
        'tahun': 2026,
        'bulan': 11,
        'pekan': 46,
        'tanggal': '2026-11-12',
      })!;

      await _service(
        t,
        (_) => _json(_garisWaktuTahun),
      ).garisWaktu('tok', posisi: posisi, pelangganId: 3, halaman: 2);

      expect(t.param, {
        'tingkat': 'hari',
        'tahun': '2026',
        'bulan': '11',
        'pekan': '46',
        'tanggal': '2026-11-12',
        'customer_id': '3',
        'page': '2',
      });
    });

    test(
      'halaman pertama tidak mengirim page; tanpa PT tanpa customer_id',
      () async {
        final t = _Tangkap();
        await _service(
          t,
          (_) => _json(_garisWaktuTahun),
        ).garisWaktu('tok', posisi: PosisiGarisWaktu.akar);

        expect(t.param.containsKey('page'), isFalse);
        expect(t.param.containsKey('customer_id'), isFalse);
      },
    );

    test('rute belum ada (404) = server belum mendukung', () async {
      final service = _service(
        _Tangkap(),
        (_) => _json({'message': 'not found'}, 404),
      );

      expect(
        () => service.garisWaktu('tok', posisi: PosisiGarisWaktu.akar),
        throwsA(isA<ServerBelumMendukungArsipException>()),
      );
    });

    test(
      '200 dengan bentuk lain = server belum mendukung, bukan kosong',
      () async {
        final service = _service(
          _Tangkap(),
          (_) => _json({'data': <dynamic>[]}),
        );

        expect(
          () => service.garisWaktu('tok', posisi: PosisiGarisWaktu.akar),
          throwsA(isA<ServerBelumMendukungArsipException>()),
        );
      },
    );

    test('422 dan 429 diteruskan sebagai ApiException', () async {
      for (final status in [422, 429]) {
        final service = _service(
          _Tangkap(),
          (_) => _json({'message': 'galat $status'}, status),
        );

        await expectLater(
          service.garisWaktu('tok', posisi: PosisiGarisWaktu.akar),
          throwsA(
            isA<ApiException>().having((e) => e.status, 'status', status),
          ),
        );
      }
    });
  });
}
