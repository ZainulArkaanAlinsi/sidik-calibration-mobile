import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/alur/alur_kerja_screen.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Alur Kerja harus kepakai di HP, bukan cuma di jendela desktop.
///
/// Dulu layar ini `Row` dengan `SizedBox(width: 340)` mati — nol `LayoutBuilder`
/// di seluruh berkasnya. Di HP 360px daftarnya makan 340 dan panel tahapannya
/// kebagian sisa ~19px. Bukan layar desktop-only yang kebetulan kebuka di HP:
/// menu "Alur Kerja" di `main_shell.dart` sengaja ditambahin buat admin yang
/// pegang HP, dan docblock di situ nyebut alasannya.
///
/// Ambang panel gandanya punya [MasterDetailPane] (900px ruang tersedia), jadi
/// yang diuji di sini perilaku layarnya di dua sisi ambang itu — bukan angkanya.
Widget _app() {
  return ProviderScope(
    overrides: [
      // `mock-token-1` = admin. Alur Kerja emang menu admin.
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      historyServiceProvider.overrideWithValue(MockHistoryService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AlurKerjaScreen(),
    ),
  );
}

Future<void> _ukuran(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Pasang layar & lewatin jeda 600 ms `MockAuthService.me()` — timer kayak gitu
/// nggak ngejadwalin frame, jadi `pumpAndSettle` doang balik duluan dan
/// timernya nyangkut waktu tree dibuang.
Future<void> _pasang(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Kotak cari cuma ada di panel daftar. Dia hadir = daftarnya masih kelihatan.
final _kotakCari = find.byType(TextField);

void main() {
  group('Alur Kerja: panel ganda vs satu panel', () {
    testWidgets('di HP tap baris → PUSH halaman tahapan, bukan panel', (
      tester,
    ) async {
      await _ukuran(tester, const Size(400, 800));
      await _pasang(tester);

      // Satu panel: panel kanan nggak dirender sama sekali, jadi ajakan
      // "Pilih sesi di kiri" — yang cuma masuk akal kalau ada kiri-kanan —
      // nggak muncul.
      expect(
        find.text('Pilih sesi di kiri buat lihat posisinya sekarang.'),
        findsNothing,
      );
      expect(_kotakCari, findsOneWidget);

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Ketimpa halaman baru, DAN ada jalan baliknya. Tanpa tombol balik,
      // admin yang mbuka ini dari menu samping HP nyangkut di situ.
      expect(_kotakCari, findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('di desktop tap baris → tahapan kebuka di panel, daftar tetap ada',
        (tester) async {
      await _ukuran(tester, const Size(1240, 860));
      await _pasang(tester);

      expect(
        find.text('Pilih sesi di kiri buat lihat posisinya sekarang.'),
        findsOneWidget,
      );

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Inti panel ganda: daftarnya NGGAK ketimpa, dan nggak ada yang di-push.
      expect(_kotakCari, findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(
        find.text('Pilih sesi di kiri buat lihat posisinya sekarang.'),
        findsNothing,
      );
    });

    testWidgets('ganti pilihan di desktop nggak numpuk halaman', (tester) async {
      await _ukuran(tester, const Size(1240, 860));
      await _pasang(tester);

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(InkWell).at(1));
      await tester.pumpAndSettle();

      // Kalau ini kebablasan jadi push, bakal ada halaman bertumpuk.
      expect(find.byType(BackButton), findsNothing);
      expect(_kotakCari, findsOneWidget);
    });
  });
}
