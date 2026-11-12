import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/audit_log.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/audit_log_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/screens/audit/audit_log_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/audit_log_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';

const _baseUrl = 'http://10.0.2.2:8000/api';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Contoh respons PERSIS dari `docs/kontrak-api.md` §11 (`GET /api/audit-logs`).
const _jawabanKontrak = {
  'data': [
    {
      'id': 812,
      'entitas': {'tipe': 'standards', 'id': 1},
      'aksi': 'diubah',
      'perubahan': {
        'nama': {'lama': 'TH-1', 'baru': 'TH-1 (kalibrasi ulang)'},
      },
      'pelaku': {'id': 1, 'nama': 'Alex Misramto', 'role': 'admin'},
      'oleh_sistem': false,
      'catatan': null,
      'dicatat_pada': '2026-07-27T10:17:43Z',
    },
  ],
  'penyaring': {'entity_type': 'standards', 'entity_id': 1},
  'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 1},
};

AuditLogItem _item(
  int id, {
  String tipe = 'standards',
  int? entitasId,
  String aksi = 'diubah',
  List<PerubahanKolom> perubahan = const [],
  String? pelaku = 'Alex Misramto',
  bool sistem = false,
  String? catatan,
}) => AuditLogItem(
  id: id,
  entitasTipe: tipe,
  entitasId: entitasId ?? id,
  aksi: aksi,
  perubahan: perubahan,
  pelakuNama: pelaku,
  olehSistem: sistem,
  catatan: catatan,
  dicatatPada: DateTime.utc(2026, 10, 20, 9, 30),
);

/// Service yang mengisi daftar BERBEDA per token, supaya test ganti akun bisa
/// membedakan "data baru dari server" dari "data lama yang kebawa".
class _PerAkun implements AuditLogService {
  final tokenDipakai = <String>[];

  @override
  Future<HalamanAuditLog> daftar(
    String token, {
    FilterAuditLog filter = const FilterAuditLog(),
    int page = 1,
  }) async {
    tokenDipakai.add(token);
    return HalamanAuditLog(
      items: [_item(token == 'mock-token-1' ? 101 : 202, tipe: 'milik-$token')],
    );
  }
}

/// Halaman 1 langsung (server "punya" 3 halaman), halaman 2 ditahan test.
class _TahanHalamanDua implements AuditLogService {
  final tahan = Completer<HalamanAuditLog>();

  @override
  Future<HalamanAuditLog> daftar(
    String token, {
    FilterAuditLog filter = const FilterAuditLog(),
    int page = 1,
  }) {
    if (page == 2) return tahan.future;
    return Future.value(
      HalamanAuditLog(
        items: [
          _item(token == 'mock-token-1' ? 101 : 202, tipe: 'milik-$token'),
        ],
        currentPage: 1,
        lastPage: 3,
      ),
    );
  }
}

/// Halaman 1 sukses, halaman berikutnya gagal.
class _GagalHalamanDua extends MockAuditLogService {
  _GagalHalamanDua()
    : super(ukuranHalaman: 2, data: [for (var i = 1; i <= 5; i++) _item(i)]);

  @override
  Future<HalamanAuditLog> daftar(
    String token, {
    FilterAuditLog filter = const FilterAuditLog(),
    int page = 1,
  }) {
    if (page > 1) throw Exception('putus di halaman $page');
    return super.daftar(token, filter: filter, page: page);
  }
}

Widget _app(
  AuditLogService service, {
  String token = 'mock-token-1',
  Izin izin = Izin.kosong,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
      auditLogServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuditLogScreen(),
    ),
  );
}

/// Jeda 600 ms `MockAuthService` harus dilewati manual; layar tinggi supaya
/// semua baris terbangun tanpa digulung.
Future<void> _pasang(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  group('Model', () {
    test('AuditLogItem: contoh respons kontrak terbaca utuh', () {
      final halaman = HalamanAuditLog.fromJson(
        Map<String, dynamic>.from(_jawabanKontrak),
      );
      final item = halaman.items.single;

      expect(item.id, 812);
      expect(item.entitasTipe, 'standards');
      expect(item.entitasId, 1);
      expect(item.aksi, 'diubah');
      expect(item.perubahan.single.kolom, 'nama');
      expect(item.perubahan.single.lama, 'TH-1');
      expect(item.perubahan.single.baru, 'TH-1 (kalibrasi ulang)');
      expect(item.pelakuNama, 'Alex Misramto');
      expect(item.pelakuRole, 'admin');
      expect(item.olehSistem, isFalse);
      expect(item.catatan, isNull);
      // Dibandingkan sebagai SATU SAAT: item menyimpan waktu lokal, `==`
      // juga membedakan UTC dari lokal.
      expect(
        item.dicatatPada!.isAtSameMomentAs(
          DateTime.utc(2026, 7, 27, 10, 17, 43),
        ),
        isTrue,
      );
      expect(halaman.currentPage, 1);
      expect(halaman.lastPage, 1);
    });

    test(
      'hapus/pulihkan: perubahan {} (objek kosong) dan [] tidak bikin crash',
      () {
        for (final kosong in [<String, dynamic>{}, <dynamic>[]]) {
          final item = AuditLogItem.fromJson({
            'id': 1,
            'entitas': {'tipe': 'rooms', 'id': 4},
            'aksi': 'dihapus',
            'perubahan': kosong,
            'pelaku': null,
            'oleh_sistem': true,
            'catatan': null,
            'dicatat_pada': '2026-07-27T10:17:43Z',
          });

          expect(item.perubahan, isEmpty);
          // Pelaku null + oleh_sistem = perubahan otomatis, bukan data hilang.
          expect(item.olehSistem, isTrue);
          expect(item.pelakuNama, isNull);
        }
      },
    );

    test('baris cacat dilewati, sisanya tetap tampil', () {
      final halaman = HalamanAuditLog.fromJson({
        'data': [
          {'id': 'bukan-angka'},
          ..._jawabanKontrak['data']! as List,
        ],
        'meta': {'current_page': 1, 'last_page': 3},
      });

      expect(halaman.items.map((e) => e.id), [812]);
      expect(halaman.lastPage, 3);
    });

    test('kolom rahasia dikenali dari namanya', () {
      for (final nama in [
        'password',
        'remember_token',
        'two_factor_secret',
        'sandi_awal',
        // Hash tidak boleh tampil walau server sudah menyensornya.
        'password_hash',
        'api_hash',
        'Hash_Kunci',
      ]) {
        expect(PerubahanKolom(kolom: nama).rahasia, isTrue, reason: nama);
      }
      for (final nama in ['nama', 'email', 'tanggal_kalibrasi']) {
        expect(PerubahanKolom(kolom: nama).rahasia, isFalse, reason: nama);
      }
    });

    test('FilterAuditLog.toQuery memakai nama kunci persis kontrak', () {
      expect(const FilterAuditLog().toQuery(), isEmpty);
      expect(const FilterAuditLog().kosong, isTrue);

      final f = FilterAuditLog(
        aksi: 'diubah',
        entityType: 'standards',
        entityId: 1,
        dari: DateTime(2026, 7, 1),
        sampai: DateTime(2026, 7, 31),
      );

      expect(f.toQuery(page: 2), {
        'action': 'diubah',
        'entity_type': 'standards',
        'entity_id': '1',
        'dari': '2026-07-01',
        'sampai': '2026-07-31',
        'page': '2',
      });
      expect(f.jumlahAktif, 5);
      // `salin` bisa MENGOSONGKAN satu penyaring, bukan cuma mengisi.
      expect(f.salin(aksi: null).aksi, isNull);
      expect(f.salin(aksi: null).entityType, 'standards');
    });
  });

  group('ApiAuditLogService', () {
    ApiAuditLogService service(
      Future<http.Response> Function(http.Request) handler,
    ) => ApiAuditLogService(
      ApiClient(client: MockClient(handler), baseUrl: _baseUrl),
    );

    test('GET /audit-logs tanpa penyaring, dengan token', () async {
      late http.Request terkirim;
      final s = service((req) async {
        terkirim = req;
        return _json(_jawabanKontrak, 200);
      });

      final halaman = await s.daftar('tkn-abc');

      expect(terkirim.method, 'GET');
      expect(terkirim.url.toString(), '$_baseUrl/audit-logs');
      expect(terkirim.headers['Authorization'], 'Bearer tkn-abc');
      expect(halaman.items, hasLength(1));
    });

    test('penyaring + halaman masuk ke query string', () async {
      late http.Request terkirim;
      final s = service((req) async {
        terkirim = req;
        return _json(_jawabanKontrak, 200);
      });

      await s.daftar(
        't',
        filter: FilterAuditLog(
          aksi: 'diubah',
          entityType: 'standards',
          entityId: 1,
          dari: DateTime(2026, 7, 1),
          sampai: DateTime(2026, 7, 31),
        ),
        page: 3,
      );

      expect(terkirim.url.path, '/api/audit-logs');
      expect(terkirim.url.queryParameters, {
        'action': 'diubah',
        'entity_type': 'standards',
        'entity_id': '1',
        'dari': '2026-07-01',
        'sampai': '2026-07-31',
        'page': '3',
      });
    });

    test(
      '403 (teknisi/viewer): ApiException 403 dengan pesan server',
      () async {
        final s = service(
          (req) async =>
              _json({'message': 'Kamu nggak punya akses ke sini.'}, 403),
        );

        await expectLater(
          s.daftar('t'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.status, 'status', 403)
                .having(
                  (e) => e.message,
                  'message',
                  'Kamu nggak punya akses ke sini.',
                ),
          ),
        );
      },
    );

    test(
      '422 (aksi di luar daftar server) dilempar sebagai ApiException 422',
      () async {
        final s = service(
          (req) async => _json({
            'message': 'Aksi cuma bisa: dibikin, diubah, dihapus, dipulihkan.',
          }, 422),
        );

        await expectLater(
          s.daftar('t', filter: const FilterAuditLog(aksi: 'dibaca')),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
        );
      },
    );

    // Riwayat tulis-sekali: server tidak punya rute tulis untuk `/audit-logs`,
    // jadi service-nya tidak boleh punya jalan tulis juga. Dibaca sebagai TEKS
    // (cara yang sama dengan `nama_izin_test.dart`) karena yang dijaga justru
    // method yang belum pernah ditulis siapa pun.
    test('service riwayat tidak punya jalur tulis ke server', () {
      final sumber = File(
        'lib/services/audit_log_service.dart',
      ).readAsStringSync();
      final api = sumber.substring(
        sumber.indexOf('class ApiAuditLogService'),
        sumber.indexOf('class MockAuditLogService'),
      );

      for (final terlarang in [
        '.post(',
        '.put(',
        '.patch(',
        '.delete(',
        'unggah',
      ]) {
        expect(api.contains(terlarang), isFalse, reason: terlarang);
      }
      expect(api.contains('_api.get('), isTrue);
    });
  });

  group('Provider', () {
    ProviderContainer wadah(AuditLogService service) {
      final w = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
          auditLogServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(w.dispose);
      return w;
    }

    Future<void> login(ProviderContainer w, String id) => w
        .read(authProvider.notifier)
        .login(identifier: id, password: 'rahasia123');

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'muat lebih banyak MENAMBAH halaman berikutnya sampai habis',
      () async {
        final service = MockAuditLogService(
          ukuranHalaman: 2,
          data: [for (var i = 1; i <= 5; i++) _item(i)],
        );
        final w = wadah(service);
        await login(w, 'SDK-0001');

        final langganan = w.listen(auditLogProvider, (_, _) {});
        addTearDown(langganan.close);
        final c = w.read(auditLogProvider.notifier);

        expect((await w.read(auditLogProvider.future)).map((e) => e.id), [
          1,
          2,
        ]);
        expect(c.bisaMuatLagi, isTrue);

        await c.muatLebihBanyak();
        expect(w.read(auditLogProvider).value!.map((e) => e.id), [1, 2, 3, 4]);

        await c.muatLebihBanyak();
        expect(w.read(auditLogProvider).value!.map((e) => e.id), [
          1,
          2,
          3,
          4,
          5,
        ]);
        expect(c.bisaMuatLagi, isFalse);

        // Sudah habis: tidak menembak server lagi.
        final sebelum = service.jumlahPanggilan;
        await c.muatLebihBanyak();
        expect(service.jumlahPanggilan, sebelum);
      },
    );

    test(
      'terapkan penyaring kembali ke halaman 1 dan mengirim penyaringnya',
      () async {
        final service = MockAuditLogService(
          ukuranHalaman: 2,
          data: [
            for (var i = 1; i <= 5; i++)
              _item(i, aksi: i.isEven ? 'diubah' : 'dibikin'),
          ],
        );
        final w = wadah(service);
        await login(w, 'SDK-0001');
        final langganan = w.listen(auditLogProvider, (_, _) {});
        addTearDown(langganan.close);
        final c = w.read(auditLogProvider.notifier);
        await w.read(auditLogProvider.future);
        await c.muatLebihBanyak();

        await c.terapkanFilter(const FilterAuditLog(aksi: 'diubah'));

        expect(service.filterTerakhir!.aksi, 'diubah');
        expect(service.halamanTerakhir, 1);
        expect(w.read(auditLogProvider).value!.map((e) => e.id), [2, 4]);
        expect(c.filter.aksi, 'diubah');
      },
    );

    test(
      'GANTI AKUN waktu "muat lebih banyak" di jalan: halaman 2 akun lama dibuang',
      () async {
        final service = _TahanHalamanDua();
        final w = wadah(service);

        await login(w, 'SDK-0001');
        final langganan = w.listen(auditLogProvider, (_, _) {});
        addTearDown(langganan.close);
        await w.read(auditLogProvider.future);

        // Akun A minta halaman 2; jawabannya ditahan.
        final pending = w.read(auditLogProvider.notifier).muatLebihBanyak();

        await w.read(authProvider.notifier).logout();
        await login(w, 'SDK-0002');
        final untukB = await w.read(auditLogProvider.future);
        expect(untukB.map((e) => e.id), [202]);

        // Halaman 2 akun A pulang SESUDAH B login.
        service.tahan.complete(
          HalamanAuditLog(
            items: [_item(999, tipe: 'MILIK-A-HALAMAN-2')],
            currentPage: 2,
            lastPage: 3,
          ),
        );
        await pending;

        expect(
          w.read(auditLogProvider).value!.map((e) => e.id),
          [202],
          reason: 'baris milik akun A menempel ke riwayat akun B',
        );
        expect(w.read(auditLogProvider.notifier).bisaMuatLagi, isTrue);
      },
    );

    test(
      'GANTI AKUN: data & penyaring akun lama tidak ikut, server ditarik ulang',
      () async {
        final service = _PerAkun();
        final w = wadah(service);

        await login(w, 'SDK-0001');
        final langganan = w.listen(auditLogProvider, (_, _) {});
        addTearDown(langganan.close);
        final c = w.read(auditLogProvider.notifier);
        expect((await w.read(auditLogProvider.future)).single.id, 101);
        await c.terapkanFilter(const FilterAuditLog(aksi: 'diubah'));
        expect(c.filter.aksi, 'diubah');

        await w.read(authProvider.notifier).logout();
        await login(w, 'SDK-0002');

        final untukB = await w.read(auditLogProvider.future);
        // Data B, bukan data A yang kebawa...
        expect(untukB.single.id, 202);
        expect(untukB.single.entitasTipe, 'milik-mock-token-2');
        // ...penyaring A tidak jadi penyaring awal B...
        expect(w.read(auditLogProvider.notifier).filter.kosong, isTrue);
        // ...dan servernya BENAR-BENAR ditanya ulang dengan token B (bukan
        // kebetulan datanya mirip).
        expect(service.tokenDipakai.last, 'mock-token-2');
        expect(
          service.tokenDipakai.where((t) => t == 'mock-token-2'),
          isNotEmpty,
        );
        expect(service.tokenDipakai.first, 'mock-token-1');
      },
    );
  });

  group('Layar Riwayat perubahan', () {
    testWidgets(
      'admin melihat daftar, catatan baca-saja, dan TIDAK ada aksi tulis',
      (tester) async {
        await _pasang(tester, _app(MockAuditLogService()));

        expect(find.text('Riwayat perubahan'), findsOneWidget);
        expect(find.text('users #2'), findsOneWidget);
        expect(find.text('standards #7'), findsOneWidget);
        expect(find.text('equipments #12'), findsOneWidget);
        expect(find.textContaining('Hanya baca'), findsOneWidget);
        // Pelaku manusia vs job otomatis.
        expect(find.textContaining('oleh Budi Santoso'), findsWidgets);
        expect(find.textContaining('oleh sistem (otomatis)'), findsOneWidget);
        // Tanggalnya ikut bahasa app (bukan "Oct").
        expect(find.textContaining('Okt 2026'), findsWidgets);

        // Baca saja: tidak ada tombol tambah/ubah/hapus/ekspor.
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.download_outlined), findsNothing);
      },
    );

    testWidgets('super admin juga melihat daftar (aturan baca GET di server)', (
      tester,
    ) async {
      await _pasang(tester, _app(MockAuditLogService(), token: 'mock-token-5'));

      expect(find.text('users #2'), findsOneWidget);
    });

    testWidgets('teknisi ditolak di layar dan server TIDAK ditanya', (
      tester,
    ) async {
      final service = MockAuditLogService();
      await _pasang(tester, _app(service, token: 'mock-token-2'));

      expect(
        find.text('Cuma admin yang bisa lihat riwayat perubahan.'),
        findsOneWidget,
      );
      expect(find.text('users #2'), findsNothing);
      expect(service.jumlahPanggilan, 0);
    });

    testWidgets('gerbang mengikuti /me/permissions, bukan cuma peran', (
      tester,
    ) async {
      // Server bilang teknisi ini BOLEH `pengguna.kelola` → layar terbuka.
      await _pasang(
        tester,
        _app(
          MockAuditLogService(),
          token: 'mock-token-2',
          izin: const Izin(
            role: UserRole.teknisi,
            boleh: {NamaIzin.penggunaKelola},
          ),
        ),
      );
      expect(find.text('users #2'), findsOneWidget);
    });

    testWidgets('ketuk baris: rincian kolom lama → baru', (tester) async {
      await _pasang(tester, _app(MockAuditLogService()));

      await tester.tap(find.text('users #2'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('email'), findsOneWidget);
      expect(find.text('Sebelum: eko@gmial.com'), findsOneWidget);
      expect(find.text('Sesudah: eko@gmail.com'), findsOneWidget);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('kolom rahasia tidak pernah menampilkan nilainya', (
      tester,
    ) async {
      final service = MockAuditLogService(
        data: [
          _item(
            9,
            tipe: 'users',
            perubahan: const [
              PerubahanKolom(
                kolom: 'password',
                lama: r'$2y$10$hashLama',
                baru: r'$2y$10$hashBaru',
              ),
              PerubahanKolom(kolom: 'nama', lama: 'Eko', baru: 'Eko P.'),
            ],
          ),
        ],
      );
      await _pasang(tester, _app(service));

      await tester.tap(find.text('users #9'));
      await tester.pumpAndSettle();

      expect(find.text('password'), findsOneWidget);
      expect(find.text('Sebelum: (disembunyikan)'), findsOneWidget);
      expect(find.text('Sesudah: (disembunyikan)'), findsOneWidget);
      expect(find.textContaining('hashLama'), findsNothing);
      expect(find.textContaining('hashBaru'), findsNothing);
      // Kolom biasa tetap tampil.
      expect(find.text('Sesudah: Eko P.'), findsOneWidget);
    });

    testWidgets(
      'hapus/pulihkan tanpa rincian kolom + aksi tak dikenal ditampilkan apa adanya',
      (tester) async {
        final service = MockAuditLogService(
          data: [
            _item(1, tipe: 'rooms', aksi: 'dihapus'),
            _item(
              2,
              tipe: 'customers',
              aksi: 'dibaca',
              catatan: 'Akses lintas lab',
            ),
          ],
        );
        await _pasang(tester, _app(service));

        expect(find.text('Dihapus'), findsOneWidget);
        expect(find.text('dibaca'), findsOneWidget);

        await tester.tap(find.text('rooms #1'));
        await tester.pumpAndSettle();
        expect(
          find.text('Tidak ada rincian kolom untuk aksi ini.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('customers #2'));
        await tester.pumpAndSettle();
        expect(find.text('Catatan: Akses lintas lab'), findsOneWidget);
      },
    );

    testWidgets(
      'filter aksi: dikirim ke server, daftar menyempit, lencana & reset',
      (tester) async {
        final service = MockAuditLogService(
          data: [
            _item(1, aksi: 'dibikin'),
            _item(2, aksi: 'diubah'),
            _item(3, aksi: 'diubah'),
          ],
        );
        await _pasang(tester, _app(service));
        expect(find.text('standards #1'), findsOneWidget);

        await tester.tap(find.byTooltip('Filter'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Diubah'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Terapkan'));
        await tester.pumpAndSettle();

        expect(service.filterTerakhir!.aksi, 'diubah');
        expect(find.text('standards #1'), findsNothing);
        expect(find.text('standards #2'), findsOneWidget);
        // Lencana jumlah penyaring aktif.
        expect(find.text('1'), findsOneWidget);

        await tester.tap(find.byTooltip('Filter'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();

        expect(service.filterTerakhir!.kosong, isTrue);
        expect(find.text('standards #1'), findsOneWidget);
      },
    );

    testWidgets('jenis data + ID data masuk sebagai penyaring', (tester) async {
      final service = MockAuditLogService();
      await _pasang(tester, _app(service));

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Jenis data (nama tabel)'),
        ' standards ',
      );
      await tester.enterText(find.widgetWithText(TextField, 'ID data'), '7');
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      expect(service.filterTerakhir!.entityType, 'standards');
      expect(service.filterTerakhir!.entityId, 7);
      expect(find.text('standards #7'), findsOneWidget);
      expect(find.text('users #2'), findsNothing);
    });

    testWidgets('hasil kosong: pesan jelas, dan reset kalau ada penyaring', (
      tester,
    ) async {
      final service = MockAuditLogService(data: const []);
      await _pasang(tester, _app(service));

      expect(
        find.text('Tidak ada riwayat untuk penyaring ini.'),
        findsOneWidget,
      );
      // Tanpa penyaring aktif, tidak ada tombol Reset yang menyesatkan.
      expect(find.widgetWithText(ElevatedButton, 'Reset'), findsNothing);
    });

    testWidgets(
      'server gagal: pesan + Coba lagi yang benar-benar menarik ulang',
      (tester) async {
        final service = MockAuditLogService(gagal: true);
        await _pasang(tester, _app(service));

        expect(find.text('Riwayat belum bisa dimuat.'), findsOneWidget);
        final sebelum = service.jumlahPanggilan;

        await tester.tap(find.text('Coba lagi'));
        await tester.pumpAndSettle();

        expect(service.jumlahPanggilan, greaterThan(sebelum));
      },
    );

    testWidgets(
      'muat lebih banyak: menambah baris, tombol hilang di halaman terakhir',
      (tester) async {
        final service = MockAuditLogService(
          ukuranHalaman: 2,
          data: [for (var i = 1; i <= 3; i++) _item(i)],
        );
        await _pasang(tester, _app(service));

        expect(find.text('standards #1'), findsOneWidget);
        expect(find.text('standards #3'), findsNothing);

        await tester.tap(find.text('Muat lebih banyak'));
        await tester.pumpAndSettle();

        expect(find.text('standards #3'), findsOneWidget);
        expect(find.text('Muat lebih banyak'), findsNothing);
      },
    );

    testWidgets('halaman berikutnya gagal: daftar yang sudah ada tetap utuh', (
      tester,
    ) async {
      await _pasang(tester, _app(_GagalHalamanDua()));

      await tester.tap(find.text('Muat lebih banyak'));
      await tester.pumpAndSettle();

      expect(
        find.text('Halaman berikutnya gagal dimuat. Coba lagi.'),
        findsOneWidget,
      );
      expect(find.text('standards #1'), findsOneWidget);
      expect(find.text('standards #2'), findsOneWidget);
      // Dan masih bisa dicoba lagi.
      expect(find.text('Muat lebih banyak'), findsOneWidget);
    });
  });
}
