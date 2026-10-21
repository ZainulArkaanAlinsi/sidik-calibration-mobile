import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/pembaru_windows.dart';
import 'package:sidik_calibration/services/penyiap_update.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/versi_service.dart';
import 'package:sidik_calibration/widgets/banner_pembaruan_windows.dart';
import 'package:sidik_calibration/widgets/pemeriksa_pembaruan.dart';

import 'support/lewati_onboarding.dart';

/// Lapisan pembaruan di shell: setiap peran melihat banner, versi dicek ulang
/// berkala (bukan sekali per proses), dan Windows memberi tahu kalau rilis
/// sudah siap dipasang dengan mulai ulang.

const _rilis = VersiAplikasi(
  versi: '1.0.60',
  urlUnduh: 'https://contoh/sidik-1.0.60.apk',
  ukuran: 52428800,
);

class _PenyiapPalsu implements PenyiapUpdate {
  int panggilanSiapkan = 0;

  @override
  Future<File?> apkSiap(String versi) async => null;

  @override
  Future<bool> siapkan(VersiAplikasi rilis) async {
    panggilanSiapkan++;
    return false;
  }
}

/// Menghitung berapa kali server ditanya versi terbaru.
class _VersiServiceBerhitung implements VersiService {
  int panggilan = 0;

  @override
  Future<String> versiTerpasang() async => '1.0.58';

  @override
  Future<String> buildTerpasang() async => '58';

  @override
  Future<VersiAplikasi?> versiTerbaru() async {
    panggilan++;
    return _rilis;
  }
}

class _PembaruPalsu extends PembaruWindows {
  _PembaruPalsu({required this.hasil})
    : super(
        urlManifest: 'https://contoh.web.app/versi-windows-v2.json',
        folderKerja: Directory('tidak-dipakai'),
        fileExe: File('tidak-dipakai.exe'),
        versiTerpasang: () async => '1.0.600',
      );

  final bool hasil;
  int panggilanTerapkan = 0;

  @override
  Future<bool> terapkanKalauSiap() async {
    panggilanTerapkan++;
    return hasil;
  }
}

GiliranPemasangOtomatis _giliranTerpakai() =>
    GiliranPemasangOtomatis()..ambil();

void main() {
  Future<_PenyiapPalsu> pasangShell(
    WidgetTester tester, {
    required int id,
    bool popUp = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final penyiap = _PenyiapPalsu();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lewatiOnboarding,
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-$id'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          dashboardServiceProvider.overrideWithValue(
            MockDashboardService(jeda: Duration.zero),
          ),
          notificationServiceProvider.overrideWithValue(
            MockNotificationService(jeda: Duration.zero),
          ),
          versiServiceProvider.overrideWithValue(
            MockVersiService(terpasang: '1.0.58', terbaru: _rilis),
          ),
          penyiapUpdateProvider.overrideWithValue(penyiap),
          // Tanpa pop-up: giliran sekali-per-proses dianggap sudah terpakai.
          if (!popUp)
            giliranPemasangOtomatisProvider.overrideWithValue(
              _giliranTerpakai(),
            ),
        ],
        child: const SidikApp(),
      ),
    );
    await tester.pumpAndSettle();

    return penyiap;
  }

  testWidgets('teknisi (tanpa tab dashboard) juga mendapat pop-up', (
    tester,
  ) async {
    await pasangShell(tester, id: 2, popUp: true);

    expect(find.byKey(const Key('dialog_update')), findsOneWidget);
  });

  group('banner pembaruan tampil untuk SEMUA peran (shell)', () {
    // id akun di MockAuthService: 1 admin, 2 teknisi, 3 viewer, 5 super admin.
    for (final (id, peran) in [
      (5, 'super admin'),
      (2, 'teknisi'),
      (3, 'viewer'),
      (1, 'admin'),
    ]) {
      testWidgets('$peran melihat banner dan unduhan latar dimulai', (
        tester,
      ) async {
        final penyiap = await pasangShell(tester, id: id);

        expect(find.byType(PemeriksaPembaruan), findsOneWidget);
        expect(find.byKey(const Key('banner_update_pasang')), findsOneWidget);
        expect(find.text('Versi 1.0.60 sudah tersedia'), findsOneWidget);
        expect(
          penyiap.panggilanSiapkan,
          greaterThan(0),
          reason: 'unduhan latar harus jalan tanpa bergantung pada banner',
        );
      });
    }
  });

  group('cek ulang versi', () {
    late DateTime sekarang;
    late _VersiServiceBerhitung layanan;

    Future<void> pasang(WidgetTester tester) async {
      sekarang = DateTime(2026, 10, 22, 8);
      layanan = _VersiServiceBerhitung();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            versiServiceProvider.overrideWithValue(layanan),
            penyiapUpdateProvider.overrideWithValue(_PenyiapPalsu()),
            giliranPemasangOtomatisProvider.overrideWithValue(
              _giliranTerpakai(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PemeriksaPembaruan(
                jam: () => sekarang,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> keLatarLaluKembali(WidgetTester tester) async {
      final b = tester.binding;
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('kembali ke depan < 1 jam: TIDAK cek ulang; >= 1 jam: cek', (
      tester,
    ) async {
      await pasang(tester);
      expect(layanan.panggilan, 1);

      sekarang = sekarang.add(const Duration(minutes: 30));
      await keLatarLaluKembali(tester);
      expect(layanan.panggilan, 1, reason: 'masih dalam jeda 1 jam');

      sekarang = sekarang.add(const Duration(minutes: 31));
      await keLatarLaluKembali(tester);
      expect(layanan.panggilan, 2);

      // Cek barusan menyetel ulang jedanya.
      sekarang = sekarang.add(const Duration(minutes: 10));
      await keLatarLaluKembali(tester);
      expect(layanan.panggilan, 2);
    });

    testWidgets('selama di depan, cek ulang tiap jam', (tester) async {
      await pasang(tester);
      expect(layanan.panggilan, 1);

      await tester.pump(const Duration(hours: 1));
      await tester.pumpAndSettle();
      expect(layanan.panggilan, 2);

      await tester.pump(const Duration(hours: 1));
      await tester.pumpAndSettle();
      expect(layanan.panggilan, 3);
    });
  });

  group('banner Windows "siap — mulai ulang"', () {
    Future<void> pasang(
      WidgetTester tester,
      PembaruWindows? pembaru, {
      VoidCallback? keluar,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jalurApkProvider.overrideWithValue(false),
            pembaruWindowsProvider.overrideWithValue(pembaru),
          ],
          child: MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: BannerPembaruanWindows(keluar: keluar)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const judul = 'Versi 1.0.700 siap — mulai ulang untuk memasang';

    testWidgets('tidak tampil tanpa pembaru (bukan Windows)', (tester) async {
      await pasang(tester, null);
      expect(find.byKey(const Key('banner_pembaruan_windows')), findsNothing);
    });

    testWidgets('tidak tampil sebelum ada versi yang terunduh', (tester) async {
      await pasang(tester, _PembaruPalsu(hasil: true));
      expect(find.byKey(const Key('banner_pembaruan_windows')), findsNothing);
    });

    testWidgets('tampil begitu unduhan siap, dan mulai ulang = keluar', (
      tester,
    ) async {
      final pembaru = _PembaruPalsu(hasil: true);
      var keluar = 0;
      await pasang(tester, pembaru, keluar: () => keluar++);

      pembaru.versiSiap.value = '1.0.700';
      await tester.pumpAndSettle();
      expect(find.text(judul), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('banner_pembaruan_windows_mulai_ulang')),
      );
      await tester.pumpAndSettle();

      expect(pembaru.panggilanTerapkan, 1);
      expect(keluar, 1);
    });

    testWidgets('pemasang tidak menyala: TIDAK keluar, pesan tampil', (
      tester,
    ) async {
      final pembaru = _PembaruPalsu(hasil: false)..versiSiap.value = '1.0.700';
      var keluar = 0;
      await pasang(tester, pembaru, keluar: () => keluar++);

      await tester.tap(
        find.byKey(const Key('banner_pembaruan_windows_mulai_ulang')),
      );
      await tester.pumpAndSettle();

      expect(keluar, 0);
      expect(find.textContaining('belum bisa dipasang'), findsOneWidget);
    });

    testWidgets('"Nanti" menyembunyikan banner', (tester) async {
      final pembaru = _PembaruPalsu(hasil: true)..versiSiap.value = '1.0.700';
      await pasang(tester, pembaru);

      await tester.tap(find.byKey(const Key('banner_pembaruan_windows_tutup')));
      await tester.pumpAndSettle();

      expect(find.text(judul), findsNothing);
    });
  });
}
