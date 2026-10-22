import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/draf_lokal_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/auth/login_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/pengatur_titik_sesi.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';
import 'package:sidik_calibration/widgets/sidik/sidik_tombol.dart';

import 'support/lewati_onboarding.dart';
import 'support/simpanan_tiruan.dart';
import 'package:sidik_calibration/services/draf_lokal.dart';

/// HP murah: layar 320 dp + huruf diperbesar pemiliknya. Aplikasi menjepit
/// skala huruf ke 1,3× (`batasSkalaHuruf` di app.dart); layar kunci harus tetap
/// tanpa luapan (overflow) di batas itu.
void main() {
  pasangSimpananTiruan();

  void layarSempit(WidgetTester tester, {double tinggi = 640}) {
    tester.view.physicalSize = Size(320, tinggi);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Skala 1,3 dipasang langsung (layar yang diuji tanpa `SidikApp`).
  Widget skala13(Widget anak) => MediaQuery.withClampedTextScaling(
    minScaleFactor: batasSkalaHuruf.max,
    maxScaleFactor: batasSkalaHuruf.max,
    child: anak,
  );

  testWidgets('SidikApp menjepit skala huruf HP (2,0×) ke 1,3×', (
    tester,
  ) async {
    layarSempit(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lewatiOnboarding,
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authServiceProvider.overrideWithValue(MockAuthService()),
          simpananDrafLokalProvider.overrideWithValue(
            SimpananDrafLokalMemori(),
          ),
        ],
        child: const SidikApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    final konteks = tester.element(find.byType(LoginScreen));
    expect(MediaQuery.textScalerOf(konteks).scale(10), closeTo(13, 1e-9));
    expect(tester.takeException(), isNull, reason: 'login tanpa overflow');
  });

  testWidgets('tombol bertinggi minimum — label 1,3× tidak terpotong', (
    tester,
  ) async {
    layarSempit(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: skala13(
          Scaffold(
            body: Center(
              child: SidikTombol(
                label: 'Simpan & kirim ke admin sekarang juga',
                penuh: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(SidikTombol)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('lembar kerja pH di 320 dp + 1,3× tanpa overflow', (
    tester,
  ) async {
    layarSempit(tester, tinggi: 4000);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pindaiLembarAktifProvider.overrideWithValue(false),
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          lembarKerjaServiceProvider.overrideWithValue(
            MockLembarKerjaService(),
          ),
          standardServiceProvider.overrideWithValue(MockStandardService()),
          roomServiceProvider.overrideWithValue(MockRoomService()),
          equipmentLookupServiceProvider.overrideWithValue(
            MockEquipmentLookupService(),
          ),
          worksheetScanServiceProvider.overrideWithValue(
            MockWorksheetScanService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => skala13(child!),
          home: const LembarKerjaScreen(profil: 'ph_meter'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byType(LembarKerjaScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('dialog pengatur titik sesi di 320 dp + 1,3×', () {
    LembarKerjaState isianTimer() {
      final m =
          jsonDecode(
                File(
                  'test/fixtures/lembar-kerja-timer_stopwatch.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      const nominal = [60, 300, 600, 900, 1800, 2400, 3600, 120, 180];
      m['batas_titik'] = {
        'didukung': true,
        'tabel': [
          {
            'kode': 'utama',
            'judul': 'Set point',
            'min': 1,
            'maks': 10,
            'boleh_tambah': true,
            'boleh_nonaktif': true,
            'nominal': 'saran',
            'bawaan': nominal,
            'fase': ['sesudah'],
            'satuan': 's',
            'pengulangan': {'min': 2, 'maks': 10, 'bawaan': 3},
          },
        ],
      };
      m['titik_sesi_bawaan'] = [
        for (var i = 0; i < nominal.length; i++)
          {
            'id': 'profil-utama-${i + 1}',
            'tabel': 'utama',
            'nominal': nominal[i],
            'satuan': 's',
            'fase': ['sesudah'],
            'aktif': true,
            'asal': 'profil',
            'alasan': null,
            'justifikasi_cmc': null,
            'tambahan': false,
          },
      ];
      return LembarKerjaState(
          bentuk: LembarKerja.fromJson(m),
          clientRequestId: 'uji-skala-huruf',
        )
        ..alat = const EquipmentLookup(
          id: 7,
          namaAlat: 'Stopwatch Uji',
          serialNumber: 'SW-1',
          kategori: 'waktu',
          status: 'aktif',
          satuan: 's',
          rangeMax: 3600,
        );
    }

    Future<LembarKerjaState> pasang(WidgetTester tester) async {
      layarSempit(tester);
      final isian = isianTimer();
      final tabel = isian.titikSesi.batas!.tabel.single;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => skala13(child!),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => PengaturTitikSesi(
                  isian: isian,
                  tabel: tabel,
                  onBerubah: () => setState(() {}),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'pengatur titik');
      return isian;
    }

    testWidgets('dialog tambah titik', (tester) async {
      await pasang(tester);
      final tambah = find.byKey(const ValueKey('titik-sesi-tambah'));
      await tester.ensureVisible(tambah);
      await tester.tap(tambah);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('titik-sesi-nominal')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dialog alasan nonaktif', (tester) async {
      final isian = await pasang(tester);
      final id = isian.titikSesi.titikDenganNominal(300)!.id;
      final menu = find.byKey(ValueKey('titik-sesi-menu-$id'));
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nonaktifkan').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('titik-sesi-alasan')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
