import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/screens/admin/antrean_approval_screen.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/certificate_provider.dart';
import 'package:sidik_calibration/providers/dashboard_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/certificate_service.dart';
import 'package:sidik_calibration/services/dashboard_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'support/lewati_onboarding.dart';

Widget _app() {
  return ProviderScope(
    overrides: [
      lewatiOnboarding,
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      dashboardServiceProvider.overrideWithValue(
        MockDashboardService(jeda: Duration.zero),
      ),
      historyServiceProvider.overrideWithValue(MockHistoryService()),
      approvalServiceProvider.overrideWithValue(MockApprovalService()),
      certificateServiceProvider.overrideWithValue(MockCertificateService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AntreanApprovalScreen(),
    ),
  );
}

/// Tombol SETUJUI hidup di Antrean Approval, BUKAN di Riwayat (keputusan
/// pemilik proyek 16 Sep 2026: riwayat itu daftar bacaan).
Future<void> _sampaiAntrean(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('setujui → lembar sertifikat langsung kebuka', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _sampaiAntrean(tester);

    await tester.tap(find.text('SETUJUI').first);
    // `pump` berjangka, BUKAN `pumpAndSettle`: sesudah disetujui, antreannya
    // ditarik ulang dan loader-nya berputar terus — `pumpAndSettle` menunggu
    // animasi yang memang tidak pernah berhenti.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sertifikat berhasil dibuat'), findsOneWidget);
  });

  testWidgets('lembarnya bawa semua cara ngeluarin & ngebagiin', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _sampaiAntrean(tester);
    await tester.tap(find.text('SETUJUI').first);
    // `pump` berjangka, BUKAN `pumpAndSettle`: sesudah disetujui, antreannya
    // ditarik ulang dan loader-nya berputar terus — `pumpAndSettle` menunggu
    // animasi yang memang tidak pernah berhenti.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    for (final aksi in [
      'Unduh PDF',
      'Ekspor Excel',
      'Kode QR',
      'Salin tautan verifikasi',
      'Kirim email',
      'Bagikan lewat WhatsApp',
    ]) {
      expect(find.text(aksi), findsOneWidget, reason: 'aksi "$aksi" ilang');
    }
  });

  testWidgets('nomornya ketarik sendiri — approve cuma balikin id', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _sampaiAntrean(tester);
    await tester.tap(find.text('SETUJUI').first);
    // `pump` berjangka, BUKAN `pumpAndSettle`: sesudah disetujui, antreannya
    // ditarik ulang dan loader-nya berputar terus — `pumpAndSettle` menunggu
    // animasi yang memang tidak pernah berhenti.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Ini yang dulu bikin popup-nya nggak pernah muncul: `approve` balikinnya
    // `certificate_id` doang, nomor sertifikatnya NGGAK ikut. Jadi sheet-nya
    // wajib bisa jalan tanpa dikasih nomor dari pemanggil.
    expect(find.text('…'), findsNothing, reason: 'nomornya nggak ketarik');
  });

  testWidgets('buka modal QR dari lembarnya', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _sampaiAntrean(tester);
    await tester.tap(find.text('SETUJUI').first);
    // `pump` berjangka, BUKAN `pumpAndSettle`: sesudah disetujui, antreannya
    // ditarik ulang dan loader-nya berputar terus — `pumpAndSettle` menunggu
    // animasi yang memang tidak pernah berhenti.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Kode QR'));
    // Alasan sama dengan di atas: loader antrean di belakang tidak pernah diam.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('QR Sertifikat'), findsOneWidget);
    expect(find.text('Simpan PNG'), findsOneWidget);
  });
}
