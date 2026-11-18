import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/pindai/banner_jenis_dari_foto.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// Lembar BARU yang dibuka lewat "Mulai kalibrasi" (jalur manual): TIDAK ada
/// dialog "Mau diisi bagaimana?" (keputusan pemilik 18 Nov 2026: foto lembar
/// hanya punya SATU pintu, dan pilihan cara isi yang muncul sendiri
/// membingungkan). Yang tersisa di layar ini hanya SATU tombol foto kecil, dan
/// hanya untuk formulir yang boleh dipindai (siap_pindai atau mode uji).
void main() {
  WorksheetTemplate asli({Map<String, dynamic> ubah = const {}}) {
    final data =
        (jsonDecode(
              File(
                'test/assets/template-asli-ph_meter-0509.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>);

    return WorksheetTemplate.fromJson({
      'data': {...(data['data'] as Map<String, dynamic>), ...ubah},
    });
  }

  Widget app(WorksheetTemplate? formulir) => ProviderScope(
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
      worksheetScanServiceProvider.overrideWithValue(
        MockWorksheetScanService(formulirAsli: formulir),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LembarKerjaScreen(),
    ),
  );

  Future<void> muat(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('formulir siap/mode uji: TIDAK ada dialog pilihan cara isi; '
      'tepat SATU tombol foto di layar', (tester) async {
    await muat(tester, app(asli()));

    // Dialog lama ("Mau diisi bagaimana?" + Ketik manual | Foto worksheet)
    // tidak pernah muncul sendiri.
    expect(find.text('Mau diisi bagaimana?'), findsNothing);
    expect(find.byKey(const ValueKey('cara-manual')), findsNothing);
    expect(find.byKey(const ValueKey('cara-foto')), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);

    // Satu-satunya pintu foto di layar ini (tegas: tidak ada pintu kedua).
    expect(find.byKey(const ValueKey('tombol-foto-lembar')), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.text('Foto worksheet'), findsOneWidget);
    // Lembar manual tidak membawa banner "dikenali dari foto".
    expect(find.byKey(BannerJenisDariFoto.kunciBanner), findsNothing);
    // Pintu per tabel ("Foto tabel ini", jalur ML Kit lama) tersembunyi
    // bawaan, jadi tidak menggandakan pintu foto.
    expect(find.text('FOTO TABEL INI'), findsNothing);
    expect(find.text('Foto tabel ini'), findsNothing);
  });

  testWidgets('foto tanpa alat dipilih: diminta pilih alat dulu', (
    tester,
  ) async {
    await muat(tester, app(asli()));

    await tester.tap(find.byKey(const ValueKey('tombol-foto-lembar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pilih alatnya dulu'), findsOneWidget);
  });

  testWidgets('formulir belum siap (bukan mode uji) atau tak dipetakan: '
      'tidak ada pintu foto', (tester) async {
    await muat(tester, app(asli(ubah: {'mode_uji': false})));
    expect(find.byKey(const ValueKey('cara-foto')), findsNothing);
    expect(find.byKey(const ValueKey('tombol-foto-lembar')), findsNothing);

    await muat(tester, app(null));
    expect(find.byKey(const ValueKey('cara-foto')), findsNothing);
    expect(find.byKey(const ValueKey('tombol-foto-lembar')), findsNothing);
  });
}
