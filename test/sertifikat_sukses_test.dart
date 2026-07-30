import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/app.dart';
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

Widget _app() {
  return ProviderScope(
    overrides: [
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
    child: const SidikApp(),
  );
}

Future<void> _sampaiRiwayat(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Riwayat'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('setujui → lembar sertifikat langsung kebuka', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _sampaiRiwayat(tester);

    await tester.tap(find.text('SETUJUI').first);
    await tester.pumpAndSettle();

    expect(find.text('Sertifikat berhasil dibuat'), findsOneWidget);
  });

  testWidgets('lembarnya bawa semua cara ngeluarin & ngebagiin', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _sampaiRiwayat(tester);
    await tester.tap(find.text('SETUJUI').first);
    await tester.pumpAndSettle();

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

    await _sampaiRiwayat(tester);
    await tester.tap(find.text('SETUJUI').first);
    await tester.pumpAndSettle();

    // Ini yang dulu bikin popup-nya nggak pernah muncul: `approve` balikinnya
    // `certificate_id` doang, nomor sertifikatnya NGGAK ikut. Jadi sheet-nya
    // wajib bisa jalan tanpa dikasih nomor dari pemanggil.
    expect(find.text('…'), findsNothing, reason: 'nomornya nggak ketarik');
  });

  testWidgets('buka modal QR dari lembarnya', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _sampaiRiwayat(tester);
    await tester.tap(find.text('SETUJUI').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kode QR'));
    await tester.pumpAndSettle();

    expect(find.text('QR Sertifikat'), findsOneWidget);
    expect(find.text('Simpan PNG'), findsOneWidget);
  });
}
