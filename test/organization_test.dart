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

void main() {
  testWidgets('nampilin data organisasi & bisa disimpan', (tester) async {
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
