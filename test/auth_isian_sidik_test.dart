import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/screens/auth/forgot_password_screen.dart';
import 'package:sidik_calibration/screens/auth/login_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/biru_awan/isian_sidik.dart';
import 'package:sidik_calibration/widgets/biru_awan/tombol_sidik.dart';

/// Login dan lupa sandi memakai komponen Biru Awan (L5), bukan lagi
/// `NeuTextField` yang dibungkus `IsianNeuLama` (L1b, sementara).
///
/// Yang dijaga: SETIAP kolom ketik di dua layar itu adalah `IsianSidik` (label
/// di atas, kotak 56, tepi dari token), dan tombol utamanya `TombolSidik`.
/// Kolom yang kembali ke `TextField` polos atau ke widget Neu membuat tes ini
/// merah. Kontrol dalam tes: isian kotak Biru Awan memang berbentuk
/// `OutlineInputBorder` pada tema app, dan `IsianSidik` mematikan semua tepi
/// `InputDecoration`-nya sendiri (tepinya digambar komponen), jadi tidak ada
/// kotak ganda.
void main() {
  Widget aplikasi(Widget layar, ThemeData tema) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
      authServiceProvider.overrideWithValue(
        MockAuthService(jeda: Duration.zero),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: tema,
      darkTheme: tema,
      home: layar,
    ),
  );

  group('layar sungguhan memakai IsianSidik untuk SETIAP kolom ketik', () {
    for (final (nama, tema) in [
      ('terang', AppTheme.light),
      ('gelap', AppTheme.dark),
    ]) {
      for (final (layar, bangun, jumlah, tombol) in <
        (String, Widget Function(), int, String)
      >[
        ('LoginScreen', () => const LoginScreen(), 2, 'MASUK'),
        (
          'ForgotPasswordScreen',
          () => const ForgotPasswordScreen(),
          1,
          'KIRIM LINK RESET',
        ),
      ]) {
        testWidgets('$layar, tema $nama: $jumlah IsianSidik', (tester) async {
          tester.view.physicalSize = const Size(800, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(aplikasi(bangun(), tema));
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pumpAndSettle();

          // Semua kolom ketik adalah isi sebuah IsianSidik.
          expect(find.byType(TextField), findsNWidgets(jumlah));
          expect(find.byType(IsianSidik), findsNWidgets(jumlah));
          expect(
            find.descendant(
              of: find.byType(IsianSidik),
              matching: find.byType(TextField),
            ),
            findsNWidgets(jumlah),
            reason: '$layar: ada TextField di luar IsianSidik',
          );

          // Tepi digambar IsianSidik, bukan InputDecoration: tidak ada kotak
          // atau garis bawah di dalam kotak.
          for (final isian in tester.widgetList<TextField>(
            find.byType(TextField),
          )) {
            final dekorasi = isian.decoration!;
            expect(dekorasi.enabledBorder, InputBorder.none);
            expect(dekorasi.focusedBorder, InputBorder.none);
            expect(dekorasi.errorBorder, InputBorder.none);
            expect(dekorasi.disabledBorder, InputBorder.none);
            expect(dekorasi.border, InputBorder.none);
          }

          // Kontrol: dengan tema app, `TextField` polos memang kotak Biru
          // Awan. Tanpa kontrol ini pemeriksaan di atas bisa lolos hampa.
          final polos = Theme.of(
            tester.element(find.byType(TextField).first),
          ).inputDecorationTheme;
          expect(
            polos.enabledBorder,
            isA<OutlineInputBorder>(),
            reason: 'tema app tidak lagi memberi kotak; tes ini hampa',
          );

          // Tombol utamanya TombolSidik berlabel $tombol.
          expect(
            find.widgetWithText(TombolSidik, tombol),
            findsOneWidget,
            reason: '$layar: tombol utama bukan TombolSidik',
          );
        });
      }
    }
  });

  test('login dan lupa sandi tidak lagi memakai widget Neu atau IsianNeuLama', () {
    for (final jalur in [
      'lib/screens/auth/login_screen.dart',
      'lib/screens/auth/forgot_password_screen.dart',
    ]) {
      final sumber = File(jalur).readAsStringSync();
      expect(sumber, isNot(contains('widgets/neu.dart')), reason: jalur);
      expect(sumber, isNot(contains('IsianNeuLama')), reason: jalur);
      expect(sumber, isNot(contains('NeuTextField')), reason: jalur);
      expect(sumber, isNot(contains('NeuButton')), reason: jalur);
    }
    expect(
      File('lib/screens/auth/widgets/isian_neu_lama.dart').existsSync(),
      isFalse,
      reason: 'pembungkus sementara L1b sudah tidak dipakai, hapus',
    );
  });
}
