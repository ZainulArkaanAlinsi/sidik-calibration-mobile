import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/jatuh_tempo_provider.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Layar Jatuh tempo & detail Pusat pelanggan memakai penyaring SERVER
/// (`customer_id`, `jatuh_tempo_dalam`, `termasuk_lewat`, `urut`) alih-alih
/// menarik semua alat lalu membuangnya di HP.
///
/// Yang dijaga: penyaringnya benar-benar sampai ke server (bukan cuma
/// dihitung di aplikasi), dan perilaku layar TIDAK berubah — alat `overdue`
/// tanpa tanggal tetap ikut lewat jadwal, alat aktif yang tanggalnya sudah
/// lewat tetap dihitung lewat.
class _Perekam extends MockEquipmentService {
  _Perekam({super.awal});

  final panggilan =
      <
        ({
          String? status,
          int? pelangganId,
          int? dalam,
          bool lewat,
          String? urut,
        })
      >[];

  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int? pelangganId,
    int? jatuhTempoDalam,
    bool termasukLewat = false,
    String? urut,
    int page = 1,
  }) {
    panggilan.add((
      status: status,
      pelangganId: pelangganId,
      dalam: jatuhTempoDalam,
      lewat: termasukLewat,
      urut: urut,
    ));
    return super.daftar(
      token,
      search: search,
      kategori: kategori,
      status: status,
      pelangganId: pelangganId,
      jatuhTempoDalam: jatuhTempoDalam,
      termasukLewat: termasukLewat,
      urut: urut,
      page: page,
    );
  }
}

Equipment _alat(
  int id,
  EquipmentStatus status,
  DateTime? tempo, {
  int pelangganId = 1,
}) => Equipment(
  id: id,
  namaAlat: 'Alat $id',
  serialNumber: 'SN-$id',
  kategori: 'suhu',
  status: status,
  pelangganId: pelangganId,
  pelangganNama: 'P$pelangganId',
  tanggalJatuhTempo: tempo,
);

ProviderContainer _wadah(_Perekam service) {
  final c = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(
        MockAuthService(jeda: Duration.zero),
      ),
      jamProvider.overrideWithValue(() => DateTime(2026, 9, 26)),
      equipmentServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ApiEquipmentService', () {
    test('penyaring baru dikirim sebagai query server', () async {
      final rekam = <Uri>[];
      final svc = ApiEquipmentService(
        ApiClient(
          baseUrl: 'http://x/api',
          client: MockClient((r) async {
            rekam.add(r.url);
            return http.Response(
              jsonEncode({
                'data': [],
                'meta': {'current_page': 1, 'last_page': 1},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await svc.daftar(
        't',
        pelangganId: 7,
        jatuhTempoDalam: 90,
        termasukLewat: true,
        urut: 'jatuh_tempo',
      );
      final q = rekam.single.queryParameters;
      expect(q['customer_id'], '7');
      expect(q['jatuh_tempo_dalam'], '90');
      expect(q['termasuk_lewat'], '1');
      expect(q['urut'], 'jatuh_tempo');
    });

    test('tanpa penyaring baru: query sama persis dengan sebelumnya', () async {
      final rekam = <Uri>[];
      final svc = ApiEquipmentService(
        ApiClient(
          baseUrl: 'http://x/api',
          client: MockClient((r) async {
            rekam.add(r.url);
            return http.Response(
              jsonEncode({
                'data': [],
                'meta': {'current_page': 1, 'last_page': 1},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await svc.daftar('t', status: 'aktif');
      expect(
        rekam.single.queryParameters.keys,
        unorderedEquals(['status', 'page']),
      );
    });

    test('termasuk_lewat tanpa jatuh_tempo_dalam tidak dikirim', () async {
      final rekam = <Uri>[];
      final svc = ApiEquipmentService(
        ApiClient(
          baseUrl: 'http://x/api',
          client: MockClient((r) async {
            rekam.add(r.url);
            return http.Response(
              jsonEncode({
                'data': [],
                'meta': {'current_page': 1, 'last_page': 1},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await svc.daftar('t', termasukLewat: true);
      expect(
        rekam.single.queryParameters.containsKey('termasuk_lewat'),
        isFalse,
      );
    });
  });

  group('jatuhTempoProvider', () {
    test('dua penarikan berpenyaring, urut jatuh tempo dari server', () async {
      final svc = _Perekam(
        awal: [
          _alat(1, EquipmentStatus.overdue, DateTime(2026, 9, 14)),
          _alat(2, EquipmentStatus.overdue, null),
          _alat(3, EquipmentStatus.aktif, DateTime(2026, 10, 5)),
          // Aktif tapi tanggalnya sudah lewat & statusnya belum berganti.
          _alat(4, EquipmentStatus.aktif, DateTime(2026, 9, 20)),
          _alat(5, EquipmentStatus.nonaktif, DateTime(2026, 10, 1)),
        ],
      );
      final c = _wadah(svc);
      await c.read(authProvider.future);

      final r = await c.read(jatuhTempoProvider.future);

      expect(svc.panggilan, [
        (
          status: 'overdue',
          pelangganId: null,
          dalam: null,
          lewat: false,
          urut: 'jatuh_tempo',
        ),
        (
          status: null,
          pelangganId: null,
          dalam: 90,
          lewat: true,
          urut: 'jatuh_tempo',
        ),
      ]);
      // Hasil layar sama dengan sebelum ada penyaring server.
      expect(r.lewat.map((a) => a.alat.id), [1, 4, 2]);
      expect(r.dalam30.map((a) => a.alat.id), [3]);
      // Nonaktif tidak dijadwalkan.
      expect([...r.lewat, ...r.dalam90].any((a) => a.alat.id == 5), isFalse);
    });

    test(
      'detail pelanggan: customer_id ikut ke server, milik lain tidak muncul',
      () async {
        final svc = _Perekam(
          awal: [
            _alat(1, EquipmentStatus.overdue, DateTime(2026, 9, 14)),
            _alat(
              2,
              EquipmentStatus.overdue,
              DateTime(2026, 9, 18),
              pelangganId: 2,
            ),
            _alat(
              3,
              EquipmentStatus.aktif,
              DateTime(2026, 10, 5),
              pelangganId: 2,
            ),
          ],
        );
        final c = _wadah(svc);
        await c.read(authProvider.future);

        final r = await c.read(jatuhTempoPelangganProvider(2).future);

        expect(svc.panggilan.every((p) => p.pelangganId == 2), isTrue);
        expect(r.lewat.map((a) => a.alat.id), [2]);
        expect(r.dalam30.map((a) => a.alat.id), [3]);
      },
    );
  });
}
