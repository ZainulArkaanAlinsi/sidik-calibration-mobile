import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/bandingkan.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/screens/admin/bandingkan_screen.dart';
import 'package:sidik_calibration/services/bandingkan_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Layar Bandingkan (K-50-02): isian asli teknisi lawan sekarang, sel yang
/// berubah disorot beserta siapa, kapan, dan alasannya. Bentuk JSON = contoh
/// di `perintah-frontend-revisi-1510.md` §3.
const _json = {
  'data': {
    'sesi_id': 88,
    'status': 'menunggu_approval',
    'ada_asli': true,
    'jenis': 'pembacaan',
    'asli_dibekukan_pada': '2026-10-15T09:00:00+00:00',
    'total_sel': 3,
    'jumlah_berubah': 1,
    'sel': [
      {
        'kunci': 'titik_1.-.sesudah_adjustment.sensor_-.pembacaan_1',
        'asli': 50.02,
        'sekarang': 50.05,
        'berubah': true,
        'diubah_oleh': {'id': 3, 'nama': 'Admin Pemeriksa'},
        'diubah_pada': '2026-10-15T10:00:00+00:00',
        'alasan': 'Koreksi pembacaan oleh Master Data: salah salin.',
      },
      {
        'kunci': 'titik_1.-.sesudah_adjustment.sensor_-.pembacaan_2',
        'asli': 50.01,
        'sekarang': 50.01,
        'berubah': false,
      },
      {
        'kunci': 'titik_2.-.sesudah_adjustment.sensor_-.pembacaan_1',
        'asli': 60.0,
        'sekarang': 60.0,
        'berubah': false,
      },
    ],
  },
};

Widget _app(BandingkanService service) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('mock-token-1')),
    authServiceProvider.overrideWithValue(MockAuthService()),
    bandingkanServiceProvider.overrideWithValue(service),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const BandingkanScreen(calibrationId: 88),
  ),
);

Future<void> _buka(WidgetTester tester, BandingkanService service) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(service));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  group('model', () {
    test('membaca bentuk kontrak apa adanya (angka tidak dibulatkan)', () {
      final b = Bandingkan.dariJson(_json);

      expect(b.sesiId, 88);
      expect(b.adaAsli, isTrue);
      expect(b.jenis, 'pembacaan');
      expect(b.totalSel, 3);
      expect(b.jumlahBerubah, 1);
      expect(b.asliDibekukanPada, DateTime.utc(2026, 10, 15, 9));

      final sel = b.sel.first;
      expect(sel.berubah, isTrue);
      expect(sel.asli, 50.02);
      expect(sel.sekarang, 50.05);
      expect(sel.diubahOleh!.nama, 'Admin Pemeriksa');
      expect(sel.alasan, startsWith('Koreksi pembacaan'));
      // Sel yang tidak berubah tidak membawa pengubah.
      expect(b.sel[1].diubahOleh, isNull);
      expect(b.sel[1].alasan, isNull);
    });

    test('sesi lama tanpa asli & field hilang: tidak melempar', () {
      final b = Bandingkan.dariJson(const {
        'data': {'sesi_id': 5, 'ada_asli': false},
      });
      expect(b.adaAsli, isFalse);
      expect(b.sel, isEmpty);
      expect(b.jumlahBerubah, 0);
      expect(b.jenis, 'pembacaan');
    });

    test('label kunci pembacaan terbaca; kunci Autoklaf apa adanya', () {
      expect(
        BandingkanScreen.labelKunci(
          'titik_1.-.sesudah_adjustment.sensor_-.pembacaan_1',
        ),
        'Titik 1 · sesudah adjustment · pembacaan 1',
      );
      expect(
        BandingkanScreen.labelKunci(
          'titik_3.uut.sebelum_adjustment.sensor_2.pembacaan_4',
        ),
        'Titik 3 · uut · sebelum adjustment · sensor 2 · pembacaan 4',
      );
      expect(
        BandingkanScreen.labelKunci('lembar.suhu.disk.0.0'),
        'lembar.suhu.disk.0.0',
      );
    });
  });

  group('layar', () {
    testWidgets('sel yang berubah disorot dengan pengubah, waktu, alasan', (
      tester,
    ) async {
      await _buka(
        tester,
        MockBandingkanService(hasil: Bandingkan.dariJson(_json)),
      );

      expect(find.text('1 dari 3 isian berubah'), findsOneWidget);
      expect(find.textContaining('Isian asli dibekukan'), findsOneWidget);

      final kartu = find.byKey(
        const ValueKey('sel-titik_1.-.sesudah_adjustment.sensor_-.pembacaan_1'),
      );
      expect(kartu, findsOneWidget);
      expect(
        find.descendant(of: kartu, matching: find.text('50,02')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: kartu, matching: find.text('50,05')),
        findsOneWidget,
      );
      expect(find.textContaining('Diubah oleh Admin Pemeriksa'), findsOneWidget);
      expect(
        find.text('Alasan: Koreksi pembacaan oleh Master Data: salah salin.'),
        findsOneWidget,
      );
      // Yang tidak berubah dilipat, tidak ikut disorot.
      expect(
        find.byKey(const ValueKey('bandingkan-tidak-berubah')),
        findsOneWidget,
      );
      expect(find.text('2 isian tidak berubah'), findsOneWidget);
    });

    testWidgets('ada_asli=false: pesan jelas, bukan daftar kosong', (
      tester,
    ) async {
      await _buka(tester, MockBandingkanService());

      expect(
        find.byKey(const ValueKey('bandingkan-tanpa-asli')),
        findsOneWidget,
      );
      expect(
        find.text('Lembar ini belum pernah dikoreksi — belum ada yang berubah.'),
        findsOneWidget,
      );
    });

    testWidgets('gagal dimuat: pesan + coba lagi', (tester) async {
      await _buka(tester, MockBandingkanService(gagal: true));

      expect(find.text('Perbandingan gagal dimuat.'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });
}
