import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/app.dart';
import 'package:asmo_mobile/models/user.dart';
import 'package:asmo_mobile/providers/auth_provider.dart';
import 'package:asmo_mobile/services/token_storage.dart';

/// Storage in-memory, biar test nggak nyentuh Keystore HP.
ProviderScope _app(TokenStorage storage) => ProviderScope(
  overrides: [tokenStorageProvider.overrideWithValue(storage)],
  child: const AsmoApp(),
);

Future<void> _isiForm(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.byType(TextField).first, email);
  await tester.enterText(find.byType(TextField).last, password);
  await tester.tap(find.text('Masuk'));
}

/// Niru Keystore yang rusak — `flutter_secure_storage` bisa lempar
/// PlatformException, bukan AuthException.
class _BrokenTokenStorage implements TokenStorage {
  @override
  Future<String?> read() async => throw Exception('keystore rusak');

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  group('alur login (pakai MockAuthService)', () {
    testWidgets('belum ada token → mendarat di layar Login', (tester) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage()));
      await tester.pumpAndSettle();

      expect(find.text('Masuk'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('kredensial benar → masuk app & token tersimpan', (
      tester,
    ) async {
      final storage = InMemoryTokenStorage();
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      await _isiForm(
        tester,
        email: 'admin@asmo.test',
        password: 'password123',
      );
      await tester.pump(); // state loading

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      // Sukses = bottom nav muncul, layar login ilang.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(await storage.read(), isNotNull, reason: 'token wajib disimpan');
    });

    testWidgets('password salah → error kredensial, tetap di layar Login', (
      tester,
    ) async {
      final storage = InMemoryTokenStorage();
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      await _isiForm(tester, email: 'admin@asmo.test', password: 'ngasal');
      await tester.pumpAndSettle();

      expect(find.text('Email atau password salah.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        await storage.read(),
        isNull,
        reason: 'login gagal nggak boleh nyimpen token',
      );
    });

    testWidgets('login gagal → email yang udah diketik NGGAK ilang', (
      tester,
    ) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage()));
      await tester.pumpAndSettle();

      await _isiForm(tester, email: 'admin@asmo.test', password: 'ngasal');
      await tester.pumpAndSettle();

      // User harus bisa langsung benerin password-nya doang, bukan ngetik
      // ulang email dari nol.
      expect(find.text('admin@asmo.test'), findsOneWidget);
    });

    testWidgets('lagi login → tetap di layar Login (nggak loncat ke splash)', (
      tester,
    ) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage()));
      await tester.pumpAndSettle();

      await _isiForm(
        tester,
        email: 'admin@asmo.test',
        password: 'password123',
      );
      await tester.pump(); // lagi loading

      // Tombol "Masuk" ilang = layar Login ke-unmount = form ke-reset.
      expect(
        find.byType(TextField),
        findsWidgets,
        reason: 'form harus tetap ada selama proses login',
      );

      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('field kosong → divalidasi lokal, nggak nembak server', (
      tester,
    ) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi.'), findsOneWidget);
      expect(find.text('Password wajib diisi.'), findsOneWidget);
    });

    testWidgets('token tersimpan → app kebuka langsung masuk, nggak login lagi', (
      tester,
    ) async {
      // 'mock-token-1' = admin, sesuai MockAuthService.
      await tester.pumpWidget(_app(InMemoryTokenStorage('mock-token-1')));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Masuk'), findsNothing);
    });

    testWidgets('token basi → dibuang, user balik ke Login (bukan crash)', (
      tester,
    ) async {
      final storage = InMemoryTokenStorage('token-kadaluarsa');
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      expect(find.text('Masuk'), findsOneWidget);
      expect(await storage.read(), isNull, reason: 'token basi harus dibuang');
    });

    testWidgets('logout → token dihapus & balik ke Login', (tester) async {
      final storage = InMemoryTokenStorage('mock-token-1');
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      // Tombol Keluar ada di bawah — scroll dulu, persis kayak user beneran.
      await tester.scrollUntilVisible(find.text('Keluar'), 200);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(find.text('Masuk'), findsOneWidget);
      expect(await storage.read(), isNull);
    });
  });

  testWidgets('logout dari tab Profil → login lagi mendarat di Dashboard', (
    tester,
  ) async {
    final storage = InMemoryTokenStorage('mock-token-1');
    await tester.pumpWidget(_app(storage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Keluar'), 200);
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    await _isiForm(tester, email: 'teknisi@asmo.test', password: 'password123');
    await tester.pumpAndSettle();

    // User baru harus mulai dari Dashboard, bukan nyangkut di tab Profil
    // punya sesi sebelumnya.
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
  });

  testWidgets('secure storage error → app tetap kebuka di Login, bukan crash', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_BrokenTokenStorage()));
    await tester.pumpAndSettle();

    // Keystore bisa rusak (mis. habis install ulang app). Kalau ini bikin
    // app crash pas dibuka, user nggak punya jalan keluar sama sekali.
    expect(find.text('Masuk'), findsOneWidget);
  });

  group('role', () {
    testWidgets('admin → menu admin dirender di tab Profil', (tester) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage('mock-token-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Menu Admin'), findsOneWidget);
      expect(find.text('Manajemen Pengguna'), findsOneWidget);
    });

    testWidgets('teknisi → menu admin NGGAK dirender sama sekali', (
      tester,
    ) async {
      // 'mock-token-2' = teknisi.
      await tester.pumpWidget(_app(InMemoryTokenStorage('mock-token-2')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Menu Admin'), findsNothing);
      expect(find.text('Manajemen Pengguna'), findsNothing);
    });

    test('role asing dari backend → dianggap viewer (paling aman)', () {
      expect(UserRole.fromApi('superadmin'), UserRole.viewer);
      expect(UserRole.fromApi('admin').isAdmin, isTrue);
      expect(UserRole.fromApi('teknisi').bisaInput, isTrue);
      expect(UserRole.fromApi('viewer').bisaInput, isFalse);
    });
  });
}
