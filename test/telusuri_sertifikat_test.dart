import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/revisi_sertifikat.dart';
import 'package:sidik_calibration/models/telusuri_sertifikat.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/pengendalian_provider.dart';
import 'package:sidik_calibration/screens/pelacakan/telusuri_sertifikat_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pelacakan_service.dart';
import 'package:sidik_calibration/services/telusuri_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

class _Spy implements TelusuriService {
  final kata = <String>[];

  @override
  Future<List<TelusuriSertifikat>> cari(String token, String q) async {
    kata.add(q);
    if (q == 'kosong') return const [];
    return const [
      TelusuriSertifikat(
        id: 9,
        nomor: '012-CAL-524-R1',
        perusahaan: 'PT Tirta',
        alat: 'Timbangan',
        serialNumber: 'C33',
        statusDokumen: StatusDokumen.berlaku,
        revisiKe: 1,
        tahapPaket: 'dikalibrasi',
        pdfUrl: 'https://x/pdf',
      ),
      // Placeholder: punya id tetapi belum terbit -> tanpa PDF, bukan "Terbit".
      TelusuriSertifikat(
        id: 10,
        nomor: '013-CAL-524',
        perusahaan: 'PT Tirta',
        status: 'gagal',
        statusDokumen: StatusDokumen.belumTerbit,
      ),
    ];
  }
}

Future<_Spy> _buka(WidgetTester tester) async {
  final spy = _Spy();
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(
          MockAuthService(jeda: Duration.zero),
        ),
        telusuriServiceProvider.overrideWithValue(spy),
        pelacakanServiceProvider.overrideWithValue(MockPelacakanService()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TelusuriSertifikatScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return spy;
}

void main() {
  testWidgets('debounce 300 ms, min 2 huruf, satu panggilan server', (
    tester,
  ) async {
    final spy = await _buka(tester);
    expect(find.text('Telusuri No. Sertifikat'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump(const Duration(milliseconds: 400));
    expect(spy.kata, isEmpty);

    await tester.enterText(find.byType(TextField), '01');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '012');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(spy.kata, ['012']);
    expect(find.text('012-CAL-524-R1'), findsOneWidget);
    expect(find.text('Terbit · R1'), findsOneWidget);
    expect(find.text('Tahap paket: Dikalibrasi'), findsOneWidget);
    expect(find.text('Buka PDF'), findsOneWidget);
    // Baris placeholder: "Belum terbit", tanpa tombol PDF kedua.
    expect(find.text('Belum terbit'), findsOneWidget);
  });

  testWidgets('hasil kosong menampilkan pesan, bukan error', (tester) async {
    await _buka(tester);
    await tester.enterText(find.byType(TextField), 'kosong');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada sertifikat dengan nomor itu.'), findsOneWidget);
  });

  testWidgets('Lihat paket membuka tampilan tahap paket', (tester) async {
    await _buka(tester);
    await tester.enterText(find.byType(TextField), '012');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat paket'));
    await tester.pumpAndSettle();
    expect(find.text('Pelacakan paket'), findsOneWidget);
    expect(find.text('ORD/2026/09/0034'), findsOneWidget);
  });
}
