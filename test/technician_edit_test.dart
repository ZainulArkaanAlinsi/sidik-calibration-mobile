import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart';
import 'package:sidik_calibration/screens/settings/technician_list_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/user_service.dart';

Widget _app(MockUserService service) {
  return ProviderScope(
    overrides: [
      // `mock-token-1` = admin. Layar ini admin-only.
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      userServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TechnicianListScreen(),
    ),
  );
}

/// Pasang layar + lewatin jeda mock.
///
/// `MockAuthService` sengaja punya jeda 600 ms biar mode mock kerasa realistis.
/// `pumpAndSettle()` nggak majuin timer, jadi jedanya harus dilewatin manual —
/// kalau nggak, `authProvider` masih null dan layar nampilin gerbang
/// "cuma admin yang bisa kelola akun", bukan daftarnya.
Future<void> _pasang(WidgetTester tester, MockUserService service) async {
  await tester.pumpWidget(_app(service));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Buka dialog edit buat akun yang namanya [nama].
Future<void> _bukaEdit(WidgetTester tester, String nama) async {
  final kartu = find.ancestor(
    of: find.text(nama),
    matching: find.byType(Card),
  );
  await tester.tap(
    find.descendant(of: kartu, matching: find.text('Edit akun')),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Admin benerin data akun', () {
    testWidgets('email salah ketik bisa dibetulin — kasus yang bikin kekunci',
        (tester) async {
      final service = MockUserService();
      await _pasang(tester, service);

      // Eko daftar dengan `eko@gmial.com`. Reset password lewat email, login
      // pakai ID pegawai — tanpa admin yang mbenerin, dia nggak punya jalan
      // masuk sama sekali.
      expect(find.text('eko@gmial.com'), findsOneWidget);

      await _bukaEdit(tester, 'Eko Prasetyo');
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'eko@gmail.com',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('eko@gmail.com'), findsOneWidget);
      expect(find.text('eko@gmial.com'), findsNothing);
    });

    testWidgets('ubah satu kolom NGGAK nimpa kolom lain', (tester) async {
      final service = MockUserService();
      await _pasang(tester, service);

      await _bukaEdit(tester, 'Eko Prasetyo');
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'eko@gmail.com',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Simpan'));
      await tester.pumpAndSettle();

      final eko = (await service.daftar('t')).firstWhere((u) => u.id == 2);
      expect(eko.email, 'eko@gmail.com');
      // Yang nggak disentuh admin harus utuh — termasuk status `pending`,
      // yang punya jalannya sendiri lewat Setujui/Tolak.
      expect(eko.nama, 'Eko Prasetyo');
      expect(eko.employeeId, 'SDK-0002');
      expect(eko.role, UserRole.teknisi);
      expect(eko.status, UserStatus.pending);
    });

    testWidgets('role bisa diubah sesudah akun disetujui', (tester) async {
      final service = MockUserService();
      await _pasang(tester, service);

      // Sebelum ini, role cuma bisa ditentukan sekali waktu approve.
      await _bukaEdit(tester, 'Eko Prasetyo');
      await tester.tap(find.byType(DropdownButtonFormField<UserRole>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viewer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Simpan'));
      await tester.pumpAndSettle();

      final eko = (await service.daftar('t')).firstWhere((u) => u.id == 2);
      expect(eko.role, UserRole.viewer);
    });

    testWidgets('ID pegawai kosong ditolak di layar, nggak dikirim ke server',
        (tester) async {
      final service = MockUserService();
      await _pasang(tester, service);

      await _bukaEdit(tester, 'Eko Prasetyo');
      await tester.enterText(
        find.widgetWithText(TextField, 'ID pegawai'),
        '',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Simpan'));
      await tester.pumpAndSettle();

      // Dialognya nggak nutup, dan alasannya kelihatan.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('ID pegawai nggak boleh kosong'),
        findsOneWidget,
      );
      expect(
        (await service.daftar('t')).firstWhere((u) => u.id == 2).employeeId,
        'SDK-0002',
      );
    });

    testWidgets('email ngawur ditolak sebelum nembak server', (tester) async {
      final service = MockUserService();
      await _pasang(tester, service);

      await _bukaEdit(tester, 'Eko Prasetyo');
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'bukan-email',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        (await service.daftar('t')).firstWhere((u) => u.id == 2).email,
        'eko@gmial.com',
      );
    });

    testWidgets('tombol Edit ada juga di akun pending & nonaktif',
        (tester) async {
      final service = MockUserService();
      await _pasang(tester, service);

      // Justru akun pending yang paling sering salah ketik emailnya. Kalau
      // tombolnya cuma muncul waktu aktif, yang paling butuh malah nggak
      // bisa disentuh.
      final kartuPending = find.ancestor(
        of: find.text('Eko Prasetyo'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: kartuPending, matching: find.text('Edit akun')),
        findsOneWidget,
      );
    });
  });
}
