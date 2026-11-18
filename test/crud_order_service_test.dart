import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/models/order_kelola.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/order_kelola_service.dart';

/// Service kelola Order lawan kontrak API.
///
/// SUMBER bentuk: `OrderController` (index/show/store/update/destroy),
/// `OrderRequest`, `OrderResource`, `OrderItemResource`, dan
/// `EquipmentController::index` (filter `customer_id`, `search`, 15/halaman) di
/// repo API pada 18 Nov 2026 — dibaca dari kode, tidak dikarang.
const _dasar = 'https://api.test/api';

http.Response _json(Object badan, [int status = 200]) => http.Response(
  jsonEncode(badan),
  status,
  headers: {'content-type': 'application/json'},
);

ApiClient _klien(Future<http.Response> Function(http.Request) h) =>
    ApiClient(client: MockClient(h), baseUrl: _dasar);

OrderKelolaService _layanan(Future<http.Response> Function(http.Request) h) =>
    ApiOrderKelolaService(_klien(h));

Map<String, dynamic> _badan(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

/// Item `OrderResource` ala `OrderController::muatRelasi`.
Map<String, dynamic> _order({int id = 301, String status = 'baru'}) => {
  'id': id,
  'nomor': 'ORD/2026/11/0003',
  'status': status,
  'tanggal_masuk': '2026-11-15T17:00:00Z',
  'tanggal_janji_selesai': null,
  'catatan': null,
  'pelanggan': {'id': 3, 'nama': 'PT Tirta Contoh Mandiri'},
  'diterima_oleh': {'id': 11, 'nama': 'Rina Master Data'},
  'jumlah_alat': 1,
  'items': [
    {
      'id': 1,
      'teknisi': null,
      'kondisi_terima': null,
      'kelengkapan': null,
      'catatan': null,
      'alat': {'id': 14, 'nama_alat': 'pH Meter', 'serial_number': 'B1'},
    },
  ],
};

Map<String, dynamic> _alat({int id = 14}) => {
  'id': id,
  'nama_alat': 'pH Meter Mettler Toledo',
  'serial_number': 'B628755900',
  'kategori': 'instrumen-analitik',
  'status': 'aktif',
  'pelanggan': {'nama': 'PT Tirta Contoh Mandiri', 'alamat': 'Bandung'},
};

FormOrder _form({int pelanggan = 3}) => FormOrder(
  pelangganId: pelanggan,
  tanggalMasuk: DateTime(2026, 11, 16),
  items: const [ItemOrderForm(alatId: 14, namaAlat: 'pH Meter', teknisiId: 21)],
);

void main() {
  group('daftar (GET /orders)', () {
    test('query status/search/page + paginasi dibaca dari meta', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({
          'data': [_order(), _order(id: 302)],
          'links': {},
          'meta': {'current_page': 2, 'last_page': 4, 'per_page': 15},
        });
      });

      final h = await s.daftar(
        'tkn-1',
        status: 'diproses',
        cari: ' PT Tirta ',
        halaman: 2,
      );

      expect(terkirim.method, 'GET');
      expect(terkirim.url.path, '/api/orders');
      expect(terkirim.url.queryParameters, {
        'status': 'diproses',
        'search': 'PT Tirta',
        'page': '2',
      });
      expect(terkirim.headers['Authorization'], 'Bearer tkn-1');
      expect(h.items, hasLength(2));
      expect(h.items.first.pelangganId, 3);
      expect(h.halaman, 2);
      expect(h.halamanTerakhir, 4);
      expect(h.adaLagi, isTrue);
    });

    test('tanpa saringan: tidak ada query sama sekali', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({'data': [], 'meta': {'current_page': 1, 'last_page': 1}});
      });
      final h = await s.daftar('t');

      expect(terkirim.url.query, isEmpty);
      expect(h.items, isEmpty);
      expect(h.adaLagi, isFalse);
    });

    test('respons tanpa meta dianggap satu halaman penuh', () async {
      final s = _layanan((_) async => _json({'data': [_order()]}));
      final h = await s.daftar('t');

      expect(h.items, hasLength(1));
      expect(h.adaLagi, isFalse);
    });
  });

  group('detail, buat, ubah, hapus', () {
    test('detail: GET /orders/{id} membawa items', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({'data': _order()});
      });
      final o = await s.detail('t', 301);

      expect(terkirim.method, 'GET');
      expect(terkirim.url.path, '/api/orders/301');
      expect(o.items, hasLength(1));
      expect(o.items.single.alatId, 14);
    });

    test('buat: POST /orders, body persis OrderRequest, nomor tak dikirim', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({'data': _order()}, 201);
      });
      final o = await s.buat('tkn', _form());

      expect(terkirim.method, 'POST');
      expect(terkirim.url.path, '/api/orders');
      final b = _badan(terkirim);
      expect(b['customer_id'], 3);
      expect(b['tanggal_masuk'], '2026-11-16');
      expect(b.containsKey('nomor'), isFalse);
      expect(b.containsKey('status'), isFalse);
      expect((b['items'] as List).single, {
        'equipment_id': 14,
        'teknisi_id': 21,
        'kondisi_terima': null,
        'kelengkapan': null,
        'catatan': null,
      });
      expect(o.nomor, 'ORD/2026/11/0003');
    });

    test('ubah: PUT /orders/{id}, tanpa customer_id, dengan status', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({'data': _order(status: 'selesai')});
      });
      final o = await s.ubah(
        'tkn',
        301,
        FormOrder(
          pelangganId: 3,
          tanggalMasuk: DateTime(2026, 11, 16),
          status: 'selesai',
          items: const [ItemOrderForm(alatId: 14, namaAlat: 'pH')],
        ),
      );

      expect(terkirim.method, 'PUT');
      expect(terkirim.url.path, '/api/orders/301');
      final b = _badan(terkirim);
      expect(b.containsKey('customer_id'), isFalse);
      expect(b['status'], 'selesai');
      expect(o.status, 'selesai');
    });

    test('hapus: DELETE /orders/{id}', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({'message': 'Order dihapus.'});
      });
      await s.hapus('tkn', 301);

      expect(terkirim.method, 'DELETE');
      expect(terkirim.url.path, '/api/orders/301');
      expect(terkirim.headers['Authorization'], 'Bearer tkn');
    });
  });

  group('alat milik PT (GET /equipments?customer_id=)', () {
    test('query customer_id + search + page, meta dibaca', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({
          'data': [_alat(), _alat(id: 15)],
          'meta': {'current_page': 1, 'last_page': 2},
        });
      });
      final h = await s.alatPelanggan('t', 3, cari: 'ph', halaman: 1);

      expect(terkirim.url.path, '/api/equipments');
      expect(terkirim.url.queryParameters, {'customer_id': '3', 'search': 'ph'});
      expect(h.items.map((a) => a.id), [14, 15]);
      expect(h.adaLagi, isTrue);
    });

    test('halaman 2 menambah page=2', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({'data': [], 'meta': {'current_page': 2, 'last_page': 2}});
      });
      await s.alatPelanggan('t', 3, halaman: 2);

      expect(terkirim.url.queryParameters, {'customer_id': '3', 'page': '2'});
    });
  });

  group('galat server dilempar sebagai ApiException berbadan asli', () {
    // Badan 422 ala Laravel `OrderRequest`; hapus-ditolak ala
    // `OrderController::destroy` (422 tanpa `kode`).
    final galat = <(String, int, Map<String, dynamic>)>[
      ('401 tanpa token', 401, {'message': 'Unauthenticated.'}),
      ('403 bukan admin', 403, {'message': 'Akses ditolak.'}),
      ('404 order lab lain', 404, {'message': 'No query results.'}),
      (
        '422 validasi',
        422,
        {
          'message': 'Minimal satu alat harus didaftarin di order ini.',
          'errors': {
            'items': ['Minimal satu alat harus didaftarin di order ini.'],
          },
        },
      ),
      (
        '422 hapus ditolak (sudah bersesi)',
        422,
        {'message': 'Order ini alatnya udah masuk kalibrasi.'},
      ),
      ('409 bentrok', 409, {'message': 'Berubah.', 'kode': 'status_berubah'}),
      ('429 throttle', 429, {'message': 'Kebanyakan percobaan.'}),
      ('500 server', 500, {'message': 'Server Error'}),
    ];

    for (final (nama, status, badan) in galat) {
      test('buat: $nama', () async {
        final s = _layanan((_) async => _json(badan, status));
        await expectLater(
          s.buat('t', _form()),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.body['kode'], 'kode', badan['kode']),
          ),
        );
      });

      test('hapus: $nama', () async {
        final s = _layanan((_) async => _json(badan, status));
        await expectLater(
          s.hapus('t', 301),
          throwsA(
            isA<ApiException>().having((e) => e.status, 'status', status),
          ),
        );
      });
    }

    test('buat: 422 membawa errors per kolom (items.0.equipment_id)', () async {
      final s = _layanan(
        (_) async => _json({
          'message': 'x',
          'errors': {
            'items.0.equipment_id': ['Alat "pH" terdaftar atas nama pelanggan lain.'],
          },
        }, 422),
      );
      try {
        await s.buat('t', _form());
        fail('harus melempar');
      } on ApiException catch (e) {
        expect(e.status, 422);
        expect(
          (e.body['errors'] as Map)['items.0.equipment_id'],
          isNotEmpty,
        );
      }
    });

    test('buat: jaringan putus → KoneksiException, TIDAK diulang (tanpa order kembar)', () async {
      var panggilan = 0;
      final s = _layanan((_) async {
        panggilan++;
        throw const SocketException('putus');
      });
      await expectLater(
        s.buat('t', _form()),
        throwsA(isA<KoneksiException>()),
      );
      expect(panggilan, 1);
    });

    test('hapus: jaringan putus → KoneksiException, tidak diulang', () async {
      var panggilan = 0;
      final s = _layanan((_) async {
        panggilan++;
        throw const SocketException('putus');
      });
      await expectLater(s.hapus('t', 301), throwsA(isA<KoneksiException>()));
      expect(panggilan, 1);
    });
  });

  group('MockOrderKelolaService meniru aturan server', () {
    test('buat → nomor dari server, masuk di daftar, items wajib', () async {
      final m = MockOrderKelolaService();
      final baru = await m.buat('t', _form());
      expect(baru.nomor, startsWith('ORD/'));
      expect((await m.daftar('t')).items.first.id, baru.id);

      await expectLater(
        m.buat(
          't',
          FormOrder(
            pelangganId: 3,
            tanggalMasuk: DateTime(2026, 11, 16),
            items: const [],
          ),
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
      );
    });

    test('hapus order bersesi → 422, order tetap ada', () async {
      final m = MockOrderKelolaService(idBersesi: {301});
      await expectLater(
        m.hapus('t', 301),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
      );
      expect((await m.detail('t', 301)).id, 301);
      await m.hapus('t', 302);
      await expectLater(
        m.detail('t', 302),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
      );
    });
  });
}
