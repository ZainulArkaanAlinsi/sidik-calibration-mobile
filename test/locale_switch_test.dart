import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/app.dart';
import 'package:asmo_mobile/providers/auth_provider.dart';
import 'package:asmo_mobile/providers/dashboard_provider.dart';
import 'package:asmo_mobile/services/dashboard_service.dart';
import 'package:asmo_mobile/services/mock_auth_service.dart';
import 'package:asmo_mobile/services/token_storage.dart';

/// Nguji dwibahasa: default ID, dan toggle bener-bener ganti teks ke EN.
void main() {
  testWidgets('toggle bahasa: default ID → tap → semua teks auth jadi EN', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authServiceProvider.overrideWithValue(MockAuthService()),
          dashboardServiceProvider.overrideWithValue(
            MockDashboardService(jeda: Duration.zero),
          ),
        ],
        child: const AsmoApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Default = Indonesia.
    expect(find.text('MASUK'), findsOneWidget);
    expect(find.text('Belum punya akun?'), findsOneWidget);
    expect(find.text('ID'), findsOneWidget, reason: 'toggle nampilin bahasa aktif');

    // Ganti bahasa.
    await tester.tap(find.text('ID'));
    await tester.pumpAndSettle();

    // Sekarang Inggris — teks auth ikut ganti.
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('MASUK'), findsNothing);
    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
  });
}
