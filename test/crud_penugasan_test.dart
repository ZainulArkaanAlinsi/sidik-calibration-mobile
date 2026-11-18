import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/penugasan.dart';
import 'package:sidik_calibration/models/penugasan_kelola.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/pendaftaran_push_provider.dart';
import 'package:sidik_calibration/providers/penugasan_kelola_provider.dart';
import 'package:sidik_calibration/screens/crud_lab/pengelolaan_data_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/penugasan_kelola_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/penugasan_ubah_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/penugasan_kelola_service.dart';
import 'package:sidik_calibration/services/pengguna_sa_service.dart';
import 'package:sidik_calibration/services/sumber_token_push.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'support/crud_uji.dart';
import 'support/layar_sa_uji.dart' show ketukDi;
import 'support/super_admin_uji.dart' show aturLayar, selesaikan;

/// Penugasan: ubah dan batalkan (kontrak `docs/perintah-frontend-crud-lengkap.md`
/// §4). Bentuk JSON `bentuk()` di `PenugasanController` (repo API, branch CRUD,
/// 18 Nov 2026): `batal`, `teknisi[]` ketua dulu, `item[]` dengan `id`,
/// `jenis_alat`, `jumlah`, `jumlah_selesai`, `paket`, `catatan`.
const _dasar = 'https://api.test/api';

http.Response _json(Object badan, [int status = 200]) => http.Response(
  jsonEncode(badan),
  status,
  headers: {'content-type': 'application/json'},
);

PenugasanKelolaService _layanan(
  Future<http.Response> Function(http.Request) h,
) => ApiPenugasanKelolaService(
  ApiClient(client: MockClient(h), baseUrl: _dasar),
);

Map<String, dynamic> _badan(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

Map<String, dynamic> _json14({String status = 'aktif', Object? batal}) => {
  'id': 14,
  'judul': 'Kalibrasi minggu ini',
  'tipe': 'grup',
  'status': status,
  'tanggal_target': '2026-11-30',
  'terlambat': false,
  'persen_tuntas': 43,
  'catatan': null,
  'dibuat_oleh': 'Rina',
  'batal': batal,
  'teknisi': [
    {
      'id': 21,
      'nama': 'Dedi',
      'kode': 'DDT',
      'peran': 'ketua',
      'dilihat_pada': null,
    },
    {
      'id': 22,
      'nama': 'Eko',
      'kode': 'EKP',
      'peran': 'anggota',
      'dilihat_pada': null,
    },
  ],
  'item': [
    {
      'id': 31,
      'jenis_alat': 'Autoklaf',
      'kategori': null,
      'jumlah': 12,
      'jumlah_selesai': 5,
      'paket': null,
      'catatan': 'catatan teknisi',
    },
    {
      'id': 32,
      'jenis_alat': 'Timbangan',
      'kategori': null,
      'jumlah': 4,
      'jumlah_selesai': 0,
      'paket': 'ORD/2026/11/0003',
      'catatan': null,
    },
  ],
};

Penugasan _p14() => Penugasan.fromJson(_json14());

/// Kolom isian yang isinya persis [teks] (isi TextField bukan `Text`, jadi
/// `widgetWithText` tidak menemukannya).
Finder _kolomDengan(String teks) =>
    find.byWidgetPredicate((w) => w is TextField && w.controller?.text == teks);

void main() {
  group('model Penugasan.batal (aditif)', () {
    test('null selama belum dibatalkan, terisi sesudahnya', () {
      expect(Penugasan.fromJson(_json14()).batal, isNull);

      final p = Penugasan.fromJson(
        _json14(
          status: 'dibatalkan',
          batal: {
            'alasan': 'Pelanggan membatalkan pesanan.',
            'oleh': 'Sari',
            'pada': '2026-11-18T11:00:00+07:00',
          },
        ),
      );
      expect(p.batal!.alasan, 'Pelanggan membatalkan pesanan.');
      expect(p.batal!.oleh, 'Sari');
      expect(p.batal!.pada, isNotNull);
    });

    test(
      'penugasan lama dibatalkan lewat panel: alasan null tidak melempar',
      () {
        final p = Penugasan.fromJson(
          _json14(
            status: 'dibatalkan',
            batal: {'alasan': null, 'oleh': null, 'pada': null},
          ),
        );
        expect(p.batal, isNotNull);
        expect(p.batal!.alasan, isNull);
      },
    );

    test('server tanpa field batal (versi lama) dibaca null', () {
      final j = _json14()..remove('batal');
      expect(Penugasan.fromJson(j).batal, isNull);
    });
  });

  group('FormUbahPenugasan.toJson', () {
    FormUbahPenugasan form({
      String judul = 'Kalibrasi minggu ini',
      DateTime? target,
      String catatan = '',
      List<int> teknisi = const [21, 22],
      List<BarisUbahPenugasan>? baris,
    }) => FormUbahPenugasan(
      judul: judul,
      teknisi: teknisi,
      baris:
          baris ?? [for (final b in _p14().baris) BarisUbahPenugasan.dari(b)],
      tanggalTarget: target ?? DateTime(2026, 11, 30),
      catatan: catatan,
      awal: _p14(),
    );

    test(
      'tanpa perubahan: target & catatan TIDAK dikirim (dibiarkan server)',
      () {
        final b = form().toJson();

        expect(b.containsKey('tanggal_target'), isFalse);
        expect(b.containsKey('catatan'), isFalse);
        expect(b['teknisi'], [21, 22]);
      },
    );

    test('baris lama membawa id dan TIDAK membawa catatan (milik teknisi)', () {
      final item = (form().toJson()['item'] as List).cast<Map>();

      expect(item[0], {'id': 31, 'jenis_alat': 'Autoklaf', 'jumlah': 12});
      expect(item[0].containsKey('catatan'), isFalse);
      expect(item[0].containsKey('jumlah_selesai'), isFalse);
    });

    test('baris BARU tanpa id, catatan hanya bila diisi', () {
      final b = form(
        baris: [
          const BarisUbahPenugasan(
            jenisAlat: ' pH Meter ',
            jumlah: 3,
            catatan: ' cepat ',
          ),
          const BarisUbahPenugasan(jenisAlat: 'Oven', jumlah: 1),
        ],
      ).toJson();
      final item = (b['item'] as List).cast<Map>();

      expect(item[0], {
        'jenis_alat': 'pH Meter',
        'jumlah': 3,
        'catatan': 'cepat',
      });
      expect(item[1], {'jenis_alat': 'Oven', 'jumlah': 1});
    });

    test('target berubah dikirim; dikosongkan dikirim null eksplisit', () {
      expect(
        form(target: DateTime(2026, 12, 5)).toJson()['tanggal_target'],
        '2026-12-05',
      );

      final kosong = FormUbahPenugasan(
        judul: 'x',
        teknisi: const [21],
        baris: const [BarisUbahPenugasan(jenisAlat: 'a', jumlah: 1)],
        tanggalTarget: null,
        awal: _p14(),
      ).toJson();
      expect(kosong.containsKey('tanggal_target'), isTrue);
      expect(kosong['tanggal_target'], isNull);
    });

    test('catatan berubah dikirim, dikosongkan menjadi null', () {
      expect(form(catatan: ' baru ').toJson()['catatan'], 'baru');

      final awal = Penugasan.fromJson(_json14()..['catatan'] = 'lama');
      final f = FormUbahPenugasan(
        judul: 'x',
        teknisi: const [21],
        baris: const [],
        tanggalTarget: awal.tanggalTarget,
        catatan: '',
        awal: awal,
      ).toJson();
      expect(f.containsKey('catatan'), isTrue);
      expect(f['catatan'], isNull);
    });

    test('urutan teknisi dipertahankan (yang pertama = ketua)', () {
      expect(form(teknisi: const [22, 21]).toJson()['teknisi'], [22, 21]);
    });

    test('baris berprogres tidak boleh dibuang dari sisi UI', () {
      final b = BarisUbahPenugasan.dari(_p14().baris.first);
      expect(b.sudahDikerjakan, isTrue);
      expect(
        BarisUbahPenugasan.dari(_p14().baris.last).sudahDikerjakan,
        isFalse,
      );
    });
  });

  group('service API', () {
    test('daftar: status + page, paginasi dari meta', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({
          'data': [_json14()],
          'meta': {
            'total': 41,
            'per_page': 20,
            'current_page': 2,
            'last_page': 3,
          },
        });
      });
      final h = await s.daftar('tkn', status: 'aktif', halaman: 2);

      expect(terkirim.method, 'GET');
      expect(terkirim.url.path, '/api/penugasan');
      expect(terkirim.url.queryParameters, {'status': 'aktif', 'page': '2'});
      expect(h.items.single.baris, hasLength(2));
      expect(h.halamanTerakhir, 3);
      expect(h.adaLagi, isTrue);
    });

    test('ubah: PUT /penugasan/{id}, body = FormUbahPenugasan', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({'message': 'Penugasan diubah.', 'data': _json14()});
      });
      final f = FormUbahPenugasan(
        judul: 'Revisi',
        teknisi: const [21],
        baris: const [
          BarisUbahPenugasan(id: 31, jenisAlat: 'Autoklaf', jumlah: 10),
        ],
        tanggalTarget: DateTime(2026, 11, 30),
        awal: _p14(),
      );
      final p = await s.ubah('tkn', 14, f);

      expect(terkirim.method, 'PUT');
      expect(terkirim.url.path, '/api/penugasan/14');
      expect(_badan(terkirim), {
        'judul': 'Revisi',
        'teknisi': [21],
        'item': [
          {'id': 31, 'jenis_alat': 'Autoklaf', 'jumlah': 10},
        ],
      });
      expect(p.id, 14);
    });

    test('batalkan: POST /penugasan/{id}/batalkan dengan alasan', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({
          'message': 'Penugasan dibatalkan.',
          'data': _json14(
            status: 'dibatalkan',
            batal: {
              'alasan': 'x',
              'oleh': 'Sari',
              'pada': '2026-11-18T11:00:00+07:00',
            },
          ),
        });
      });
      final p = await s.batalkan('tkn', 14, alasan: 'Pelanggan membatalkan.');

      expect(terkirim.method, 'POST');
      expect(terkirim.url.path, '/api/penugasan/14/batalkan');
      expect(_badan(terkirim), {'alasan': 'Pelanggan membatalkan.'});
      expect(p.status, 'dibatalkan');
      expect(p.batal!.oleh, 'Sari');
    });

    // Badan galat disalin dari §4 dan §7 kontrak.
    final galat = <(String, int, Map<String, dynamic>)>[
      ('401', 401, {'message': 'Unauthenticated.'}),
      ('403 peran', 403, {'message': 'Akses ditolak.'}),
      ('404 lab lain', 404, {'message': 'No query results.'}),
      (
        '422 penugasan_tidak_aktif',
        422,
        {
          'message': 'Sudah selesai.',
          'kode': 'penugasan_tidak_aktif',
          'status': 'selesai',
        },
      ),
      (
        '422 penugasan_sudah_selesai',
        422,
        {'message': 'Sudah selesai.', 'kode': 'penugasan_sudah_selesai'},
      ),
      (
        '422 item_sudah_dikerjakan',
        422,
        {
          'message': 'x',
          'kode': 'item_sudah_dikerjakan',
          'errors': {
            'item': ['Baris yang sudah ada progresnya tidak bisa dibuang.'],
          },
        },
      ),
      ('429', 429, {'message': 'Kebanyakan.'}),
      ('500', 500, {'message': 'Server Error'}),
    ];

    for (final (nama, status, badan) in galat) {
      test('ubah & batalkan: $nama → ApiException berbadan asli', () async {
        final s = _layanan((_) async => _json(badan, status));
        final f = FormUbahPenugasan(
          judul: 'x',
          teknisi: const [21],
          baris: const [BarisUbahPenugasan(jenisAlat: 'a', jumlah: 1)],
          awal: _p14(),
        );
        for (final panggil in [
          () => s.ubah('t', 14, f),
          () => s.batalkan('t', 14, alasan: 'alasan sah'),
        ]) {
          await expectLater(
            panggil(),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.status, 'status', status)
                  .having((e) => e.body['kode'], 'kode', badan['kode']),
            ),
          );
        }
      });
    }

    test(
      'batalkan: jaringan putus → KoneksiException, tidak diulang',
      () async {
        var panggilan = 0;
        final s = _layanan((_) async {
          panggilan++;
          throw const SocketException('putus');
        });
        await expectLater(
          s.batalkan('t', 14, alasan: 'alasan sah'),
          throwsA(isA<KoneksiException>()),
        );
        expect(panggilan, 1);
      },
    );
  });

  group('provider', () {
    ProviderContainer wadah(PenugasanKelolaService layanan) {
      final w = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          sumberTokenPushProvider.overrideWithValue(const TanpaTokenPush()),
          penugasanKelolaServiceProvider.overrideWithValue(layanan),
        ],
      );
      addTearDown(w.dispose);
      return w;
    }

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('bawaan hanya penugasan AKTIF; saring mengganti status', () async {
      final layanan = MockPenugasanKelolaService();
      final w = wadah(layanan);
      await w
          .read(authProvider.notifier)
          .login(identifier: 'SDK-0001', password: 'rahasia123');
      final l = w.listen(penugasanKelolaProvider, (_, _) {});
      addTearDown(l.close);

      final awal = await w.read(penugasanKelolaProvider.future);
      expect(awal.items.every((p) => p.status == 'aktif'), isTrue);
      expect(layanan.catatan.first, contains('status=aktif'));

      await w.read(penugasanKelolaProvider.notifier).saring('dibatalkan');
      expect(
        w.read(penugasanKelolaProvider).value!.items.single.status,
        'dibatalkan',
      );

      await w.read(penugasanKelolaProvider.notifier).saring(null);
      expect(w.read(penugasanKelolaProvider).value!.items, hasLength(4));
    });

    test(
      'ganti akun: saringan kembali ke aktif dan server dipanggil lagi',
      () async {
        final layanan = MockPenugasanKelolaService();
        final w = wadah(layanan);
        await w
            .read(authProvider.notifier)
            .login(identifier: 'SDK-0001', password: 'rahasia123');
        final l = w.listen(penugasanKelolaProvider, (_, _) {});
        addTearDown(l.close);
        await w.read(penugasanKelolaProvider.future);
        await w.read(penugasanKelolaProvider.notifier).saring('selesai');
        final sebelum = layanan.catatan.length;

        await w.read(authProvider.notifier).logout();
        await w
            .read(authProvider.notifier)
            .login(identifier: 'SDK-0002', password: 'rahasia123');
        await w.read(penugasanKelolaProvider.future);

        expect(layanan.catatan.length, greaterThan(sebelum));
        expect(w.read(penugasanKelolaProvider.notifier).status, 'aktif');
      },
    );
  });

  group('papan: gerbang izin dan aksi', () {
    Future<void> buka(
      WidgetTester tester, {
      MockPenugasanKelolaService? layanan,
      String token = tokenAdminCrud,
      Izin izin = izinAdminCrud,
      Widget layar = const PenugasanKelolaScreen(),
      double lebar = 392,
    }) async {
      aturLayar(tester, lebar, 852);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...LapisanUjiCrud(
              penugasan: layanan ?? MockPenugasanKelolaService(),
            ).overrides(token: token, izin: izin),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: layar,
          ),
        ),
      );
      await selesaikan(tester);
    }

    Future<void> menu(WidgetTester tester, int id, String aksi) async {
      await ketukDi(tester, find.byKey(Key('menu-penugasan-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(aksi));
      await tester.pumpAndSettle();
    }

    testWidgets('admin: kartu aktif punya menu Ubah + Batalkan', (
      tester,
    ) async {
      await buka(tester);

      expect(find.text('Kalibrasi minggu ini'), findsOneWidget);
      expect(find.text('Tim: Dedi Teknisi, Eko Prasetyo'), findsOneWidget);
      expect(find.byKey(const Key('menu-penugasan-14')), findsOneWidget);
      // Penugasan dibatalkan/selesai tidak tampil di bawaan (aktif saja).
      expect(find.text('Pengujian lama'), findsNothing);
    });

    testWidgets('teknisi: terkunci', (tester) async {
      await buka(tester, token: tokenTeknisiCrud, izin: izinTeknisiCrud);
      expect(
        find.text('Akun Anda tidak punya izin untuk bagian ini.'),
        findsOneWidget,
      );
      expect(find.text('Kalibrasi minggu ini'), findsNothing);
    });

    testWidgets('izin ubah tanpa izin batalkan: menu hanya Ubah', (
      tester,
    ) async {
      await buka(
        tester,
        izin: const Izin(role: UserRole.admin, boleh: {NamaIzin.penugasanUbah}),
      );
      await ketukDi(tester, find.byKey(const Key('menu-penugasan-14')));
      await tester.pumpAndSettle();

      expect(find.text('Ubah'), findsOneWidget);
      expect(find.text('Batalkan penugasan'), findsNothing);
    });

    testWidgets('saring Dibatalkan menampilkan jejak: alasan + pembatal', (
      tester,
    ) async {
      await buka(tester);
      await ketukDi(
        tester,
        find.byKey(const Key('saring-penugasan-dibatalkan')),
      );
      await selesaikan(tester);

      expect(
        find.text('Alasan: Pelanggan membatalkan pesanan.'),
        findsOneWidget,
      );
      expect(find.textContaining('Dibatalkan oleh Sari'), findsOneWidget);
      // Penugasan dibatalkan tidak punya menu aksi.
      expect(find.byKey(const Key('menu-penugasan-16')), findsNothing);
    });

    testWidgets('kosong: kalimat sendiri', (tester) async {
      await buka(tester, layanan: MockPenugasanKelolaService(awal: const []));
      expect(
        find.text('Tidak ada penugasan dengan status ini.'),
        findsOneWidget,
      );
    });

    testWidgets('galat memuat: kalimat sendiri + Coba lagi', (tester) async {
      await buka(
        tester,
        layanan: MockPenugasanKelolaService(galat: const KoneksiException('x')),
      );
      expect(find.text('Daftar penugasan belum bisa dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets(
      'batalkan: alasan wajib 5-400, tidak menembak server bila pendek',
      (tester) async {
        final layanan = MockPenugasanKelolaService();
        await buka(tester, layanan: layanan);

        await menu(tester, 14, 'Batalkan penugasan');
        await tester.enterText(find.byKey(const Key('isian-dialog')), 'abc');
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();

        expect(find.text('Alasan minimal 5 karakter.'), findsOneWidget);
        expect(layanan.catatan.where((c) => c.startsWith('batalkan')), isEmpty);

        await tester.enterText(
          find.byKey(const Key('isian-dialog')),
          'x' * 401,
        );
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();
        expect(find.text('Alasan maksimal 400 karakter.'), findsOneWidget);
        expect(layanan.catatan.where((c) => c.startsWith('batalkan')), isEmpty);
      },
    );

    testWidgets(
      'batalkan sah: server dipanggil, papan diambil ulang, kabar tampil',
      (tester) async {
        final layanan = MockPenugasanKelolaService();
        await buka(tester, layanan: layanan);

        await menu(tester, 14, 'Batalkan penugasan');
        await tester.enterText(
          find.byKey(const Key('isian-dialog')),
          'Pelanggan membatalkan pesanan.',
        );
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();

        expect(
          layanan.catatan,
          contains('batalkan 14 "Pelanggan membatalkan pesanan."'),
        );
        expect(find.text('Penugasan dibatalkan.'), findsOneWidget);
        // Bawaan = aktif: kartu itu hilang dari papan.
        expect(find.text('Kalibrasi minggu ini'), findsNothing);
      },
    );

    testWidgets(
      'batalkan penugasan yang sudah selesai: kalimat kode, dialog tetap',
      (tester) async {
        await buka(tester, layanan: _SelesaiSaatBatal());

        await menu(tester, 14, 'Batalkan penugasan');
        await tester.enterText(
          find.byKey(const Key('isian-dialog')),
          'alasan sah',
        );
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();

        expect(
          find.text('Penugasan ini sudah selesai, jadi tidak bisa dibatalkan.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('aksi-dialog')), findsOneWidget);
      },
    );
  });

  group('form ubah penugasan', () {
    Future<MockPenugasanKelolaService> buka(
      WidgetTester tester, {
      Penugasan? penugasan,
      MockPenugasanKelolaService? layanan,
      String token = tokenAdminCrud,
      Izin izin = izinAdminCrud,
      double lebar = 392,
    }) async {
      final l = layanan ?? MockPenugasanKelolaService();
      // Tinggi besar: daftar baris alat dibangun malas, dan tes ini memeriksa
      // isi SEMUA baris. Perilaku pada layar pendek diuji di crud_responsif.
      aturLayar(tester, lebar, 2400);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...LapisanUjiCrud(penugasan: l).overrides(token: token, izin: izin),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PenugasanUbahScreen(penugasan: penugasan ?? _p14()),
          ),
        ),
      );
      await selesaikan(tester);
      return l;
    }

    testWidgets('terisi dari penugasan; ketua ditandai; progres tampil', (
      tester,
    ) async {
      await buka(tester);

      expect(find.text('Kalibrasi minggu ini'), findsOneWidget);
      expect(find.textContaining('Dedi Teknisi · Ketua'), findsOneWidget);
      expect(find.text('Selesai 5'), findsOneWidget);
      expect(find.textContaining('Paket ORD/2026/11/0003'), findsOneWidget);
    });

    testWidgets('baris berprogres: tombol buang nonaktif; yang belum: bisa', (
      tester,
    ) async {
      await buka(tester);

      final terkunci = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.close).first,
      );
      final bebas = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.close).last,
      );
      expect(terkunci.onPressed, isNull);
      expect(bebas.onPressed, isNotNull);
    });

    testWidgets('simpan tanpa perubahan: body hanya judul/teknisi/item', (
      tester,
    ) async {
      final l = await buka(tester);
      await ketukDi(tester, find.byKey(const Key('simpan-penugasan')));
      await tester.pumpAndSettle();

      final b = l.badanTerakhir!;
      expect(b.containsKey('tanggal_target'), isFalse);
      expect(b.containsKey('catatan'), isFalse);
      expect((b['item'] as List).first, {
        'id': 31,
        'jenis_alat': 'Autoklaf',
        'jumlah': 12,
      });
    });

    testWidgets('ubah jumlah dan tambah baris terkirim; baris baru tanpa id', (
      tester,
    ) async {
      final l = await buka(tester);

      final jumlah = _kolomDengan('12');
      await tester.enterText(jumlah, '20');
      await ketukDi(tester, find.byKey(const Key('tambah-baris')));
      await tester.pumpAndSettle();
      final kosong = find.byType(TextField).evaluate().length;
      expect(kosong, greaterThan(0));
      // Isi jenis baris baru (kolom jenis terakhir bertulis kosong).
      final jenisBaru = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '' && w.maxLines == 1,
      );
      await tester.enterText(jenisBaru.first, 'pH Meter');
      await tester.pump();

      await ketukDi(tester, find.byKey(const Key('simpan-penugasan')));
      await tester.pumpAndSettle();

      final item = (l.badanTerakhir!['item'] as List).cast<Map>();
      expect(item.first['jumlah'], 20);
      expect(item.last.containsKey('id'), isFalse);
      expect(item.last['jenis_alat'], 'pH Meter');
    });

    testWidgets('baris tanpa jenis alat ditolak di klien', (tester) async {
      final l = await buka(tester);
      await ketukDi(tester, find.byKey(const Key('tambah-baris')));
      await tester.pumpAndSettle();
      await ketukDi(tester, find.byKey(const Key('simpan-penugasan')));
      await tester.pumpAndSettle();

      expect(find.text('Jenis alat wajib diisi.'), findsOneWidget);
      expect(l.catatan.where((c) => c.startsWith('ubah')), isEmpty);
    });

    testWidgets('jumlah 0 ditolak di klien (bukan diam-diam jadi 1)', (
      tester,
    ) async {
      final l = await buka(tester);
      await tester.enterText(_kolomDengan('4'), '0');
      await ketukDi(tester, find.byKey(const Key('simpan-penugasan')));
      await tester.pumpAndSettle();

      expect(find.text('Jumlah harus 1 sampai 999.'), findsOneWidget);
      expect(l.catatan.where((c) => c.startsWith('ubah')), isEmpty);
    });

    testWidgets('melepas semua teknisi ditolak di klien', (tester) async {
      final l = await buka(tester);
      await tester.tap(find.byKey(const Key('teknisi-21')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('teknisi-22')));
      await tester.pump();
      await ketukDi(tester, find.byKey(const Key('simpan-penugasan')));
      await tester.pumpAndSettle();

      expect(find.text('Pilih minimal satu teknisi.'), findsOneWidget);
      expect(l.catatan.where((c) => c.startsWith('ubah')), isEmpty);
    });

    testWidgets('judul kosong ditolak di klien', (tester) async {
      final l = await buka(tester);
      await tester.enterText(_kolomDengan('Kalibrasi minggu ini'), ' ');
      await ketukDi(tester, find.byKey(const Key('simpan-penugasan')));
      await tester.pumpAndSettle();

      expect(find.text('Judul wajib diisi.'), findsOneWidget);
      expect(l.catatan.where((c) => c.startsWith('ubah')), isEmpty);
    });

    testWidgets('penugasan sudah selesai (server): kalimat kode, form tetap', (
      tester,
    ) async {
      final l = await buka(
        tester,
        layanan: MockPenugasanKelolaService(
          awal: [Penugasan.fromJson(_json14(status: 'selesai'))],
        ),
      );
      expect(l, isNotNull);
      await ketukDi(tester, find.byKey(const Key('simpan-penugasan')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          RegExp('sudah selesai, jadi tidak bisa diubah', caseSensitive: false),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('simpan-penugasan')), findsOneWidget);
    });

    testWidgets('teknisi tidak boleh membuka form (gerbang izin di layar)', (
      tester,
    ) async {
      await buka(tester, token: tokenTeknisiCrud, izin: izinTeknisiCrud);

      expect(find.byKey(const Key('simpan-penugasan')), findsNothing);
      expect(
        find.text('Akun Anda tidak punya izin untuk bagian ini.'),
        findsOneWidget,
      );
    });
  });

  group('hub', () {
    testWidgets('admin melihat pintu Penugasan; teknisi tidak', (tester) async {
      aturLayar(tester, 392, 852);
      await tester.pumpWidget(bungkusCrud(const PengelolaanDataScreen()));
      await selesaikan(tester);
      expect(find.byKey(const Key('pintu-penugasan')), findsOneWidget);

      // Akar diganti dulu supaya ProviderScope baru lahir bersih (overrides
      // satu scope tidak boleh berganti di tengah jalan).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        bungkusCrud(
          const PengelolaanDataScreen(),
          token: tokenTeknisiCrud,
          izin: izinTeknisiCrud,
        ),
      );
      await selesaikan(tester);
      expect(find.byKey(const Key('pintu-penugasan')), findsNothing);
    });
  });
}

/// Meniru server yang menjawab `penugasan_sudah_selesai` saat dibatalkan.
class _SelesaiSaatBatal extends MockPenugasanKelolaService {
  _SelesaiSaatBatal() : super();

  @override
  Future<Penugasan> batalkan(
    String token,
    int id, {
    required String alasan,
  }) async => throw const ApiException(
    'x',
    status: 422,
    body: {'message': 'x', 'kode': 'penugasan_sudah_selesai'},
  );
}
