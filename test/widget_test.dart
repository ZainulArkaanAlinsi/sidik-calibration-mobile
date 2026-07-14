import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/app.dart';
import 'package:asmo_mobile/core/config/app_config.dart';
import 'package:asmo_mobile/providers/app_config_provider.dart';

void main() {
  testWidgets('app ke-build dan nampilin identitas ASMO', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AsmoApp()));

    expect(find.text('ASMO Mobile'), findsOneWidget);
    expect(find.text('Kalibrasi alat ukur & sertifikat digital'), findsOneWidget);
  });

  testWidgets('Riverpod ke-wire: provider config kebaca dari widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiBaseUrlProvider.overrideWithValue('http://localhost:9000/api'),
        ],
        child: const AsmoApp(),
      ),
    );

    expect(find.text('http://localhost:9000/api'), findsOneWidget);
  });

  test('AppConfig default ke environment dev', () {
    expect(AppConfig.env, AppEnv.dev);
    expect(AppConfig.envLabel, 'DEV');
    expect(AppConfig.isProd, isFalse);
  });
}
