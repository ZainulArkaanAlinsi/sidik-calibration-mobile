import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Draft Viscometer yang dibuka lagi harus NAMPILIN Spindle & Model yang udah
/// kepilih, bukan kotak kosong.
///
/// Nilainya masuk lewat `muatDariSesi`, dan itu jalan SESUDAH formulir kegambar
/// sekali — detail sesinya ditarik dari jaringan di `initState`. Jadi yang
/// dijaga di sini urutannya: nilai yang mendarat BELAKANGAN tetap kelihatan di
/// dropdown, bukan cuma nyangkut di controller dan diam-diam ikut kekirim.
///
/// Yang bikin ini jalan `_DropdownButtonFormFieldState.didUpdateWidget`, yang
/// manggil `setValue` tiap `initialValue` berubah — bukan `FormField` bawaan,
/// yang emang nggak nyinkronin apa-apa. Bedanya halus dan gampang kebalik
/// waktu dropdown-nya ditulis ulang atau diganti widget lain, dan salahnya
/// nggak keluar sebagai error: teknisi cuma lihat lembar yang dia simpan
/// kemarin balik dengan Spindle ilang.
class _RiwayatDenganSpesifikasi extends MockHistoryService {
  _RiwayatDenganSpesifikasi(this.spesifikasi);

  final Map<String, String> spesifikasi;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    // Jeda SENGAJA: yang diuji di sini urutannya, bukan isinya. Detail sesi
    // datang dari jaringan, jadi dia mendarat sesudah formulir kegambar sekali
    // — persis keadaan yang bikin dropdown-nya nyangkut kosong.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    return CalibrationDetail(
      id: id,
      namaAlat: 'Viscometer',
      namaTeknisi: 'Joko',
      tanggalKalibrasi: DateTime(2026, 8, 19),
      status: CalibrationStatus.draft,
      isianTeknisi: IsianTeknisi(spesifikasiAlat: spesifikasi),
    );
  }
}

Widget _app(HistoryService riwayat) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-1'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService()),
    lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
    standardServiceProvider.overrideWithValue(MockStandardService()),
    roomServiceProvider.overrideWithValue(MockRoomService()),
    equipmentLookupServiceProvider.overrideWithValue(
      MockEquipmentLookupService(),
    ),
    historyServiceProvider.overrideWithValue(riwayat),
    worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const LembarKerjaScreen(profil: 'viscometer', sesiId: 7),
  ),
);

void main() {
  /// Lembar Viscometer panjang — seluruh formulir dibikin ke-build sekaligus
  /// biar dropdown-nya kejangkau tanpa scroll.
  void perbesarViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Spindle & Model dari draft kelihatan di dropdown-nya', (
    tester,
  ) async {
    perbesarViewport(tester);

    await tester.pumpWidget(
      _app(
        _RiwayatDenganSpesifikasi(const {
          'model_viscometer': 'DV2THA',
          'spindle_titik_1': 'HA7',
        }),
      ),
    );
    // `MockAuthService.me()` jeda 600 ms lewat `Future.delayed`, dan timer
    // kayak gitu nggak ngejadwalin frame — `pumpAndSettle` doang balik duluan.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    // Sesudah detail sesinya mendarat — bukan sebelum.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Labelnya, bukan nilai mentahnya: yang teknisi baca di kotak itu
    // `HA7 (SMC 400)`, dan itu yang hilang waktu dropdown-nya nggak sinkron.
    expect(find.text('HA7 (SMC 400)'), findsOneWidget);
    expect(find.text('DV2THA / HA (TK 2)'), findsOneWidget);
  });

  testWidgets('sesi tanpa spesifikasi tetap ngasih dropdown kosong', (
    tester,
  ) async {
    perbesarViewport(tester);

    await tester.pumpWidget(_app(_RiwayatDenganSpesifikasi(const {})));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    // Sesudah detail sesinya mendarat — bukan sebelum.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('HA7 (SMC 400)'), findsNothing);
    expect(find.text('DV2THA / HA (TK 2)'), findsNothing);
  });
}
