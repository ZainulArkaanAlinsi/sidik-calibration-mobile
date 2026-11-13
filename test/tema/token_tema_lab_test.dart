import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/sidik_theme.dart';
import 'package:sidik_calibration/widgets/sidik/sidik_status.dart';

/// Gerbang desain Lab, pelengkap: aturan token yang bukan kontras.
///
/// - Huruf: minimum 12 sp di semua slot, di HP maupun desktop (skala 0,9x).
/// - Ukuran sentuh: aksi utama 56 dp, semua aksi lain 48 dp (desktop 44).
/// - Bentuk: radius tema hanya dari set `BentukLab` (4, 8, 10, 16, 20, 999).
/// - Datar: resep permukaan tidak punya gradien dan tidak punya bayangan.
/// - Status: tiap lencana membawa ikon DAN kata, tidak hanya warna.
void main() {
  final tema = <(String, ThemeData Function())>[
    ('terang', () => SidikTheme.terang),
    ('gelap', () => SidikTheme.gelap),
  ];

  group('huruf: minimum 12 sp', () {
    for (final (nama, bangun) in tema) {
      for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
        test('tema $nama di ${platform.name}', () {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final t = bangun().textTheme;
          final slot = <String, TextStyle?>{
            'displayLarge': t.displayLarge,
            'displayMedium': t.displayMedium,
            'displaySmall': t.displaySmall,
            'headlineLarge': t.headlineLarge,
            'headlineMedium': t.headlineMedium,
            'headlineSmall': t.headlineSmall,
            'titleLarge': t.titleLarge,
            'titleMedium': t.titleMedium,
            'titleSmall': t.titleSmall,
            'bodyLarge': t.bodyLarge,
            'bodyMedium': t.bodyMedium,
            'bodySmall': t.bodySmall,
            'labelLarge': t.labelLarge,
            'labelMedium': t.labelMedium,
            'labelSmall': t.labelSmall,
          };
          for (final e in slot.entries) {
            expect(e.value, isNotNull, reason: '${e.key} tidak diatur');
            expect(
              e.value!.fontSize,
              greaterThanOrEqualTo(12),
              reason: '${e.key} di bawah 12 sp',
            );
            expect(e.value!.fontFamily, SidikTheme.keluarga);
          }
        });
      }
    }

    test('gayaEtsa menaikkan permintaan di bawah 12 sp', () {
      final m = SidikMaterial.terangDefault;
      expect(m.gayaEtsa(ukuran: 11).fontSize, 12);
      expect(m.gayaEtsa(ukuran: 8.5).fontSize, 12);
      expect(m.gayaEtsa(ukuran: 14).fontSize, 14);
      expect(m.gayaEtsa().fontSize, greaterThanOrEqualTo(12));
    });
  });

  group('ukuran sentuh: aksi utama 56, sisanya 48', () {
    for (final (nama, bangun) in tema) {
      test('tema $nama di HP', () {
        final t = bangun();
        double tinggi(ButtonStyle? s) => s!.minimumSize!.resolve({})!.height;
        expect(tinggi(t.filledButtonTheme.style), UkuranLab.aksiUtama);
        expect(UkuranLab.aksiUtama, 56);
        expect(tinggi(t.outlinedButtonTheme.style), UkuranLab.aksi);
        expect(tinggi(t.textButtonTheme.style), UkuranLab.aksi);
        expect(tinggi(t.iconButtonTheme.style), UkuranLab.aksi);
        expect(tinggi(t.segmentedButtonTheme.style), UkuranLab.aksi);
        expect(UkuranLab.aksi, 48);
        expect(
          t.textButtonTheme.style!.minimumSize!.resolve({})!.width,
          greaterThanOrEqualTo(48),
        );
      });

      test('tema $nama di desktop: 44 dp (tetikus)', () {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final t = bangun();
        double tinggi(ButtonStyle? s) => s!.minimumSize!.resolve({})!.height;
        expect(tinggi(t.filledButtonTheme.style), UkuranLab.aksiMeja);
        expect(tinggi(t.outlinedButtonTheme.style), UkuranLab.aksiMeja);
        expect(UkuranLab.aksiMeja, 44);
      });
    }
  });

  group('bentuk: radius hanya dari set BentukLab', () {
    final set = <double>{
      BentukLab.sel,
      BentukLab.panel,
      BentukLab.kontrol,
      BentukLab.utama,
      BentukLab.lembar,
      BentukLab.pil,
    };

    double radius(ShapeBorder? b, String apa) {
      expect(b, isA<RoundedRectangleBorder>(), reason: '$apa bukan persegi');
      final r = (b! as RoundedRectangleBorder).borderRadius.resolve(
        TextDirection.ltr,
      );
      return r.topLeft.x;
    }

    for (final (nama, bangun) in tema) {
      test('tema $nama', () {
        final t = bangun();
        final dipakai = <String, double>{
          'FilledButton': radius(
            t.filledButtonTheme.style!.shape!.resolve({}),
            'FilledButton',
          ),
          'OutlinedButton': radius(
            t.outlinedButtonTheme.style!.shape!.resolve({}),
            'OutlinedButton',
          ),
          'TextButton': radius(
            t.textButtonTheme.style!.shape!.resolve({}),
            'TextButton',
          ),
          'Card': radius(t.cardTheme.shape, 'Card'),
          'Dialog': radius(t.dialogTheme.shape, 'Dialog'),
          'Chip': radius(t.chipTheme.shape, 'Chip'),
          'SnackBar': radius(t.snackBarTheme.shape, 'SnackBar'),
          'Checkbox': radius(t.checkboxTheme.shape, 'Checkbox'),
          'FAB': radius(t.floatingActionButtonTheme.shape, 'FAB'),
          'Tooltip': (t.tooltipTheme.decoration! as BoxDecoration).borderRadius!
              .resolve(TextDirection.ltr)
              .topLeft
              .x,
          'BottomSheet': (t.bottomSheetTheme.shape! as RoundedRectangleBorder)
              .borderRadius
              .resolve(TextDirection.ltr)
              .topLeft
              .x,
        };
        for (final e in dipakai.entries) {
          expect(
            set,
            contains(e.value),
            reason: '${e.key} memakai radius ${e.value}, di luar set BentukLab',
          );
        }
        expect(dipakai['FilledButton'], BentukLab.utama);
        expect(dipakai['OutlinedButton'], BentukLab.kontrol);
        expect(dipakai['Card'], BentukLab.panel);
        expect(dipakai['Dialog'], BentukLab.lembar);
        expect(dipakai['BottomSheet'], BentukLab.lembar);
      });
    }
  });

  group('datar: tanpa gradien dan tanpa bayangan', () {
    for (final (nama, m) in <(String, SidikMaterial)>[
      ('terang', SidikMaterial.terangDefault),
      ('gelap', SidikMaterial.gelapDefault),
    ]) {
      test('resep permukaan tema $nama', () {
        final resep = <String, BoxDecoration>{
          'kertasLembar': m.kertasLembar(),
          'kertasBaki': m.kertasBaki(),
          'logamPanel': m.logamPanel(),
          'logamTimbul': m.logamTimbul(),
          'logamTimbul warna': m.logamTimbul(warna: [m.biruAtas, m.biru]),
          'logamTertekan': m.logamTertekan(),
          'logamTertekan warna': m.logamTertekan(warna: [m.biru]),
          'kacaCekung': m.kacaCekung(),
          'isian': m.isian(),
          'isian fokus': m.isian(fokus: true),
        };
        for (final e in resep.entries) {
          expect(e.value.gradient, isNull, reason: '${e.key} punya gradien');
          expect(
            e.value.boxShadow,
            anyOf(isNull, isEmpty),
            reason: '${e.key} punya bayangan',
          );
          expect(e.value.color, isNotNull, reason: '${e.key} tanpa isi rata');
        }
      });
    }

    test('tema: kartu, app bar, dan navigasi tanpa elevasi', () {
      for (final (_, bangun) in tema) {
        final t = bangun();
        expect(t.cardTheme.elevation, 0);
        expect(t.appBarTheme.elevation, 0);
        expect(t.appBarTheme.scrolledUnderElevation, 0);
        expect(t.navigationBarTheme.elevation, 0);
        expect(t.navigationRailTheme.elevation, 0);
      }
    });
  });

  group('status: ikon dan kata, tidak hanya warna', () {
    const kode = [
      'draft',
      'menunggu_approval',
      'perlu_revisi',
      'PASS',
      'FAIL',
      'valid',
      'warning',
      'expired',
      'aktif',
      'nonaktif',
      'overdue',
    ];
    for (final (nama, bangun) in tema) {
      testWidgets('semua lencana, tema $nama', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: bangun(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [for (final k in kode) SidikLencana.dariApi(k)],
                ),
              ),
            ),
          ),
        );
        for (final k in kode) {
          final s = StatusSidik.dariApi(k);
          expect(find.text(s.label), findsWidgets, reason: 'kata untuk $k');
          expect(find.byIcon(s.ikon), findsWidgets, reason: 'ikon untuk $k');
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
