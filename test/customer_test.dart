import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/screens/settings/customer_list_screen.dart';
import 'package:sidik_calibration/services/customer_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

Widget _app({bool gagal = false}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      customerServiceProvider.overrideWithValue(
        MockCustomerService(gagal: gagal),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CustomerListScreen(),
    ),
  );
}

void main() {
  testWidgets('nampilin daftar pelanggan', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('PT Maju Jaya'), findsOneWidget);
    expect(find.text('CV Sentosa Abadi'), findsOneWidget);
  });

  testWidgets('gagal muat → pesan + tombol coba lagi', (tester) async {
    await tester.pumpWidget(_app(gagal: true));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat pelanggan.'), findsOneWidget);
    expect(find.text('COBA LAGI'), findsOneWidget);
  });

  testWidgets('tambah pelanggan baru → muncul di list', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('TAMBAH PELANGGAN'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'PT Baru Sekali');
    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();

    expect(find.text('PT Baru Sekali'), findsOneWidget);
  });

  testWidgets('hapus pelanggan yang masih punya alat → gagal, pesan jelas', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // PT Maju Jaya (jumlahAlat: 3) — tombol hapus pertama di list.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('masih punya alat terdaftar'),
      findsOneWidget,
    );
    expect(find.text('PT Maju Jaya'), findsOneWidget); // nggak jadi kehapus
  });
}
