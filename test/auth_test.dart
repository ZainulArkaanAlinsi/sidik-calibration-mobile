import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asmo_mobile/app.dart';
import 'package:asmo_mobile/models/user.dart';
import 'package:asmo_mobile/providers/auth_provider.dart';
import 'package:asmo_mobile/providers/dashboard_provider.dart';
import 'package:asmo_mobile/services/dashboard_service.dart';
import 'package:asmo_mobile/services/mock_auth_service.dart';
import 'package:asmo_mobile/services/token_storage.dart';

/// Test alur UI pakai `MockAuthService` — nggak nembak jaringan.
/// Sambungan ke API asli diuji terpisah di `api_auth_service_test.dart`
/// pakai HTTP tiruan.
ProviderScope _app(TokenStorage storage) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(storage),
    authServiceProvider.overrideWithValue(MockAuthService()),
    // Dashboard ikut kebuka begitu login sukses. Tanpa jeda, biar nggak ada
    // timer nyangkut waktu test kelar (Flutter nganggep itu error).
    dashboardServiceProvider.overrideWithValue(
      MockDashboardService(jeda: Duration.zero),
    ),
  ],
  child: const AsmoApp(),
);

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

/// Scroll dulu baru tap. Di viewport test (800x600) tombol di bawah form
/// sering ke luar layar — `tap()` bakal meleset diam-diam tanpa bikin error.
Future<void> _tapTeks(WidgetTester tester, String teks) async {
  final finder = find.text(teks);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _isiLogin(
  WidgetTester tester, {
  required String identifier,
  required String password,
}) async {
  await tester.enterText(find.byType(TextField).first, identifier);
  await tester.enterText(find.byType(TextField).last, password);
  await _tapTeks(tester, 'MASUK');
}

void main() {
  group('login', () {
    testWidgets('belum ada token → mendarat di layar Login', (tester) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage()));
      await tester.pumpAndSettle();

      expect(find.text('MASUK'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('login pakai EMAIL → masuk & token tersimpan', (tester) async {
      final storage = InMemoryTokenStorage();
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      await _isiLogin(
        tester,
        identifier: 'admin@asmo.test',
        password: 'password123',
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(await storage.read(), isNotNull, reason: 'token wajib disimpan');
    });

    testWidgets('login pakai ID PEGAWAI → masuk juga', (tester) async {
      final storage = InMemoryTokenStorage();
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      // Teknisi di lapangan hafal nomor pegawainya, bukan emailnya.
      await _isiLogin(tester, identifier: 'ASM-0002', password: 'password123');
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(await storage.read(), isNotNull);
    });

    testWidgets('akun PENDING ditolak masuk, pesannya jelas', (tester) async {
      final storage = InMemoryTokenStorage();
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      await _isiLogin(tester, identifier: 'ASM-0004', password: 'password123');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('belum disetujui admin'),
        findsOneWidget,
        reason: 'akun yang belum di-approve nggak boleh bisa masuk',
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(await storage.read(), isNull);
    });

    testWidgets('password salah → error, tetap di Login, token nggak disimpan', (
      tester,
    ) async {
      final storage = InMemoryTokenStorage();
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      await _isiLogin(tester, identifier: 'ASM-0001', password: 'ngasal');
      await tester.pumpAndSettle();

      expect(find.textContaining('atau password salah'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(await storage.read(), isNull);
    });

    testWidgets('login gagal → yang udah diketik NGGAK ilang', (tester) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage()));
      await tester.pumpAndSettle();

      await _isiLogin(tester, identifier: 'ASM-0001', password: 'ngasal');
      await tester.pumpAndSettle();

      // User tinggal benerin password-nya doang, nggak ngetik ulang dari nol.
      expect(find.text('ASM-0001'), findsOneWidget);
    });

    testWidgets('field kosong → divalidasi lokal, nggak nembak server', (
      tester,
    ) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('MASUK'));
      await tester.pumpAndSettle();

      expect(find.text('ID pegawai atau email wajib diisi.'), findsOneWidget);
      expect(find.text('Password wajib diisi.'), findsOneWidget);
    });

    testWidgets('token tersimpan → langsung masuk, nggak login lagi', (
      tester,
    ) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage('mock-token-1')));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('MASUK'), findsNothing);
    });

    testWidgets('token basi → dibuang, balik ke Login (bukan crash)', (
      tester,
    ) async {
      final storage = InMemoryTokenStorage('token-kadaluarsa');
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      expect(find.text('MASUK'), findsOneWidget);
      expect(await storage.read(), isNull, reason: 'token basi harus dibuang');
    });

    testWidgets('secure storage error → tetap kebuka di Login, bukan crash', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_BrokenTokenStorage()));
      await tester.pumpAndSettle();

      expect(find.text('MASUK'), findsOneWidget);
    });

    testWidgets('logout → token dihapus & balik ke Login', (tester) async {
      final storage = InMemoryTokenStorage('mock-token-1');
      await tester.pumpWidget(_app(storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Keluar'), 200);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(find.text('MASUK'), findsOneWidget);
      expect(await storage.read(), isNull);
    });
  });

  group('register', () {
    Future<void> bukaRegister(WidgetTester tester) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage()));
      await tester.pumpAndSettle();

      await _tapTeks(tester, 'Daftar');
      await tester.pumpAndSettle();
    }

    Future<void> isiForm(
      WidgetTester tester, {
      required String nama,
      required String employeeId,
      required String email,
      required String password,
      String departemen = 'Kalibrasi',
    }) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), nama);
      await tester.enterText(fields.at(1), employeeId);

      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(departemen).last);
      await tester.pumpAndSettle();

      // Dropdown bukan TextField, jadi email & password geser indeksnya.
      final fieldsLagi = find.byType(TextField);
      await tester.enterText(fieldsLagi.at(2), email);
      await tester.enterText(fieldsLagi.at(3), password);

      await _tapTeks(tester, 'DAFTAR');
    }

    testWidgets('daftar sukses → akun PENDING, NGGAK langsung masuk app', (
      tester,
    ) async {
      await bukaRegister(tester);

      await isiForm(
        tester,
        nama: 'Eko Prasetyo',
        employeeId: 'ASM-0099',
        email: 'eko@ptasmo.com',
        password: 'password123',
      );
      await tester.pumpAndSettle();

      // Ini inti keamanannya: daftar ≠ boleh masuk.
      expect(find.text('Pendaftaran terkirim'), findsOneWidget);
      expect(
        find.textContaining('menunggu persetujuan admin'),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('setelah tutup dialog sukses → balik ke layar Login', (
      tester,
    ) async {
      await bukaRegister(tester);

      await isiForm(
        tester,
        nama: 'Eko Prasetyo',
        employeeId: 'ASM-0098',
        email: 'eko2@ptasmo.com',
        password: 'password123',
      );
      await tester.pumpAndSettle();

      await _tapTeks(tester, 'MENGERTI');
      await tester.pumpAndSettle();

      expect(find.text('MASUK'), findsOneWidget);
    });

    testWidgets('email udah kepakai → ditolak dengan pesan jelas', (
      tester,
    ) async {
      await bukaRegister(tester);

      await isiForm(
        tester,
        nama: 'Budi Kembar',
        employeeId: 'ASM-0097',
        email: 'admin@asmo.test', // udah ada
        password: 'password123',
      );
      await tester.pumpAndSettle();

      expect(find.text('Email ini sudah terdaftar.'), findsOneWidget);
    });

    testWidgets('validasi lokal: field kosong, email ngawur, password pendek', (
      tester,
    ) async {
      await bukaRegister(tester);

      await _tapTeks(tester, 'DAFTAR');
      await tester.pumpAndSettle();

      expect(find.text('Nama wajib diisi.'), findsOneWidget);
      expect(find.text('ID pegawai wajib diisi.'), findsOneWidget);
      expect(find.text('Pilih departemen dulu.'), findsOneWidget);
      expect(find.text('Email wajib diisi.'), findsOneWidget);
      expect(find.text('Password wajib diisi.'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(2), 'bukan-email');
      await tester.enterText(fields.at(3), '123');
      await _tapTeks(tester, 'DAFTAR');
      await tester.pumpAndSettle();

      expect(find.text('Format email nggak valid.'), findsOneWidget);
      expect(find.text('Password minimal 8 karakter.'), findsOneWidget);
    });
  });

  group('role & status', () {
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
      await tester.pumpWidget(_app(InMemoryTokenStorage('mock-token-2')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Menu Admin'), findsNothing);
      expect(find.text('Manajemen Pengguna'), findsNothing);
    });

    testWidgets('logout dari tab Profil → login lagi mendarat di Dashboard', (
      tester,
    ) async {
      await tester.pumpWidget(_app(InMemoryTokenStorage('mock-token-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Keluar'), 200);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      await _isiLogin(tester, identifier: 'ASM-0002', password: 'password123');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
    });

    test('role asing dari backend → dianggap viewer (paling aman)', () {
      expect(UserRole.fromApi('superadmin'), UserRole.viewer);
      expect(UserRole.fromApi('admin').isAdmin, isTrue);
      expect(UserRole.fromApi('teknisi').bisaInput, isTrue);
      expect(UserRole.fromApi('viewer').bisaInput, isFalse);
    });

    test('status asing / hilang → aman, nggak ngunci semua orang', () {
      expect(UserStatus.fromApi('pending'), UserStatus.pending);
      expect(UserStatus.fromApi('aktif'), UserStatus.aktif);
      expect(UserStatus.fromApi('entah'), UserStatus.nonaktif);
    });
  });
}
