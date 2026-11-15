import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/core/theme/tema_beku.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/screens/auth/forgot_password_screen.dart';
import 'package:sidik_calibration/screens/auth/login_screen.dart';
import 'package:sidik_calibration/screens/auth/widgets/isian_neu_lama.dart';
import 'package:sidik_calibration/screens/auth/widgets/neu.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// `NeuTextField` (login dan lupa sandi) memakai `InputDecoration.collapsed`,
/// tetapi `enabledBorder`/`focusedBorder` dari `inputDecorationTheme` tetap
/// berlaku. Tema Biru Awan (L1b) memberi kotak radius 16, yang tergambar DI DALAM
/// kotak Neu. `IsianNeuLama` mengembalikan `inputDecorationTheme` lama (garis
/// bawah) hanya untuk isian itu; tes ini mengunci keduanya: dengan pembungkus
/// temanya = tema beku, tanpa pembungkus kotak Biru Awan (jadi tes tidak hampa).
///
/// Grup kedua menjaga PEMASANGANNYA: setiap `TextField` di `LoginScreen` (2) dan
/// `ForgotPasswordScreen` (1), diambil dari layar sungguhan di bawah `AppTheme`,
/// membaca isian garis bawah lama. Isian yang lepas dari `IsianNeuLama` jatuh ke
/// kotak Biru Awan dan tes ini merah.
void main() {
  Future<InputDecorationThemeData> temaIsian(
    WidgetTester tester, {
    required ThemeData tema,
    required bool bungkus,
  }) async {
    final isian = NeuTextField(
      icon: Icons.person_outline,
      controller: TextEditingController(),
      hint: 'ID Pegawai / Email',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: tema,
        home: Material(child: bungkus ? IsianNeuLama(child: isian) : isian),
      ),
    );
    await tester.pumpAndSettle();

    return Theme.of(
      tester.element(find.byType(TextField)),
    ).inputDecorationTheme;
  }

  for (final (nama, app, beku) in [
    ('terang', AppTheme.light, TemaBeku.terang),
    ('gelap', AppTheme.dark, TemaBeku.gelap),
  ]) {
    testWidgets('isian login dan lupa sandi memakai tema isian lama, $nama', (
      tester,
    ) async {
      final lama = beku.inputDecorationTheme;
      final dibungkus = await temaIsian(tester, tema: app, bungkus: true);
      for (final (apa, b, acuan) in [
        ('border', dibungkus.border, lama.border),
        ('enabledBorder', dibungkus.enabledBorder, lama.enabledBorder),
        ('focusedBorder', dibungkus.focusedBorder, lama.focusedBorder),
        ('errorBorder', dibungkus.errorBorder, lama.errorBorder),
        ('disabledBorder', dibungkus.disabledBorder, lama.disabledBorder),
      ]) {
        expect(
          b,
          isA<UnderlineInputBorder>(),
          reason: '$apa bukan garis bawah',
        );
        expect(b, acuan, reason: '$apa beda dari tema lama');
      }
      expect(dibungkus.filled, lama.filled);
      expect(dibungkus.contentPadding, lama.contentPadding);

      // Kontrol: tanpa pembungkus isian memang kotak Biru Awan.
      final tanpa = await temaIsian(tester, tema: app, bungkus: false);
      expect(
        tanpa.enabledBorder,
        isA<OutlineInputBorder>(),
        reason:
            'tanpa pembungkus harusnya kotak: tes tidak membuktikan apa-apa',
      );
    });
  }

  group(
    'layar sungguhan membungkus SETIAP NeuTextField dengan IsianNeuLama',
    () {
      Widget aplikasi(Widget layar, ThemeData tema) => ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authServiceProvider.overrideWithValue(MockAuthService()),
        ],
        child: MaterialApp(theme: tema, darkTheme: tema, home: layar),
      );

      for (final (nama, app) in [
        ('terang', AppTheme.light),
        ('gelap', AppTheme.dark),
      ]) {
        for (final (layar, bangun, jumlah)
            in <(String, Widget Function(), int)>[
              ('LoginScreen', () => const LoginScreen(), 2),
              ('ForgotPasswordScreen', () => const ForgotPasswordScreen(), 1),
            ]) {
          testWidgets('$layar, tema $nama: $jumlah isian bergaris bawah', (
            tester,
          ) async {
            tester.view.physicalSize = const Size(800, 1600);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(aplikasi(bangun(), app));
            await tester.pump(const Duration(milliseconds: 700));
            await tester.pumpAndSettle();

            expect(find.byType(NeuTextField), findsNWidgets(jumlah));
            expect(find.byType(TextField), findsNWidgets(jumlah));
            // Tiap NeuTextField punya IsianNeuLama sebagai leluhurnya.
            expect(
              find.ancestor(
                of: find.byType(NeuTextField),
                matching: find.byType(IsianNeuLama),
              ),
              findsNWidgets(jumlah),
              reason:
                  '$layar: ada NeuTextField yang tidak dibungkus IsianNeuLama',
            );

            final lama = (nama == 'terang' ? TemaBeku.terang : TemaBeku.gelap)
                .inputDecorationTheme;
            for (final isian in tester.elementList(find.byType(TextField))) {
              final tema = Theme.of(isian).inputDecorationTheme;
              expect(
                tema.enabledBorder,
                isA<UnderlineInputBorder>(),
                reason:
                    '$layar: isian memakai kotak Biru Awan, bukan garis bawah',
              );
              expect(tema.enabledBorder, lama.enabledBorder);
              expect(tema.focusedBorder, lama.focusedBorder);
            }
          });
        }
      }
    },
  );
}
