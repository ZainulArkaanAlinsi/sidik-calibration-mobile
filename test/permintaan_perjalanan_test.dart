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
import 'package:sidik_calibration/providers/jam_provider.dart';
import 'package:sidik_calibration/providers/koreksi_provider.dart';
import 'package:sidik_calibration/providers/permintaan_provider.dart';
import 'package:sidik_calibration/screens/permintaan/antrean_permintaan_screen.dart';
import 'package:sidik_calibration/screens/permintaan/detail_permintaan_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/services/koreksi_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/permintaan_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Perjalanan alat sesudah permintaan diterima: tahap, resi, jadwal teknisi,
/// alat tiba, progres, dan foto pelat nama (kontrak A5, 1 Okt 2026).
///
/// Token mock: 1 admin · 2 teknisi · 3 viewer · 5 super admin.
///
/// ## Yang dijaga
///
/// - **Server lama tidak merusak layar**: field baru boleh hilang, kartu
///   perjalanan tidak tampil kosong.
/// - **Tombol ikut syarat server**: Jadwalkan hanya untuk `diterima` +
///   `diambil_lab`; Tandai tiba hanya selama belum ditandai; super admin,
///   teknisi, dan viewer tidak melihat keduanya.
/// - **Jadwal dikirim sebagai cap waktu Zulu**, dan wajib punya tanggal + jam.
const _admin = 'mock-token-1';
const _teknisi = 'mock-token-2';
const _superAdmin = 'mock-token-5';

final _hariIni = DateTime(2026, 10, 1, 10);

/// #14 diantar sendiri (resi, foto, progres), #15 diambil lab belum dijadwal,
/// #16 diambil lab sudah dijadwalkan.
const _diantar = 14;
const _belumJadwal = 15;
const _sudahJadwal = 16;

MockPermintaanService _layanan() =>
    MockPermintaanService(awal: MockPermintaanService.contohPerjalanan);

List<Override> _semua({
  required MockPermintaanService service,
  String token = _admin,
}) => [
  tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
  authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
  izinServiceProvider.overrideWithValue(MockIzinService()),
  jamProvider.overrideWithValue(() => _hariIni),
  permintaanServiceProvider.overrideWithValue(service),
  koreksiServiceProvider.overrideWithValue(MockKoreksiService()),
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
  await tester.binding.setSurfaceSize(Size(lebar, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

Future<void> _ok(WidgetTester tester, Type dialog) async {
  await tester.tap(
    find.text(
      MaterialLocalizations.of(tester.element(find.byType(dialog))).okButtonLabel,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('model', () {
    test('fromJson membaca tahap, resi, jadwal, tiba, progres, foto', () {
      final p = PermintaanPelanggan.fromJson(
        jsonDecode('''
{
  "id": 14, "nomor": "PMT/2026/09/0014", "status": "diterima",
  "metode_pengantaran": "diantar_sendiri",
  "tahap": "dalam_pengiriman", "tahap_label": "Alat dalam pengiriman",
  "resi": {"kurir": "JNE", "nomor": "JNE001", "diisi_pada": "2026-09-30T05:00:00Z"},
  "jadwal": {"pada": "2026-10-05T02:00:00Z", "lokasi": "Gudang QC", "catatan": "Bawa berkas"},
  "alat_tiba_pada": "2026-10-01T03:00:00Z",
  "progres": {"selesai": 1, "total": 3},
  "alat": [
    {"id": 62, "baru": true, "nama_alat": "pH Meter",
     "foto": [{"id": 5, "url": "https://x/api/foto-pelanggan/5"}]}
  ]
}''')
            as Map<String, dynamic>,
      );

      expect(p.tahap, TahapPermintaan.dalamPengiriman);
      expect(p.tahapLabel, 'Alat dalam pengiriman');
      expect(p.resi!.kurir, 'JNE');
      expect(p.resi!.nomor, 'JNE001');
      expect(p.resi!.diisiPada, DateTime.utc(2026, 9, 30, 5));
      expect(p.jadwal!.lokasi, 'Gudang QC');
      expect(p.jadwal!.pada, DateTime.utc(2026, 10, 5, 2));
      expect(p.alatTibaPada, DateTime.utc(2026, 10, 1, 3));
      expect(p.progres!.selesai, 1);
      expect(p.progres!.total, 3);
      expect(p.alat.single.foto.single.id, 5);
      expect(p.adaPerjalanan, isTrue);
    });

    test('server lama: semua field baru kosong, tidak ada kartu perjalanan', () {
      final p = PermintaanPelanggan.fromJson(const {
        'id': 1,
        'nomor': 'PMT/1',
        'status': 'diterima',
        'metode_pengantaran': 'diambil_lab',
      });
      expect(p.tahap, isNull);
      expect(p.tahapLabel, isNull);
      expect(p.resi, isNull);
      expect(p.jadwal, isNull);
      expect(p.progres, isNull);
      expect(p.adaPerjalanan, isFalse);
    });

    test('tahap asing tidak melempar; label kosong dianggap tidak ada', () {
      final p = PermintaanPelanggan.fromJson(const {
        'id': 1,
        'nomor': 'PMT/1',
        'status': 'diterima',
        'tahap': 'tahap_masa_depan',
        'tahap_label': '  ',
        'resi': 'bukan objek',
        'progres': {'selesai': 0, 'total': 0},
      });
      expect(p.tahap, TahapPermintaan.lainnya);
      expect(p.tahapLabel, isNull);
      expect(p.resi, isNull);
      // Paket kosong (0 dari 0) tidak membuat kartu.
      expect(p.adaPerjalanan, isFalse);
    });

    test('syarat tombol: diterima + diambil_lab / belum ditandai tiba', () {
      PermintaanPelanggan buat(
        StatusPermintaan s,
        MetodePengantaran m, {
        DateTime? tiba,
      }) => PermintaanPelanggan(
        id: 1,
        nomor: 'x',
        status: s,
        metode: m,
        alatTibaPada: tiba,
      );

      final a = buat(StatusPermintaan.diterima, MetodePengantaran.diambilLab);
      expect(a.bisaDijadwalkan, isTrue);
      expect(a.bisaDitandaiTiba, isTrue);

      final b = buat(
        StatusPermintaan.diterima,
        MetodePengantaran.diantarSendiri,
        tiba: DateTime.utc(2026, 10, 1),
      );
      expect(b.bisaDijadwalkan, isFalse);
      expect(b.bisaDitandaiTiba, isFalse);

      final c = buat(StatusPermintaan.baru, MetodePengantaran.diambilLab);
      expect(c.bisaDijadwalkan, isFalse);
      expect(c.bisaDitandaiTiba, isFalse);
    });

    test('capWaktuZulu: ISO-8601 Zulu tanpa pecahan detik', () {
      expect(
        capWaktuZulu(DateTime.utc(2026, 10, 5, 2, 7, 9, 123)),
        '2026-10-05T02:07:09Z',
      );
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

    test('jadwalkan: POST /jadwal dengan jadwal_pada Zulu; kosong tak dikirim', () async {
      final (svc, rekam) = buat(
        (_) => json({
          'data': {
            'id': 15,
            'nomor': 'PMT/15',
            'status': 'diterima',
            'tahap': 'teknisi_dijadwalkan',
            'tahap_label': 'Teknisi dijadwalkan',
          },
        }),
      );

      final hasil = await svc.jadwalkan(
        't',
        15,
        jadwalPada: DateTime.utc(2026, 10, 5, 2),
        lokasi: ' Gudang QC ',
        catatan: '  ',
      );

      expect(rekam.single.url.path, '/api/permintaan-pelanggan/15/jadwal');
      final badan = jsonDecode(rekam.single.body) as Map<String, dynamic>;
      expect(badan['jadwal_pada'], '2026-10-05T02:00:00Z');
      expect(badan['lokasi'], 'Gudang QC');
      expect(badan.containsKey('catatan'), isFalse);
      expect(hasil.tahapLabel, 'Teknisi dijadwalkan');
    });

    test('alatTiba: POST /alat-tiba tanpa badan', () async {
      final (svc, rekam) = buat(
        (_) => json({
          'data': {
            'id': 14,
            'nomor': 'PMT/14',
            'status': 'diterima',
            'alat_tiba_pada': '2026-10-01T03:00:00Z',
          },
        }),
      );

      final hasil = await svc.alatTiba('t', 14);

      expect(rekam.single.method, 'POST');
      expect(rekam.single.url.path, '/api/permintaan-pelanggan/14/alat-tiba');
      expect(rekam.single.body, '{}');
      expect(hasil.alatTibaPada, DateTime.utc(2026, 10, 1, 3));
    });

    test('422 {message} jadi GalatPermintaan', () async {
      final (svc, _) = buat(
        (_) => json({'message': 'Alat sudah ditandai tiba.'}, 422),
      );
      await expectLater(
        svc.alatTiba('t', 14),
        throwsA(
          isA<GalatPermintaan>().having(
            (e) => e.pesan,
            'pesan',
            'Alat sudah ditandai tiba.',
          ),
        ),
      );
    });
  });

  group('detail', () {
    testWidgets('diantar sendiri: tahap, resi, progres, foto; hanya Tandai tiba', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _diantar),
          service: _layanan(),
        ),
      );

      expect(find.byKey(const ValueKey('kartu-perjalanan-permintaan')), findsOne);
      expect(find.text('Alat dalam pengiriman'), findsOneWidget);
      expect(find.textContaining('JNE · JNE0012345678'), findsOneWidget);
      expect(find.text('0 dari 2 alat selesai'), findsOneWidget);
      // Foto pelat nama alat baru: dua thumbnail.
      expect(find.byKey(const ValueKey('foto-pelanggan-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('foto-pelanggan-6')), findsOneWidget);
      // Bukan diambil lab: tidak ada penjadwalan.
      expect(find.byKey(const ValueKey('tombol-jadwalkan-teknisi')), findsNothing);
      expect(find.byKey(const ValueKey('tombol-alat-tiba')), findsOneWidget);
    });

    testWidgets('diambil lab belum dijadwalkan: dua tombol', (tester) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _belumJadwal),
          service: _layanan(),
        ),
      );
      expect(find.text('Menunggu jadwal teknisi'), findsOneWidget);
      expect(find.byKey(const ValueKey('tombol-jadwalkan-teknisi')), findsOne);
      expect(find.byKey(const ValueKey('tombol-alat-tiba')), findsOneWidget);
    });

    testWidgets('sudah dijadwalkan: jadwal, lokasi, dan catatan tampil', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _sudahJadwal),
          service: _layanan(),
        ),
      );
      expect(find.text('Teknisi dijadwalkan'), findsOneWidget);
      expect(find.textContaining('5 Okt 2026'), findsOneWidget);
      expect(
        find.text('Gudang QC, Jl. Contoh Raya 10, Bandung'),
        findsOneWidget,
      );
      expect(find.text('Bawa dokumen serah terima.'), findsOneWidget);
      expect(find.text('1 dari 3 alat selesai'), findsOneWidget);
    });

    testWidgets('permintaan lama (tanpa field baru): tidak ada kartu perjalanan', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: 9),
          service: MockPermintaanService(),
        ),
      );
      expect(find.byKey(const ValueKey('kartu-perjalanan-permintaan')), findsNothing);
      // Diterima + diantar sendiri + belum ditandai: hanya Tandai tiba.
      expect(find.byKey(const ValueKey('tombol-jadwalkan-teknisi')), findsNothing);
    });

    for (final (nama, token) in [
      ('super admin', _superAdmin),
      ('teknisi', _teknisi),
    ]) {
      testWidgets('$nama tidak melihat tombol operasional', (tester) async {
        await _pasang(
          tester,
          _app(
            const DetailPermintaanScreen(permintaanId: _belumJadwal),
            service: _layanan(),
            token: token,
          ),
        );
        // Kartu tetap terbaca; hanya tombol tulis yang hilang.
        expect(find.text('Menunggu jadwal teknisi'), findsOneWidget);
        expect(find.byKey(const ValueKey('tombol-jadwalkan-teknisi')), findsNothing);
        expect(find.byKey(const ValueKey('tombol-alat-tiba')), findsNothing);
      });
    }
  });

  group('tandai alat tiba', () {
    testWidgets('mengirim, tombol hilang, tahap menjadi Alat di lab', (
      tester,
    ) async {
      final svc = _layanan();
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _diantar),
          service: svc,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('tombol-alat-tiba')));
      await tester.pumpAndSettle();

      expect(svc.alatTibaDitandai, [_diantar]);
      expect(find.text('Alat ditandai sudah tiba.'), findsOneWidget);
      expect(find.byKey(const ValueKey('tombol-alat-tiba')), findsNothing);
      expect(find.text('Alat di lab'), findsOneWidget);
    });

    testWidgets('422 (sudah ditandai admin lain): pesan server tampil', (
      tester,
    ) async {
      final svc = _layanan();
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _diantar),
          service: svc,
        ),
      );
      // Admin lain menandainya lebih dulu, diam-diam di server.
      await svc.alatTiba('t', _diantar);

      await tester.tap(find.byKey(const ValueKey('tombol-alat-tiba')));
      await tester.pumpAndSettle();

      expect(find.text('Alat sudah ditandai tiba.'), findsOneWidget);
    });
  });

  group('jadwalkan teknisi', () {
    Future<MockPermintaanService> bukaLembar(WidgetTester tester) async {
      final svc = _layanan();
      await _pasang(
        tester,
        _app(
          const DetailPermintaanScreen(permintaanId: _belumJadwal),
          service: svc,
        ),
        // Pemilih jam bawaan Flutter meluap di 420 px pada surface uji.
        lebar: 800,
      );
      await tester.tap(find.byKey(const ValueKey('tombol-jadwalkan-teknisi')));
      await tester.pumpAndSettle();
      return svc;
    }

    testWidgets('tanggal & jam wajib: kosong tidak terkirim', (tester) async {
      final svc = await bukaLembar(tester);
      expect(find.byKey(const ValueKey('lembar-jadwal-permintaan')), findsOne);

      await tester.tap(find.byKey(const ValueKey('kirim-jadwal-permintaan')));
      await tester.pumpAndSettle();

      expect(find.text('Pilih tanggal dan jam dulu.'), findsOneWidget);
      expect(svc.dijadwalkanDengan, isEmpty);
    });

    testWidgets('diisi lengkap: terkirim, toast, tahap menjadi dijadwalkan', (
      tester,
    ) async {
      final svc = await bukaLembar(tester);

      await tester.tap(find.byKey(const ValueKey('isian-jadwal-tanggal')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('15'),
        ),
      );
      await tester.pump();
      await _ok(tester, DatePickerDialog);

      await tester.tap(find.byKey(const ValueKey('isian-jadwal-jam')));
      await tester.pumpAndSettle();
      await _ok(tester, TimePickerDialog);

      await tester.enterText(
        find.byKey(const ValueKey('isian-jadwal-lokasi')),
        'Gudang QC Bandung',
      );
      await tester.enterText(
        find.byKey(const ValueKey('isian-jadwal-catatan')),
        'Bawa dokumen serah terima.',
      );
      await tester.tap(find.byKey(const ValueKey('kirim-jadwal-permintaan')));
      await tester.pumpAndSettle();

      final k = svc.dijadwalkanDengan.single;
      expect(k.id, _belumJadwal);
      expect(k.jadwalPada.day, 15);
      expect(k.jadwalPada.hour, 9);
      expect(k.lokasi, 'Gudang QC Bandung');
      expect(k.catatan, 'Bawa dokumen serah terima.');
      expect(find.byKey(const ValueKey('lembar-jadwal-permintaan')), findsNothing);
      expect(find.text('Jadwal teknisi tersimpan.'), findsOneWidget);
      expect(find.text('Teknisi dijadwalkan'), findsOneWidget);
    });
  });

  group('antrean', () {
    testWidgets('tahap tampil di baris permintaan yang sudah diterima', (
      tester,
    ) async {
      await _pasang(
        tester,
        _app(
          const AntreanPermintaanScreen(),
          service: MockPermintaanService(
            awal: [
              ...MockPermintaanService.contoh,
              ...MockPermintaanService.contohPerjalanan,
            ],
          ),
        ),
      );

      final chip = find.byKey(const ValueKey('tab-permintaan-diterima'));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('tahap-permintaan-14')),
        findsOneWidget,
      );
      expect(find.text('Alat dalam pengiriman'), findsOneWidget);
      expect(find.text('Menunggu jadwal teknisi'), findsOneWidget);
      // Permintaan lama (#9) tidak membawa label: tidak ada baris tahap.
      expect(find.byKey(const ValueKey('tahap-permintaan-9')), findsNothing);
    });
  });
}
