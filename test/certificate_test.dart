import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/history/certificate_screen.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pdf_downloader.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Datanya (nomor, status, `pdf_url`) sekarang datang dari
/// `calibrationDetailProvider` (`GET /api/calibrations/{id}`), bukan
/// endpoint sertifikat sendiri — lihat komentar di
/// `certificate_screen.dart`. Sesi id 1 di `MockHistoryService` punya
/// `certificateId: 901` & `nomorSertifikat: 'CAL/2026/07/0001'`.
Widget _app({bool gagal = false}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      historyServiceProvider.overrideWithValue(
        MockHistoryService(gagal: gagal),
      ),
      approvalServiceProvider.overrideWithValue(MockApprovalService()),
      pdfDownloaderProvider.overrideWithValue(MockPdfDownloader()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CertificateScreen(calibrationId: 1),
    ),
  );
}

void main() {
  testWidgets('nampilin nomor sertifikat & tombol lihat PDF', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('CAL/2026/07/0001'), findsOneWidget);
    expect(find.text('LIHAT PDF'), findsOneWidget);
  });

  testWidgets('gagal muat → pesan + tombol coba lagi', (tester) async {
    await tester.pumpWidget(_app(gagal: true));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat sertifikat.'), findsOneWidget);
    expect(find.text('COBA LAGI'), findsOneWidget);
  });
}
