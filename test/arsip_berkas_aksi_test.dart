import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/arsip.dart';
import 'package:sidik_calibration/models/izin.dart';
import 'package:sidik_calibration/models/user.dart';
import 'package:sidik_calibration/providers/arsip_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/izin_provider.dart';
import 'package:sidik_calibration/screens/arsip/arsip_screen.dart';
import 'package:sidik_calibration/services/arsip_service.dart';
import 'package:sidik_calibration/services/izin_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pdf_downloader.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Arsip jadi pintu tunggal: aksi berkas (unduh, kirim, ganti nama) hidup di
/// sini dan lewat `/arsip/*`, bukan `/folders` / `/folder-files`.
Widget _app(MockPdfDownloader unduh, MockArsipService arsip) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-1'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService(jeda: Duration.zero)),
    arsipServiceProvider.overrideWithValue(arsip),
    izinServiceProvider.overrideWithValue(
      MockIzinService(
        izin: Izin(
          role: UserRole.admin,
          boleh: {NamaIzin.sertifikatKirim, NamaIzin.arsipFolderKelola},
        ),
      ),
    ),
    pdfDownloaderProvider.overrideWithValue(unduh),
  ],
  child: const MaterialApp(
    locale: Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: FolderScreen(alamat: AlamatFolder.folder(1), judul: 'PT'),
  ),
);

Future<void> _bukaMenu(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.tap(find.byIcon(Icons.more_horiz));
  await tester.pumpAndSettle();
}

void main() {
  test('parser membaca id berkas, id sertifikat, dan siap_diunduh', () {
    final isi = ArsipIsiFolder.fromJson({
      'data': {
        'id': 1,
        'nama': '2026',
        'file': [
          {
            'id': 30,
            'nama': 'a.pdf',
            'sertifikat': {
              'id': 7,
              'nomor': 'X',
              'status': 'gagal',
              'siap_diunduh': false,
            },
            'lembar_kerja': {'calibration_session_id': 3},
          },
        ],
      },
    });
    final b = isi.berkas.single;
    expect(b.fileId, 30);
    expect(b.sertifikatId, 7);
    // Placeholder `gagal`: punya id sertifikat, tetapi BUKAN terbit.
    expect(b.sertifikatSiap, isFalse);
    expect(b.bisaDiunduh, isFalse);
  });

  testWidgets('unduh berkas lewat /arsip/berkas/{id}/unduh', (tester) async {
    final unduh = MockPdfDownloader();
    await tester.pumpWidget(_app(unduh, MockArsipService()));
    await _bukaMenu(tester);

    await tester.tap(find.text('Buka berkas'));
    // Bukan pumpAndSettle: setelah unduh, penampil berkas bawaan sistem dipanggil.
    await tester.pump(const Duration(milliseconds: 300));

    expect(unduh.lastUrl, endsWith('/arsip/berkas/30/unduh'));
  });

  testWidgets('menu berkas menawarkan Bagikan dan Ganti nama untuk admin', (
    tester,
  ) async {
    final arsip = MockArsipService();
    await tester.pumpWidget(_app(MockPdfDownloader(), arsip));
    await _bukaMenu(tester);

    expect(find.text('Bagikan sertifikat'), findsOneWidget);
    await tester.tap(find.text('Ganti nama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'baru.pdf');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(arsip.namaBerkasBaru, {30: 'baru.pdf'});
    expect(find.text('Nama berkas diubah.'), findsOneWidget);
  });
}
