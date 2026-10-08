import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/riwayat_tersembunyi_provider.dart';
import 'package:sidik_calibration/screens/history/history_screen.dart';
import 'package:sidik_calibration/services/api_client.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/riwayat_tersembunyi_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Riwayat: cari, lencana status sertifikat, dan sembunyikan per akun
/// (keputusan pemilik 8 Okt 2026).
///
/// Yang paling dijaga: "sembunyikan" itu TAMPILAN saja. Datanya tetap ada,
/// bisa dimunculkan lagi, dan kegagalan server tidak boleh meninggalkan baris
/// yang kelihatan tersembunyi padahal server tidak pernah mencatatnya.

/// Bentuk `GET /api/calibrations?ringkas=1` satu baris — kunci & sarangnya
/// diambil dari `CalibrationResource::toArray()` di repo API.
Map<String, dynamic> _json({
  Object? tersembunyi,
  Map<String, dynamic>? sertifikat,
  String? alatSeri,
  String? equipmentSeri,
}) => {
  'id': 77,
  'nomor_sesi': 'KAL/2026/10/0077',
  'status': 'disetujui',
  'tanggal_kalibrasi': '2026-10-01',
  'equipment': {
    'nama_alat': 'pH Meter Mettler Toledo',
    'serial_number': equipmentSeri,
  },
  'alat_serial_number': alatSeri,
  'teknisi': {'nama': 'Dimas'},
  'pelanggan': {'nama': 'PT Contoh Sejahtera'},
  'sertifikat': sertifikat,
  'tersembunyi': ?tersembunyi,
};

const _sesiPh = CalibrationHistoryItem(
  id: 1,
  namaAlat: 'pH Meter Mettler Toledo',
  namaTeknisi: 'Andi',
  status: CalibrationStatus.disetujui,
  keputusan: Keputusan.pass,
  nomorSesi: 'KAL/2026/10/0001',
  namaPelanggan: 'PT Contoh Sejahtera',
  nomorSertifikat: 'CAL/2026/10/0101',
  statusSertifikat: 'terbit',
  nomorSeri: 'SN-PH-7781',
);

const _sesiOven = CalibrationHistoryItem(
  id: 2,
  namaAlat: 'Oven Memmert UN55',
  namaTeknisi: 'Sari',
  status: CalibrationStatus.disetujui,
  keputusan: Keputusan.pass,
  nomorSesi: 'KAL/2026/10/0002',
  namaPelanggan: 'CV Uji Coba',
  nomorSertifikat: 'CAL/2026/10/0102',
  statusSertifikat: 'dibatalkan',
);

const _sesiTermometer = CalibrationHistoryItem(
  id: 3,
  namaAlat: 'Termometer Digital Fluke',
  namaTeknisi: 'Andi',
  // Bukan `menungguApproval`: lencana "Menunggu approval" sendiri sudah
  // meluap 12 px di 360 px dengan font test (sudah begitu sebelum fitur ini,
  // dicek ke baseline 8 Okt 2026). Yang diuji di sini elemen baru.
  status: CalibrationStatus.disetujui,
  keputusan: Keputusan.pass,
  nomorSesi: 'KAL/2026/10/0003',
  namaPelanggan: 'PT Contoh Sejahtera',
  tersembunyi: true,
);

/// Daftar tetap — tanpa `MockHistoryService` supaya penanda tersembunyi dari
/// `MockStore` tidak ikut campur.
class _RiwayatTetap implements HistoryService {
  _RiwayatTetap(this.isi);

  final List<CalibrationHistoryItem> isi;

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async => isi;

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async => const [];

  @override
  Future<List<CalibrationHistoryItem>> ambilDraf(String token) async =>
      const [];

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) =>
      MockHistoryService().ambilDetail(token, id);

  @override
  Future<CalibrationDetail> verifikasiPembacaan(String token, int id) =>
      MockHistoryService().verifikasiPembacaan(token, id);
}

Widget _app({
  required List<CalibrationHistoryItem> isi,
  required RiwayatTersembunyiService sembunyi,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-2'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      historyServiceProvider.overrideWithValue(_RiwayatTetap(isi)),
      approvalServiceProvider.overrideWithValue(MockApprovalService()),
      riwayatTersembunyiServiceProvider.overrideWithValue(sembunyi),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HistoryScreen(),
    ),
  );
}

/// Lebar HP 360 px — kartu dengan menu tiga titik paling sempit di sini, dan
/// luapan baris langsung bikin test merah.
void _ukuranHp(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 760 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _buka(WidgetTester tester, Widget app) async {
  _ukuranHp(tester);
  await tester.pumpWidget(app);
  // `MockAuthService.me` punya jeda 600 ms dan `HistoryController.build`
  // nge-`watch` auth — tunggu sampai benar-benar diam.
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  tearDown(MockStore.instance.reset);

  group('parse baris riwayat', () {
    test(
      'tersembunyi, status sertifikat, nomor sesi, dan No. Seri terbaca',
      () {
        final item = CalibrationHistoryItem.fromJson(
          _json(
            tersembunyi: true,
            sertifikat: {
              'id': 5,
              'nomor': 'CAL/2026/10/0077',
              'status': 'dibatalkan',
            },
            alatSeri: 'SN-LEMBAR',
            equipmentSeri: 'SN-ALAT',
          ),
        );

        expect(item.tersembunyi, isTrue);
        expect(item.statusSertifikat, 'dibatalkan');
        expect(item.nomorSertifikat, 'CAL/2026/10/0077');
        expect(item.nomorSesi, 'KAL/2026/10/0077');
        // Versi lembar kerja duluan — itu yang tercetak di sertifikat.
        expect(item.nomorSeri, 'SN-LEMBAR');
      },
    );

    test('server lama tanpa `tersembunyi` = tidak tersembunyi; '
        'tanpa sertifikat = status null', () {
      final item = CalibrationHistoryItem.fromJson(_json());

      expect(item.tersembunyi, isFalse);
      expect(item.statusSertifikat, isNull);
      expect(item.nomorSertifikat, isNull);
    });

    test('nilai `tersembunyi` yang bukan bool dibaca TIDAK tersembunyi', () {
      // Lebih aman baris kelihatan daripada hilang tanpa jejak.
      expect(
        CalibrationHistoryItem.fromJson(_json(tersembunyi: 1)).tersembunyi,
        isFalse,
      );
      expect(
        CalibrationHistoryItem.fromJson(_json(tersembunyi: 'true')).tersembunyi,
        isFalse,
      );
    });

    test('seri lembar kerja kosong jatuh ke seri data alat', () {
      final item = CalibrationHistoryItem.fromJson(
        _json(alatSeri: '  ', equipmentSeri: 'SN-ALAT'),
      );
      expect(item.nomorSeri, 'SN-ALAT');
    });

    test('copyWith(tersembunyi) tidak membuang field baru', () {
      final salinan = _sesiPh.copyWith(tersembunyi: true);
      expect(salinan.tersembunyi, isTrue);
      expect(salinan.statusSertifikat, 'terbit');
      expect(salinan.nomorSesi, 'KAL/2026/10/0001');
      expect(salinan.nomorSeri, 'SN-PH-7781');
    });
  });

  group('cocokDengan', () {
    test('kosong / spasi doang = semua cocok', () {
      expect(_sesiPh.cocokDengan(''), isTrue);
      expect(_sesiPh.cocokDengan('   '), isTrue);
    });

    test('nomor sesi, alat, pelanggan, nomor sertifikat, No. Seri', () {
      expect(_sesiPh.cocokDengan('kal/2026/10/0001'), isTrue);
      expect(_sesiPh.cocokDengan('METTLER'), isTrue);
      expect(_sesiPh.cocokDengan('contoh sejahtera'), isTrue);
      expect(_sesiPh.cocokDengan('0101'), isTrue);
      expect(_sesiPh.cocokDengan('sn-ph'), isTrue);
      expect(_sesiPh.cocokDengan('  ph meter  '), isTrue);
    });

    test('yang tidak ada di kolom mana pun tidak cocok', () {
      expect(_sesiPh.cocokDengan('oven'), isFalse);
      // Nama teknisi sengaja bukan kunci cari Riwayat.
      expect(_sesiPh.cocokDengan('andi'), isFalse);
    });
  });

  group('HistoryController.sembunyikan', () {
    ProviderContainer wadah(RiwayatTersembunyiService sembunyi) {
      final c = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-2'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          historyServiceProvider.overrideWithValue(
            _RiwayatTetap(const [_sesiPh, _sesiOven]),
          ),
          riwayatTersembunyiServiceProvider.overrideWithValue(sembunyi),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    bool tersembunyi(ProviderContainer c, int id) => c
        .read(historyProvider)
        .value!
        .firstWhere((e) => e.id == id)
        .tersembunyi;

    test('memanggil service, lalu bisa diurungkan', () async {
      final servis = MockRiwayatTersembunyiService();
      final c = wadah(servis);
      await c.read(historyProvider.future);

      await c.read(historyProvider.notifier).sembunyikan(1);
      expect(tersembunyi(c, 1), isTrue);
      expect(tersembunyi(c, 2), isFalse);

      await c.read(historyProvider.notifier).tampilkanLagi(1);
      expect(tersembunyi(c, 1), isFalse);

      expect(servis.panggilan, [(1, true), (1, false)]);
    });

    test('server gagal → penanda dibalikin & galatnya dilempar', () async {
      final c = wadah(MockRiwayatTersembunyiService(gagal: true));
      await c.read(historyProvider.future);

      await expectLater(
        c.read(historyProvider.notifier).sembunyikan(1),
        throwsA(isA<Exception>()),
      );
      expect(tersembunyi(c, 1), isFalse);
    });

    test(
      'optimistic: baris sudah tersembunyi SEBELUM server menjawab',
      () async {
        final c = wadah(
          MockRiwayatTersembunyiService(jeda: const Duration(milliseconds: 50)),
        );
        await c.read(historyProvider.future);

        final jalan = c.read(historyProvider.notifier).sembunyikan(2);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(tersembunyi(c, 2), isTrue);
        await jalan;
        expect(tersembunyi(c, 2), isTrue);
      },
    );
  });

  group('layar Riwayat', () {
    testWidgets('lencana status sertifikat: Terbit & Dibatalkan (dicoret)', (
      tester,
    ) async {
      await _buka(
        tester,
        _app(
          isi: const [_sesiPh, _sesiOven],
          sembunyi: MockRiwayatTersembunyiService(),
        ),
      );

      expect(find.text('Terbit'), findsOneWidget);
      expect(find.text('Dibatalkan'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);

      final nomorBatal = tester.widget<Text>(
        find.text('No. sertifikat CAL/2026/10/0102'),
      );
      expect(nomorBatal.style?.decoration, TextDecoration.lineThrough);
      final nomorBerlaku = tester.widget<Text>(
        find.text('No. sertifikat CAL/2026/10/0101'),
      );
      expect(nomorBerlaku.style?.decoration, isNot(TextDecoration.lineThrough));
    });

    testWidgets('lencana Diproses & Gagal dibuat', (tester) async {
      await _buka(
        tester,
        _app(
          isi: [
            _sesiPh.copyWith(),
            const CalibrationHistoryItem(
              id: 8,
              namaAlat: 'Neraca Analitik',
              namaTeknisi: 'Andi',
              status: CalibrationStatus.disetujui,
              nomorSertifikat: 'CAL/2026/10/0108',
              statusSertifikat: 'menunggu_generate',
            ),
            const CalibrationHistoryItem(
              id: 9,
              namaAlat: 'Hygrometer',
              namaTeknisi: 'Andi',
              status: CalibrationStatus.disetujui,
              nomorSertifikat: 'CAL/2026/10/0109',
              statusSertifikat: 'gagal',
            ),
          ],
          sembunyi: MockRiwayatTersembunyiService(),
        ),
      );

      expect(find.text('Diproses'), findsOneWidget);
      expect(find.text('Gagal dibuat'), findsOneWidget);
    });

    testWidgets('pencarian menyaring: nomor sesi, alat, pelanggan, '
        'nomor sertifikat', (tester) async {
      await _buka(
        tester,
        _app(
          isi: const [_sesiPh, _sesiOven],
          sembunyi: MockRiwayatTersembunyiService(),
        ),
      );

      final kolom = find.byType(TextField);

      Future<void> cari(String kata) async {
        await tester.enterText(kolom, kata);
        await tester.pumpAndSettle();
      }

      await cari('kal/2026/10/0002');
      expect(find.text('Oven Memmert UN55'), findsOneWidget);
      expect(find.text('pH Meter Mettler Toledo'), findsNothing);

      await cari('METTLER');
      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
      expect(find.text('Oven Memmert UN55'), findsNothing);

      await cari('uji coba');
      expect(find.text('Oven Memmert UN55'), findsOneWidget);
      expect(find.text('pH Meter Mettler Toledo'), findsNothing);

      await cari('0101');
      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
      expect(find.text('Oven Memmert UN55'), findsNothing);

      // Hasil kosong → pesan yang jelas, bukan layar kosong.
      await cari('autoclave');
      expect(
        find.text('Tidak ada riwayat yang cocok dengan "autoclave".'),
        findsOneWidget,
      );

      // Tombol hapus teks mengembalikan semuanya.
      await tester.tap(find.byTooltip('Hapus pencarian'));
      await tester.pumpAndSettle();
      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
      expect(find.text('Oven Memmert UN55'), findsOneWidget);
    });

    testWidgets('yang tersembunyi tidak tampil default, tampil saat sakelar '
        'nyala dengan penanda', (tester) async {
      await _buka(
        tester,
        _app(
          isi: const [_sesiPh, _sesiTermometer],
          sembunyi: MockRiwayatTersembunyiService(),
        ),
      );

      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
      expect(find.text('Termometer Digital Fluke'), findsNothing);

      await tester.tap(find.text('Tampilkan yang disembunyikan (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Termometer Digital Fluke'), findsOneWidget);
      expect(find.text('Disembunyikan'), findsOneWidget);
      expect(find.text('Tampilkan lagi di Riwayat'), findsOneWidget);
    });

    testWidgets('cari sesuatu yang cuma ada di baris tersembunyi → '
        'disebut, bukan seolah hilang', (tester) async {
      await _buka(
        tester,
        _app(
          isi: const [_sesiPh, _sesiTermometer],
          sembunyi: MockRiwayatTersembunyiService(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'fluke');
      await tester.pumpAndSettle();

      expect(
        find.text('1 yang cocok ada di riwayat yang disembunyikan.'),
        findsOneWidget,
      );
    });

    testWidgets('sembunyikan dari menu → baris hilang, SnackBar Urungkan '
        'mengembalikannya', (tester) async {
      final servis = MockRiwayatTersembunyiService();
      await _buka(
        tester,
        _app(isi: const [_sesiPh, _sesiOven], sembunyi: servis),
      );

      await tester.tap(find.byTooltip('Opsi lain').first);
      await tester.pumpAndSettle();

      // Teks menu wajib bilang datanya TIDAK dihapus.
      expect(find.text('Data & sertifikat tetap tersimpan'), findsOneWidget);
      await tester.tap(find.text('Sembunyikan dari Riwayat saya'));
      await tester.pumpAndSettle();

      expect(find.text('pH Meter Mettler Toledo'), findsNothing);
      expect(find.text('Oven Memmert UN55'), findsOneWidget);
      expect(servis.panggilan, [(1, true)]);
      expect(
        find.text(
          'Disembunyikan dari Riwayat kamu. Data & sertifikat tetap tersimpan.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Urungkan'));
      await tester.pumpAndSettle();

      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
      expect(servis.panggilan, [(1, true), (1, false)]);
    });

    testWidgets('server menolak (403, super admin) → pesan jelas, baris tetap '
        'tampil, tidak crash', (tester) async {
      await _buka(
        tester,
        _app(
          isi: const [_sesiPh],
          sembunyi: MockRiwayatTersembunyiService(statusGagal: 403),
        ),
      );

      await tester.tap(find.byTooltip('Opsi lain'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sembunyikan dari Riwayat saya'));
      await tester.pumpAndSettle();

      expect(
        find.text('Akun ini tidak bisa menyembunyikan riwayat.'),
        findsOneWidget,
      );
      expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semua disembunyikan → pesan + tombol tampilkan, bukan '
        'layar kosong', (tester) async {
      await _buka(
        tester,
        _app(
          isi: const [_sesiTermometer],
          sembunyi: MockRiwayatTersembunyiService(),
        ),
      );

      expect(
        find.text(
          'Semua riwayat kamu sedang disembunyikan. Datanya tetap tersimpan.',
        ),
        findsOneWidget,
      );
      // Chip di kepala + tombol di badan pesan.
      expect(find.text('Tampilkan yang disembunyikan (1)'), findsNWidgets(2));
    });
  });

  /// Kontrak 8 Okt 2026: `POST`/`DELETE /api/calibrations/{id}/sembunyikan`
  /// → `{"data": {"id": .., "tersembunyi": bool}}`.
  group('ApiRiwayatTersembunyiService', () {
    late List<http.Request> terkirim;

    ApiRiwayatTersembunyiService servis(int status, Map<String, dynamic> body) {
      terkirim = [];
      final client = MockClient((req) async {
        terkirim.add(req);
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
      });
      return ApiRiwayatTersembunyiService(
        ApiClient(client: client, baseUrl: 'https://api.contoh/api'),
      );
    }

    test('sembunyikan = POST, tampilkan lagi = DELETE, alamat sama', () async {
      final s = servis(200, {
        'data': {'id': 12, 'tersembunyi': true},
      });
      expect(await s.sembunyikan('tkn', 12), isTrue);
      expect(terkirim.single.method, 'POST');
      expect(
        terkirim.single.url.toString(),
        'https://api.contoh/api/calibrations/12/sembunyikan',
      );
      expect(terkirim.single.headers['Authorization'], 'Bearer tkn');

      final t = servis(200, {
        'data': {'id': 12, 'tersembunyi': false},
      });
      expect(await t.tampilkanLagi('tkn', 12), isFalse);
      expect(terkirim.single.method, 'DELETE');
      expect(
        terkirim.single.url.toString(),
        'https://api.contoh/api/calibrations/12/sembunyikan',
      );
    });

    test(
      '403 (super admin) & 404 dilempar sebagai ApiException ber-status',
      () async {
        await expectLater(
          servis(403, {'message': 'Tidak boleh.'}).sembunyikan('tkn', 12),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
        );
        await expectLater(
          servis(404, {'message': 'Tidak ditemukan.'}).sembunyikan('tkn', 99),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
        );
      },
    );
  });

  group('mock mode', () {
    test('MockHistoryService ikut memulangkan tersembunyi sesudah '
        'disembunyikan lewat MockRiwayatTersembunyiService', () async {
      final riwayat = MockHistoryService();
      final sembunyi = MockRiwayatTersembunyiService();

      await sembunyi.sembunyikan('t', 1);
      final sesudah = await riwayat.ambilRiwayat('t');
      expect(sesudah.firstWhere((e) => e.id == 1).tersembunyi, isTrue);

      await sembunyi.tampilkanLagi('t', 1);
      final balik = await riwayat.ambilRiwayat('t');
      expect(balik.firstWhere((e) => e.id == 1).tersembunyi, isFalse);
    });
  });
}
