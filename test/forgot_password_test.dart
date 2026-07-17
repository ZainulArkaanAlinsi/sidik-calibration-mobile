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

/// Langkah 1: isi email + LANJUT.
Future<void> _verifikasiEmail(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextField).first, email);
  await _tapTeks(tester, 'LANJUT');
  await tester.pumpAndSettle();
}

/// Langkah 2: isi password baru + ulangi + SIMPAN.
Future<void> _isiPasswordBaru(
  WidgetTester tester, {
  required String baru,
  required String ulang,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), baru);
  await tester.enterText(fields.at(1), ulang);
  await _tapTeks(tester, 'SIMPAN PASSWORD BARU');
  await tester.pumpAndSettle();
}

void main() {
  group('reset password — alur langkah', () {
    testWidgets('NORMAL: link di Login beneran buka layar reset', (
      tester,
    ) async {
      await _bukaLupaPassword(tester);

      expect(find.text('Lupa Password'), findsOneWidget);
      expect(find.text('LANJUT'), findsOneWidget);
    });

    testWidgets('email terdaftar → lanjut ke langkah atur password', (
      tester,
    ) async {
      await _bukaLupaPassword(tester);
      await _verifikasiEmail(tester, 'admin@pt-sidik.com');

      expect(find.text('Atur Password Baru'), findsOneWidget);
      // Emailnya disebut ulang biar user sadar kalau salah ketik.
      expect(find.textContaining('admin@pt-sidik.com'), findsOneWidget);
      // Langkah email udah lewat.
      expect(find.text('LANJUT'), findsNothing);
    });

    testWidgets('email nggak terdaftar → pesan jelas, tetap di langkah email', (
      tester,
    ) async {
      await _bukaLupaPassword(tester);
      await _verifikasiEmail(tester, 'bukan.siapa2@pt-sidik.com');

      expect(find.text('Email ini nggak terdaftar.'), findsOneWidget);
      expect(find.text('Atur Password Baru'), findsNothing);
      // Masih di langkah email, user bisa langsung benerin.
      expect(find.text('LANJUT'), findsOneWidget);
    });
  });

  group('validasi lokal', () {
    testWidgets('email kosong → nggak nembak server', (tester) async {
      await _bukaLupaPassword(tester);
      await _tapTeks(tester, 'LANJUT');
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi.'), findsOneWidget);
    });

    testWidgets('format email ngawur → ditolak duluan', (tester) async {
      await _bukaLupaPassword(tester);
      await _verifikasiEmail(tester, 'bukan-email');

      expect(find.text('Format email nggak valid.'), findsOneWidget);
    });

    testWidgets('password baru & ulangan beda → ditolak', (tester) async {
      await _bukaLupaPassword(tester);
      await _verifikasiEmail(tester, 'viewer@pt-sidik.com');
      await _isiPasswordBaru(tester, baru: 'password999', ulang: 'password000');

      expect(find.text('Password nggak sama.'), findsOneWidget);
      expect(find.text('Password berhasil diubah'), findsNothing);
    });

    testWidgets('password baru kependekan → ditolak', (tester) async {
      await _bukaLupaPassword(tester);
      await _verifikasiEmail(tester, 'viewer@pt-sidik.com');
      await _isiPasswordBaru(tester, baru: 'pendek', ulang: 'pendek');

      expect(find.text('Password minimal 8 karakter.'), findsOneWidget);
    });
  });

  testWidgets(
    'FUNGSIONAL: reset beneran ganti password → login lama gagal, baru sukses',
    (tester) async {
      await _bukaLupaPassword(tester);
      await _verifikasiEmail(tester, 'teknisi@pt-sidik.com');
      await _isiPasswordBaru(tester, baru: 'rahasiaBaru1', ulang: 'rahasiaBaru1');

      expect(find.text('Password berhasil diubah'), findsOneWidget);

      // Balik ke Login.
      await _tapTeks(tester, 'BALIK KE LOGIN');
      await tester.pumpAndSettle();
      expect(find.text('MASUK'), findsOneWidget);

      // Password LAMA harus ditolak — reset-nya beneran, bukan pajangan.
      await tester.enterText(find.byType(TextField).at(0), 'ASM-0002');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await _tapTeks(tester, 'MASUK');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('atau password salah'),
        findsOneWidget,
        reason: 'password lama nggak boleh jalan lagi',
      );

      // Password BARU harus sukses → mendarat di Dashboard.
      await tester.enterText(find.byType(TextField).at(1), 'rahasiaBaru1');
      await _tapTeks(tester, 'MASUK');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
    },
  );
}
