import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/validasi.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/screens/admin/perhitungan_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

HasilValidasi _validasi({
  int error = 0,
  int peringatan = 0,
  int info = 0,
  List<Temuan> temuan = const [],
}) => HasilValidasi(
  valid: error == 0 && peringatan == 0,
  bolehTerbit: error == 0,
  temuan: temuan,
  ringkasan: {
    TingkatTemuan.error: error,
    TingkatTemuan.peringatan: peringatan,
    TingkatTemuan.info: info,
  },
);

Widget _app(MockPerhitunganService service) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      perhitunganServiceProvider.overrideWithValue(service),
      standardServiceProvider.overrideWithValue(MockStandardService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PerhitunganScreen(calibrationId: 1),
    ),
  );
}

void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _muat(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  group('lembar PERHITUNGAN dirender apa adanya', () {
    testWidgets('empat blok sheet PERHITUNGAN muncul', (tester) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockPerhitunganService()));

      expect(find.text('IDENTITAS ALAT'), findsOneWidget);
      expect(find.text('IDENTITAS CUSTOMER'), findsOneWidget);
      expect(find.text('PERHITUNGAN KONDISI LINGKUNGAN'), findsOneWidget);
      expect(find.text('DATA HASIL KALIBRASI'), findsOneWidget);

      expect(find.text('Before Adjustment Reading'), findsOneWidget);
      expect(find.text('After Adjustment Reading'), findsOneWidget);
    });

    testWidgets('angka ditampilkan dari server, bukan dihitung ulang', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockPerhitunganService()));

      // Nilai Standard = nilai buffer pada suhu larutan (4,0092252 di 22,2 °C),
      // BUKAN nominal 4,00. Ini angka asli dari PERHITUNGAN.csv.
      expect(find.text('4.0092252'), findsOneWidget);
      expect(find.text('6.9885032'), findsOneWidget);

      // U95% Sertifikat suhu TH-3, hasil akar(1,7² + 0,2²).
      expect(find.text('1.7117'), findsOneWidget);
    });

    testWidgets('dua catatan tanda & nilai standar ikut ditampilkan', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(tester, _app(MockPerhitunganService()));

      // Correction di lembar ini kebalikan dari sertifikat — kalau catatan ini
      // ilang, cepat atau lambat ada yang salah baca tandanya.
      expect(
        find.textContaining('Correction = Average − Standard'),
        findsOneWidget,
      );
      expect(
        find.textContaining('nilai buffer pada suhu larutan'),
        findsOneWidget,
      );
    });

    testWidgets('kolom yang belum kehitung nampil strip, bukan nol', (
      tester,
    ) async {
      _perbesarViewport(tester);
      await _muat(
        tester,
        _app(MockPerhitunganService(thermohygroBelumDipilih: true)),
      );

      // Koreksi 0 itu hasil pengukuran; koreksi kosong itu data sertifikat
      // thermohygro yang belum diisi. Dua hal beda.
      expect(find.text('—'), findsWidgets);
      expect(
        find.textContaining('Belum dipilih'),
        findsOneWidget,
      );
    });
  });

  group('alur periksa & setujui', () {
    testWidgets('Periksa nampilin temuan tanpa nyetujuin', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService(
        validasi: _validasi(
          info: 1,
          temuan: const [
            Temuan(
              tingkat: TingkatTemuan.info,
              kode: 'nomor_order_kosong',
              pesan: 'Order Number belum diisi.',
            ),
          ],
        ),
      );
      await _muat(tester, _app(service));

      await tester.tap(find.text('PERIKSA'));
      await tester.pumpAndSettle();

      expect(find.text('Order Number belum diisi.'), findsOneWidget);
      expect(service.aksi, contains(('periksa', 1)));
      // Periksa NGGAK boleh ikut nyetujuin.
      expect(service.aksi.any((a) => a.$1 == 'setujui'), isFalse);
    });

    testWidgets('temuan error mematikan tombol Setujui', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService(
        validasi: _validasi(
          error: 1,
          temuan: const [
            Temuan(
              tingkat: TingkatTemuan.error,
              kode: 'belum_ada_hitungan',
              pesan: 'Belum ada titik yang kehitung.',
            ),
          ],
        ),
      );
      await _muat(tester, _app(service));

      await tester.tap(find.text('PERIKSA'));
      await tester.pumpAndSettle();

      expect(find.textContaining('nahan penerbitan'), findsWidgets);

      // Temuan fatal nahan approve TANPA SYARAT — tombolnya mati, bukan cuma
      // dikasih peringatan.
      final tombol = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('SETUJUI'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(tombol.onTap, isNull);
    });

    testWidgets('peringatan: ditolak sekali, muncul dialog, lalu lanjut', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService(
        validasi: _validasi(
          peringatan: 1,
          temuan: const [
            Temuan(
              tingkat: TingkatTemuan.peringatan,
              kode: 'hitung_ulang_beda',
              pesan: 'Hasil hitung ulang beda dari yang tersimpan.',
            ),
          ],
        ),
      );
      await _muat(tester, _app(service));

      await tester.tap(find.text('SETUJUI'));
      await tester.pumpAndSettle();

      // Percobaan pertama HARUS ditolak dengan dialog konfirmasi.
      expect(find.text('Hasil hitung ulang beda. Lanjut?'), findsOneWidget);
      expect(service.aksi, contains(('setujui', false)));

      await tester.tap(find.text('TETAP SETUJUI'));
      await tester.pumpAndSettle();

      // Percobaan kedua bawa abaikan_peringatan: true.
      expect(service.aksi, contains(('setujui', true)));
    });

    testWidgets('batal di dialog peringatan = nggak jadi disetujui', (
      tester,
    ) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService(
        validasi: _validasi(peringatan: 1),
      );
      await _muat(tester, _app(service));

      await tester.tap(find.text('SETUJUI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PERIKSA LAGI'));
      await tester.pumpAndSettle();

      expect(service.aksi, contains(('setujui', false)));
      expect(service.aksi, isNot(contains(('setujui', true))));
    });

    testWidgets('sesi bersih langsung disetujui tanpa dialog', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService();
      await _muat(tester, _app(service));

      await tester.tap(find.text('SETUJUI'));
      await tester.pumpAndSettle();

      expect(service.aksi, contains(('setujui', false)));
      expect(find.text('Hasil hitung ulang beda. Lanjut?'), findsNothing);
    });
  });

  group('tolak', () {
    testWidgets('catatan kosong nggak dikirim ke server', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService();
      await _muat(tester, _app(service));

      await tester.tap(find.text('TOLAK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('KEMBALIKAN'));
      await tester.pumpAndSettle();

      expect(service.aksi.any((a) => a.$1 == 'tolak'), isFalse);
      expect(
        find.textContaining('Tulis dulu apa yang harus dibenerin'),
        findsOneWidget,
      );
    });

    testWidgets('catatan terisi kekirim apa adanya', (tester) async {
      _perbesarViewport(tester);
      final service = MockPerhitunganService();
      await _muat(tester, _app(service));

      await tester.tap(find.text('TOLAK'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Buffer 7 cuma 2 bacaan.');
      await tester.tap(find.text('KEMBALIKAN'));
      await tester.pumpAndSettle();

      expect(service.aksi, contains(('tolak', 'Buffer 7 cuma 2 bacaan.')));
    });
  });

  group('model validasi', () {
    test('tingkat asing dianggap info — nggak nahan apa-apa', () {
      final t = Temuan.fromJson({
        'tingkat': 'sesuatu_yang_baru',
        'kode': 'x',
        'pesan': 'y',
      });
      expect(t.tingkat, TingkatTemuan.info);
    });

    test('perluKonfirmasi cuma waktu boleh terbit tapi nggak valid', () {
      expect(_validasi(peringatan: 1).perluKonfirmasi, isTrue);
      expect(_validasi(error: 1).perluKonfirmasi, isFalse);
      expect(_validasi().perluKonfirmasi, isFalse);
      expect(_validasi(info: 3).perluKonfirmasi, isFalse);
    });
  });
}
