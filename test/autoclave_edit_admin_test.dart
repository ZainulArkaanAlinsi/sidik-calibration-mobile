import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/autoclave_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/autoclave_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// **Edit Admin untuk Autoklaf** (`PUT /calibrations/autoclave/{id}` di `main`
/// `56668b1`): admin mengoreksi lembar `menunggu_approval` lewat PUT ke id
/// sesinya, dan koreksi angka wajib membawa `alasan_koreksi` (kontrak "Edit
/// Admin", 10-500 karakter). Angka yang tidak diubah tidak meminta alasan.
///
/// Token mock: 1 admin, 2 teknisi.
void main() {
  setUp(() => MockStore.instance.reset());

  Future<MockAutoclaveService> buka(
    WidgetTester tester, {
    String token = 'mock-token-1',
    String status = 'menunggu_approval',
  }) async {
    tester.view.physicalSize = const Size(1400, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final autoclave = MockAutoclaveService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
          authServiceProvider.overrideWithValue(MockAuthService()),
          historyServiceProvider.overrideWithValue(_Riwayat(status)),
          lembarKerjaServiceProvider.overrideWithValue(
            MockLembarKerjaService(),
          ),
          autoclaveServiceProvider.overrideWithValue(autoclave),
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LembarKerjaScreen(
                        profil: 'autoclave',
                        sesiId: 88,
                      ),
                    ),
                  ),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('buka'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    return autoclave;
  }

  Future<void> ubahSatuSel(WidgetTester tester) async {
    final sel = find.descendant(
      of: find.byKey(const Key('matriks_suhu.disk.0_1')),
      matching: find.byType(TextField),
    );
    await tester.enterText(sel, '121.9');
    await tester.pump();
  }

  Future<void> simpan(WidgetTester tester) async {
    await tester.tap(find.text('Simpan sebagai draft'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('angka diubah: alasan diminta, lalu PUT ke id sesi membawa '
      'alasan_koreksi', (tester) async {
    final autoclave = await buka(tester);

    await ubahSatuSel(tester);
    await simpan(tester);

    expect(find.byType(DialogAlasanKoreksi), findsOneWidget);
    expect(autoclave.panggilan, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('isian-alasan-koreksi')),
      'Disk 1 titik 2 salah salin, kertas asli 121,9',
    );
    await tester.tap(find.byKey(const ValueKey('simpan-alasan-koreksi')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(autoclave.panggilan, hasLength(1));
    final p = autoclave.panggilan.single;
    expect(p.metode, 'PUT');
    expect(p.id, 88);
    expect(
      p.payload['alasan_koreksi'],
      'Disk 1 titik 2 salah salin, kertas asli 121,9',
    );
  });

  testWidgets('angka TIDAK diubah: tanpa dialog dan tanpa alasan_koreksi', (
    tester,
  ) async {
    final autoclave = await buka(tester);

    await simpan(tester);

    expect(find.byType(DialogAlasanKoreksi), findsNothing);
    expect(autoclave.panggilan, hasLength(1));
    expect(autoclave.panggilan.single.metode, 'PUT');
    expect(
      autoclave.panggilan.single.payload.containsKey('alasan_koreksi'),
      isFalse,
    );
  });

  testWidgets('batal di dialog: tidak ada yang tersimpan', (tester) async {
    final autoclave = await buka(tester);

    await ubahSatuSel(tester);
    await simpan(tester);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(autoclave.panggilan, isEmpty);
  });

  testWidgets('draf: tidak diminta alasan', (tester) async {
    final autoclave = await buka(tester, status: 'draft');

    await ubahSatuSel(tester);
    await simpan(tester);

    expect(find.byType(DialogAlasanKoreksi), findsNothing);
    expect(
      autoclave.panggilan.single.payload.containsKey('alasan_koreksi'),
      isFalse,
    );
  });
}

class _Riwayat extends MockHistoryService {
  _Riwayat(this.status);

  final String status;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson({
        'id': id,
        'status': status,
        'desimal': 2,
        'equipment': {
          'id': 14,
          'nama_alat': 'Autoclave',
          'profil': 'autoclave',
          'serial_number': 'B628755900',
        },
        'teknisi': {'nama': 'Teknisi Sidik'},
        'hasil': {'keputusan': null},
        'titik': const <Map<String, dynamic>>[],
        'pembacaan_mentah': const <Map<String, dynamic>>[],
        'hasil_autoclave': {
          'set_point': 121,
          'lembar': {
            'set_point': 121,
            'waktu': ['10:00:00', '10:01:00', '10:02:00'],
            'suhu': {
              'disk': [
                [121.3, 121.4, 121.2],
              ],
            },
          },
        },
      });
}
