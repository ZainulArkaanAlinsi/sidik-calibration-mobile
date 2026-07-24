import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/folder_provider.dart';
import 'package:sidik_calibration/screens/folder/folder_manager_screen.dart';
import 'package:sidik_calibration/services/folder_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/notification_service.dart';
import 'package:sidik_calibration/providers/notification_provider.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// `mock-token-1` = Admin, `mock-token-2` = Teknisi (lihat MockAuthService).
Widget _app(MockFolderService service, {required String token}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      folderServiceProvider.overrideWithValue(service),
      notificationServiceProvider.overrideWithValue(MockNotificationService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const FolderManagerScreen(),
    ),
  );
}

Future<void> _muat(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  // MockAuthService.me() jeda 600 ms lewat Future.delayed, dan timer kayak gitu
  // nggak ngejadwalin frame — `pumpAndSettle` doang balik duluan.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  group('hak tulis folder', () {
    testWidgets('teknisi nggak dikasih tombol tulis sama sekali', (
      tester,
    ) async {
      await _muat(
        tester,
        _app(MockFolderService(), token: 'mock-token-2'),
      );

      // Backend nolak teknisi dengan 403 — nampilin tombolnya cuma bikin dia
      // nyoba lalu ditolak.
      expect(find.text('Folder baru'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('admin dapat tombol buat + menu per folder', (tester) async {
      await _muat(
        tester,
        _app(MockFolderService(), token: 'mock-token-1'),
      );

      expect(find.text('Folder baru'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsWidgets);
    });
  });

  group('folder sistem dilindungi', () {
    testWidgets('folder sistem nggak dikasih "Ganti nama"', (tester) async {
      await _muat(
        tester,
        _app(MockFolderService(), token: 'mock-token-1'),
      );

      // Folder pertama = PT TIRTA GRACIA, tipe `sistem`.
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      // Namanya dipakai backend buat nemuin folder yang udah ada — direname,
      // sertifikat berikutnya bikin folder baru dan arsipnya kepecah dua.
      expect(find.text('Ganti nama'), findsNothing);
      expect(
        find.text('Kebentuk otomatis — namanya ngikut PT/tahun, '
            'nggak bisa diubah.'),
        findsOneWidget,
      );
      // Hapus tetap ada: folder sistem yang udah KOSONG boleh dibuang.
      expect(find.text('Hapus'), findsOneWidget);
    });

    testWidgets('folder manual dapat "Ganti nama"', (tester) async {
      await _muat(
        tester,
        _app(MockFolderService(), token: 'mock-token-1'),
      );

      // Folder ketiga = "Arsip Lama", tipe `manual`.
      await tester.tap(find.byIcon(Icons.more_vert).at(2));
      await tester.pumpAndSettle();

      expect(find.text('Ganti nama'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);
    });
  });

  group('aksi tulis', () {
    testWidgets('buat folder nembak service dengan namanya', (tester) async {
      final service = MockFolderService();
      await _muat(tester, _app(service, token: 'mock-token-1'));

      await tester.tap(find.text('Folder baru'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Arsip 2025');
      await tester.tap(find.text('SIMPAN'));
      await tester.pumpAndSettle();

      expect(service.aksi, contains(('buat', 'Arsip 2025')));
    });

    testWidgets('nama kosong nggak dikirim ke server', (tester) async {
      final service = MockFolderService();
      await _muat(tester, _app(service, token: 'mock-token-1'));

      await tester.tap(find.text('Folder baru'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SIMPAN'));
      await tester.pumpAndSettle();

      expect(service.aksi, isEmpty);
      expect(find.text('Isi nama foldernya dulu.'), findsOneWidget);
    });

    testWidgets('hapus minta konfirmasi dulu', (tester) async {
      final service = MockFolderService();
      await _muat(tester, _app(service, token: 'mock-token-1'));

      await tester.tap(find.byIcon(Icons.more_vert).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(find.text('Hapus folder ini?'), findsOneWidget);

      // Batal = nggak ada yang kehapus.
      await tester.tap(find.text('BATAL'));
      await tester.pumpAndSettle();
      expect(service.aksi, isEmpty);

      await tester.tap(find.byIcon(Icons.more_vert).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HAPUS'));
      await tester.pumpAndSettle();

      expect(service.aksi, contains(('hapus', 3)));
    });

    testWidgets('gagal dari server ditampilin apa adanya', (tester) async {
      // Backend yang paling tau konteksnya ("folder otomatis yang masih ada
      // isinya nggak bisa dihapus") — jangan diganti pesan generik.
      final service = MockFolderService(gagal: true);
      await _muat(tester, _app(service, token: 'mock-token-1'));

      // Daftar foldernya sendiri ikut gagal, jadi yang diperiksa layar error.
      expect(find.text('Gagal memuat folder.'), findsOneWidget);
      expect(find.text('COBA LAGI'), findsOneWidget);
    });
  });
}
