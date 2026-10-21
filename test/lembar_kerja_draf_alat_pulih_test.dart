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

/// **Draft yang dibuka lagi membawa alatnya kembali.**
///
/// Ketahuan uji E2E app lapangan 13 Okt 2026 (server lokal, sesi
/// `KAL/2026/10/0001`): draft pH Meter `B628755900` disimpan dengan
/// `equipment_id` 7, tapi waktu dibuka lagi dari layar Draf, "Pilih alat"
/// kosong dan simpan ditahan "Pilih alatnya dulu". `IsianTeknisi.equipmentId`
/// sudah diurai dari respons `GET /calibrations/{id}` sejak Juli, tapi tidak
/// pernah dipasang ke formulir.
///
/// Respons tiruan mengikuti bentuk `GET /calibrations/{id}` server (kunci
/// `equipment.id`, `alat_model`, …). Alat id 14 = `daftarAlatMock` (worksheet
/// 012-CAL-524).
void main() {
  Future<MockLembarKerjaService> buka(
    WidgetTester tester,
    Map<String, dynamic> sesi,
  ) async {
    tester.view.physicalSize = const Size(1400, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final lembar = MockLembarKerjaService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
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
          home: const LembarKerjaScreen(profil: 'ph_meter', sesiId: 72),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    return lembar;
  }

  const alatMock = 'pH Meter Mettler Toledo · B628755900';
  final belumPilih = find.textContaining('Pilih alatnya dulu');

  testWidgets('alat sesi kembali terpilih dan ikut tersimpan', (tester) async {
    final lembar = await buka(tester, _sesi(equipmentId: 14));

    expect(find.text(alatMock), findsWidgets);

    await tester.tap(find.text('Simpan sebagai draft'));
    await tester.pumpAndSettle();

    expect(belumPilih, findsNothing);
    expect(lembar.jumlahKirim, 1);
    expect(lembar.payloadTerakhir!['equipment_id'], 14);
  });

  testWidgets('identitas yang tersimpan di sesi TIDAK ditimpa data master', (
    tester,
  ) async {
    // Master: model `Five Easy`. Teknisi membetulkannya di draft.
    final lembar = await buka(
      tester,
      _sesi(equipmentId: 14, alatModel: 'Five Easy Plus FP20'),
    );

    await tester.tap(find.text('Simpan sebagai draft'));
    await tester.pumpAndSettle();

    expect(lembar.payloadTerakhir!['alat_model'], 'Five Easy Plus FP20');
  });

  testWidgets('alat yang tidak ada lagi di daftar: perilaku lama — pilih '
      'sendiri', (tester) async {
    final lembar = await buka(tester, _sesi(equipmentId: 999));

    expect(find.text(alatMock), findsNothing);

    await tester.tap(find.text('Simpan sebagai draft'));
    await tester.pumpAndSettle();

    expect(belumPilih, findsOneWidget);
    expect(lembar.jumlahKirim, 0);
  });
}

Map<String, dynamic> _sesi({required int equipmentId, String? alatModel}) => {
  'id': 72,
  'nomor_sesi': 'KAL/2026/10/0001',
  'tanggal_kalibrasi': '2026-10-13T00:00:00.000Z',
  'status': 'draft',
  'desimal': 2,
  'equipment': {
    'id': equipmentId,
    'nama_alat': 'pH Meter',
    'profil': 'ph_meter',
    'serial_number': 'B628755900',
  },
  'alat_model': ?alatModel,
  'alat_serial_number': 'B628755900',
  'alat_merk': 'Mettler Toledo',
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
