import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/l10n/app_localizations_id.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/penugasan.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/screens/crud_lab/penugasan_kelola_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/widgets/pesan_galat_crud.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/penugasan_kelola_service.dart';

import 'support/crud_uji.dart';
import 'support/layar_sa_uji.dart' show ketukDi;
import 'support/super_admin_uji.dart' show aturLayar, selesaikan;

/// Selesaikan dan buka lagi penugasan (PR #284, 19 Nov 2026). Bentuk JSON,
/// rute, kode galat, dan izin disalin dari kontrak di repo API:
/// `docs/perintah-frontend-penugasan-selesai.md` (branch `fix/qa-ronde2-b`,
/// head 09653f46) bagian 1 sampai 4:
///  - `POST /penugasan/{p}/selesaikan` tanpa badan; admin dan super admin;
///    200 `{message, data}` dengan `diselesaikan_pada` ISO-8601.
///  - `POST /penugasan/{p}/buka-lagi` `{alasan}` 5 sampai 400; super admin saja.
///  - 422 berkode: `penugasan_belum_tuntas` (+`persen_tuntas`),
///    `penugasan_sudah_selesai` (kirim ulang: anggap sudah selesai),
///    `penugasan_tidak_aktif`, `penugasan_tidak_selesai`.
///  - izin `penugasan.selesaikan` dan `penugasan.buka-lagi`.
const _dasar = 'https://api.test/api';

http.Response _json(Object badan, [int status = 200]) => http.Response(
  jsonEncode(badan),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _json14({
  String status = 'aktif',
  int persen = 100,
  String? diselesaikanPada,
}) => {
  'id': 14,
  'judul': 'Kalibrasi minggu ini',
  'tipe': 'grup',
  'status': status,
  'tanggal_target': '2026-11-30',
  'terlambat': false,
  'persen_tuntas': persen,
  'catatan': null,
  'dibuat_oleh': 'Rina',
  'batal': null,
  'diselesaikan_pada': diselesaikanPada,
  'teknisi': [
    {'id': 21, 'nama': 'Dedi', 'kode': 'DDT', 'peran': 'ketua'},
  ],
  'item': [
    {
      'id': 31,
      'jenis_alat': 'Autoklaf',
      'jumlah': 12,
      'jumlah_selesai': 12,
      'paket': null,
      'catatan': null,
    },
  ],
};

PenugasanKelolaService _layanan(
  Future<http.Response> Function(http.Request) h,
) => ApiPenugasanKelolaService(
  ApiClient(client: MockClient(h), baseUrl: _dasar),
);

Penugasan _p(
  int id, {
  String status = 'aktif',
  int persen = 100,
  DateTime? selesaiPada,
}) => Penugasan(
  id: id,
  judul: 'Tugas $id',
  tipe: 'personal',
  status: status,
  terlambat: false,
  persenTuntas: persen,
  diselesaikanPada: selesaiPada,
  teknisi: const [AnggotaPenugasan(id: 21, nama: 'Dedi', peran: 'ketua')],
  baris: [
    BarisPenugasan(
      id: id * 10,
      jenisAlat: 'Autoklaf',
      jumlah: 10,
      jumlahSelesai: persen ~/ 10,
    ),
  ],
);

void main() {
  group('model Penugasan', () {
    test('diselesaikan_pada ISO-8601 dibaca; null selama belum selesai', () {
      final selesai = Penugasan.fromJson(
        _json14(
          status: 'selesai',
          diselesaikanPada: '2026-11-19T10:15:00+07:00',
        ),
      );
      expect(selesai.selesai, isTrue);
      expect(
        selesai.diselesaikanPada!.toUtc(),
        DateTime.utc(2026, 11, 19, 3, 15),
      );

      final aktif = Penugasan.fromJson(_json14());
      expect(aktif.diselesaikanPada, isNull);
      // Server lama tanpa kuncinya: tidak crash.
      expect(
        Penugasan.fromJson(_json14()..remove('diselesaikan_pada')).selesai,
        isFalse,
      );
    });

    test('siapDitutup: hanya aktif DAN 100 persen', () {
      expect(_p(1, persen: 100).siapDitutup, isTrue);
      expect(_p(2, persen: 99).siapDitutup, isFalse);
      expect(_p(3, persen: 0).siapDitutup, isFalse);
      expect(_p(4, status: 'selesai').siapDitutup, isFalse);
      expect(_p(5, status: 'dibatalkan').siapDitutup, isFalse);
    });
  });

  group('service (HTTP tiruan)', () {
    test('selesaikan: POST /penugasan/14/selesaikan tanpa badan, jawaban '
        'dibaca', () async {
      late http.Request terkirim;
      var panggilan = 0;
      final hasil = await _layanan((r) async {
        panggilan++;
        terkirim = r;
        return _json({
          'message': 'Penugasan diselesaikan.',
          'data': _json14(
            status: 'selesai',
            diselesaikanPada: '2026-11-19T10:15:00+07:00',
          ),
        });
      }).selesaikan('tok', 14);

      expect(terkirim.method, 'POST');
      expect(terkirim.url.path, '/api/penugasan/14/selesaikan');
      expect(terkirim.headers['Authorization'], 'Bearer tok');
      expect(jsonDecode(terkirim.body), isEmpty);
      expect(panggilan, 1);
      expect(hasil.status, 'selesai');
      expect(hasil.diselesaikanPada, isNotNull);
    });

    test('selesaikan 422 penugasan_belum_tuntas: kode dan persen terbawa, '
        'TIDAK diulang otomatis', () async {
      var panggilan = 0;
      final f = _layanan((r) async {
        panggilan++;
        return _json({
          'message':
              'Penugasan ini baru 60% tuntas. Selesaikan dulu semua barisnya '
              '(laporkan progresnya) sebelum menutup penugasan.',
          'kode': 'penugasan_belum_tuntas',
          'persen_tuntas': 60,
        }, 422);
      }).selesaikan('tok', 14);

      await expectLater(
        f,
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 422)
              .having((e) => e.body['kode'], 'kode', 'penugasan_belum_tuntas')
              .having((e) => e.body['persen_tuntas'], 'persen', 60),
        ),
      );
      expect(panggilan, 1);
    });

    test('selesaikan 422 penugasan_sudah_selesai dilempar apa adanya (layar '
        'yang menganggapnya berhasil)', () async {
      await expectLater(
        _layanan(
          (r) async => _json({
            'message': 'Penugasan ini sudah selesai.',
            'kode': 'penugasan_sudah_selesai',
            'status': 'selesai',
          }, 422),
        ).selesaikan('tok', 14),
        throwsA(
          isA<ApiException>().having(
            (e) => e.body['kode'],
            'kode',
            'penugasan_sudah_selesai',
          ),
        ),
      );
    });

    test('bukaLagi: POST /penugasan/14/buka-lagi dengan alasan; aktif lagi '
        'dan diselesaikan_pada null', () async {
      late http.Request terkirim;
      final hasil = await _layanan((r) async {
        terkirim = r;
        return _json({'message': 'Penugasan dibuka lagi.', 'data': _json14()});
      }).bukaLagi('tok', 14, alasan: 'Ada alat yang ternyata belum diperiksa.');

      expect(terkirim.method, 'POST');
      expect(terkirim.url.path, '/api/penugasan/14/buka-lagi');
      expect(jsonDecode(terkirim.body), {
        'alasan': 'Ada alat yang ternyata belum diperiksa.',
      });
      expect(hasil.aktif, isTrue);
      expect(hasil.diselesaikanPada, isNull);
    });

    test(
      'bukaLagi: admin biasa 403, dan 422 penugasan_tidak_selesai',
      () async {
        await expectLater(
          _layanan(
            (r) async => _json({'message': 'Kamu nggak punya akses.'}, 403),
          ).bukaLagi('tok', 14, alasan: 'alasan sah'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
        );
        await expectLater(
          _layanan(
            (r) async => _json({
              'message': 'Penugasan ini tidak berstatus selesai.',
              'kode': 'penugasan_tidak_selesai',
              'status': 'dibatalkan',
            }, 422),
          ).bukaLagi('tok', 14, alasan: 'alasan sah'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.body['kode'],
              'kode',
              'penugasan_tidak_selesai',
            ),
          ),
        );
      },
    );
  });

  group('kalimat galat', () {
    final l10n = AppLocalizationsId();

    String pesan(Map<String, dynamic> badan, [int status = 422]) =>
        pesanGalatCrud(l10n, ApiException('x', status: status, body: badan));

    test('belum tuntas menyebut persen dari server', () {
      expect(
        pesan({'kode': 'penugasan_belum_tuntas', 'persen_tuntas': 80}),
        contains('baru 80% tuntas'),
      );
    });

    test('belum tuntas tanpa persen tetap terbaca, tanpa angka karangan', () {
      final p = pesan({'kode': 'penugasan_belum_tuntas'});
      expect(p, contains('belum tuntas'));
      expect(p, isNot(contains('%')));
    });

    test('tidak selesai: menyebut penugasan batal tidak dibuka lagi', () {
      expect(
        pesan({'kode': 'penugasan_tidak_selesai', 'status': 'dibatalkan'}),
        contains('tidak dibuka lagi'),
      );
    });

    test('kode baru memuat ulang papan', () {
      for (final kode in [
        'penugasan_belum_tuntas',
        'penugasan_tidak_selesai',
      ]) {
        expect(
          perluMuatUlangCrud(
            ApiException('x', status: 422, body: {'kode': kode}),
          ),
          isTrue,
          reason: kode,
        );
      }
    });
  });

  group('papan', () {
    Future<MockPenugasanKelolaService> buka(
      WidgetTester tester, {
      List<Penugasan>? awal,
      MockPenugasanKelolaService? layanan,
      String token = tokenAdminCrud,
      Izin izin = izinAdminCrud,
      double lebar = 392,
    }) async {
      final l = layanan ?? MockPenugasanKelolaService(awal: awal);
      aturLayar(tester, lebar, 852);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...LapisanUjiCrud(penugasan: l).overrides(token: token, izin: izin),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PenugasanKelolaScreen(),
          ),
        ),
      );
      await selesaikan(tester);
      return l;
    }

    final selesaikanTombol = find.byKey(const Key('selesaikan-penugasan-18'));
    final bukaLagiTombol = find.byKey(const Key('buka-lagi-penugasan-19'));

    final data = <Penugasan>[
      _p(18, persen: 100),
      _p(20, persen: 43),
      _p(19, status: 'selesai', selesaiPada: DateTime.utc(2026, 11, 19, 3, 15)),
    ];

    Future<void> saringSelesai(WidgetTester tester) async {
      await ketukDi(tester, find.byKey(const Key('saring-penugasan-selesai')));
      await selesaikan(tester);
    }

    testWidgets('admin: tombol Selesaikan HANYA di penugasan yang siap; '
        'badge Siap diselesaikan; tanpa Buka lagi', (tester) async {
      await buka(tester, awal: data);

      expect(selesaikanTombol, findsOneWidget);
      expect(find.text('Siap diselesaikan'), findsOneWidget);
      // 43 persen: tidak ada tombol maupun badge-nya.
      expect(find.byKey(const Key('selesaikan-penugasan-20')), findsNothing);

      await saringSelesai(tester);
      expect(find.text('Tugas 19'), findsOneWidget);
      expect(find.textContaining('Selesai 19 Nov 2026'), findsOneWidget);
      // Admin biasa tidak punya penugasan.buka-lagi.
      expect(bukaLagiTombol, findsNothing);
      expect(find.byKey(const Key('menu-penugasan-19')), findsNothing);
    });

    testWidgets('tanpa izin penugasan.selesaikan: tidak ada tombol walau '
        'siap', (tester) async {
      await buka(
        tester,
        awal: data,
        izin: const Izin(
          role: UserRole.admin,
          boleh: {NamaIzin.penugasanUbah, NamaIzin.penugasanBatalkan},
        ),
      );

      expect(find.text('Tugas 18'), findsOneWidget);
      expect(selesaikanTombol, findsNothing);
    });

    testWidgets('izin selesaikan saja (tanpa ubah/batalkan): layar tidak '
        'terkunci', (tester) async {
      await buka(
        tester,
        awal: data,
        izin: const Izin(
          role: UserRole.admin,
          boleh: {NamaIzin.penugasanSelesaikan},
        ),
      );

      expect(selesaikanTombol, findsOneWidget);
      expect(find.byKey(const Key('menu-penugasan-18')), findsNothing);
    });

    testWidgets('teknisi: layar terkunci, tidak ada tombol', (tester) async {
      await buka(
        tester,
        awal: data,
        token: tokenTeknisiCrud,
        izin: izinTeknisiCrud,
      );

      expect(selesaikanTombol, findsNothing);
      expect(find.text('Tugas 18'), findsNothing);
    });

    testWidgets('selesaikan sah: konfirmasi, server dipanggil, papan diambil '
        'ulang, kabar tampil', (tester) async {
      final l = await buka(tester, awal: data);

      await ketukDi(tester, selesaikanTombol);
      await tester.pumpAndSettle();
      expect(find.text('Selesaikan penugasan "Tugas 18"?'), findsOneWidget);
      // Belum ada panggilan sebelum dikonfirmasi.
      expect(l.catatan.where((c) => c.startsWith('selesaikan')), isEmpty);

      final sebelum = l.catatan.where((c) => c.startsWith('daftar')).length;
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(l.catatan, contains('selesaikan 18'));
      expect(find.text('Penugasan diselesaikan.'), findsOneWidget);
      expect(
        l.catatan.where((c) => c.startsWith('daftar')).length,
        greaterThan(sebelum),
      );
      // Bawaan = aktif: kartu itu pindah ke Selesai.
      expect(find.text('Tugas 18'), findsNothing);
    });

    testWidgets('dibatalkan di dialog: server tidak dipanggil', (tester) async {
      final l = await buka(tester, awal: data);

      await ketukDi(tester, selesaikanTombol);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(l.catatan.where((c) => c.startsWith('selesaikan')), isEmpty);
      expect(find.text('Tugas 18'), findsOneWidget);
    });

    testWidgets('kirim ulang: penugasan_sudah_selesai dianggap SUDAH SELESAI, '
        'bukan galat', (tester) async {
      final l = await buka(tester, layanan: _SudahSelesai(data));

      await ketukDi(tester, selesaikanTombol);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      // Dialog tertutup, tidak ada kalimat galat, papan dimuat ulang.
      expect(find.byKey(const Key('galat-dialog')), findsNothing);
      expect(find.byKey(const Key('aksi-dialog')), findsNothing);
      expect(find.text('Penugasan ini sudah selesai.'), findsOneWidget);
      expect(find.text('Penugasan diselesaikan.'), findsNothing);
      expect(l.catatan.where((c) => c.startsWith('selesaikan')).length, 1);
    });

    testWidgets('belum tuntas di server: kalimat dengan persen, dialog tetap '
        'terbuka, papan dimuat ulang', (tester) async {
      final l = await buka(tester, layanan: _BelumTuntas(data));
      final sebelum = l.catatan.where((c) => c.startsWith('daftar')).length;

      await ketukDi(tester, selesaikanTombol);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Penugasan ini baru 80% tuntas'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('aksi-dialog')), findsOneWidget);
      expect(
        l.catatan.where((c) => c.startsWith('daftar')).length,
        greaterThan(sebelum),
      );
    });

    testWidgets('403 dari server (izin dicabut di tengah jalan): kalimat '
        'izin, dialog tetap', (tester) async {
      await buka(tester, layanan: _Tolak403(data));

      await ketukDi(tester, selesaikanTombol);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(
        find.text('Akun Anda tidak boleh melakukan aksi ini.'),
        findsOneWidget,
      );
    });

    testWidgets('super admin: Buka lagi di penugasan selesai; alasan wajib '
        '5-400 dan tidak menembak server bila pendek', (tester) async {
      final l = await buka(
        tester,
        awal: data,
        token: tokenSuperAdminCrud,
        izin: izinSuperAdminCrud,
      );
      await saringSelesai(tester);

      expect(bukaLagiTombol, findsOneWidget);
      await ketukDi(tester, bukaLagiTombol);
      await tester.pumpAndSettle();
      expect(find.text('Buka lagi penugasan "Tugas 19"?'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('isian-dialog')), 'abc');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Alasan minimal 5 karakter.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('isian-dialog')), 'x' * 401);
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Alasan maksimal 400 karakter.'), findsOneWidget);

      expect(l.catatan.where((c) => c.startsWith('bukaLagi')), isEmpty);
    });

    testWidgets('buka lagi sah: alasan terkirim, kabar tampil, kartu keluar '
        'dari daftar Selesai', (tester) async {
      final l = await buka(
        tester,
        awal: data,
        token: tokenSuperAdminCrud,
        izin: izinSuperAdminCrud,
      );
      await saringSelesai(tester);

      await ketukDi(tester, bukaLagiTombol);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('isian-dialog')),
        'Ada alat yang ternyata belum diperiksa.',
      );
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(
        l.catatan,
        contains('bukaLagi 19 "Ada alat yang ternyata belum diperiksa."'),
      );
      expect(find.text('Penugasan dibuka lagi.'), findsOneWidget);
      expect(find.text('Tugas 19'), findsNothing);
    });

    testWidgets('super admin: penugasan aktif yang siap tetap bisa '
        'diselesaikan (admin DAN super admin)', (tester) async {
      await buka(
        tester,
        awal: data,
        token: tokenSuperAdminCrud,
        izin: izinSuperAdminCrud,
      );

      expect(selesaikanTombol, findsOneWidget);
      // Buka lagi hanya untuk penugasan SELESAI, tidak untuk yang aktif.
      expect(find.byKey(const Key('buka-lagi-penugasan-18')), findsNothing);
      expect(find.byKey(const Key('buka-lagi-penugasan-20')), findsNothing);
    });

    testWidgets('layar sempit 320 dp, huruf 2,0: tombol dan badge tanpa '
        'luapan', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await buka(tester, awal: data, lebar: 320);

      expect(selesaikanTombol, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Server menjawab `penugasan_sudah_selesai` (kirim ulang sesudah balasan
/// pertama hilang).
class _SudahSelesai extends MockPenugasanKelolaService {
  _SudahSelesai(List<Penugasan> awal) : super(awal: awal);

  @override
  Future<Penugasan> selesaikan(String token, int id) async {
    catatan.add('selesaikan $id');
    throw const ApiException(
      'Penugasan ini sudah selesai.',
      status: 422,
      body: {
        'message': 'Penugasan ini sudah selesai.',
        'kode': 'penugasan_sudah_selesai',
        'status': 'selesai',
      },
    );
  }
}

/// Papan menampilkan 100 persen, di server baru 80 (laporan dikoreksi).
class _BelumTuntas extends MockPenugasanKelolaService {
  _BelumTuntas(List<Penugasan> awal) : super(awal: awal);

  @override
  Future<Penugasan> selesaikan(String token, int id) async =>
      throw const ApiException(
        'Penugasan ini baru 80% tuntas.',
        status: 422,
        body: {
          'message': 'Penugasan ini baru 80% tuntas.',
          'kode': 'penugasan_belum_tuntas',
          'persen_tuntas': 80,
        },
      );
}

class _Tolak403 extends MockPenugasanKelolaService {
  _Tolak403(List<Penugasan> awal) : super(awal: awal);

  @override
  Future<Penugasan> selesaikan(String token, int id) async =>
      throw const ApiException('x', status: 403);
}
