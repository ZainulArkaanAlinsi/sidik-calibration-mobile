import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidik_calibration/core/config/app_config.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/services/simpanan_alamat_server.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_studio/inti/lingkungan_studio.dart';
import 'package:sidik_studio/inti/penimpaan.dart';

import 'pembantu/studio_uji.dart';

/// Pengaturan dev "Alamat server" (S1b butir 6): tablet di lab bisa
/// diarahkan ke laptop pengembang lewat Wi-Fi tanpa adb. HANYA build
/// `APP_ENV=dev`; build rilis tidak menampilkan isiannya dan tidak membaca
/// nilai tersimpannya.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('normalisasi', () {
    test('http(s) + host diterima, garis miring akhir dibuang; selain itu '
        'ditolak', () {
      expect(
        normalisasiAlamatServer(' http://192.168.1.10:8000/api/ '),
        'http://192.168.1.10:8000/api',
      );
      expect(
        normalisasiAlamatServer('https://sidik.example/api'),
        'https://sidik.example/api',
      );
      for (final salah in [
        '',
        '192.168.1.10:8000/api',
        'ftp://host/api',
        'http:///api',
        'http://host/api?x=1',
      ]) {
        expect(normalisasiAlamatServer(salah), isNull, reason: salah);
      }
    });
  });

  group('saat start', () {
    test('build dev membaca nilai tersimpan; build rilis TIDAK', () async {
      final simpanan = MemoriSimpananAlamatServer('http://10.0.0.5:8000/api/');
      expect(
        await bacaAlamatServerDevAwal(simpanan: simpanan, dev: true),
        'http://10.0.0.5:8000/api',
      );
      expect(
        await bacaAlamatServerDevAwal(simpanan: simpanan, dev: false),
        isNull,
      );
      // Nilai rusak di disk tidak menghalangi Studio terbuka.
      expect(
        await bacaAlamatServerDevAwal(
          simpanan: MemoriSimpananAlamatServer('bukan url'),
          dev: true,
        ),
        isNull,
      );
    });

    test('nilai awal menimpa API_BASE_URL hanya bila build dev', () {
      ProviderContainer wadah({required bool dev}) {
        final w = ProviderContainer(
          overrides: [
            isianServerDevStudioProvider.overrideWithValue(dev),
            alamatServerDevAwalProvider.overrideWithValue(
              'http://10.0.0.5:8000/api',
            ),
          ],
        );
        addTearDown(w.dispose);
        return w;
      }

      expect(
        wadah(dev: true).read(alamatServerStudioProvider),
        'http://10.0.0.5:8000/api',
      );
      expect(
        wadah(dev: false).read(alamatServerStudioProvider),
        AppConfig.apiBaseUrl,
      );
    });

    test('ApiClient Studio benar-benar menembak alamat dev (server '
        'loopback)', () async {
      HttpOverrides.global = null;
      final masuk = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        await req.drain<void>();
        masuk.add(req.uri.path);
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));
        await req.response.close();
      });

      final wadah = ProviderContainer(
        overrides: [
          ...penimpaanStudio,
          isianServerDevStudioProvider.overrideWithValue(true),
          alamatServerDevAwalProvider.overrideWithValue(
            'http://127.0.0.1:${server.port}/api',
          ),
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        ],
      );
      addTearDown(wadah.dispose);

      await wadah.read(apiClientProvider).get('/health');
      expect(masuk, ['/api/health']);
    });
  });

  group('layar masuk', () {
    testWidgets('build rilis: isian alamat server TIDAK tampil', (
      tester,
    ) async {
      await pasangUkuran(tester, const Size(1280, 800));
      await tester.pumpWidget(studioUji(meja: true));
      await tenang(tester);
      expect(find.byKey(const ValueKey('isian-server-dev')), findsNothing);
    });

    testWidgets('build dev: alamat salah ditolak; alamat sah disimpan dan '
        'langsung dipakai; "Pakai bawaan" mengembalikan', (tester) async {
      final simpanan = MemoriSimpananAlamatServer();
      await pasangUkuran(tester, const Size(1280, 900));
      await tester.pumpWidget(
        studioUji(
          meja: true,
          isianServerDev: true,
          alamatServer: null,
          tambahan: [
            simpananAlamatServerDevProvider.overrideWithValue(simpanan),
          ],
        ),
      );
      await tenang(tester);

      final isian = find.descendant(
        of: find.byKey(const ValueKey('isian-server-dev')),
        matching: find.byType(TextField),
      );
      expect(isian, findsOneWidget);
      expect(find.text(AppConfig.apiBaseUrl), findsOneWidget);

      await tester.enterText(isian, '192.168.1.10:8000/api');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Simpan'));
      await tenang(tester);
      expect(
        find.text('Pakai http:// atau https:// dengan host.'),
        findsOneWidget,
      );
      expect(await simpanan.baca(), isNull);

      await tester.enterText(isian, 'http://192.168.1.10:8000/api/');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Simpan'));
      await tenang(tester);
      expect(await simpanan.baca(), 'http://192.168.1.10:8000/api');
      expect(
        wadahDari(tester).read(alamatServerStudioProvider),
        'http://192.168.1.10:8000/api',
      );
      // Teks server di bawah tombol masuk ikut berganti.
      expect(
        find.text('Server 192.168.1.10:8000 · Studio $versiStudio'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Pakai bawaan'));
      await tenang(tester);
      expect(await simpanan.baca(), isNull);
      expect(
        wadahDari(tester).read(alamatServerStudioProvider),
        AppConfig.apiBaseUrl,
      );
    });
  });
}
