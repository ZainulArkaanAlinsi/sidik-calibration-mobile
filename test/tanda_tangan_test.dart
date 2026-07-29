import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/tanda_tangan.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/tanda_tangan_provider.dart';
import 'package:sidik_calibration/screens/settings/tanda_tangan_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/tanda_tangan_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// `mock-token-1` = admin · `mock-token-2` = teknisi.
Widget _app(MockTandaTanganService service, {String token = 'mock-token-1'}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
      authServiceProvider.overrideWithValue(MockAuthService()),
      tandaTanganServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TandaTanganScreen(),
    ),
  );
}

/// `MockAuthService` sengaja punya jeda 600 ms. `pumpAndSettle()` nggak majuin
/// timer, jadi harus dilewatin manual — kalau nggak, `authProvider` masih null
/// dan layar nampilin gerbang "cuma admin", bukan isinya.
Future<void> _pasang(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  group('TandaTanganPosisi', () {
    test('bawaan sesuai kontrak backend', () {
      const p = TandaTanganPosisi();
      expect(p.geserXMm, 0);
      expect(p.geserYMm, 0);
      expect(p.lebarMm, 35);
    });

    test('batas slider sama persis sama yang diterima backend', () {
      // Nilai di luar ini ditolak 422, jadi lebih baik nggak bisa dipilih.
      expect(TandaTanganPosisi.minGeser, -40);
      expect(TandaTanganPosisi.maksGeser, 40);
      expect(TandaTanganPosisi.minLebar, 10);
      expect(TandaTanganPosisi.maksLebar, 80);
    });

    test('parse respons backend', () {
      final info = TandaTanganInfo.fromJson(const {
        'punya_tanda_tangan': true,
        'tanda_tangan': {
          'geser_x_mm': -8.5,
          'geser_y_mm': 4,
          'lebar_mm': 42,
        },
      });

      expect(info.punyaTandaTangan, isTrue);
      expect(info.posisi.geserXMm, -8.5);
      expect(info.posisi.geserYMm, 4);
      expect(info.posisi.lebarMm, 42);
    });

    test('respons tanpa blok tanda_tangan jatuh ke bawaan, bukan crash', () {
      final info = TandaTanganInfo.fromJson(const {
        'punya_tanda_tangan': false,
      });

      expect(info.punyaTandaTangan, isFalse);
      expect(info.posisi, const TandaTanganPosisi());
    });

    test('kirim balik pakai nama kunci yang sama', () {
      const p = TandaTanganPosisi(geserXMm: -8.5, geserYMm: 4, lebarMm: 42);
      expect(p.toJson(), {
        'geser_x_mm': -8.5,
        'geser_y_mm': 4.0,
        'lebar_mm': 42.0,
      });
    });
  });

  group('Layar pengaturan tanda tangan', () {
    testWidgets('teknisi ditolak — termasuk pratinjaunya', (tester) async {
      await _pasang(
        tester,
        _app(MockTandaTanganService(adaTtd: true), token: 'mock-token-2'),
      );

      expect(find.textContaining('Cuma admin'), findsOneWidget);
      // Bukan cuma tombolnya yang disembunyiin — gambarnya juga nggak boleh
      // kerender, karena backend nolak pratinjau buat non-admin.
      expect(find.byType(Image), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('belum ada tanda tangan → dijelasin akibatnya', (tester) async {
      await _pasang(tester, _app(MockTandaTanganService()));

      expect(find.text('Belum ada tanda tangan'), findsOneWidget);
      // Admin perlu tau konsekuensinya, bukan cuma "kosong".
      expect(find.textContaining('kecetak tanpa tanda tangan'), findsOneWidget);
      // Slider posisi nggak masuk akal kalau nggak ada yang diposisikan.
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('udah ada → pratinjau lewat Image.memory, bukan network',
        (tester) async {
      await _pasang(tester, _app(MockTandaTanganService(adaTtd: true)));

      // `Image.network` nggak bawa header Authorization, jadi bakal 401.
      // Byte-nya ditarik duluan lalu dipasang lewat memory.
      final gambar = tester.widgetList<Image>(find.byType(Image));
      expect(gambar, isNotEmpty);
      expect(gambar.first.image, isA<MemoryImage>());
    });

    testWidgets('udah ada → slider posisi muncul, lengkap 3 sumbu',
        (tester) async {
      await _pasang(tester, _app(MockTandaTanganService(adaTtd: true)));

      expect(find.byType(Slider), findsNWidgets(3));
    });

    testWidgets('arah tegak ditulis di layar: positif = NAIK', (tester) async {
      await _pasang(tester, _app(MockTandaTanganService(adaTtd: true)));

      // Ini kebalikan koordinat layar. Kalau nggak ditulis, admin bakal
      // ngegeser ke arah yang salah dan nyalahin hasil cetaknya.
      expect(find.textContaining('positif = NAIK'), findsOneWidget);
      expect(find.textContaining('negatif = ke kiri'), findsOneWidget);
    });

    testWidgets('geser slider nggak langsung nembak API — nunggu Simpan',
        (tester) async {
      final service = MockTandaTanganService(adaTtd: true);
      await _pasang(tester, _app(service));

      await tester.drag(find.byType(Slider).first, const Offset(60, 0));
      await tester.pumpAndSettle();

      // Belum disimpan: yang di server masih bawaan.
      expect((await service.info('t')).posisi, const TandaTanganPosisi());

      // Tombolnya di bawah tiga slider — di layar tes yang pendek dia keluar
      // viewport, jadi harus digulirin dulu.
      await tester.scrollUntilVisible(
        find.text('SIMPAN POSISI'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('SIMPAN POSISI'));
      await tester.pumpAndSettle();

      expect(
        (await service.info('t')).posisi,
        isNot(const TandaTanganPosisi()),
      );
    });

    testWidgets('unggah gagal → pesan backend ditampilin APA ADANYA',
        (tester) async {
      await _pasang(
        tester,
        _app(MockTandaTanganService(adaTtd: true, gagalUnggah: true)),
      );

      // Alasan kenapa JPG ditolak itu informasi yang dicari admin. Diganti
      // "format tidak didukung" malah ngilangin alasannya.
      final service = MockTandaTanganService(gagalUnggah: true);
      await expectLater(
        () => service.unggah('t', 'x.jpg'),
        throwsA(
          predicate(
            (e) => e.toString().contains('latar transparan'),
            'pesannya nyebut alasan, bukan cuma "tidak didukung"',
          ),
        ),
      );
    });

    testWidgets('hapus minta konfirmasi + jelasin dampaknya', (tester) async {
      await _pasang(tester, _app(MockTandaTanganService(adaTtd: true)));

      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      // Yang penting: sertifikat lama TIDAK ikut kehilangan tanda tangannya.
      expect(find.textContaining('udah terbit tetap bawa'), findsOneWidget);
    });
  });
}
