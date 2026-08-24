import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/room_service.dart';

const _baseUrl = 'http://10.0.2.2:8000/api';

/// Bug yang dijaga file ini: dropdown "Ruangan" di lembar kerja cuma nampilin
/// 15 ruangan pertama.
///
/// `GET /rooms` dipatok `paginate(15)` di backend, dan dulu `ApiRoomService`
/// cuma baca `json['data']` halaman pertama. Ruangan ke-16 dan seterusnya
/// ilang TANPA error apa pun — teknisi nggak nemu ruangannya, admin nggak
/// punya cara tau ada yang kurang. Kegagalan yang diam itu yang bikin test ini
/// ada.
ApiRoomService _service(
  Future<http.Response> Function(http.Request req) handler,
) {
  return ApiRoomService(
    ApiClient(client: MockClient(handler), baseUrl: _baseUrl),
  );
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _room(int id, {bool aktif = true}) => {
  'id': id,
  'nama': 'Lab. Uji $id',
  'kode': 'LAB-$id',
  'aktif': aktif,
};

/// Halaman ala Laravel: `data` + `meta` yang nyebut posisi halamannya.
Map<String, dynamic> _halaman(
  List<Map<String, dynamic>> data, {
  required int kini,
  required int akhir,
}) => {
  'data': data,
  'meta': {'current_page': kini, 'last_page': akhir},
};

void main() {
  group('ApiRoomService.daftar ngikutin paginasi', () {
    test(
      'halaman ke-2 beneran ditarik — ruangan ke-16 nyampe ke dropdown',
      () async {
      final diminta = <Uri>[];

      final service = _service((req) async {
        diminta.add(req.url);
        final halaman = int.parse(req.url.queryParameters['page']!);

        return _json(
          halaman == 1
              ? _halaman(
                  [for (var i = 1; i <= 15; i++) _room(i)],
                  kini: 1,
                  akhir: 2,
                )
              : _halaman([_room(16)], kini: 2, akhir: 2),
        );
      });

      final hasil = await service.daftar('1|token');

      // Inti bug-nya: 16, bukan 15.
      expect(hasil.length, 16);
      expect(hasil.last.id, 16);
      expect(hasil.last.kode, 'LAB-16');

      // Dua permintaan, bukan satu — dan berhenti di halaman terakhir, bukan
      // nerusin ke halaman 3 yang nggak ada.
      expect(diminta.length, 2);
      expect(diminta[0].queryParameters['page'], '1');
      expect(diminta[1].queryParameters['page'], '2');
    });

    test(
      '`hanya_aktif=1` kekirim di tiap halaman, bukan cuma yang pertama',
      () async {
      final diminta = <Uri>[];

      final service = _service((req) async {
        diminta.add(req.url);
        final halaman = int.parse(req.url.queryParameters['page']!);

        return _json(_halaman([_room(halaman)], kini: halaman, akhir: 3));
      });

      await service.daftar('1|token');

      expect(diminta.length, 3);
      // Kalau `page=` nabrak `hanya_aktif=` waktu path-nya dirakit, yang
      // ilang bakal diam-diam lagi — jadi dicek per halaman, bukan sekali.
      for (final url in diminta) {
        expect(url.queryParameters['hanya_aktif'], '1');
      }
    });

    test(
      'server lama yang ngabaikan `hanya_aktif` tetap disaring di sini',
      () async {
      // Server yang belum punya parameter itu nggak nolak dengan 422 — dia
      // ngabaikannya DIAM-DIAM dan tetap ngirim yang nonaktif. Ini sabuk
      // keduanya: tanpa saringan klien, ruangan nonaktif nongol lagi di
      // dropdown sesi baru.
      final service = _service(
        (_) async => _json(
          _halaman([
            _room(1),
            _room(2, aktif: false),
            _room(3),
          ], kini: 1, akhir: 1),
        ),
      );

      final hasil = await service.daftar('1|token');

      expect(hasil.map((r) => r.id), [1, 3]);
    });

    test(
      'respons tanpa `meta` cukup sekali ambil',
      () async {
      // Bentuk lama / endpoint yang belum dipaginasi. Kalau nggak di-break,
      // loopnya nembak halaman 2..50 yang isinya sama persis.
      var panggilan = 0;

      final service = _service((_) async {
        panggilan++;
        return _json({
          'data': [_room(1), _room(2)],
        });
      });

      final hasil = await service.daftar('1|token');

      expect(panggilan, 1);
      expect(hasil.length, 2);
    });

    test(
      'rem 50 halaman: `meta` yang muter nggak bikin ngeloop selamanya',
      () async {
      // Backend yang salah ngitung `last_page` nggak boleh bikin app-nya
      // gantung. Berhenti dengan data seadanya lebih baik daripada nggak
      // pernah berhenti.
      var panggilan = 0;

      final service = _service((req) async {
        panggilan++;
        final halaman = int.parse(req.url.queryParameters['page']!);

        return _json(_halaman([_room(halaman)], kini: halaman, akhir: 999));
      });

      final hasil = await service.daftar('1|token');

      expect(panggilan, 50);
      expect(hasil.length, 50);
    });
  });
}
