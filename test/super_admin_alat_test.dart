import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/models/alat_pelanggan.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/models/revisi_sertifikat.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/riwayat_alat_provider.dart';
import 'package:sidik_calibration/screens/certificate/sertifikat_screen.dart';
import 'package:sidik_calibration/screens/super_admin/pelanggan_detail_screen.dart';
import 'package:sidik_calibration/screens/super_admin/riwayat_sertifikat_alat_screen.dart';
import 'package:sidik_calibration/screens/super_admin/widgets/lencana_status_alat.dart';
import 'package:sidik_calibration/services/anggota_pelanggan_service.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/riwayat_alat_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'support/lewati_onboarding.dart';
import 'support/super_admin_uji.dart';

/// Pelanggan → alat → sertifikat di sisi lab: model, service (paginasi
/// KURSOR), provider (muat lebih banyak yang menambah), dan layar.
///
/// SUMBER bentuk JSON alat/sertifikat: `EquipmentResource` dan
/// `CertificateResource` di repo API (kunci `nama_alat`, `merk`, `model`,
/// `serial_number`, `status`, `tanggal_jatuh_tempo`; `nomor`, `status`,
/// `status_dokumen`, `diterbitkan_pada`, `berlaku_sampai`, `keputusan`) +
/// `docs/perintah-frontend-super-admin.md` untuk rute dan kursornya.
const _dasar = 'https://api.test/api';

http.Response _json(Object badan, [int status = 200]) => http.Response(
  jsonEncode(badan),
  status,
  headers: {'content-type': 'application/json'},
);

SertifikatRingkas _s(
  int id,
  DateTime? t, {
  KeadaanSertifikat k = KeadaanSertifikat.terbit,
}) =>
    SertifikatRingkas(id: id, nomor: 'CAL/$id', keadaan: k, diterbitkanPada: t);

String _ringkas(BarisRiwayat b) => switch (b) {
  JudulTahun(:final tahun) => 'T${tahun ?? '-'}',
  JudulBulan(:final tahun, :final bulan) => 'B$tahun-$bulan',
  BarisSertifikat(:final sertifikat) => 'S${sertifikat.id}',
};

void main() {
  setUpAll(muatFontSa);

  group('model: keadaan sertifikat dari dua kolom server', () {
    const tabel = <(String, StatusDokumen?, KeadaanSertifikat)>[
      ('terbit', StatusDokumen.berlaku, KeadaanSertifikat.terbit),
      ('terbit', StatusDokumen.digantikan, KeadaanSertifikat.digantikan),
      ('terbit', StatusDokumen.ditarik, KeadaanSertifikat.ditarik),
      ('ditarik', StatusDokumen.ditarik, KeadaanSertifikat.ditarik),
      ('dibatalkan', StatusDokumen.dibatalkan, KeadaanSertifikat.dibatalkan),
      ('gagal', StatusDokumen.belumTerbit, KeadaanSertifikat.gagal),
      ('gagal', null, KeadaanSertifikat.gagal),
      (
        'menunggu_generate',
        StatusDokumen.belumTerbit,
        KeadaanSertifikat.menunggu,
      ),
      ('menunggu_generate', null, KeadaanSertifikat.menunggu),
      // Server lama tanpa status_dokumen.
      ('terbit', null, KeadaanSertifikat.terbit),
      ('dibatalkan', null, KeadaanSertifikat.dibatalkan),
    ];
    for (final (status, dokumen, harap) in tabel) {
      test('status=$status dokumen=${dokumen?.kode} → $harap', () {
        expect(keadaanSertifikat(status, dokumen), harap);
      });
    }
  });

  group('model: pengelompokan tahun lalu bulan (terbaru dulu)', () {
    test('judul hanya disisipkan saat tahun/bulan BERGANTI', () {
      final baris = susunRiwayat([
        _s(1, DateTime(2026, 11, 15)),
        _s(2, DateTime(2026, 11, 2)),
        _s(3, DateTime(2026, 9, 30)),
        _s(4, DateTime(2025, 12, 31)),
        _s(5, DateTime(2025, 12, 1)),
        _s(6, null),
      ]);
      expect(baris.map(_ringkas).toList(), [
        'T2026',
        'B2026-11',
        'S1',
        'S2',
        'B2026-9',
        'S3',
        'T2025',
        'B2025-12',
        'S4',
        'S5',
        // Belum terbit (tanpa tanggal): menempel di kelompok yang berjalan.
        'S6',
      ]);
    });

    test(
      'daftar yang DIMULAI sertifikat belum terbit membuka "tanpa tanggal"',
      () {
        final baris = susunRiwayat([
          _s(1, null, k: KeadaanSertifikat.gagal),
          _s(2, DateTime(2026, 11, 2)),
        ]);
        expect(baris.map(_ringkas).toList(), [
          'T-',
          'S1',
          'T2026',
          'B2026-11',
          'S2',
        ]);
      },
    );

    test('tahun/bulan dari server menang atas tanggal terbit', () {
      const s = SertifikatRingkas(
        id: 1,
        nomor: 'CAL/1',
        keadaan: KeadaanSertifikat.terbit,
        tahun: 2026,
        bulan: 1,
      );
      expect(susunRiwayat([s]).map(_ringkas).toList(), [
        'T2026',
        'B2026-1',
        'S1',
      ]);
    });

    test(
      'urutan server TIDAK diacak, dan halaman susulan menyambung mulus',
      () {
        final halaman1 = [
          _s(1, DateTime(2026, 11, 15)),
          _s(2, DateTime(2026, 10, 1)),
        ];
        final halaman2 = [
          _s(3, DateTime(2026, 10, 1)),
          _s(4, DateTime(2026, 8, 1)),
        ];

        final sebelum = susunRiwayat(halaman1).map(_ringkas).toList();
        final sesudah = susunRiwayat([
          ...halaman1,
          ...halaman2,
        ]).map(_ringkas).toList();

        // Yang sudah tampak tetap di tempatnya; yang baru ditambahkan di bawah.
        expect(sesudah.take(sebelum.length), sebelum);
        expect(sesudah.skip(sebelum.length), ['S3', 'B2026-8', 'S4']);
      },
    );

    test('daftar kosong → tanpa baris', () {
      expect(susunRiwayat(const []), isEmpty);
    });
  });

  group('service: GET /customers/{c}/alat dan /equipments/{e}/sertifikat', () {
    RiwayatAlatService baru(Future<http.Response> Function(http.Request) h) =>
        ApiRiwayatAlatService(
          ApiClient(client: MockClient(h), baseUrl: _dasar),
        );

    // Disalin dari kontrak §3.4.
    final alatJson = {
      'id': 118,
      'nama_alat': 'Termometer Digital',
      'merk': 'Fluke',
      'model': '1524',
      'serial_number': 'SN-2231',
      'no_identifikasi': 'TH-014',
      'status': 'aktif',
      'status_alat': 'mendekati_jadwal',
      'tanggal_kalibrasi_terakhir': '2025-12-03',
      'tanggal_jatuh_tempo': '2026-12-02',
      'hari_ke_jatuh_tempo': 14,
      'jumlah_sertifikat': 3,
      'sertifikat_terbaru': {
        'id': 31,
        'nomor': 'CAL/2025/12/0007',
        'diterbitkan_pada': '2025-12-03',
        'status': 'terbit',
        'status_dokumen': 'berlaku',
      },
    };

    test(
      'alat: path, limit, kursor di-encode; kursor berikut dari meta',
      () async {
        late http.Request terkirim;
        final s = baru((r) async {
          terkirim = r;
          return _json({
            'data': [alatJson],
            'meta': {'limit': 20, 'next_cursor': 'azE6MTE4', 'ada_lagi': true},
          });
        });

        final hal = await s.alat('tkn', 17, kursor: 'a/b+c=', batas: 20);

        expect(terkirim.method, 'GET');
        expect(terkirim.url.path, '/api/customers/17/alat');
        expect(terkirim.url.queryParameters, {
          'limit': '20',
          'cursor': 'a/b+c=',
        });
        expect(terkirim.headers['Authorization'], 'Bearer tkn');
        expect(hal.kursorBerikut, 'azE6MTE4');
        final a = hal.items.single;
        expect(a.id, 118);
        expect(a.nama, 'Termometer Digital');
        expect(a.merk, 'Fluke');
        expect(a.model, '1524');
        expect(a.nomorSeri, 'SN-2231');
        expect(a.status, 'aktif');
        // Kode untuk pelanggan, dibaca apa adanya (tidak dihitung ulang).
        expect(a.statusAlat, 'mendekati_jadwal');
        expect(a.jatuhTempo, DateTime(2026, 12, 2));
        expect(a.hariKeJatuhTempo, 14);
        expect(a.jumlahSertifikat, 3);
        expect(a.sertifikatTerbaru?.nomor, 'CAL/2025/12/0007');
        expect(a.sertifikatTerbaru?.keadaan, KeadaanSertifikat.terbit);
      },
    );

    test('ada_lagi:false menang atas kursor yang tersisa', () async {
      final s = baru(
        (_) async => _json({
          'data': [],
          'meta': {'limit': 20, 'next_cursor': 'sisa', 'ada_lagi': false},
        }),
      );
      expect((await s.alat('t', 17)).kursorBerikut, isNull);
    });

    test('halaman pertama tanpa kursor; kursor kosong/null = habis', () async {
      late http.Request terkirim;
      final s = baru((r) async {
        terkirim = r;
        return _json({
          'data': [],
          'meta': {'next_cursor': null, 'ada_lagi': false},
        });
      });
      final hal = await s.alat('t', 17);
      expect(terkirim.url.queryParameters.containsKey('cursor'), isFalse);
      expect(hal.kursorBerikut, isNull);
      expect(hal.items, isEmpty);

      final s2 = baru((_) async => _json({'data': [], 'next_cursor': ''}));
      expect((await s2.alat('t', 17)).kursorBerikut, isNull);

      final s3 = baru((_) async => _json({'data': [], 'next_cursor': 'zz'}));
      expect((await s3.alat('t', 17)).kursorBerikut, 'zz');
    });

    test('field kosong/null di alat tidak membuat crash', () async {
      final s = baru(
        (_) async => _json({
          'data': [
            {
              'id': 9,
              'nama_alat': null,
              'merk': null,
              'serial_number': null,
              'status': null,
              'status_alat': null,
              'tanggal_jatuh_tempo': null,
              'hari_ke_jatuh_tempo': null,
              'sertifikat_terbaru': null,
            },
          ],
        }),
      );
      final a = (await s.alat('t', 1)).items.single;
      expect(a.nama, '');
      expect(a.nomorSeri, '');
      expect(a.status, 'aktif');
      expect(a.statusAlat, isNull);
      expect(a.jatuhTempo, isNull);
      expect(a.hariKeJatuhTempo, isNull);
      expect(a.jumlahSertifikat, 0);
      expect(a.sertifikatTerbaru, isNull);
    });

    test(
      'sertifikat: bentuk kontrak §3.5 (revisi menunjuk pengganti)',
      () async {
        late http.Request terkirim;
        final s = baru((r) async {
          terkirim = r;
          return _json({
            'data': [
              {
                'id': 40,
                'nomor': 'CAL/2025/12/0007-R1',
                'revisi_ke': 1,
                'status': 'terbit',
                'status_dokumen': 'berlaku',
                'diterbitkan_pada': '2026-01-15',
                'berlaku_sampai': '2026-12-02',
                'tahun': 2026,
                'bulan': 1,
                'revisi_dari': {'id': 31, 'nomor': 'CAL/2025/12/0007'},
                'digantikan_oleh': null,
                'ditarik_pada': null,
                'dibatalkan_pada': null,
              },
              {
                'id': 31,
                'nomor': 'CAL/2025/12/0007',
                'revisi_ke': 0,
                'status': 'terbit',
                'status_dokumen': 'digantikan',
                'diterbitkan_pada': '2025-12-03',
                'berlaku_sampai': '2026-12-02',
                'tahun': 2025,
                'bulan': 12,
                'revisi_dari': null,
                'digantikan_oleh': {
                  'id': 40,
                  'nomor': 'CAL/2025/12/0007-R1',
                  'diterbitkan_pada': '2026-01-15',
                },
                'ditarik_pada': null,
                'dibatalkan_pada': null,
              },
              {
                'id': 20,
                'nomor': 'CAL/2025/11/0003',
                'revisi_ke': 0,
                'status': 'gagal',
                'status_dokumen': 'belum_terbit',
                'diterbitkan_pada': null,
                'berlaku_sampai': null,
                'tahun': null,
                'bulan': null,
                'revisi_dari': null,
                'digantikan_oleh': null,
                'ditarik_pada': null,
                'dibatalkan_pada': null,
              },
              {
                'id': 10,
                'nomor': 'CAL/2024/05/0001',
                'revisi_ke': 0,
                'status': 'ditarik',
                'status_dokumen': 'ditarik',
                'diterbitkan_pada': '2024-05-30',
                'tahun': 2024,
                'bulan': 5,
                'ditarik_pada': '2024-06-02T03:00:00+00:00',
              },
            ],
            'meta': {'limit': 20, 'next_cursor': 'k2', 'ada_lagi': true},
          });
        });

        final hal = await s.sertifikat('t', 501, kursor: 'k1');

        expect(terkirim.url.path, '/api/equipments/501/sertifikat');
        expect(terkirim.url.queryParameters['cursor'], 'k1');
        expect(hal.items.map((e) => e.keadaan), [
          KeadaanSertifikat.terbit,
          KeadaanSertifikat.digantikan,
          KeadaanSertifikat.gagal,
          KeadaanSertifikat.ditarik,
        ]);
        final revisi = hal.items[0];
        expect(revisi.revisiKe, 1);
        expect(revisi.revisiDari?.nomor, 'CAL/2025/12/0007');
        expect(revisi.tahun, 2026);
        expect(revisi.bulan, 1);
        expect(revisi.diterbitkanPada, DateTime(2026, 1, 15));
        final lama = hal.items[1];
        expect(lama.digantikanOleh?.id, 40);
        expect(lama.digantikanOleh?.nomor, 'CAL/2025/12/0007-R1');
        expect(hal.items[2].diterbitkanPada, isNull);
        expect(hal.items[2].tahun, isNull);
        expect(hal.items[3].ditarikPada, isNotNull);
        expect(hal.kursorBerikut, 'k2');
      },
    );

    for (final (nama, status) in [
      ('403', 403),
      ('404', 404),
      ('422', 422),
      ('429', 429),
    ]) {
      test('galat $nama dilempar sebagai ApiException', () async {
        final s = baru((_) async => _json({'message': 'tolak'}, status));
        await expectLater(
          s.sertifikat('t', 501),
          throwsA(isA<ApiException>().having((e) => e.status, 's', status)),
        );
        await expectLater(
          s.alat('t', 17),
          throwsA(isA<ApiException>().having((e) => e.status, 's', status)),
        );
      });
    }

    test('baris tanpa id TIDAK dilewati diam-diam', () async {
      final s = baru(
        (_) async => _json({
          'data': [
            {'nomor': 'tanpa id'},
          ],
        }),
      );
      await expectLater(s.sertifikat('t', 1), throwsA(isA<TypeError>()));
    });
  });

  group('provider: kursor menambah, tidak menimpa', () {
    ProviderContainer wadah(MockRiwayatAlatService layanan) {
      final c = ProviderContainer(
        overrides: [
          lewatiOnboarding,
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage(tokenSuperAdmin),
          ),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          riwayatAlatServiceProvider.overrideWithValue(layanan),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'halaman pertama, lalu muat lebih banyak menambah sampai habis',
      () async {
        final layanan = MockRiwayatAlatService(jumlahAlat: 45);
        final c = wadah(layanan);
        await c.read(authProvider.future);
        final p = alatPelangganProvider(17);
        c.listen(p, (_, _) {});

        final awal = await c.read(p.future);
        expect(awal.items, hasLength(20));
        expect(awal.adaLagi, isTrue);

        await c.read(p.notifier).muatLebihBanyak();
        expect(c.read(p).value!.items, hasLength(40));

        await c.read(p.notifier).muatLebihBanyak();
        final akhir = c.read(p).value!;
        expect(akhir.items, hasLength(45));
        expect(akhir.adaLagi, isFalse);
        expect(
          akhir.items.map((a) => a.id).toSet(),
          hasLength(45),
          reason: 'tanpa dobel',
        );

        // Habis: panggilan lagi tidak meminta apa-apa.
        await c.read(p.notifier).muatLebihBanyak();
        expect(layanan.catatan, ['alat:17:', 'alat:17:c20', 'alat:17:c40']);
      },
    );

    test('dua pemicu gulir beruntun meminta satu halaman saja', () async {
      final layanan = MockRiwayatAlatService(
        jumlahAlat: 45,
        jeda: const Duration(milliseconds: 50),
      );
      final c = wadah(layanan);
      await c.read(authProvider.future);
      final p = alatPelangganProvider(17);
      c.listen(p, (_, _) {});
      await c.read(p.future);

      final a = c.read(p.notifier).muatLebihBanyak();
      final b = c.read(p.notifier).muatLebihBanyak();
      await Future.wait([a, b]);

      expect(layanan.catatan.where((e) => e.endsWith(':c20')), hasLength(1));
      expect(c.read(p).value!.items, hasLength(40));
    });

    test(
      'halaman berikutnya gagal: daftar tetap, tidak mengulang sendiri',
      () async {
        final layanan = MockRiwayatAlatService(
          jumlahAlat: 45,
          galatHalamanKedua: const KoneksiException('putus'),
        );
        final c = wadah(layanan);
        await c.read(authProvider.future);
        final p = alatPelangganProvider(17);
        c.listen(p, (_, _) {});
        await c.read(p.future);

        await c.read(p.notifier).muatLebihBanyak();
        final s = c.read(p).value!;
        expect(
          s.items,
          hasLength(20),
          reason: 'daftar yang sudah tampak tidak hilang',
        );
        expect(s.galatLanjut, isA<KoneksiException>());
        expect(s.memuatLagi, isFalse);

        // Pemicu gulir berikutnya TIDAK menembak lagi (bukan badai permintaan).
        await c.read(p.notifier).muatLebihBanyak();
        expect(layanan.catatan.where((e) => e.endsWith(':c20')), hasLength(1));

        // Tombol Coba lagi (paksa) boleh.
        await c.read(p.notifier).muatLebihBanyak(paksa: true);
        expect(layanan.catatan.where((e) => e.endsWith(':c20')), hasLength(2));
      },
    );

    test('muat ulang kembali ke halaman pertama', () async {
      final layanan = MockRiwayatAlatService(jumlahSertifikat: 60);
      final c = wadah(layanan);
      await c.read(authProvider.future);
      final p = sertifikatAlatProvider(501);
      c.listen(p, (_, _) {});
      await c.read(p.future);
      await c.read(p.notifier).muatLebihBanyak();
      expect(c.read(p).value!.items, hasLength(40));

      await c.read(p.notifier).muatUlang();
      expect(c.read(p).value!.items, hasLength(20));
    });

    test('halaman pertama gagal → galat; tidak mengulang otomatis', () async {
      final layanan = MockRiwayatAlatService(
        galat: const KoneksiException('putus'),
      );
      final c = wadah(layanan);
      await c.read(authProvider.future);
      final p = alatPelangganProvider(17);
      c.listen(p, (_, _) {});

      await expectLater(c.read(p.future), throwsA(isA<KoneksiException>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(layanan.catatan, hasLength(1));
    });
  });

  group('layar: alat di detail pelanggan', () {
    final pelanggan = MockAnggotaPelangganService.contohPelanggan.first;

    Future<void> pasang(
      WidgetTester tester, {
      LapisanUjiSa? lapisan,
      double lebar = 392,
      double tinggi = 800,
    }) async {
      aturLayar(tester, lebar, tinggi);
      await tester.pumpWidget(
        bungkusSa(
          PelangganDetailScreen(pelanggan: pelanggan),
          lapisan: lapisan,
        ),
      );
      await selesaikan(tester);
    }

    /// Gulir detail sampai [finder] tampak.
    Future<void> gulirKe(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets(
      'kartu alat: nama, merek/model, seri, status, jadwal, sertifikat',
      (tester) async {
        await pasang(tester);
        await gulirKe(tester, find.byKey(const Key('alat-501')));

        final kartu = find.byKey(const Key('alat-501'));
        expect(
          find.descendant(
            of: kartu,
            matching: find.text('Timbangan Analitik 1'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: kartu,
            matching: find.text('Mettler Toledo · XS204'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: kartu, matching: find.text('No. seri SN-10001')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: kartu, matching: find.text('Terkalibrasi')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: kartu, matching: find.text('1 sertifikat')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: kartu,
            matching: find.text('Kalibrasi ulang 10 Feb 2027 · 121 hari lagi'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'lazy: hanya halaman pertama diminta sampai pengguna menggulir',
      (tester) async {
        final layanan = MockRiwayatAlatService(jumlahAlat: 45);
        await pasang(tester, lapisan: LapisanUjiSa(riwayat: layanan));
        expect(layanan.catatan, ['alat:17:'], reason: 'belum menggulir');

        // Gulir ke ujung daftar yang termuat → halaman berikutnya diminta.
        for (var i = 0; i < 12; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -900),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        await selesaikan(tester);
        expect(layanan.catatan, contains('alat:17:c20'));
      },
    );

    testWidgets('kosong: pelanggan tanpa alat', (tester) async {
      await pasang(
        tester,
        lapisan: LapisanUjiSa(riwayat: MockRiwayatAlatService(jumlahAlat: 0)),
      );
      await gulirKe(tester, find.byKey(const Key('alat-kosong')));
      expect(find.text('Pelanggan ini belum punya alat.'), findsOneWidget);
    });

    testWidgets('galat: pesan server + Coba lagi meminta ulang', (
      tester,
    ) async {
      final layanan = MockRiwayatAlatService(
        galat: const ApiException(
          'Kamu nggak punya akses ke sini.',
          status: 403,
          body: {'message': 'Kamu nggak punya akses ke sini.'},
        ),
      );
      await pasang(tester, lapisan: LapisanUjiSa(riwayat: layanan));
      await gulirKe(tester, find.byKey(const Key('alat-galat')));
      expect(find.text('Kamu nggak punya akses ke sini.'), findsOneWidget);

      final sebelum = layanan.catatan.length;
      final coba = find.descendant(
        of: find.byKey(const Key('alat-galat')),
        matching: find.text('Coba lagi'),
      );
      await tester.tap(coba);
      await selesaikan(tester);
      expect(layanan.catatan.length, greaterThan(sebelum));
    });

    testWidgets('memuat: kerangka lebih dulu, lalu kartu', (tester) async {
      final layanan = MockRiwayatAlatService(
        jeda: const Duration(milliseconds: 800),
      );
      await pasang(tester, lapisan: LapisanUjiSa(riwayat: layanan));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('alat-501')), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await selesaikan(tester);
      await gulirKe(tester, find.text('Thermohygrometer 0'));
      expect(find.text('Thermohygrometer 0'), findsOneWidget);
    });

    testWidgets('mengetuk alat membuka riwayat sertifikatnya', (tester) async {
      await pasang(tester);
      await gulirKe(tester, find.byKey(const Key('alat-500')));
      await tester.tap(find.byKey(const Key('alat-500')));
      await selesaikan(tester);

      expect(find.byType(RiwayatSertifikatAlatScreen), findsOneWidget);
      expect(find.text('Riwayat sertifikat'), findsOneWidget);
      expect(find.text('Thermohygrometer 0'), findsOneWidget);
    });
  });

  group('layar: riwayat sertifikat alat', () {
    const alat = AlatRingkas(
      id: 500,
      nama: 'Thermohygrometer 0',
      merk: 'Fluke',
      model: '1620A',
      nomorSeri: 'SN-10000',
      status: 'aktif',
    );

    Future<void> pasang(
      WidgetTester tester, {
      LapisanUjiSa? lapisan,
      double tinggi = 4200,
    }) async {
      aturLayar(tester, 392, tinggi);
      await tester.pumpWidget(
        bungkusSa(
          const RiwayatSertifikatAlatScreen(alat: alat),
          lapisan: lapisan,
        ),
      );
      await selesaikan(tester);
    }

    testWidgets('dikelompokkan tahun → bulan, terbaru dulu', (tester) async {
      await pasang(tester);

      expect(find.byKey(const Key('tahun-2026')), findsOneWidget);
      expect(find.byKey(const Key('bulan-2026-11')), findsOneWidget);
      expect(find.byKey(const Key('bulan-2026-10')), findsOneWidget);
      expect(find.byKey(const Key('tahun-2025')), findsOneWidget);

      // Urutan vertikal: 2026 di atas 2025; November di atas Oktober.
      double y(String kunci) => tester.getTopLeft(find.byKey(Key(kunci))).dy;
      expect(y('tahun-2026'), lessThan(y('bulan-2026-11')));
      expect(y('bulan-2026-11'), lessThan(y('bulan-2026-10')));
      expect(y('bulan-2026-10'), lessThan(y('tahun-2025')));
      // 2026 dan 2025 sama-sama punya bulan November.
      expect(find.text('November'), findsNWidgets(2));
      expect(find.text('CAL/2026/0100'), findsOneWidget);
      // Sertifikat paling baru di atas sertifikat sebelumnya.
      expect(
        tester.getTopLeft(find.byKey(const Key('sertifikat-9000'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('sertifikat-9001'))).dy,
        ),
      );
    });

    testWidgets(
      'lencana jelas: terbit, digantikan, ditarik, gagal, dibatalkan',
      (tester) async {
        await pasang(tester);
        for (final label in [
          'Terbit',
          'Digantikan',
          'Ditarik',
          'Gagal terbit',
          'Dibatalkan',
        ]) {
          expect(find.text(label), findsWidgets, reason: label);
        }
        // Sertifikat lama TETAP tampil walau tidak lagi sah.
        expect(find.byKey(const Key('sertifikat-9001')), findsOneWidget);
      },
    );

    testWidgets('mengetuk sertifikat membuka pratinjau yang sudah ada', (
      tester,
    ) async {
      await pasang(tester);
      await tester.tap(find.byKey(const Key('sertifikat-9000')));
      await selesaikan(tester);
      expect(find.byType(SertifikatScreen), findsOneWidget);
    });

    testWidgets('lazy: halaman kedua diminta saat menggulir ke bawah', (
      tester,
    ) async {
      final layanan = MockRiwayatAlatService(jumlahSertifikat: 60);
      await pasang(
        tester,
        lapisan: LapisanUjiSa(riwayat: layanan),
        tinggi: 800,
      );
      expect(layanan.catatan, ['sertifikat:500:']);

      for (var i = 0; i < 14; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -1200));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await selesaikan(tester);
      expect(layanan.catatan, contains('sertifikat:500:c20'));
    });

    testWidgets('kosong: alat tanpa sertifikat', (tester) async {
      await pasang(
        tester,
        lapisan: LapisanUjiSa(
          riwayat: MockRiwayatAlatService(jumlahSertifikat: 0),
        ),
      );
      expect(find.text('Alat ini belum punya sertifikat.'), findsOneWidget);
      expect(
        find.text('Thermohygrometer 0'),
        findsOneWidget,
        reason: 'kepala alat tetap',
      );
    });

    testWidgets('galat halaman pertama: kalimat + Coba lagi', (tester) async {
      final layanan = MockRiwayatAlatService(
        galat: const KoneksiException('Nggak bisa nyambung ke server.'),
      );
      await pasang(tester, lapisan: LapisanUjiSa(riwayat: layanan));
      expect(find.text('Nggak bisa nyambung ke server.'), findsOneWidget);

      final sebelum = layanan.catatan.length;
      await tester.tap(find.text('Coba lagi'));
      await selesaikan(tester);
      expect(layanan.catatan.length, greaterThan(sebelum));
    });

    testWidgets('galat halaman berikutnya: daftar tetap + Coba lagi di kaki', (
      tester,
    ) async {
      final layanan = MockRiwayatAlatService(
        jumlahSertifikat: 60,
        galatHalamanKedua: const KoneksiException('Putus di tengah jalan.'),
      );
      await pasang(
        tester,
        lapisan: LapisanUjiSa(riwayat: layanan),
        tinggi: 800,
      );
      for (var i = 0; i < 14; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -1200));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await selesaikan(tester);

      expect(find.byKey(const Key('kaki-galat')), findsOneWidget);
      expect(find.text('Putus di tengah jalan.'), findsOneWidget);
      expect(
        find.byKey(const Key('sertifikat-9000')),
        findsNothing,
        reason: 'tergulir lewat',
      );
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('memuat: kepala alat + kerangka kartu', (tester) async {
      final layanan = MockRiwayatAlatService(jeda: const Duration(seconds: 1));
      aturLayar(tester, 392, 852);
      await tester.pumpWidget(
        bungkusSa(
          const RiwayatSertifikatAlatScreen(alat: alat),
          lapisan: LapisanUjiSa(riwayat: layanan),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Thermohygrometer 0'), findsOneWidget);
      expect(find.byKey(const Key('sertifikat-9000')), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await selesaikan(tester);
      expect(find.byKey(const Key('sertifikat-9000')), findsOneWidget);
    });
  });

  group(
    'izin alat & riwayat sertifikat (dari server, bukan tebakan peran)',
    () {
      final pelanggan = MockAnggotaPelangganService.contohPelanggan.first;

      // Boleh melihat anggota, tetapi TIDAK `pelanggan.alat-lihat`.
      const tanpaAlat = Izin(
        role: UserRole.superAdmin,
        boleh: {
          NamaIzin.anggotaPelangganLihat,
          NamaIzin.penggunaBuatAdmin,
          NamaIzin.penggunaUbahStatus,
        },
      );

      // Boleh melihat alat, tetapi TIDAK `alat.riwayat-sertifikat`.
      const tanpaRiwayat = Izin(
        role: UserRole.superAdmin,
        boleh: {
          NamaIzin.anggotaPelangganLihat,
          NamaIzin.pelangganAlatLihat,
          NamaIzin.penggunaBuatAdmin,
        },
      );

      testWidgets('tanpa pelanggan.alat-lihat: bagian alat TIDAK ada, server '
          'tidak ditanya', (tester) async {
        final layanan = MockRiwayatAlatService();
        aturLayar(tester, 392, 800);
        await tester.pumpWidget(
          bungkusSa(
            PelangganDetailScreen(pelanggan: pelanggan),
            lapisan: LapisanUjiSa(riwayat: layanan),
            izin: tanpaAlat,
          ),
        );
        await selesaikan(tester);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -3000),
        );
        await selesaikan(tester);

        expect(find.text('Alat pelanggan'), findsNothing);
        expect(layanan.catatan, isEmpty);
      });

      testWidgets('tanpa alat.riwayat-sertifikat: kartu alat tampil tetapi '
          'tidak bisa dibuka', (tester) async {
        aturLayar(tester, 392, 800);
        await tester.pumpWidget(
          bungkusSa(
            PelangganDetailScreen(pelanggan: pelanggan),
            izin: tanpaRiwayat,
          ),
        );
        await selesaikan(tester);
        await tester.scrollUntilVisible(
          find.byKey(const Key('alat-500')),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('alat-500')));
        await selesaikan(tester);

        expect(find.byType(RiwayatSertifikatAlatScreen), findsNothing);
      });

      testWidgets('riwayat dibuka tanpa izin: terkunci, server tidak ditanya', (
        tester,
      ) async {
        final layanan = MockRiwayatAlatService();
        aturLayar(tester, 392, 800);
        await tester.pumpWidget(
          bungkusSa(
            const RiwayatSertifikatAlatScreen(
              alat: AlatRingkas(id: 500, nama: 'Alat'),
            ),
            lapisan: LapisanUjiSa(riwayat: layanan),
            token: tokenTeknisi,
            izin: izinTeknisi,
          ),
        );
        await selesaikan(tester);

        expect(
          find.text('Layar ini hanya untuk akun yang diberi izin oleh server.'),
          findsOneWidget,
        );
        expect(layanan.catatan, isEmpty);
      });
    },
  );

  group('lencana status alat: kode server apa adanya', () {
    Future<void> lihat(WidgetTester tester, AlatRingkas alat) async {
      aturLayar(tester, 392, 400);
      await tester.pumpWidget(
        bungkusSa(
          Scaffold(
            body: Center(child: LencanaStatusAlat(alat: alat)),
          ),
        ),
      );
      await selesaikan(tester);
    }

    const tabel = <(String, String)>[
      ('terkalibrasi', 'Terkalibrasi'),
      ('mendekati_jadwal', 'Mendekati jadwal'),
      ('lewat_jadwal', 'Lewat jadwal'),
      ('belum_pernah', 'Belum pernah dikalibrasi'),
      ('nonaktif', 'Nonaktif'),
    ];
    for (final (kode, label) in tabel) {
      testWidgets('$kode → "$label"', (tester) async {
        await lihat(tester, AlatRingkas(id: 1, nama: 'A', statusAlat: kode));
        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('kode baru dari server tampil apa adanya', (tester) async {
      await lihat(
        tester,
        const AlatRingkas(id: 1, nama: 'A', statusAlat: 'kode_baru_server'),
      );
      expect(find.text('kode_baru_server'), findsOneWidget);
    });

    testWidgets('server lama tanpa status_alat: jatuh ke status lab', (
      tester,
    ) async {
      await lihat(
        tester,
        const AlatRingkas(id: 1, nama: 'A', status: 'overdue'),
      );
      expect(find.byType(LencanaStatusAlat), findsOneWidget);
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('jejak revisi di riwayat sertifikat', () {
    const alat = AlatRingkas(id: 500, nama: 'Thermohygrometer 0');

    testWidgets('digantikan, revisi, ditarik, dibatalkan dan gagal tampil '
        'dengan keterangannya', (tester) async {
      aturLayar(tester, 392, 4200);
      await tester.pumpWidget(
        bungkusSa(const RiwayatSertifikatAlatScreen(alat: alat)),
      );
      await selesaikan(tester);

      // i=1: terbit-digantikan sekaligus revisi (mock): kedua rujukan tampil.
      final digantikan = find.byKey(const Key('sertifikat-9001'));
      expect(
        find.descendant(
          of: digantikan,
          matching: find.text('Digantikan oleh CAL/2026/0099-R1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: digantikan,
          matching: find.text('Revisi dari CAL/2026/0099-R0'),
        ),
        findsOneWidget,
      );
      // i=2: ditarik 6 Okt 2026.
      expect(
        find.descendant(
          of: find.byKey(const Key('sertifikat-9002')),
          matching: find.text('Ditarik 6 Okt 2026'),
        ),
        findsOneWidget,
      );
      // i=4: dibatalkan.
      expect(
        find.descendant(
          of: find.byKey(const Key('sertifikat-9004')),
          matching: find.textContaining('Dibatalkan 27 Agu 2026'),
        ),
        findsOneWidget,
      );
      // i=3: gagal terbit, tanpa tanggal — menempel di kelompoknya, tanpa
      // judul "tanpa tanggal" sendiri.
      expect(find.byKey(const Key('sertifikat-9003')), findsOneWidget);
      expect(find.byKey(const Key('tahun-kosong')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('sertifikat-9003')),
          matching: find.text('Tanpa tanggal terbit'),
        ),
        findsOneWidget,
      );
    });
  });
}
