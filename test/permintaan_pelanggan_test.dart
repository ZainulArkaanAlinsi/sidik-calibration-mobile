import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/permintaan_pelanggan.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/permintaan_provider.dart';
import 'package:sidik_calibration/providers/realtime_provider.dart';
import 'package:sidik_calibration/screens/permintaan/antrean_permintaan_screen.dart';
import 'package:sidik_calibration/screens/permintaan/detail_permintaan_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/permintaan_service.dart';
import 'package:sidik_calibration/services/realtime_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';

/// Permintaan kalibrasi pelanggan, sisi lab (30 Sep 2026, §41).
///
/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
///
/// ## Yang dijaga
///
/// - **Siapa melihat tombol apa.** Super admin membaca saja; tombol yang pasti
///   dijawab 403 tidak boleh ditawarkan — dan tidak boleh hilang DIAM-DIAM
///   (ada kalimat yang menjelaskannya).
/// - **Terima tidak bisa lolos tanpa kategori & nomor seri** untuk alat baru,
///   dan bentrok nomor seri (422) muncul di bawah kolom alat yang bersangkutan.
/// - **Tolak wajib beralasan** (≥ 5 karakter) — dibaca pelanggan apa adanya.
/// - **Antrean ikut sinyal `data.berubah`** dari perangkat admin lain.
const _admin = 'mock-token-1';
const _superAdmin = 'mock-token-5';

/// "Hari ini" semua test — lama menunggu dihitung dari sini.
final _hariIni = DateTime(2026, 10, 1, 10);

List<Override> _semua({
  required MockPermintaanService service,
  String token = _admin,
}) => [
  tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
  authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
  izinServiceProvider.overrideWithValue(MockIzinService()),
  jamProvider.overrideWithValue(() => _hariIni),
  permintaanServiceProvider.overrideWithValue(service),
  categoryServiceProvider.overrideWithValue(MockCategoryService()),
];

Widget _app(
  Widget layar, {
  required MockPermintaanService service,
  String token = _admin,
}) => ProviderScope(
  overrides: _semua(service: service, token: token),
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: layar,
  ),
);

Future<void> _pasang(
  WidgetTester tester,
  Widget app, {
  double lebar = 420,
}) async {
  await tester.binding.setSurfaceSize(Size(lebar, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  // MockAuthService dipasang jeda nol, tapi tetap satu tarikan async.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// Permintaan #12: satu alat terdaftar + satu alat BARU (butuh kategori &
/// nomor seri). #13: hanya alat terdaftar.
const _barang = 12;
const _hanyaTerdaftar = 13;

void main() {
  group('model', () {
    test('fromJson membaca detail kontrak §3.2 apa adanya', () {
      final p = PermintaanPelanggan.fromJson(
        jsonDecode('''
{
  "id": 12, "nomor": "PMT/2026/09/0012", "status": "baru",
  "customer": {"id": 7, "nama": "PT Tirta Mandiri Laboratorium"},
  "pemohon": {"id": 41, "nama": "Budi", "email": "budi@x.co.id", "telepon": "+62812"},
  "metode_pengantaran": "diambil_lab",
  "tanggal_diinginkan_dari": "2026-10-05", "tanggal_diinginkan_sampai": "2026-10-09",
  "catatan": "Tolong diprioritaskan.",
  "diputuskan_oleh": null, "order": null,
  "jumlah_alat": 2, "jumlah_pesan": 1,
  "alat": [
    {"id": 32, "equipment_id": null, "baru": true, "nama_alat": "pH Meter",
     "merk": "Hanna", "rentang_min": 0, "rentang_maks": 14, "satuan": "pH",
     "resolusi": 0.01, "perlu_kategori": true, "perlu_nomor_seri": true}
  ],
  "dibuat_pada": "2026-09-30T02:11:05Z"
}''')
            as Map<String, dynamic>,
      );

      expect(p.status, StatusPermintaan.baru);
      expect(p.status.bisaDiputuskan, isTrue);
      expect(p.pelangganId, 7);
      expect(p.metode, MetodePengantaran.diambilLab);
      expect(p.orderNomor, isNull);
      expect(p.alat.single.id, 32);
      expect(p.alat.single.baru, isTrue);
      expect(p.alat.single.perluKategori, isTrue);
      expect(p.alat.single.perluNomorSeri, isTrue);
      // Rentang dicetak sebagai bilangan bulat kalau memang bulat.
      expect(p.alat.single.rentang, '0 – 14 pH');
    });

    test(
      'status yang belum dikenal tidak membuang kartunya & tidak bisa diputus',
      () {
        final p = PermintaanPelanggan.fromJson(const {
          'id': 1,
          'nomor': 'PMT/1',
          'status': 'dijadwalkan',
        });
        expect(p.status, StatusPermintaan.lainnya);
        expect(p.status.bisaDiputuskan, isFalse);
      },
    );

    test('GalatPermintaan memilah errors per kunci', () {
      final g = GalatPermintaan.dariBody('m', {
        'errors': {
          'alat_baru.32.serial_number': ['bentrok'],
          'status': 'sudah diputuskan',
        },
      });
      expect(g.untuk('alat_baru.32.serial_number'), 'bentrok');
      expect(g.status, 'sudah diputuskan');
      expect(g.untuk('tidak.ada'), isNull);
    });
  });

  group('ApiPermintaanService', () {
    (ApiPermintaanService, List<http.Request>) buat(
      http.Response Function(http.Request) jawab,
    ) {
      final rekam = <http.Request>[];
      final client = MockClient((r) async {
        rekam.add(r);
        return jawab(r);
      });
      return (
        ApiPermintaanService(
          ApiClient(client: client, baseUrl: 'http://x/api'),
        ),
        rekam,
      );
    }

    http.Response json(Object o, [int kode = 200]) => http.Response(
      jsonEncode(o),
      kode,
      headers: {'content-type': 'application/json'},
    );

    test('daftar mengirim saringan & membaca meta.jumlah_baru', () async {
      final (svc, rekam) = buat(
        (_) => json({
          'data': [
            {'id': 1, 'nomor': 'PMT/1', 'status': 'baru'},
          ],
          'meta': {'total': 1, 'jumlah_baru': 4},
        }),
      );

      final h = await svc.daftar(
        't',
        status: 'baru',
        pelangganId: 7,
        cari: 'tirta mandiri',
      );

      final q = rekam.single.url.queryParameters;
      expect(q['status'], 'baru');
      expect(q['customer_id'], '7');
      expect(q['search'], 'tirta mandiri');
      expect(rekam.single.url.path, '/api/permintaan-pelanggan');
      expect(h.items.single.nomor, 'PMT/1');
      expect(h.jumlahBaru, 4);
    });

    test(
      'terima mengirim alat_baru per item & 422 jadi GalatPermintaan',
      () async {
        final (svc, rekam) = buat(
          (_) => json({
            'message': 'Data yang dikirim tidak valid.',
            'errors': {
              'alat_baru.32.serial_number': ['Nomor seri sudah dipakai.'],
            },
          }, 422),
        );

        await expectLater(
          svc.terima(
            't',
            12,
            tanggalMasuk: DateTime(2026, 10, 2),
            alatBaru: const [
              LengkapiAlatBaru(
                itemId: 32,
                kategoriId: 4,
                serialNumber: ' X-1 ',
              ),
            ],
          ),
          throwsA(
            isA<GalatPermintaan>().having(
              (e) => e.untuk('alat_baru.32.serial_number'),
              'pesan serial',
              'Nomor seri sudah dipakai.',
            ),
          ),
        );

        final badan = jsonDecode(rekam.single.body) as Map<String, dynamic>;
        expect(rekam.single.url.path, '/api/permintaan-pelanggan/12/terima');
        expect(badan['tanggal_masuk'], '2026-10-02');
        expect(badan['alat_baru'], [
          {'item_id': 32, 'equipment_category_id': 4, 'serial_number': 'X-1'},
        ]);
      },
    );

    test(
      '403 (super admin menulis) tidak diubah jadi galat validasi',
      () async {
        final (svc, _) = buat(
          (_) => json({'message': 'Kamu nggak punya akses ke sini.'}, 403),
        );
        await expectLater(
          svc.tolak('t', 12, 'alasan cukup'),
          throwsA(isNot(isA<GalatPermintaan>())),
        );
      },
    );
  });

  group('antrean', () {
    testWidgets('admin: tab Baru dibuka dulu, dengan hitungan & kartunya', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(const AntreanPermintaanScreen(), service: MockPermintaanService()),
      );

      expect(find.text('Permintaan pelanggan'), findsOneWidget);
      expect(find.text('PMT/2026/09/0012'), findsOneWidget);
      expect(find.text('PMT/2026/09/0013'), findsOneWidget);
      // Yang sudah diputuskan tidak di tab Baru.
      expect(find.text('PMT/2026/09/0009'), findsNothing);
      expect(find.text('PMT/2026/09/0008'), findsNothing);
      // Menunggu dihitung dari jam yang dipatok: 28 Sep → 1 Okt = 3 hari.
      expect(find.text('Menunggu 3 hari'), findsOneWidget);
      expect(find.text('2 permintaan'), findsOneWidget);
    });

    testWidgets('pindah tab memuat status itu; tab Semua memuat semuanya', (
      tester,
    ) async {
      // Lebar tablet: lima chip muat tanpa digeser (di HP barisnya bisa
      // digulir; chip di luar layar memang belum dibangun).
      await _pasang(
        tester,
        _app(const AntreanPermintaanScreen(), service: MockPermintaanService()),
        lebar: 800,
      );

      await tester.tap(find.byKey(const ValueKey('tab-permintaan-ditolak')));
      await tester.pumpAndSettle();
      expect(find.text('PMT/2026/09/0008'), findsOneWidget);
      expect(find.text('PMT/2026/09/0012'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tab-permintaan-semua')));
      await tester.pumpAndSettle();
      expect(find.text('PMT/2026/09/0012'), findsOneWidget);
      expect(find.text('PMT/2026/09/0009'), findsOneWidget);
      expect(find.text('PMT/2026/09/0008'), findsOneWidget);
    });

    testWidgets('kotak cari menyaring lewat server (nama perusahaan)', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(const AntreanPermintaanScreen(), service: MockPermintaanService()),
      );

      await tester.enterText(find.byType(TextField), 'anugerah');
      // Jeda ketik 400 ms.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('PMT/2026/09/0013'), findsOneWidget);
      expect(find.text('PMT/2026/09/0012'), findsNothing);
    });

    testWidgets('kosong: pesan tab Baru, dan pesan pencarian bila mencari', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const AntreanPermintaanScreen(),
          service: MockPermintaanService(awal: const []),
        ),
      );
      expect(find.textContaining('Tidak ada permintaan baru'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Tidak ada permintaan yang cocok'),
        findsOneWidget,
      );
    });

    testWidgets('galat muat: pesan + coba lagi', (tester) async {
      await _pasang(
        tester,
        _app(
          const AntreanPermintaanScreen(),
          service: MockPermintaanService(gagal: true),
        ),
      );
      expect(find.text('Permintaan pelanggan gagal dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  group('detail: siapa melihat tombol apa', () {
    testWidgets('admin + status baru: Terima & Tolak ada', (tester) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _barang),
          service: MockPermintaanService(),
        ),
      );

      expect(
        find.byKey(const ValueKey('tombol-terima-permintaan')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tombol-tolak-permintaan')),
        findsOneWidget,
      );
      // Dua alat: satu terdaftar, satu baru yang perlu dilengkapi.
      expect(find.text('Timbangan Ohaus PX224'), findsOneWidget);
      expect(find.text('Alat baru'), findsOneWidget);
      expect(find.text('Terdaftar'), findsOneWidget);
      expect(find.text('Lengkapi saat menerima'), findsOneWidget);
    });

    testWidgets('super admin: tombol tidak ada, ada kalimat yang menjelaskan', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _barang),
          service: MockPermintaanService(),
          token: _superAdmin,
        ),
      );

      expect(
        find.byKey(const ValueKey('tombol-terima-permintaan')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('tombol-tolak-permintaan')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('catatan-baca-saja-permintaan')),
        findsOneWidget,
      );
    });

    testWidgets('sudah diterima: tanpa tombol, order kelihatan', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: 9),
          service: MockPermintaanService(),
        ),
      );
      expect(
        find.byKey(const ValueKey('tombol-terima-permintaan')),
        findsNothing,
      );
      expect(find.text('ORD/2026/09/0055'), findsOneWidget);
    });

    testWidgets('ditolak: alasan tampil apa adanya', (tester) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: 8),
          service: MockPermintaanService(),
        ),
      );
      expect(
        find.text('Nomor seri alat sudah terdaftar atas perusahaan lain.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tombol-tolak-permintaan')),
        findsNothing,
      );
    });

    testWidgets('gagal muat: pesan + coba lagi', (tester) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _barang),
          service: MockPermintaanService(gagal: true),
        ),
      );
      expect(
        find.textContaining('tidak ditemukan atau gagal dimuat'),
        findsOneWidget,
      );
    });
  });

  group('terima', () {
    testWidgets('tanpa alat baru: sekali ketuk, order lahir', (tester) async {
      final svc = MockPermintaanService();
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _hanyaTerdaftar),
          service: svc,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('tombol-terima-permintaan')));
      await tester.pumpAndSettle();
      // Tidak ada formulir alat baru.
      expect(find.text('Lengkapi alat baru'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('kirim-terima-permintaan')));
      await tester.pumpAndSettle();

      expect(svc.diterimaDengan, hasLength(1));
      expect(svc.diterimaDengan.single, isEmpty);
      // Kembali ke detail, status sudah Diterima & tombol hilang.
      expect(
        find.byKey(const ValueKey('tombol-terima-permintaan')),
        findsNothing,
      );
      expect(find.textContaining('Order ORD/2026/10/'), findsOneWidget);
    });

    testWidgets('alat baru: kategori & nomor seri wajib sebelum terkirim', (
      tester,
    ) async {
      final svc = MockPermintaanService();
      await _pasang(
        tester,
        _app(const DetailPermintaanScreen(permintaanId: _barang), service: svc),
      );
      await tester.tap(find.byKey(const ValueKey('tombol-terima-permintaan')));
      await tester.pumpAndSettle();
      expect(find.text('Lengkapi alat baru'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('kirim-terima-permintaan')));
      await tester.pumpAndSettle();

      // Dicegah di sisi aplikasi: tidak satu pun panggilan sampai ke server.
      expect(svc.diterimaDengan, isEmpty);
      expect(find.text('Pilih kategori'), findsWidgets);
      expect(find.text('Isi nomor seri'), findsOneWidget);
    });

    testWidgets('bentrok nomor seri (422) muncul di bawah kolom alatnya, lalu '
        'bisa diperbaiki', (tester) async {
      final svc = MockPermintaanService();
      await _pasang(
        tester,
        _app(const DetailPermintaanScreen(permintaanId: _barang), service: svc),
      );
      await tester.tap(find.byKey(const ValueKey('tombol-terima-permintaan')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('kategori-32')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Instrumen Analitik').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('serial-32')),
        'BENTROK-01',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-terima-permintaan')));
      await tester.pumpAndSettle();

      // Pesan server di bawah kolom, bukan snackbar yang tak bilang alat mana;
      // dan saran keluarnya (ubah nomor atau tolak) dibaca admin.
      expect(
        find.text('Nomor seri sudah dipakai alat lain di lab ini.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('banner-galat-terima')), findsOneWidget);
      expect(find.textContaining('tolak permintaan ini'), findsOneWidget);
      expect(svc.diterimaDengan, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('serial-32')),
        'HI-0419',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-terima-permintaan')));
      await tester.pumpAndSettle();

      final dikirim = svc.diterimaDengan.single.single;
      expect(dikirim.itemId, 32);
      expect(dikirim.kategoriId, 5);
      expect(dikirim.serialNumber, 'HI-0419');
      expect(
        find.byKey(const ValueKey('tombol-terima-permintaan')),
        findsNothing,
      );
    });
  });

  group('tolak', () {
    testWidgets(
      'alasan < 5 karakter tidak bisa dikirim; cukup → status ditolak',
      (tester) async {
        final svc = MockPermintaanService();
        await _pasang(
          tester,
          _app(
            const DetailPermintaanScreen(permintaanId: _hanyaTerdaftar),
            service: svc,
          ),
        );

        await tester.tap(find.byKey(const ValueKey('tombol-tolak-permintaan')));
        await tester.pumpAndSettle();

        final kirim = find.byKey(const ValueKey('kirim-tolak-permintaan'));
        expect(tester.widget<TextButton>(kirim).onPressed, isNull);

        await tester.enterText(
          find.byKey(const ValueKey('isian-alasan-tolak')),
          'abc',
        );
        await tester.pump();
        expect(tester.widget<TextButton>(kirim).onPressed, isNull);

        await tester.enterText(
          find.byKey(const ValueKey('isian-alasan-tolak')),
          '  Alat di luar cakupan akreditasi.  ',
        );
        await tester.pump();
        expect(tester.widget<TextButton>(kirim).onPressed, isNotNull);

        await tester.tap(kirim);
        await tester.pumpAndSettle();

        // Dikirim tanpa spasi pinggir — dibaca pelanggan apa adanya.
        expect(svc.ditolakDengan, ['Alat di luar cakupan akreditasi.']);
        expect(find.text('Ditolak'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('tombol-tolak-permintaan')),
          findsNothing,
        );
      },
    );

    testWidgets('membatalkan dialog tidak mengirim apa pun (dan tidak crash)', (
      tester,
    ) async {
      final svc = MockPermintaanService();
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _hanyaTerdaftar),
          service: svc,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('tombol-tolak-permintaan')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(svc.ditolakDengan, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('pesan', () {
    Future<void> bukaTabPesan(WidgetTester tester) async {
      await tester.tap(find.textContaining('Pesan'));
      await tester.pumpAndSettle();
    }

    testWidgets('utas tampil dengan nama pengirim; kirim menambah pesan', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _barang),
          service: MockPermintaanService(),
        ),
      );
      await bukaTabPesan(tester);

      expect(
        find.text('Apakah pH meter bisa dikalibrasi di tempat kami?'),
        findsOneWidget,
      );
      expect(find.text('Sari (admin)'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('isian-pesan-permintaan')),
        'Silakan bawa ke lab.',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-pesan-permintaan')));
      await tester.pumpAndSettle();

      expect(find.text('Silakan bawa ke lab.'), findsOneWidget);
      // Kotak dikosongkan setelah terkirim.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('isian-pesan-permintaan')),
            )
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('pesan gagal terkirim tetap di kotak ketik', (tester) async {
      final svc = _PesanGagal();
      await _pasang(
        tester,
        _app(const DetailPermintaanScreen(permintaanId: _barang), service: svc),
      );
      await bukaTabPesan(tester);

      await tester.enterText(
        find.byKey(const ValueKey('isian-pesan-permintaan')),
        'Jangan hilang.',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-pesan-permintaan')));
      await tester.pumpAndSettle();

      expect(find.text('Terlalu sering. Tunggu sebentar.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('isian-pesan-permintaan')),
            )
            .controller!
            .text,
        'Jangan hilang.',
      );
    });

    testWidgets(
      'percakapan ditutup (ditolak): riwayat ada, kotak ketik tidak',
      (tester) async {
        await _pasang(
          tester,
          _app(
            const DetailPermintaanScreen(permintaanId: 8),
            service: MockPermintaanService(
              pesan: {
                8: [
                  PesanPermintaan(
                    id: 1,
                    dariLab: false,
                    namaPengirim: 'Sari',
                    isi: 'Halo lab.',
                  ),
                ],
              },
            ),
          ),
        );
        await bukaTabPesan(tester);

        expect(find.text('Halo lab.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('isian-pesan-permintaan')),
          findsNothing,
        );
        expect(find.textContaining('Percakapan ditutup'), findsOneWidget);
      },
    );

    testWidgets('super admin membaca utas tapi tidak bisa membalas', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _barang),
          service: MockPermintaanService(),
          token: _superAdmin,
        ),
      );
      await bukaTabPesan(tester);

      expect(
        find.text('Apakah pH meter bisa dikalibrasi di tempat kami?'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('isian-pesan-permintaan')),
        findsNothing,
      );
    });

    testWidgets('utas kosong: pesan kosong, bukan layar hampa', (tester) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _hanyaTerdaftar),
          service: MockPermintaanService(),
        ),
      );
      await bukaTabPesan(tester);
      expect(find.text('Belum ada pesan.'), findsOneWidget);
    });
  });

  group('realtime', () {
    test('data.berubah menarik ulang antrean & badge permintaan', () async {
      final rt = MockRealtimeService();
      final svc = _HitungPermintaan();
      final container = ProviderContainer(
        overrides: [
          realtimeServiceProvider.overrideWithValue(rt),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_admin)),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          notificationServiceProvider.overrideWithValue(
            MockNotificationService(),
          ),
          permintaanServiceProvider.overrideWithValue(svc),
        ],
      );
      addTearDown(container.dispose);

      container.listen(realtimeSyncProvider, (_, _) {});
      container.listen(antreanPermintaanProvider, (_, _) {});
      container.listen(jumlahPermintaanBaruProvider, (_, _) {});

      await container.read(authProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.read(antreanPermintaanProvider.future);
      await container.read(jumlahPermintaanBaruProvider.future);
      final sebelum = svc.daftarDipanggil;

      rt.pancarkan(
        const DataBerubah(jenis: 'permintaan', aksi: 'dibuat', id: 12),
      );
      await Future<void>.delayed(Duration.zero);
      await container.read(antreanPermintaanProvider.future);
      await container.read(jumlahPermintaanBaruProvider.future);

      // Dua penarikan baru: antrean dan badge.
      expect(svc.daftarDipanggil, sebelum + 2);
    });

    test('tab & kata cari selamat dari invalidate realtime', () async {
      final rt = MockRealtimeService();
      final container = ProviderContainer(
        overrides: [
          realtimeServiceProvider.overrideWithValue(rt),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(_admin)),
          authServiceProvider.overrideWithValue(
            MockAuthService(jeda: Duration.zero),
          ),
          notificationServiceProvider.overrideWithValue(
            MockNotificationService(),
          ),
          permintaanServiceProvider.overrideWithValue(MockPermintaanService()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(realtimeSyncProvider, (_, _) {});
      container.listen(antreanPermintaanProvider, (_, _) {});
      container.listen(unreadCountProvider, (_, _) {});
      await container.read(authProvider.future);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(antreanPermintaanProvider.notifier)
          .saring('ditolak');
      await container.read(antreanPermintaanProvider.notifier).cari('anugerah');

      rt.pancarkan(
        const DataBerubah(jenis: 'permintaan', aksi: 'pesan', id: 8),
      );
      await Future<void>.delayed(Duration.zero);
      final h = await container.read(antreanPermintaanProvider.future);

      expect(container.read(statusPermintaanProvider), 'ditolak');
      expect(h.items.map((p) => p.nomor), ['PMT/2026/09/0008']);
    });
  });
}

/// Mock yang menghitung berapa kali antrean/badge ditarik.
class _HitungPermintaan extends MockPermintaanService {
  int daftarDipanggil = 0;

  @override
  Future<HalamanPermintaan> daftar(
    String token, {
    String? status,
    int? pelangganId,
    String? cari,
    int perPage = 50,
  }) {
    daftarDipanggil++;
    return super.daftar(
      token,
      status: status,
      pelangganId: pelangganId,
      cari: cari,
      perPage: perPage,
    );
  }
}

/// Server menolak kiriman pesan (mis. kena throttle 429).
class _PesanGagal extends MockPermintaanService {
  @override
  Future<PesanPermintaan> kirimPesan(String token, int id, String isi) async {
    throw const GalatPermintaan('Terlalu sering. Tunggu sebentar.');
  }
}
