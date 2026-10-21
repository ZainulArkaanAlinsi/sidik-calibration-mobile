import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/kalibrasi_teknisi_provider.dart';
import 'package:sidik_calibration/screens/teknisi/kalibrasi_teknisi_screen.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/kalibrasi_teknisi_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Tab "Kalibrasi" teknisi (K-50-14): Mulai, Perlu revisi (hanya sesi LAMA —
/// jalur Tolak dicabut), Draf, Terkirim. Tidak ada dashboard/alat/riwayat.
CalibrationHistoryItem _sesi(
  int id,
  String alat,
  CalibrationStatus status, {
  String? catatan,
}) => CalibrationHistoryItem(
  id: id,
  namaAlat: alat,
  namaTeknisi: 'Teknisi Sidik',
  tanggalKalibrasi: DateTime(2026, 10, 14),
  status: status,
  catatanRevisi: catatan,
);

class _Draf extends MockHistoryService {
  _Draf(this.draf);

  final List<CalibrationHistoryItem> draf;

  @override
  Future<List<CalibrationHistoryItem>> ambilDraf(String token) async => draf;
}

Widget _app(
  List<CalibrationHistoryItem> sesi, {
  List<CalibrationHistoryItem> draf = const [],
  bool gagal = false,
}) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('mock-token-2')),
    authServiceProvider.overrideWithValue(MockAuthService()),
    historyServiceProvider.overrideWithValue(_Draf(draf)),
    kalibrasiTeknisiServiceProvider.overrideWithValue(
      MockKalibrasiTeknisiService(sesi: sesi, gagal: gagal),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const KalibrasiTeknisiScreen(),
  ),
);

Future<void> _buka(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tanpa sesi lama: Mulai, Draf, Terkirim — Perlu revisi tidak '
      'dipajang', (tester) async {
    await _buka(
      tester,
      _app([_sesi(1, 'pH Meter', CalibrationStatus.menungguApproval)]),
    );

    expect(find.byKey(const ValueKey('tombol-mulai-kalibrasi')), findsOneWidget);
    expect(find.byKey(const ValueKey('bagian-perlu-revisi')), findsNothing);
    expect(find.byKey(const ValueKey('bagian-draf')), findsOneWidget);
    expect(find.byKey(const ValueKey('bagian-terkirim')), findsOneWidget);
    expect(find.text('pH Meter'), findsOneWidget);
    // Terkirim = baca saja: kartunya tidak membuka lembar.
    expect(find.text('Belum ada draf.'), findsOneWidget);
  });

  testWidgets('sesi lama perlu_revisi tampil lengkap dengan catatannya', (
    tester,
  ) async {
    await _buka(
      tester,
      _app([
        _sesi(
          7,
          'Turbidimeter',
          CalibrationStatus.perluRevisi,
          catatan: 'Ulangi titik 3, bacaan 2 meleset.',
        ),
      ]),
    );

    expect(find.byKey(const ValueKey('bagian-perlu-revisi')), findsOneWidget);
    expect(find.text('Ulangi titik 3, bacaan 2 meleset.'), findsOneWidget);
    expect(find.byKey(const ValueKey('kartu-sesi-teknisi-7')), findsOneWidget);
  });

  testWidgets('draf tampil di bagian Draf dan bisa dibuka', (tester) async {
    await _buka(
      tester,
      _app(const [], draf: [_sesi(9, 'Thermometer', CalibrationStatus.draft)]),
    );

    expect(find.byKey(const ValueKey('kartu-sesi-teknisi-9')), findsOneWidget);
    expect(find.text('Thermometer'), findsOneWidget);
  });

  testWidgets('daftar gagal dimuat: bagian itu sendiri yang menampilkan '
      'galat + coba lagi, tombol Mulai tetap ada', (tester) async {
    await _buka(tester, _app(const [], gagal: true));

    expect(find.text('Daftar ini gagal dimuat.'), findsWidgets);
    expect(find.byKey(const ValueKey('tombol-mulai-kalibrasi')), findsOneWidget);
  });
}
