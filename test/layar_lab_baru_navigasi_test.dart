import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/app.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/audit_log_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/providers/logo_organisasi_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/providers/platform_provider.dart';
import 'package:sidik_calibration/providers/technician_provider.dart';
import 'package:sidik_calibration/screens/audit/audit_log_screen.dart';
import 'package:sidik_calibration/screens/settings/buat_teknisi_screen.dart';
import 'package:sidik_calibration/screens/settings/kelola_lab_screen.dart';
import 'package:sidik_calibration/screens/settings/logo_organisasi_screen.dart';
import 'package:sidik_calibration/services/audit_log_service.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/logo_organisasi_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/technician_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'support/lewati_onboarding.dart';

/// Pintu menuju tiga layar lab baru (Buat akun teknisi, Logo kop sertifikat,
/// Riwayat perubahan). Layar tujuannya diuji di berkas masing-masing; yang
/// dijaga di sini cuma: pintunya ADA untuk yang berhak, TIDAK ADA untuk yang
/// tidak, dan membuka layar yang benar.
///
/// Token mock: 1 admin · 2 teknisi · 5 super admin.
List<Override> _override(String token, Izin izin) => [
  lewatiOnboarding,
  tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
  authServiceProvider.overrideWithValue(MockAuthService()),
  izinServiceProvider.overrideWithValue(MockIzinService(izin: izin)),
  auditLogServiceProvider.overrideWithValue(MockAuditLogService()),
  logoOrganisasiServiceProvider.overrideWithValue(MockLogoOrganisasiService()),
  technicianServiceProvider.overrideWithValue(MockTechnicianService()),
];

Widget _kelolaLab(String token, {Izin izin = Izin.kosong}) {
  return ProviderScope(
    overrides: _override(token, izin),
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const KelolaLabScreen(),
    ),
  );
}

Future<void> _pasangKelolaLab(
  WidgetTester tester,
  String token, {
  Izin izin = Izin.kosong,
}) async {
  // Tinggi: ListView tidak membangun pintu di bawah lipatan layar.
  await tester.binding.setSurfaceSize(const Size(800, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_kelolaLab(token, izin: izin));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

const _pintuBaru = [
  'Buat akun teknisi',
  'Logo kop sertifikat',
  'Riwayat perubahan',
];

Future<void> _muatFont() async {
  final inter = FontLoader('Inter');
  for (final b in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter-$b.ttf').readAsBytesSync();
    inter.addFont(Future.value(bytes.buffer.asByteData()));
  }
  await inter.load();
}

void main() {
  setUpAll(_muatFont);

  group('Kelola lab', () {
    for (final (token, siapa) in [
      ('mock-token-1', 'admin'),
      ('mock-token-5', 'super admin'),
    ]) {
      testWidgets('$siapa: ketiga pintu baru ada, di grup yang benar', (
        tester,
      ) async {
        await _pasangKelolaLab(tester, token);

        for (final judul in _pintuBaru) {
          expect(find.text(judul), findsOneWidget, reason: judul);
        }
        // Grup baru khusus pengawasan; pintu lama tidak dipindah.
        expect(find.text('PENGAWASAN'), findsOneWidget);
        expect(find.text('Data Teknisi'), findsOneWidget);
        expect(find.text('Tanda Tangan Sertifikat'), findsOneWidget);
        expect(find.text('Data Organisasi'), findsOneWidget);
      });
    }

    testWidgets('teknisi tanpa izin dari server: tidak ada pintu baru', (
      tester,
    ) async {
      await _pasangKelolaLab(tester, 'mock-token-2');

      for (final judul in _pintuBaru) {
        expect(find.text(judul), findsNothing, reason: judul);
      }
      // Grup yang kosong tidak digambar (kartu kosong dengan judul saja).
      expect(find.text('PENGAWASAN'), findsNothing);
    });

    testWidgets(
      'pintu mengikuti /me/permissions: izin dari server membukanya',
      (tester) async {
        await _pasangKelolaLab(
          tester,
          'mock-token-2',
          izin: const Izin(
            role: UserRole.teknisi,
            boleh: {
              NamaIzin.teknisiKelola,
              NamaIzin.organisasiLogo,
              NamaIzin.penggunaKelola,
            },
          ),
        );

        for (final judul in _pintuBaru) {
          expect(find.text(judul), findsOneWidget, reason: judul);
        }
      },
    );

    for (final (judul, tipe) in <(String, Type)>[
      ('Buat akun teknisi', BuatTeknisiScreen),
      ('Logo kop sertifikat', LogoOrganisasiScreen),
      ('Riwayat perubahan', AuditLogScreen),
    ]) {
      testWidgets('pintu "$judul" membuka layarnya', (tester) async {
        await _pasangKelolaLab(tester, 'mock-token-1');
        await tester.ensureVisible(find.text(judul));
        await tester.pumpAndSettle();
        await tester.tap(find.text(judul));
        await tester.pumpAndSettle();

        expect(find.byType(tipe), findsOneWidget);
      });
    }
  });

  group('Panel desktop', () {
    List<Override> desktop(String token) => [
      ..._override(token, Izin.kosong),
      pakaiPanelDesktopProvider.overrideWithValue(true),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      notificationServiceProvider.overrideWithValue(
        MockNotificationService(jeda: Duration.zero),
      ),
      equipmentServiceProvider.overrideWithValue(MockEquipmentService()),
    ];

    testWidgets(
      'admin: sidebar memuat ketiganya; klik membuka layar di area kerja',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: desktop('mock-token-1'),
            child: const SidikApp(),
          ),
        );
        await tester.pumpAndSettle();

        for (final judul in _pintuBaru) {
          expect(find.text(judul), findsOneWidget, reason: judul);
        }

        await tester.tap(find.text('Riwayat perubahan'));
        await tester.pumpAndSettle();
        expect(find.byType(AuditLogScreen), findsOneWidget);
        expect(find.text('users #2'), findsOneWidget);

        await tester.tap(find.text('Buat akun teknisi'));
        await tester.pumpAndSettle();
        expect(find.byType(BuatTeknisiScreen), findsOneWidget);

        await tester.tap(find.text('Logo kop sertifikat'));
        await tester.pumpAndSettle();
        expect(find.byType(LogoOrganisasiScreen), findsOneWidget);
      },
    );

    // K-49-14: super admin memegang semua aksi admin, termasuk ketiganya.
    // Izin dari server tetap penjaganya; di sini cadangan `hakAdmin` yang
    // dipakai karena izin mock kosong.
    testWidgets('super admin: sidebar memuat ketiganya dan layarnya terbuka', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: desktop('mock-token-5'),
          child: const SidikApp(),
        ),
      );
      await tester.pumpAndSettle();

      for (final judul in _pintuBaru) {
        expect(find.text(judul), findsOneWidget, reason: judul);
      }

      await tester.tap(find.text('Riwayat perubahan'));
      await tester.pumpAndSettle();
      expect(find.byType(AuditLogScreen), findsOneWidget);
      expect(find.text('users #2'), findsOneWidget);
    });

    testWidgets('teknisi di desktop: tidak ada satu pun dari ketiganya', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: desktop('mock-token-2'),
          child: const SidikApp(),
        ),
      );
      await tester.pumpAndSettle();

      for (final judul in _pintuBaru) {
        expect(find.text(judul), findsNothing, reason: judul);
      }
    });
  });
}
