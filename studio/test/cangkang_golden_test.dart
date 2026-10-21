import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_studio/inti/lingkungan_studio.dart';
import 'package:sidik_studio/layar/beranda/beranda_screen.dart';
import 'package:sidik_studio/widget/bilah_status.dart';

import 'pembantu/studio_uji.dart';

/// Golden cangkang final (ST-T-011): tiga lebar FR-STU-011 × terang/gelap.
///
/// | lebar | perangkat | navigasi |
/// |---|---|---|
/// | 1280 × 800 | Windows | sidebar 240 + bilah status |
/// | 1138 × 711 | tablet lanskap | rail 72 berlabel + menu akun |
/// | 711 × 1138 | tablet potret | rail 56 ikon + menu akun |
///
/// Isi: Beranda admin (Budi, "Master Data") dengan kartu data acuan dari
/// `MockDataAcuanService`. Dibuat di Windows — lihat
/// `test/flutter_test_config.dart` soal platform acuan.
///
/// Perbarui: `flutter test test/cangkang_golden_test.dart --update-goldens`
/// (di Windows), lalu PERIKSA gambarnya sebelum disimpan.
void main() {
  setUpAll(muatFontStudio);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (nama, mode) in const [
    ('terang', ThemeMode.light),
    ('gelap', ThemeMode.dark),
  ]) {
    testWidgets(
      '1280 Windows — $nama',
      (tester) async {
        await _pompa(tester, const Size(1280, 800), meja: true, mode: mode);
        expect(find.byType(BilahStatus), findsOneWidget);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/cangkang-1280-$nama.png'),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets('1138 tablet lanskap — $nama', (tester) async {
      await _pompa(tester, const Size(1138, 711), mode: mode);
      expect(find.byType(NavigationRail), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/cangkang-1138-$nama.png'),
      );
    });

    testWidgets('711 tablet potret — $nama', (tester) async {
      await _pompa(tester, const Size(711, 1138), mode: mode);
      expect(find.byType(NavigationRail), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/cangkang-711-$nama.png'),
      );
    });
  }
}

Future<void> _pompa(
  WidgetTester tester,
  Size ukuran, {
  bool meja = false,
  required ThemeMode mode,
}) async {
  await pasangUkuran(tester, ukuran);
  await tester.pumpWidget(
    studioUji(
      meja: meja,
      token: 'mock-token-1',
      tambahan: [modeTemaStudioProvider.overrideWith(() => _TemaTetap(mode))],
    ),
  );
  await tenang(tester);
  expect(find.byType(BerandaScreen), findsOneWidget);

  // Ikon merek dimuat dari bundel secara asinkron sungguhan; tanpa precache
  // golden memotret kotak kosong.
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      final gambar = (e.widget as Image).image;
      await precacheImage(gambar, e);
    }
  });
  await tenang(tester);
}

class _TemaTetap extends ModeTemaStudio {
  _TemaTetap(this.mode);

  final ThemeMode mode;

  @override
  ThemeMode build() => mode;
}
