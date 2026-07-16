import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/app.dart';
import 'package:asmo_mobile/providers/auth_provider.dart';
import 'package:asmo_mobile/services/mock_auth_service.dart';
import 'package:asmo_mobile/services/token_storage.dart';

ProviderScope _app() => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
    authServiceProvider.overrideWithValue(MockAuthService()),
  ],
  child: const SidikApp(),
);

Future<void> _tapTeks(WidgetTester tester, String teks) async {
  final finder = find.text(teks);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Dari Login → tap "Lupa Password?" → mendarat di layar reset.
Future<void> _bukaLupaPassword(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();

  await _tapTeks(tester, 'Lupa Password?');
  await tester.pumpAndSettle();
}

Future<void> _kirim(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextField).first, email);
  await _tapTeks(tester, 'KIRIM LINK RESET');
  await tester.pumpAndSettle();
}

void main() {
  group('reset password — 3 state', () {
    testWidgets('NORMAL: link di Login beneran buka layar reset', (
      tester,
    ) async {
      await _bukaLupaPassword(tester);

      expect(find.text('Lupa Password'), findsOneWidget);
      expect(find.text('KIRIM LINK RESET'), findsOneWidget);
    });

    testWidgets('SUKSES: email terdaftar → panel "link terkirim"', (
      tester,
    ) async {
      await _bukaLupaPassword(tester);
      await _kirim(tester, 'admin@pt-sidik.com');

      expect(find.text('Link reset terkirim'), findsOneWidget);
      // Emailnya disebut ulang, biar user sadar kalau salah ketik.
      expect(find.textContaining('admin@pt-sidik.com'), findsOneWidget);
      // Form-nya udah nggak ada — nggak bisa kirim dua kali nggak sengaja.
      expect(find.text('KIRIM LINK RESET'), findsNothing);
    });

    testWidgets('ERROR: email nggak terdaftar → pesan jelas, tetap di form', (
      tester,
    ) async {
      await _bukaLupaPassword(tester);
      await _kirim(tester, 'bukan.siapa2@pt-sidik.com');

      expect(find.text('Email ini nggak terdaftar.'), findsOneWidget);
      expect(find.text('Link reset terkirim'), findsNothing);
      // Form tetap ada, user bisa langsung benerin emailnya.
      expect(find.text('KIRIM LINK RESET'), findsOneWidget);
    });
  });

  group('validasi lokal', () {
    testWidgets('email kosong → nggak nembak server', (tester) async {
      await _bukaLupaPassword(tester);
      await _tapTeks(tester, 'KIRIM LINK RESET');
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi.'), findsOneWidget);
    });

    testWidgets('format email ngawur → ditolak duluan', (tester) async {
      await _bukaLupaPassword(tester);
      await _kirim(tester, 'bukan-email');

      expect(find.text('Format email nggak valid.'), findsOneWidget);
    });
  });

  testWidgets('dari panel sukses → balik ke Login', (tester) async {
    await _bukaLupaPassword(tester);
    await _kirim(tester, 'teknisi@pt-sidik.com');

    await _tapTeks(tester, 'BALIK KE LOGIN');
    await tester.pumpAndSettle();

    expect(find.text('MASUK'), findsOneWidget);
  });
}
