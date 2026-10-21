import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Lembar kerja yang dibuka admin/super admin dari layar periksa (K-49-14).
///
/// 1. Menyimpan sesi `menunggu_approval` = MENGOREKSI angka teknisi. Server
///    mewajibkan `alasan_koreksi` (min. 10 karakter) dan menyimpan nilai lama
///    + baru + alasan. Layar meminta alasannya SEBELUM mengirim.
/// 2. Order Number di lembar kerja BACA SAJA untuk semua peran — teknisi tidak
///    pernah mengisinya; Master Data mengisinya di kartu Data administrasi.
///
/// Token mock: 1 admin · 2 teknisi · 5 super admin.
Future<MockLembarKerjaService> _buka(
  WidgetTester tester, {
  required String token,
  required Map<String, dynamic> sesi,
  String profil = 'ph_meter',
}) async {
  tester.view.physicalSize = const Size(1400, 20000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final lembar = MockLembarKerjaService();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
        authServiceProvider.overrideWithValue(MockAuthService()),
        historyServiceProvider.overrideWithValue(_Riwayat(sesi)),
        lembarKerjaServiceProvider.overrideWithValue(lembar),
        standardServiceProvider.overrideWithValue(MockStandardService()),
        roomServiceProvider.overrideWithValue(MockRoomService()),
        equipmentLookupServiceProvider.overrideWithValue(
          MockEquipmentLookupService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LembarKerjaScreen(profil: profil, sesiId: 72),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();

  return lembar;
}

Map<String, dynamic> _sesi({
  required String status,
  String profil = 'ph_meter',
  String? nomorOrder,
}) => {
  'id': 72,
  'nomor_sesi': 'KAL/2026/10/0072',
  'tanggal_kalibrasi': '2026-10-13T00:00:00.000Z',
  'status': status,
  'desimal': 2,
  'equipment': {
    'id': 14,
    'nama_alat': 'pH Meter',
    'profil': profil,
    'serial_number': 'B628755900',
  },
  'alat_serial_number': 'B628755900',
  'alat_merk': 'Mettler Toledo',
  'nomor_order': nomorOrder,
  'teknisi': {'nama': 'Teknisi Sidik'},
  'hasil': {'keputusan': null},
  'titik': const <Map<String, dynamic>>[],
  'pembacaan_mentah': const <Map<String, dynamic>>[],
};

class _Riwayat extends MockHistoryService {
  _Riwayat(this.sesi);

  final Map<String, dynamic> sesi;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(sesi);
}

/// Mengubah satu angka di tabel After adjustment (pembacaan BERUBAH dari yang
/// dipulihkan) — syarat diminta alasan koreksi.
Future<void> _ubahAngka(WidgetTester tester) async {
  final tabel = find.ancestor(
    of: find.text('After adjustment Reading').first,
    matching: find.byType(Column),
  );
  final kotak = find.descendant(
    of: tabel.first,
    matching: find.byType(TextField),
  );
  await tester.enterText(kotak.at(0), '7.04');
  await tester.pump();
}

Future<void> _simpanDraf(WidgetTester tester) async {
  await tester.tap(find.text('Simpan sebagai draft'));
  await tester.pumpAndSettle();
}

void main() {
  group('alasan koreksi untuk sesi yang sudah dikirim', () {
    for (final (nama, token) in [
      ('admin', 'mock-token-1'),
      ('super admin', 'mock-token-5'),
    ]) {
      testWidgets('$nama: diminta alasan, lalu ikut terkirim', (tester) async {
        final lembar = await _buka(
          tester,
          token: token,
          sesi: _sesi(status: 'menunggu_approval'),
        );

        await _ubahAngka(tester);
        await _simpanDraf(tester);

        // Belum ada yang terkirim — alasannya diminta dulu.
        expect(find.byType(DialogAlasanKoreksi), findsOneWidget);
        expect(lembar.jumlahKirim, 0);

        await tester.enterText(
          find.byKey(const ValueKey('isian-alasan-koreksi')),
          'Titik 2 salah ketik 7,40 dari kertas asli 7,04',
        );
        await tester.tap(find.byKey(const ValueKey('simpan-alasan-koreksi')));
        await tester.pumpAndSettle();

        expect(lembar.jumlahKirim, 1);
        expect(
          lembar.payloadTerakhir!['alasan_koreksi'],
          'Titik 2 salah ketik 7,40 dari kertas asli 7,04',
        );
      });
    }

    testWidgets('alasan < 10 karakter ditahan di dialog, tidak terkirim', (
      tester,
    ) async {
      final lembar = await _buka(
        tester,
        token: 'mock-token-1',
        sesi: _sesi(status: 'menunggu_approval'),
      );

      await _ubahAngka(tester);
      await _simpanDraf(tester);
      await tester.enterText(
        find.byKey(const ValueKey('isian-alasan-koreksi')),
        'typo',
      );
      await tester.tap(find.byKey(const ValueKey('simpan-alasan-koreksi')));
      await tester.pumpAndSettle();

      expect(find.text('Minimal 10 karakter.'), findsOneWidget);
      expect(find.byType(DialogAlasanKoreksi), findsOneWidget);
      expect(lembar.jumlahKirim, 0);
    });

    testWidgets('batal = tidak menyimpan apa pun', (tester) async {
      final lembar = await _buka(
        tester,
        token: 'mock-token-1',
        sesi: _sesi(status: 'menunggu_approval'),
      );

      await _ubahAngka(tester);
      await _simpanDraf(tester);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(lembar.jumlahKirim, 0);
    });

    testWidgets('angka TIDAK diubah: tidak diminta alasan dan tidak dikirim', (
      tester,
    ) async {
      final lembar = await _buka(
        tester,
        token: 'mock-token-1',
        sesi: _sesi(status: 'menunggu_approval'),
      );

      await _simpanDraf(tester);

      expect(find.byType(DialogAlasanKoreksi), findsNothing);
      expect(lembar.jumlahKirim, 1);
      expect(lembar.payloadTerakhir!.containsKey('alasan_koreksi'), isFalse);
    });

    testWidgets('draf / perlu revisi: TIDAK diminta alasan', (tester) async {
      for (final status in ['draft', 'perlu_revisi']) {
        final lembar = await _buka(
          tester,
          token: 'mock-token-1',
          sesi: _sesi(status: status),
        );

        await _simpanDraf(tester);

        expect(find.byType(DialogAlasanKoreksi), findsNothing, reason: status);
        expect(lembar.jumlahKirim, 1, reason: status);
        expect(
          lembar.payloadTerakhir!.containsKey('alasan_koreksi'),
          isFalse,
          reason: status,
        );

        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('Order Number di lembar kerja', () {
    testWidgets('teknisi melihatnya BACA SAJA dan nilainya tidak dikirim', (
      tester,
    ) async {
      final lembar = await _buka(
        tester,
        token: 'mock-token-2',
        profil: 'micrometer',
        sesi: _sesi(
          status: 'draft',
          profil: 'micrometer',
          nomorOrder: '2405.13.A',
        ),
      );

      final kotak = find.byKey(const ValueKey('kotak-nomor-order-baca-saja'));
      expect(kotak, findsOneWidget);

      final field = tester.widget<TextField>(kotak);
      expect(field.readOnly, isTrue);
      // Nilai yang diisi Master Data kelihatan.
      expect(field.controller!.text, '2405.13.A');
      expect(
        find.text(
          'Diisi Master Data waktu memeriksa sesi — bukan oleh teknisi.',
        ),
        findsOneWidget,
      );

      await _simpanDraf(tester);
      expect(
        lembar.payloadTerakhir?.containsKey('nomor_order') ?? false,
        isFalse,
      );
    });
  });
}
