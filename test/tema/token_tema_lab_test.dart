import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_ukuran.dart';
import 'package:sidik_calibration/core/theme/bentuk_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/sidik_theme.dart';
import 'package:sidik_calibration/core/theme/tema_beku.dart';
import 'package:sidik_calibration/widgets/sidik/sidik_status.dart';

/// Gerbang desain Lab, pelengkap: aturan token yang bukan kontras.
///
/// - Huruf: minimum 12 sp di semua slot, di HP maupun desktop (skala 0,9x).
/// - Ukuran sentuh: aksi utama 56 dp, semua aksi lain 48 dp (desktop 44).
/// - Bentuk (Biru Awan, L1b): tombol dan chip pil, isian 16, dialog 28, lembar
///   bawah 32 (`BentukBiruAwan`); kartu, snack, centang, tooltip masih
///   `BentukLab` (4, 8, 10). Nilai LAMA tema (tombol utama 16, dialog 20, isian
///   garis bawah) kini dijaga untuk tema beku di `tema_beku_test.dart`.
/// - Datar: resep permukaan tidak punya gradien dan tidak punya bayangan.
/// - Status: tiap lencana membawa ikon DAN kata, tidak hanya warna.
/// - Tema app BUKAN tema beku (lembar kerja memakai `TemaBeku`).
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
        expect(tinggi(t.filledButtonTheme.style), UkuranBiruAwan.tombolUtama);
        expect(UkuranBiruAwan.tombolUtama, 56);
        expect(tinggi(t.outlinedButtonTheme.style), UkuranBiruAwan.tombolTegas);
        expect(tinggi(t.textButtonTheme.style), UkuranBiruAwan.tombolTegas);
        expect(tinggi(t.iconButtonTheme.style), UkuranLab.aksi);
        expect(tinggi(t.segmentedButtonTheme.style), UkuranLab.aksi);
        expect(UkuranBiruAwan.tombolTegas, 48);
        expect(UkuranLab.aksi, 48);
        expect(
          t.textButtonTheme.style!.minimumSize!.resolve({})!.width,
          greaterThanOrEqualTo(48),
        );
      });

      test('tema $nama di desktop: 44 dp (tetikus, keputusan L1b)', () {
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

  group('bentuk: radius hanya dari set Biru Awan + sudut kecil lama', () {
    // Biru Awan (`BentukBiruAwan`) ditambah sudut kecil `BentukLab` yang MASIH
    // dipakai tema: kartu 8 (kartu 24 dibawa layar yang didesain ulang), snack
    // 10, centang dan tooltip 4. Tombol utama 16 dan dialog/lembar 20 milik
    // `BentukLab` sudah tidak dipakai tema app.
    // `ikonUbin` (16) dan `hero` (28) tidak ditulis: nilainya sama dengan
    // `isian` dan `dialog`, dan set literal tidak boleh memuat nilai ganda.
    final set = <double>{
      BentukLab.sel,
      BentukLab.panel,
      BentukLab.kontrol,
      BentukBiruAwan.isian,
      BentukBiruAwan.kartu,
      BentukBiruAwan.dialog,
      BentukBiruAwan.lembarBawah,
      BentukBiruAwan.dock,
      BentukBiruAwan.pil,
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
          'Isian (enabled)': _radiusIsian(t.inputDecorationTheme.enabledBorder),
          'Isian (fokus)': _radiusIsian(t.inputDecorationTheme.focusedBorder),
          'Isian (galat)': _radiusIsian(t.inputDecorationTheme.errorBorder),
        };
        for (final e in dipakai.entries) {
          expect(
            set,
            contains(e.value),
            reason: '${e.key} memakai radius ${e.value}, di luar set Biru Awan',
          );
        }
        expect(dipakai['FilledButton'], BentukBiruAwan.pil);
        expect(dipakai['OutlinedButton'], BentukBiruAwan.pil);
        expect(dipakai['TextButton'], BentukBiruAwan.pil);
        expect(dipakai['Chip'], BentukBiruAwan.pil);
        expect(dipakai['Card'], BentukLab.panel);
        expect(dipakai['Dialog'], BentukBiruAwan.dialog);
        expect(dipakai['BottomSheet'], BentukBiruAwan.lembarBawah);
        expect(dipakai['Isian (enabled)'], BentukBiruAwan.isian);
        expect(BentukBiruAwan.dialog, 28);
        expect(BentukBiruAwan.lembarBawah, 32);
        expect(BentukBiruAwan.isian, 16);
      });
    }
  });

  group('isian: kotak, fokus 2 dp, galat 2 dp (Biru Awan)', () {
    for (final (nama, bangun) in tema) {
      test('tema $nama', () {
        final d = bangun().inputDecorationTheme;
        for (final b in [
          d.border,
          d.enabledBorder,
          d.focusedBorder,
          d.errorBorder,
          d.focusedErrorBorder,
          d.disabledBorder,
        ]) {
          expect(b, isA<OutlineInputBorder>(), reason: 'isian harus kotak');
        }
        double tebal(InputBorder? b) =>
            (b! as OutlineInputBorder).borderSide.width;
        expect(tebal(d.enabledBorder), 1);
        expect(tebal(d.focusedBorder), 2);
        expect(tebal(d.errorBorder), 2);
        expect(tebal(d.focusedErrorBorder), 2);
      });
    }
  });

  group('tema app BUKAN tema beku', () {
    // Lembar kerja memakai `TemaBeku`. Kalau tema app kebetulan sama dengan
    // tema beku, pembungkus `BekuLembarKerja` tidak terbukti apa-apa.
    test('warna kunci dan bentuk berbeda, terang dan gelap', () {
      for (final (app, beku) in [
        (SidikTheme.terang, TemaBeku.terang),
        (SidikTheme.gelap, TemaBeku.gelap),
      ]) {
        expect(app.colorScheme.primary, isNot(beku.colorScheme.primary));
        expect(
          app.scaffoldBackgroundColor,
          isNot(beku.scaffoldBackgroundColor),
        );
        expect(
          app.extension<SidikMaterial>()!.kertasTepi,
          isNot(beku.extension<SidikMaterial>()!.kertasTepi),
        );
        expect(
          app.inputDecorationTheme.enabledBorder,
          isNot(isA<UnderlineInputBorder>()),
        );
        expect(
          beku.inputDecorationTheme.enabledBorder,
          isA<UnderlineInputBorder>(),
        );
      }
    });
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

double _radiusIsian(InputBorder? b) {
  expect(b, isA<OutlineInputBorder>(), reason: 'isian harus kotak');

  return (b! as OutlineInputBorder).borderRadius.topLeft.x;
}
