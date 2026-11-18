import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/category.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/screens/crud_lab/kategori_kelola_screen.dart';
import 'package:sidik_calibration/screens/crud_lab/pengelolaan_data_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/kategori_kelola_service.dart';

import 'support/crud_uji.dart';
import 'support/layar_sa_uji.dart' show ketukDi;
import 'support/super_admin_uji.dart' show aturLayar, selesaikan;

/// Kategori alat: daftar (termasuk nonaktif), tambah, ubah nama, nonaktifkan,
/// aktifkan, hapus (kontrak `docs/perintah-frontend-crud-lengkap.md` §2).
/// Bentuk JSON disalin dari §2.1–§2.7; kode galat dari §7.
const _dasar = 'https://api.test/api';

http.Response _json(Object badan, [int status = 200]) => http.Response(
  jsonEncode(badan),
  status,
  headers: {'content-type': 'application/json'},
);

KategoriKelolaService _layanan(
  Future<http.Response> Function(http.Request) h,
) =>
    ApiKategoriKelolaService(ApiClient(client: MockClient(h), baseUrl: _dasar));

Map<String, dynamic> _badan(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

/// Bentuk kategori §2.1 (field lama + field ADDITIVE).
Map<String, dynamic> _kat({
  int id = 21,
  String kode = 'tekanan-vakum',
  String nama = 'Tekanan Vakum',
  bool aktif = true,
  String? nonaktifPada,
  int alat = 0,
  int kemampuan = 0,
}) => {
  'id': id,
  'kode': kode,
  'nama': nama,
  'rentang_ukur': null,
  'ketidakpastian_terbaik': null,
  'satuan': null,
  'jumlah_kemampuan': kemampuan,
  'jumlah_tanpa_cmc': 0,
  'aktif': aktif,
  'nonaktif_pada': nonaktifPada,
  'jumlah_alat': alat,
};

void main() {
  group('model Category (field tambahan, aditif)', () {
    test('membaca aktif, nonaktif_pada, jumlah_alat, jumlah_kemampuan', () {
      final k = Category.fromJson(
        _kat(
          aktif: false,
          nonaktifPada: '2026-11-18T10:15:00+07:00',
          alat: 3,
          kemampuan: 2,
        ),
      );

      expect(k.id, 21);
      expect(k.aktif, isFalse);
      expect(k.nonaktifPada, isNotNull);
      expect(k.jumlahAlat, 3);
      expect(k.jumlahKemampuan, 2);
      expect(k.bisaDihapus, isFalse);
    });

    test('server lama tanpa field baru: dianggap aktif dan tanpa pemakai', () {
      final k = Category.fromJson({'kode': 'massa', 'nama': 'Massa'});

      expect(k.aktif, isTrue);
      expect(k.jumlahAlat, 0);
      expect(k.bisaDihapus, isTrue);
    });

    test('bisaDihapus hanya bila alat DAN kemampuan nol', () {
      expect(Category.fromJson(_kat()).bisaDihapus, isTrue);
      expect(Category.fromJson(_kat(alat: 1)).bisaDihapus, isFalse);
      expect(Category.fromJson(_kat(kemampuan: 1)).bisaDihapus, isFalse);
    });
  });

  group('service API', () {
    test('daftar: GET /categories?termasuk_nonaktif=1', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({
          'data': [
            _kat(),
            _kat(id: 22, kode: 'lama', nama: 'Lama', aktif: false),
          ],
        });
      });
      final daftar = await s.daftar('tkn');

      expect(terkirim.method, 'GET');
      expect(terkirim.url.path, '/api/categories');
      expect(terkirim.url.queryParameters, {'termasuk_nonaktif': '1'});
      expect(daftar.map((k) => k.aktif), [true, false]);
    });

    test('buat: POST /categories hanya {nama}; kode TIDAK dikirim', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({'message': 'Kategori dibuat.', 'data': _kat()}, 201);
      });
      final k = await s.buat('tkn', nama: 'Tekanan Vakum');

      expect(terkirim.method, 'POST');
      expect(terkirim.url.path, '/api/categories');
      expect(_badan(terkirim), {'nama': 'Tekanan Vakum'});
      expect(k.kode, 'tekanan-vakum');
    });

    test('ubahNama: PUT /categories/{kode}', () async {
      late http.Request terkirim;
      final s = _layanan((r) async {
        terkirim = r;
        return _json({
          'message': 'Kategori diubah.',
          'data': _kat(nama: 'Baru'),
        });
      });
      final k = await s.ubahNama('t', 'tekanan-vakum', nama: 'Baru');

      expect(terkirim.method, 'PUT');
      expect(terkirim.url.path, '/api/categories/tekanan-vakum');
      expect(_badan(terkirim), {'nama': 'Baru'});
      expect(k.nama, 'Baru');
    });

    test('nonaktifkan: alasan opsional hanya dikirim bila ada', () async {
      final badan = <Map<String, dynamic>>[];
      late http.Request terakhir;
      final s = _layanan((r) async {
        terakhir = r;
        badan.add(_badan(r));
        return _json({'message': 'ok', 'data': _kat(aktif: false)});
      });
      await s.nonaktifkan('t', 'tekanan-vakum');
      await s.nonaktifkan('t', 'tekanan-vakum', alasan: 'Tidak dipakai lagi');

      expect(terakhir.url.path, '/api/categories/tekanan-vakum/nonaktifkan');
      expect(badan.first, isEmpty);
      expect(badan.last, {'alasan': 'Tidak dipakai lagi'});
    });

    test(
      'aktifkan: POST .../aktifkan; hapus: DELETE /categories/{kode}',
      () async {
        final dipanggil = <String>[];
        final s = _layanan((r) async {
          dipanggil.add('${r.method} ${r.url.path}');
          return _json({'message': 'ok', 'data': _kat()});
        });
        await s.aktifkan('t', 'tekanan-vakum');
        await s.hapus('t', 'tekanan-vakum');

        expect(dipanggil, [
          'POST /api/categories/tekanan-vakum/aktifkan',
          'DELETE /api/categories/tekanan-vakum',
        ]);
      },
    );

    // Badan galat disalin dari §2.3, §2.7, §7.
    final galat = <(String, int, Map<String, dynamic>)>[
      ('401', 401, {'message': 'Unauthenticated.'}),
      ('403 peran', 403, {'message': 'Akses ditolak.'}),
      ('404 hilang', 404, {'message': 'No query results.'}),
      (
        '422 nama kembar nonaktif',
        422,
        {
          'message': 'Sudah ada kategori bernama itu.',
          'kode': 'nama_kategori_kembar',
          'errors': {
            'nama': ['Sudah ada kategori bernama itu.'],
          },
          'kategori': {
            'kode': 'tekanan-vakum',
            'nama': 'Tekanan Vakum',
            'aktif': false,
          },
        },
      ),
      (
        '422 kategori_dipakai',
        422,
        {
          'message': 'Kategori ini masih dipakai (3 alat).',
          'kode': 'kategori_dipakai',
          'pemakai': {
            'alat': 3,
            'kemampuan': 0,
            'penugasan': 0,
            'metode': 0,
            'rumus': 0,
          },
        },
      ),
      (
        '409 kode_kategori_bentrok',
        409,
        {'message': 'Bentrok.', 'kode': 'kode_kategori_bentrok'},
      ),
      ('429 throttle', 429, {'message': 'Kebanyakan.'}),
      ('500', 500, {'message': 'Server Error'}),
    ];

    for (final (nama, status, badan) in galat) {
      test('buat & hapus: $nama → ApiException berbadan asli', () async {
        final s = _layanan((_) async => _json(badan, status));
        for (final panggil in [
          () => s.buat('t', nama: 'Tekanan Vakum'),
          () => s.hapus('t', 'tekanan-vakum'),
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

    test('buat: jaringan putus → KoneksiException, tidak diulang', () async {
      var n = 0;
      final s = _layanan((_) async {
        n++;
        throw const SocketException('putus');
      });
      await expectLater(
        s.buat('t', nama: 'Tekanan'),
        throwsA(isA<KoneksiException>()),
      );
      expect(n, 1);
    });
  });

  group('layar kelola kategori', () {
    Future<MockKategoriKelolaService> buka(
      WidgetTester tester, {
      MockKategoriKelolaService? layanan,
      String token = tokenAdminCrud,
      Izin izin = izinAdminCrud,
      double lebar = 392,
    }) async {
      final l = layanan ?? MockKategoriKelolaService();
      aturLayar(tester, lebar, 852);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...LapisanUjiCrud(kategori: l).overrides(token: token, izin: izin),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const KategoriKelolaScreen(),
          ),
        ),
      );
      await selesaikan(tester);
      return l;
    }

    Future<void> menu(WidgetTester tester, String kode, String aksi) async {
      await ketukDi(tester, find.byKey(Key('menu-kategori-$kode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(aksi));
      await tester.pumpAndSettle();
    }

    testWidgets('admin: daftar memuat yang nonaktif juga, dengan penanda', (
      tester,
    ) async {
      await buka(tester);

      expect(find.text('Massa'), findsOneWidget);
      expect(find.text('Suhu Lama'), findsOneWidget);
      expect(find.text('Kode: suhu-lama'), findsOneWidget);
      expect(find.textContaining('Nonaktif sejak'), findsOneWidget);
      expect(find.textContaining('12 alat'), findsOneWidget);
      expect(find.byKey(const Key('tambah-kategori')), findsOneWidget);
    });

    for (final (nama, token, izin) in [
      ('teknisi', tokenTeknisiCrud, izinTeknisiCrud),
      ('viewer', 'mock-token-3', izinViewerCrud),
    ]) {
      testWidgets('$nama: terkunci', (tester) async {
        await buka(tester, token: token, izin: izin);

        expect(
          find.text('Akun Anda tidak punya izin untuk bagian ini.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('tambah-kategori')), findsNothing);
        expect(find.text('Massa'), findsNothing);
      });
    }

    testWidgets('saring Nonaktif / Aktif bekerja di sisi aplikasi', (
      tester,
    ) async {
      await buka(tester);

      await tester.tap(find.byKey(const Key('saring-kategori-nonaktif')));
      await tester.pumpAndSettle();
      expect(find.text('Suhu Lama'), findsOneWidget);
      expect(find.text('Massa'), findsNothing);

      await tester.tap(find.byKey(const Key('saring-kategori-aktif')));
      await tester.pumpAndSettle();
      expect(find.text('Suhu Lama'), findsNothing);
      expect(find.text('Massa'), findsOneWidget);
    });

    testWidgets('menu: Hapus HANYA untuk kategori yang tidak dipakai', (
      tester,
    ) async {
      await buka(tester);

      await ketukDi(tester, find.byKey(const Key('menu-kategori-massa')));
      await tester.pumpAndSettle();
      expect(find.text('Hapus'), findsNothing); // 12 alat memakainya
      expect(find.text('Nonaktifkan'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await ketukDi(tester, find.byKey(const Key('menu-kategori-tekanan')));
      await tester.pumpAndSettle();
      expect(find.text('Hapus'), findsOneWidget);
    });

    testWidgets(
      'menu kategori nonaktif menawarkan Aktifkan kembali, bukan Nonaktifkan',
      (tester) async {
        await buka(tester);
        await ketukDi(tester, find.byKey(const Key('menu-kategori-suhu-lama')));
        await tester.pumpAndSettle();

        expect(find.text('Aktifkan kembali'), findsOneWidget);
        expect(find.text('Nonaktifkan'), findsNothing);
      },
    );

    testWidgets(
      'tambah: nama pendek ditolak di klien; sah → kode dari server',
      (tester) async {
        final l = await buka(tester);

        await ketukDi(tester, find.byKey(const Key('tambah-kategori')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('isian-dialog')), 'a');
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();
        expect(find.text('Nama minimal 2 karakter.'), findsOneWidget);
        expect(l.catatan.where((c) => c.startsWith('buat')), isEmpty);

        await tester.enterText(
          find.byKey(const Key('isian-dialog')),
          'Tekanan Vakum',
        );
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();

        expect(l.catatan, contains('buat "Tekanan Vakum"'));
        expect(find.text('Kategori dibuat.'), findsOneWidget);
        // Kartu baru bisa di bawah lipatan (daftar dibangun malas).
        await tester.scrollUntilVisible(
          find.text('Kode: tekanan-vakum'),
          250,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axis == Axis.vertical,
              )
              .first,
        );
        expect(find.text('Kode: tekanan-vakum'), findsOneWidget);
      },
    );

    testWidgets(
      'tambah dengan nama kembar milik yang NONAKTIF: arahkan ke Aktifkan',
      (tester) async {
        await buka(tester);

        await ketukDi(tester, find.byKey(const Key('tambah-kategori')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('isian-dialog')),
          'suhu lama',
        );
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Sudah ada kategori dengan nama itu, tetapi nonaktif. Aktifkan kembali dari daftar.',
          ),
          findsOneWidget,
        );
        // Dialog tetap terbuka dengan isian yang sama.
        expect(find.byKey(const Key('aksi-dialog')), findsOneWidget);
      },
    );

    testWidgets('tambah dengan nama kembar milik yang aktif: kalimat biasa', (
      tester,
    ) async {
      await buka(tester);

      await ketukDi(tester, find.byKey(const Key('tambah-kategori')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('isian-dialog')), ' MASSA ');
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(find.text('Sudah ada kategori dengan nama itu.'), findsOneWidget);
    });

    testWidgets('ubah nama: kotak terisi nama sekarang; kode tidak berubah', (
      tester,
    ) async {
      final l = await buka(tester);

      await menu(tester, 'tekanan', 'Ubah nama');
      final kotak = tester.widget<TextField>(
        find.byKey(const Key('isian-dialog')),
      );
      expect(kotak.controller!.text, 'Tekanan');

      await tester.enterText(
        find.byKey(const Key('isian-dialog')),
        'Tekanan Gas',
      );
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(l.catatan, contains('ubahNama tekanan "Tekanan Gas"'));
      expect(find.text('Tekanan Gas'), findsOneWidget);
      expect(find.text('Kode: tekanan'), findsOneWidget);
    });

    testWidgets(
      'nonaktifkan: alasan opsional; kategori berpindah ke status nonaktif',
      (tester) async {
        final l = await buka(tester);

        await menu(tester, 'massa', 'Nonaktifkan');
        await tester.tap(find.byKey(const Key('aksi-dialog'))); // tanpa alasan
        await tester.pumpAndSettle();

        expect(l.catatan.any((c) => c.startsWith('nonaktifkan massa')), isTrue);
        expect(find.text('Kategori dinonaktifkan.'), findsOneWidget);
        await tester.tap(find.byKey(const Key('saring-kategori-nonaktif')));
        await tester.pumpAndSettle();
        expect(find.text('Massa'), findsOneWidget);
      },
    );

    testWidgets('aktifkan kembali lewat konfirmasi', (tester) async {
      final l = await buka(tester);

      await menu(tester, 'suhu-lama', 'Aktifkan kembali');
      expect(find.text('Aktifkan Suhu Lama kembali?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(l.catatan, contains('aktifkan suhu-lama'));
      expect(find.text('Kategori diaktifkan.'), findsOneWidget);
    });

    testWidgets('hapus: konfirmasi tegas, lalu hilang dari daftar', (
      tester,
    ) async {
      final l = await buka(tester);

      await menu(tester, 'tekanan', 'Hapus');
      expect(find.text('Hapus Tekanan?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('aksi-dialog')));
      await tester.pumpAndSettle();

      expect(l.catatan, contains('hapus tekanan'));
      expect(find.text('Kategori dihapus.'), findsOneWidget);
      expect(find.text('Kode: tekanan'), findsNothing);
    });

    testWidgets(
      'hapus ditolak server (kategori_dipakai): rincian pemakai, dialog tetap',
      (tester) async {
        // Hitungan di layar basi: server tahu kategori itu dipakai 3 alat.
        final l = _DipakaiSaatHapus();
        await buka(tester, layanan: l);

        await menu(tester, 'tekanan', 'Hapus');
        await tester.tap(find.byKey(const Key('aksi-dialog')));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Kategori ini masih dipakai (3 alat). Nonaktifkan saja supaya tidak ditawarkan lagi.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('aksi-dialog')), findsOneWidget);
      },
    );

    testWidgets('kosong dan galat memuat', (tester) async {
      await buka(tester, layanan: MockKategoriKelolaService(awal: const []));
      expect(find.text('Belum ada kategori.'), findsOneWidget);
    });

    testWidgets('galat memuat: kalimat + Coba lagi', (tester) async {
      await buka(
        tester,
        layanan: MockKategoriKelolaService(galat: const KoneksiException('x')),
      );
      expect(find.text('Daftar kategori belum bisa dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  group('hub', () {
    testWidgets('admin melihat pintu Kategori; teknisi tidak', (tester) async {
      aturLayar(tester, 392, 852);
      await tester.pumpWidget(bungkusCrud(const PengelolaanDataScreen()));
      await selesaikan(tester);
      expect(find.byKey(const Key('pintu-kategori')), findsOneWidget);

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
      expect(find.byKey(const Key('pintu-kategori')), findsNothing);
    });
  });
}

/// Server yang menolak hapus karena kategori dipakai 3 alat.
class _DipakaiSaatHapus extends MockKategoriKelolaService {
  @override
  Future<void> hapus(String token, String kode) async =>
      throw const ApiException(
        'Kategori ini masih dipakai (3 alat).',
        status: 422,
        body: {
          'message': 'Kategori ini masih dipakai (3 alat).',
          'kode': 'kategori_dipakai',
          'pemakai': {
            'alat': 3,
            'kemampuan': 0,
            'penugasan': 0,
            'metode': 0,
            'rumus': 0,
          },
        },
      );
}
