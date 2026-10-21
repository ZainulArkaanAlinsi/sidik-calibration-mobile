import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/services/pembaru_windows.dart';
import 'package:sidik_calibration/widgets/banner_pembaruan_windows.dart';
import 'package:sidik_studio/inti/lingkungan_studio.dart';
import 'package:sidik_studio/layar/beranda/beranda_screen.dart';

import 'pembantu/studio_uji.dart';

/// Studio memakai mesin `PembaruWindows` paket bersama dengan manifest
/// SENDIRI, dan memberi tahu di cangkang kalau rilis baru siap dipasang.
void main() {
  setUpAll(muatFontStudio);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('manifest Studio terpisah dari manifest app lapangan', () {
    expect(urlManifestStudio, endsWith('/versi-studio-windows.json'));
    expect(urlManifestStudio, isNot(PembaruWindows.urlManifestBawaan));
  });

  testWidgets('cangkang menampilkan "siap — mulai ulang" bila ada unduhan', (
    tester,
  ) async {
    await pasangUkuran(tester, const Size(1280, 800));
    final pembaru = PembaruWindows(
      urlManifest: urlManifestStudio,
      folderKerja: Directory('tidak-dipakai'),
      fileExe: File('sidik_studio.exe'),
      versiTerpasang: () async => '0.1.0',
    );

    await tester.pumpWidget(
      studioUji(
        meja: true,
        token: 'mock-token-1',
        tambahan: [pembaruWindowsProvider.overrideWithValue(pembaru)],
      ),
    );
    await tenang(tester);
    expect(find.byType(BerandaScreen), findsOneWidget);
    expect(find.byKey(const Key('banner_pembaruan_windows')), findsNothing);

    pembaru.versiSiap.value = '0.1.900';
    await tenang(tester);

    expect(find.byType(BannerPembaruanWindows), findsOneWidget);
    expect(find.byKey(const Key('banner_pembaruan_windows')), findsOneWidget);
    expect(find.textContaining('0.1.900'), findsOneWidget);
  });
}
