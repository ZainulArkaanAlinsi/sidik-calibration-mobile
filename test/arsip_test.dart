import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/arsip_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/screens/arsip/arsip_screen.dart';
import 'package:sidik_calibration/services/arsip_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

Widget _app({bool gagal = false}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      arsipServiceProvider.overrideWithValue(MockArsipService(gagal: gagal)),
    ],
    child: const MaterialApp(
      locale: Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ArsipScreen(),
    ),
  );
}

void main() {
  testWidgets('daftar folder perusahaan muncul dengan ringkasan isinya', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('PT Tirta Gracia'), findsOneWidget);
    expect(find.text('PT Contoh Sejahtera'), findsOneWidget);
    expect(find.text('2 alat · 1 sertifikat'), findsOneWidget);
  });

  testWidgets('cari perusahaan nyaring daftarnya', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Tirta');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('PT Tirta Gracia'), findsOneWidget);
    expect(find.text('PT Contoh Sejahtera'), findsNothing);
  });

  testWidgets('buka perusahaan → masuk folder akarnya, isinya kelihatan', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('PT Tirta Gracia'));
    await tester.pumpAndSettle();

    // Subfolder + berkas, dua-duanya di satu daftar.
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('012-CAL-524'), findsOneWidget);
  });

  testWidgets('folder akar dikunci — nggak ada menu rename/hapus', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Tirta Gracia'));
    await tester.pumpAndSettle();

    // Yang kelihatan cuma subfolder "2026" yang bukan akar → satu menu titik
    // tiga. Folder akar sendiri nggak dirender sebagai baris di dalam dirinya.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('bikin folder baru → nongol di daftar', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Tirta Gracia'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Folder baru'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Semester 1');
    await tester.tap(find.text('BUAT'));
    await tester.pumpAndSettle();

    expect(find.text('Folder dibuat.'), findsOneWidget);
    expect(find.text('Semester 1'), findsOneWidget);
  });

  testWidgets('nama folder kembar ditolak, pesannya dari backend', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Tirta Gracia'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Folder baru'));
    await tester.pumpAndSettle();
    // "2026" udah ada di folder ini.
    await tester.enterText(find.byType(TextField).last, '2026');
    await tester.tap(find.text('BUAT'));
    await tester.pumpAndSettle();

    // Pesannya sengaja diambil apa adanya dari server, bukan ditulis ulang
    // di mobile — biar nggak ada dua versi kalimat yang bisa beda.
    expect(
      find.text('Di folder ini udah ada folder dengan nama yang sama.'),
      findsOneWidget,
    );
  });

  testWidgets('folder berisi: opsi hapus dimatiin', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Tirta Gracia'));
    await tester.pumpAndSettle();

    // Bikin dulu subfolder di dalam "2026" biar dia nggak kosong.
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Folder baru'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Semester 1');
    await tester.tap(find.text('BUAT'));
    await tester.pumpAndSettle();

    // Balik ke folder akar, buka menu "2026" — sekarang dia ada isinya.
    // `pageBack()` nyari tombol Cupertino; app ini Material, jadi pakai
    // BackButton yang dipasang AppBar.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Tombolnya dimatiin duluan, bukan nunggu ditolak 422 waktu dipencet.
    expect(find.text('Pindahin atau hapus isinya dulu.'), findsOneWidget);
    expect(find.text('Hapus'), findsNothing);
  });

  testWidgets('hapus folder kosong lewat konfirmasi', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Tirta Gracia'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();

    expect(find.text('Hapus folder ini?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Folder dihapus.'), findsOneWidget);
    expect(find.text('2026'), findsNothing);
  });

  testWidgets('server mati → pesan gagal + tombol coba lagi', (tester) async {
    await tester.pumpWidget(_app(gagal: true));
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat arsip.'), findsOneWidget);
    expect(find.text('COBA LAGI'), findsOneWidget);
  });
}
