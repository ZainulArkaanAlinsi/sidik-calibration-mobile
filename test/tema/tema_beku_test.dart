import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/palet_beku.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/tema_beku.dart';

/// Nilai tema BEKU (lembar kerja), dikunci dengan angka mentah.
///
/// Dulu asersi ini milik `token_tema_lab_test.dart` (tema app). Sejak L1b tema
/// app berganti ke Biru Awan, dan nilai lama tinggal di sini: `TemaBeku` harus
/// tetap persis `SidikTheme` per 14 Nov 2026 (`docs/desain-ulang/BEKU.md`).
/// Hash `tema_beku.dart`/`palet_beku.dart` (`test/beku/berkas_beku_test.dart`)
/// menjaga berkasnya; tes ini menjaga HASIL yang dibaca layar, dengan literal
/// hex (bukan rujukan ke `PaletBeku`), jadi menggeser `PaletBeku` pun ketahuan.
void main() {
  final tema = <(String, ThemeData Function())>[
    ('terang', () => TemaBeku.terang),
    ('gelap', () => TemaBeku.gelap),
  ];

  group('huruf: minimum 12 sp', () {
    for (final (nama, bangun) in tema) {
      for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
        test('tema beku $nama di ${platform.name}', () {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final t = bangun().textTheme;
          for (final (apa, gaya) in <(String, TextStyle?)>[
            ('displayLarge', t.displayLarge),
            ('headlineSmall', t.headlineSmall),
            ('titleLarge', t.titleLarge),
            ('titleMedium', t.titleMedium),
            ('titleSmall', t.titleSmall),
            ('bodyLarge', t.bodyLarge),
            ('bodyMedium', t.bodyMedium),
            ('bodySmall', t.bodySmall),
            ('labelLarge', t.labelLarge),
            ('labelMedium', t.labelMedium),
            ('labelSmall', t.labelSmall),
          ]) {
            expect(gaya, isNotNull, reason: '$apa tidak diatur');
            expect(gaya!.fontSize, greaterThanOrEqualTo(12), reason: apa);
            expect(gaya.fontFamily, 'Inter');
          }
        });
      }
    }
  });

  group('ukuran sentuh: aksi utama 56, sisanya 48 (desktop 44)', () {
    double tinggi(ButtonStyle? s) => s!.minimumSize!.resolve({})!.height;

    for (final (nama, bangun) in tema) {
      test('tema beku $nama di HP', () {
        final t = bangun();
        expect(tinggi(t.filledButtonTheme.style), UkuranBeku.aksiUtama);
        expect(UkuranBeku.aksiUtama, 56);
        expect(tinggi(t.outlinedButtonTheme.style), UkuranBeku.aksi);
        expect(tinggi(t.textButtonTheme.style), UkuranBeku.aksi);
        expect(tinggi(t.iconButtonTheme.style), UkuranBeku.aksi);
        expect(tinggi(t.segmentedButtonTheme.style), UkuranBeku.aksi);
        expect(UkuranBeku.aksi, 48);
      });

      test('tema beku $nama di desktop: 44 dp', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final t = bangun();
        expect(tinggi(t.filledButtonTheme.style), UkuranBeku.aksiMeja);
        expect(tinggi(t.outlinedButtonTheme.style), UkuranBeku.aksiMeja);
        expect(UkuranBeku.aksiMeja, 44);
      });
    }
  });

  group(
    'bentuk: sudut lama (tombol utama 16, kontrol 10, kartu 8, dialog 20)',
    () {
      double radius(ShapeBorder? b, String apa) {
        expect(b, isA<RoundedRectangleBorder>(), reason: '$apa bukan persegi');

        return (b! as RoundedRectangleBorder).borderRadius
            .resolve(TextDirection.ltr)
            .topLeft
            .x;
      }

      for (final (nama, bangun) in tema) {
        test('tema beku $nama', () {
          final t = bangun();
          expect(
            radius(t.filledButtonTheme.style!.shape!.resolve({}), 'Filled'),
            16,
          );
          expect(
            radius(t.outlinedButtonTheme.style!.shape!.resolve({}), 'Outlined'),
            10,
          );
          expect(
            radius(t.textButtonTheme.style!.shape!.resolve({}), 'Text'),
            10,
          );
          expect(radius(t.cardTheme.shape, 'Card'), 8);
          expect(radius(t.dialogTheme.shape, 'Dialog'), 20);
          expect(radius(t.chipTheme.shape, 'Chip'), 10);
          expect(radius(t.snackBarTheme.shape, 'SnackBar'), 10);
          expect(radius(t.floatingActionButtonTheme.shape, 'FAB'), 16);
          expect(
            (t.bottomSheetTheme.shape! as RoundedRectangleBorder).borderRadius
                .resolve(TextDirection.ltr)
                .topLeft
                .x,
            20,
          );
          // Isian = kolom bergaris bawah tegas 2 dp, sudut atas 4.
          for (final b in [
            t.inputDecorationTheme.border,
            t.inputDecorationTheme.enabledBorder,
            t.inputDecorationTheme.focusedBorder,
          ]) {
            expect(b, isA<UnderlineInputBorder>());
            final u = b! as UnderlineInputBorder;
            expect(u.borderSide.width, 2);
            expect(u.borderRadius.topLeft.x, 4);
          }
        });
      }
    },
  );

  group(
    'warna kunci (literal): tidak ikut berganti saat palet Lab diganti',
    () {
      test('terang', () {
        final t = TemaBeku.terang;
        final s = t.colorScheme;
        expect(s.primary, const Color(0xFF043EA1));
        expect(s.onPrimary, const Color(0xFFFFFFFF));
        expect(s.primaryContainer, const Color(0xFFDCE6FA));
        expect(s.onPrimaryContainer, const Color(0xFF0A2A6B));
        expect(s.secondary, const Color(0xFF043EA1));
        expect(s.error, const Color(0xFFA81B33));
        expect(s.surface, const Color(0xFFFFFFFF));
        expect(s.onSurface, const Color(0xFF111827));
        expect(s.onSurfaceVariant, const Color(0xFF475467));
        expect(s.outline, const Color(0xFF5F6B7E));
        expect(s.outlineVariant, const Color(0xFFDDE2EB));
        expect(s.inverseSurface, const Color(0xFF111827));
        expect(t.scaffoldBackgroundColor, const Color(0xFFF2F4F8));
        final m = t.extension<SidikMaterial>()!;
        expect(m.biru, const Color(0xFF043EA1));
        expect(m.biruTipis, const Color(0xFFDCE6FA));
        expect(m.lulus, const Color(0xFF125739));
        expect(m.lulusTipis, const Color(0xFFE1F0E8));
        expect(m.awas, const Color(0xFF8C5C0A));
        expect(m.awasTipis, const Color(0xFFFBF0DA));
        expect(m.gagalTipis, const Color(0xFFFBE4E8));
        expect(m.tungguTipis, const Color(0xFFE6EAF2));
        expect(m.logamTepi, const Color(0xFF6B7588));
        expect(m.kertas2, const Color(0xFFF8F9FC));
        expect(m.pensil, const Color(0xFF5F6B7E));
      });

      test('gelap', () {
        final t = TemaBeku.gelap;
        final s = t.colorScheme;
        expect(s.primary, const Color(0xFF8CB0FF));
        expect(s.onPrimary, const Color(0xFF04265F));
        expect(s.primaryContainer, const Color(0xFF14306F));
        expect(s.onPrimaryContainer, const Color(0xFFD6E3FF));
        expect(s.error, const Color(0xFFFF8FA0));
        expect(s.surface, const Color(0xFF171D2B));
        expect(s.onSurface, const Color(0xFFE6EAF2));
        expect(s.outline, const Color(0xFF7C879B));
        expect(s.inverseSurface, const Color(0xFF283044));
        expect(t.scaffoldBackgroundColor, const Color(0xFF0E1320));
        final m = t.extension<SidikMaterial>()!;
        expect(m.biru, const Color(0xFF8CB0FF));
        expect(m.biruTinta, const Color(0xFF8CB0FF));
        expect(m.lulus, const Color(0xFF6FD3A0));
        expect(m.awas, const Color(0xFFDB9A2B));
        expect(m.pensil, const Color(0xFF8E98AC));
        expect(m.kaca, const Color(0xFF0E1320));
      });

      test('PaletBeku sendiri tidak merujuk Biru Awan', () {
        expect(PaletBeku.kobalt700, const Color(0xFF043EA1));
        expect(PaletBeku.latarTerang, const Color(0xFFF2F4F8));
        expect(PaletBeku.garisTegasTerang, const Color(0xFF6B7588));
        expect(PaletBeku.latarGelap, const Color(0xFF0E1320));
      });
    },
  );
}
