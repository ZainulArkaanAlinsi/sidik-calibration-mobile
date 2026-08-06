import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/folder_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/screens/folder/folder_manager_screen.dart';
import 'package:sidik_calibration/services/folder_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/services/pdf_downloader.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// **Bug asli:** baris berkas di Folder Manager itu `ListTile` tanpa `onTap`,
/// tanpa tombol, tanpa menu — ditekan nggak terjadi apa-apa. Sertifikat yang
/// udah rapi kefolder per PT jadi nggak bisa dibuka maupun dibagikan dari
/// sana, padahal semua bahannya udah ada dan udah kepakai di layar Sertifikat.
///
/// Yang dikunci di sini: barisnya **bisa ditekan**, penekanannya **beneran
/// nembak unduhan**, dan sertifikat dapat aksi **Bagikan**.
Widget _app(PdfDownloader unduh) => ProviderScope(
  overrides: [
    // `mock-token-1` = admin — yang punya hak arsip.
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-1'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService()),
    folderServiceProvider.overrideWithValue(MockFolderService()),
    notificationServiceProvider.overrideWithValue(MockNotificationService()),
    pdfDownloaderProvider.overrideWithValue(unduh),
  ],
  child: const MaterialApp(
    locale: Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // Folder 11 = folder yang isinya satu sertifikat (lihat MockFolderService).
    home: FolderManagerScreen(folderId: 11, judul: '2026'),
  ),
);

Future<void> _muat(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  // `MockAuthService.me()` jeda 600 ms lewat `Future.delayed`, dan timer kayak
  // gitu nggak ngejadwalin frame — `pumpAndSettle` doang balik duluan.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('baris berkas BISA ditekan & beneran nembak unduhan', (
    tester,
  ) async {
    final unduh = MockPdfDownloader();
    await _muat(tester, _app(unduh));

    final baris = find.text('012-CAL-524.pdf');
    expect(baris, findsOneWidget, reason: 'berkas sertifikat mestinya kerender');

    // Inti regresinya: sebelum diperbaiki `onTap`-nya null, jadi `lastUrl`
    // tetap null berapa kali pun ditekan.
    final tile = find.ancestor(of: baris, matching: find.byType(ListTile));
    expect(tester.widget<ListTile>(tile).onTap, isNotNull,
        reason: 'baris berkas harus bisa ditekan');

    await tester.tap(baris);

    // Sengaja BUKAN `pumpAndSettle`: selama mengunduh barisnya nampilin
    // `CircularProgressIndicator` yang beranimasi terus, jadi nggak pernah
    // "settle" dan pumpAndSettle bakal timeout.
    for (var i = 0; i < 40 && unduh.lastUrl == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      unduh.lastUrl,
      'https://contoh/folder-files/101/download',
      reason: 'penekanan harus nembak download_url berkasnya',
    );

    // Biarin alurnya kelar supaya spinner berhenti sebelum teardown.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('sertifikat dapat aksi Buka & Bagikan', (tester) async {
    await _muat(tester, _app(MockPdfDownloader()));

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('Buka berkas'), findsOneWidget);
    expect(
      find.text('Bagikan sertifikat'),
      findsOneWidget,
      reason: 'berkas sertifikat punya id, jadi bisa dikirim ke pelanggan',
    );
  });
}
