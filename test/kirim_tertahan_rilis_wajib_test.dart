import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_draft.dart';
import 'package:sidik_calibration/models/versi_aplikasi.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/versi_provider.dart';
import 'package:sidik_calibration/screens/calibration/calibration_input_screen.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/versi_service.dart';

/// Rilis WAJIB menahan PENGIRIMAN, bukan layarnya.
///
/// Keputusan 4 Sep 2026, alasan lengkapnya di `kirimTertahanRilisWajibProvider`.
/// `wajib` didefinisikan sebagai "versi lama diam-diam mengirim data yang
/// salah", jadi yang ditahan langkah yang tidak bisa ditarik balik — bukan
/// pekerjaan teknisinya.
///
/// Yang diadu di sini bukan pesannya, tapi **apakah datanya benar-benar tidak
/// sampai ke service.** Mengassert SnackBar saja bisa hijau sambil sesinya
/// tetap terkirim: pesan muncul, `return` kelupaan, dan tidak ada yang tahu.
class _ServicePencatat implements CalibrationService {
  int panggilan = 0;
  bool? draftTerakhir;

  @override
  Future<int> buatSesi(String token, CalibrationDraft draft) async {
    panggilan++;
    draftTerakhir = draft.simpanSebagaiDraft;

    return 999;
  }
}

VersiAplikasi _rilis({bool wajib = false}) => VersiAplikasi(
  // Harus lebih baru dari `MockVersiService.terpasang` (1.0.10), kalau tidak
  // `updateTersediaProvider` memulangkan null dan yang diuji bukan lagi
  // rilis wajib, tapi "tidak ada rilis".
  versi: '1.0.60',
  urlUnduh: 'https://contoh/app.apk',
  wajib: wajib,
);

Widget _app({
  required _ServicePencatat service,
  VersiAplikasi? rilis,
  bool versiGagal = false,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      categoryServiceProvider.overrideWithValue(MockCategoryService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      calibrationServiceProvider.overrideWithValue(service),
      versiServiceProvider.overrideWithValue(
        MockVersiService(terbaru: rilis, gagal: versiGagal),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CalibrationInputScreen(),
                ),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ),
  );
}

void _perbesarViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _scrollKe(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _isiFormLengkap(WidgetTester tester) async {
  await tester.tap(find.text('Pilih kategori alat'), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Panjang').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Pilih alat'), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Jangka Sorong Mitutoyo').last);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Pilih standar acuan'), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gauge Block Set Grade 0').last);
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).at(2), '50.0');
  await tester.enterText(find.byType(TextField).at(3), 'mm');
  await tester.enterText(find.byType(TextField).at(4), '50.02');
  await tester.enterText(find.byType(TextField).at(5), '50.01');
}

Future<void> _siapkan(
  WidgetTester tester, {
  required _ServicePencatat service,
  VersiAplikasi? rilis,
  bool versiGagal = false,
}) async {
  _perbesarViewport(tester);
  await tester.pumpWidget(
    _app(service: service, rilis: rilis, versiGagal: versiGagal),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  await _isiFormLengkap(tester);
  await tester.pumpAndSettle();
}

Future<void> _tekan(WidgetTester tester, String label) async {
  final tombol = find.text(label);
  await _scrollKe(tester, tombol);
  await tester.tap(tombol);
  await tester.pumpAndSettle();
}

void main() {
  group('provider penjaganya', () {
    /// Dibaca lewat container langsung, bukan lewat layar: aturannya milik
    /// provider, dan menguji lewat layar bikin kegagalannya bisa datang dari
    /// belasan sebab lain.
    Future<bool> tertahan({VersiAplikasi? rilis, bool gagal = false}) async {
      final container = ProviderContainer(
        overrides: [
          versiServiceProvider.overrideWithValue(
            MockVersiService(terbaru: rilis, gagal: gagal),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateTersediaProvider.future);

      return container.read(kirimTertahanRilisWajibProvider);
    }

    test('rilis wajib → menahan', () async {
      expect(await tertahan(rilis: _rilis(wajib: true)), isTrue);
    });

    test('rilis biasa → tidak menahan', () async {
      expect(await tertahan(rilis: _rilis()), isFalse);
    });

    test('tidak ada rilis → tidak menahan', () async {
      expect(await tertahan(), isFalse);
    });

    test('pengecekan versi gagal → tidak menahan, bukan menahan', () async {
      // Ini yang paling gampang kebalik. Teknisi tanpa sinyal itu justru yang
      // PALING tidak bisa memperbaiki keadaan; menahan pengirimannya karena
      // server versi tidak terjawab menghukum orang yang salah.
      expect(await tertahan(gagal: true), isFalse);
    });
  });

  group('layar isian kalibrasi', () {
    testWidgets('rilis wajib → KIRIM ditolak dan tidak sampai ke service', (
      tester,
    ) async {
      final service = _ServicePencatat();
      await _siapkan(tester, service: service, rilis: _rilis(wajib: true));

      await _tekan(tester, 'KIRIM UNTUK APPROVAL');

      expect(
        find.textContaining('WAJIB dipasang sebelum sesi bisa dikirim'),
        findsOneWidget,
      );
      expect(
        service.panggilan,
        0,
        reason: 'sesinya tetap terkirim padahal pesan penahannya muncul — '
            'pesan tanpa `return` itu penjagaan yang cuma kelihatan',
      );
    });

    testWidgets('rilis wajib → SIMPAN DRAFT tetap jalan', (tester) async {
      // Inti keputusannya. Kalau ini merah, yang dibangun bukan penahan
      // pengiriman melainkan pengunci layar — dan pekerjaan teknisi di lokasi
      // pelanggan hilang.
      final service = _ServicePencatat();
      await _siapkan(tester, service: service, rilis: _rilis(wajib: true));

      await _tekan(tester, 'SIMPAN DRAFT');

      expect(service.panggilan, 1);
      expect(service.draftTerakhir, isTrue);
    });

    testWidgets('rilis biasa → KIRIM tidak terhalang', (tester) async {
      final service = _ServicePencatat();
      await _siapkan(tester, service: service, rilis: _rilis());

      await _tekan(tester, 'KIRIM UNTUK APPROVAL');

      expect(service.panggilan, 1);
      expect(service.draftTerakhir, isFalse);
    });

    testWidgets('tidak ada rilis → KIRIM tidak terhalang', (tester) async {
      // Bersama test di atas, dua ini yang menjaga penjaganya TIDAK NAIK
      // PANGKAT jadi "semua pengiriman ditahan". Tanpa keduanya, penjaga yang
      // kelewat rajin tetap hijau.
      final service = _ServicePencatat();
      await _siapkan(tester, service: service);

      await _tekan(tester, 'KIRIM UNTUK APPROVAL');

      expect(service.panggilan, 1);
    });
  });
}
