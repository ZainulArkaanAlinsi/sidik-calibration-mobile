import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/penerbitan_ditahan.dart';
import 'package:sidik_calibration/models/validasi.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/admin/perhitungan_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/app_button.dart';

import 'support/riwayat_ditahan_uji.dart';

/// Penerbitan ditahan menunggu Technical Manager (PR #280) di layar
/// Perhitungan/Setujui.
///
/// Teks alasan dan rujukan disalin dari respons API NYATA (uji kontrak app-API
/// 19 Nov 2026, `kontrak/hasil/dart-ditahan.json`, DT-D-proving_ring dan
/// DT-P-proving_ring). Mock di sini hanya mengantar JSON yang sama bentuknya.
Widget _app(
  MockPerhitunganService perhitungan,
  RiwayatSesiDitahan riwayat, {
  CalibrationStatus? status = CalibrationStatus.menungguApproval,
}) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-1'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService()),
    perhitunganServiceProvider.overrideWithValue(perhitungan),
    historyServiceProvider.overrideWithValue(riwayat),
    standardServiceProvider.overrideWithValue(MockStandardService()),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PerhitunganScreen(calibrationId: 30, statusSesi: status),
  ),
);

Future<void> _muat(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1400, 4400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

AppButton _tombol(WidgetTester tester, String label) =>
    tester.widget<AppButton>(find.widgetWithText(AppButton, label));

final _banner = find.byKey(const ValueKey('banner-penerbitan-ditahan'));
final _dialog = find.byKey(const ValueKey('dialog-penerbitan-ditahan'));
final _petunjuk = find.byKey(const ValueKey('petunjuk-setujui-ditahan'));

void main() {
  group('banner dan tombol Setujui', () {
    testWidgets('ditahan: banner memuat alasan + rujukan TM, Setujui mati dan '
        'tidak mengirim apa pun', (tester) async {
      final svc = MockPerhitunganService();
      await _muat(
        tester,
        _app(svc, RiwayatSesiDitahan(() => ditahanProvingRingUji)),
      );

      expect(_banner, findsOneWidget);
      expect(find.text('Penerbitan ditahan'), findsOneWidget);
      expect(find.text(alasanProvingRingUji), findsOneWidget);
      expect(find.text('Rujukan TM: TM-4'), findsOneWidget);
      expect(_petunjuk, findsOneWidget);

      expect(_tombol(tester, 'Setujui').onPressed, isNull);
      // Periksa tetap hidup: hitung ulang boleh kapan saja.
      expect(_tombol(tester, 'Periksa').onPressed, isNotNull);

      await tester.tap(find.text('Setujui'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        svc.aksi.where((a) => a.$1 == 'setujui'),
        isEmpty,
        reason: 'tombol mati tidak boleh mengirim approve',
      );
    });

    testWidgets('server yang juga menahan lewat /validasi (temuan error): '
        'kalimat merah menjelaskan, petunjuk tidak digandakan, tombol mati', (
      tester,
    ) async {
      // Kontrak PR #280: GET /validasi memuat penahanannya sebagai temuan
      // `error` berkode `menunggu_keputusan_tm` dan boleh_terbit false.
      final svc = MockPerhitunganService(
        validasi: const HasilValidasi(
          valid: false,
          bolehTerbit: false,
          temuan: [
            Temuan(
              tingkat: TingkatTemuan.error,
              kode: 'menunggu_keputusan_tm',
              pesan: 'Ditahan menunggu keputusan Technical Manager (TM-4).',
            ),
          ],
          ringkasan: {
            TingkatTemuan.error: 1,
            TingkatTemuan.peringatan: 0,
            TingkatTemuan.info: 0,
          },
        ),
      );
      await _muat(
        tester,
        _app(svc, RiwayatSesiDitahan(() => ditahanProvingRingUji)),
      );

      expect(_banner, findsOneWidget);
      expect(
        find.textContaining('Ada temuan yang nahan penerbitan'),
        findsOneWidget,
      );
      expect(_petunjuk, findsNothing);
      expect(_tombol(tester, 'Setujui').onPressed, isNull);
    });

    testWidgets('tidak ditahan: tidak ada banner dan Setujui hidup', (
      tester,
    ) async {
      await _muat(
        tester,
        _app(
          MockPerhitunganService(),
          RiwayatSesiDitahan(() => PenerbitanDitahan.tidak),
        ),
      );

      expect(_banner, findsNothing);
      expect(_petunjuk, findsNothing);
      expect(_tombol(tester, 'Setujui').onPressed, isNotNull);
    });

    testWidgets('sesi yang sudah tidak bisa diputuskan tidak memajang banner', (
      tester,
    ) async {
      await _muat(
        tester,
        _app(
          MockPerhitunganService(),
          RiwayatSesiDitahan(() => ditahanProvingRingUji),
          status: CalibrationStatus.disetujui,
        ),
      );

      expect(_banner, findsNothing);
    });

    testWidgets('"Baca alasan lengkap" membuka dialog dengan alasan utuh', (
      tester,
    ) async {
      await _muat(
        tester,
        _app(
          MockPerhitunganService(),
          RiwayatSesiDitahan(() => ditahanProvingRingUji),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('baca-alasan-ditahan')));
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(find.byKey(const ValueKey('alasan-dialog')), findsOneWidget);
      expect(find.text(alasanProvingRingUji), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('tutup-dialog-ditahan')));
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
    });

    testWidgets('Periksa membaca ulang penahanan: TM melepas, banner hilang '
        'dan Setujui hidup lagi', (tester) async {
      var kini = ditahanProvingRingUji;
      final riwayat = RiwayatSesiDitahan(() => kini);
      await _muat(tester, _app(MockPerhitunganService(), riwayat));
      expect(_banner, findsOneWidget);
      final sebelum = riwayat.panggilDetail;

      kini = PenerbitanDitahan.tidak;
      await tester.tap(find.text('Periksa'));
      await tester.pumpAndSettle();

      expect(riwayat.panggilDetail, greaterThan(sebelum));
      expect(_banner, findsNothing);
      expect(_tombol(tester, 'Setujui').onPressed, isNotNull);
    });
  });

  group('422 profil_ditahan dari klien yang datanya basi', () {
    testWidgets('dialog yang terbaca, bukan SnackBar; banner menyusul dari '
        'detail yang dibaca ulang', (tester) async {
      // Detail awal belum tahu soal penahanan (klien lama / data basi); server
      // sudah menahan, jadi approve ditolak dan bacaan berikutnya ikut ditahan.
      var serverMenahan = false;
      final svc = MockPerhitunganService(
        penerbitanDitahan: ditahanProvingRingUji,
      );
      final riwayat = RiwayatSesiDitahan(
        () => serverMenahan ? ditahanProvingRingUji : PenerbitanDitahan.tidak,
      );
      await _muat(tester, _app(svc, riwayat));
      expect(_banner, findsNothing);
      expect(_tombol(tester, 'Setujui').onPressed, isNotNull);

      serverMenahan = true;
      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('isian-nomor-sertifikat')),
        'CAL/KT/H-proving_ring',
      );
      await tester.tap(find.byKey(const ValueKey('simpan-setujui')));
      await tester.pumpAndSettle();

      // Server menjawab 422: dialog penjelasan, bukan SnackBar panjang.
      expect(_dialog, findsOneWidget);
      expect(find.text('Penerbitan sertifikat ditahan'), findsOneWidget);
      expect(find.text(alasanProvingRingUji), findsWidgets);
      expect(find.text('Rujukan TM: TM-4'), findsWidgets);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tutup-dialog-ditahan')));
      await tester.pumpAndSettle();

      // Layar tetap terbuka (status sesi tidak berubah) dan kini ikut server.
      expect(find.byType(PerhitunganScreen), findsOneWidget);
      expect(_banner, findsOneWidget);
      expect(_tombol(tester, 'Setujui').onPressed, isNull);
      expect(svc.aksi.where((a) => a.$1 == 'setujui').length, 1);
      // Hasil pemeriksaan dibaca ulang sesudah dialog (pemeriksaan otomatis
      // saat layar dibuka + satu lagi), supaya tidak ada "Aman disetujui" yang
      // basi di bawah banner yang menahan.
      expect(svc.aksi.where((a) => a.$1 == 'periksa').length, 2);
    });
  });
}
