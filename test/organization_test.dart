import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/screens/settings/organization_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/organization_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

Widget _app({bool gagal = false}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      organizationServiceProvider.overrideWithValue(
        MockOrganizationService(gagal: gagal),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OrganizationScreen(),
    ),
  );
}

/// Form-nya lebih panjang dari viewport test standar (800x600) sejak field
/// akreditasi ditambah — `ListView` cuma nge-build item yang deket viewport,
/// jadi tombol SIMPAN di paling bawah nggak ke-tap kalau viewport-nya kecil
/// (sama kasusnya kayak `ph_calibration_input_test.dart`).
void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('nampilin data organisasi & bisa disimpan', (tester) async {
    _perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.text('PT Sistem Dirgantara Inovasi Teknologi (PT Sidik)'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'PT Sidik Baru');
    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();

    expect(find.text('Data organisasi disimpan.'), findsOneWidget);
  });

  testWidgets('gagal muat → pesan + tombol coba lagi', (tester) async {
    await tester.pumpWidget(_app(gagal: true));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat data organisasi.'), findsOneWidget);
    expect(find.text('COBA LAGI'), findsOneWidget);
  });
}
