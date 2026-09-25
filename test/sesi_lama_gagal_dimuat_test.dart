import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// **Sesi lama yang gagal dimuat tidak boleh ditimpa tanpa sepengetahuan
/// teknisi.**
///
/// Chaos review 25 Sep 2026. `_muatSesiLama` dulu menelan galatnya: formulir
/// kosong kelihatan persis seperti draft yang memang kosong, dan simpan dari
/// situ menimpa isian di server — termasuk catatan, merk, nomor seri, dan
/// pemilik, karena PUT sengaja mengirim `null` eksplisit.
///
/// Yang TIDAK boleh ikut berubah: formulirnya tetap bisa diisi dan disimpan.
/// Karena itu yang diuji tiga arah — kelihatan, bisa dicoba lagi, dan tetap
/// bisa disimpan secara sadar.
void main() {
  Future<MockLembarKerjaService> buka(
    WidgetTester tester,
    HistoryService riwayat,
  ) async {
    tester.view.physicalSize = const Size(1400, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final lembar = MockLembarKerjaService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          historyServiceProvider.overrideWithValue(riwayat),
          lembarKerjaServiceProvider.overrideWithValue(lembar),
          standardServiceProvider.overrideWithValue(MockStandardService()),
          roomServiceProvider.overrideWithValue(MockRoomService()),
          equipmentLookupServiceProvider.overrideWithValue(
            MockEquipmentLookupService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LembarKerjaScreen(profil: 'ph_meter', sesiId: 72),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    return lembar;
  }

  final banner = find.textContaining('belum berhasil dimuat');
  final dialog = find.text('Isian lama belum termuat');

  Finder diDialog(String teks) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(teks));

  testWidgets('gagal dimuat: banner kelihatan, muat ulang memulihkan', (
    tester,
  ) async {
    final riwayat = _GagalSekali();
    await buka(tester, riwayat);

    expect(banner, findsOneWidget, reason: 'Formulir kosong tanpa penanda.');

    await tester.tap(find.text('Muat ulang'));
    await tester.pumpAndSettle();

    expect(
      riwayat.panggilan,
      2,
      reason: 'Galat lama masih ter-cache — muat ulang tidak menarik ulang.',
    );
    expect(banner, findsNothing);
  });

  testWidgets('simpan waktu gagal dimuat: minta konfirmasi, muat ulang '
      'membatalkan simpan', (tester) async {
    final riwayat = _GagalSekali();
    final lembar = await buka(tester, riwayat);

    await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
    await tester.pumpAndSettle();

    expect(dialog, findsOneWidget);

    await tester.tap(diDialog('Muat ulang'));
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
    expect(lembar.jumlahKirim, 0, reason: 'Isian di server ditimpa.');
    expect(riwayat.panggilan, 2);
    expect(banner, findsNothing);
  });

  testWidgets('simpan tetap: jalan kerja tidak ditutup', (tester) async {
    await buka(tester, _SelaluGagal());

    await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
    await tester.pumpAndSettle();
    await tester.tap(diDialog('Simpan tetap'));
    await tester.pumpAndSettle();

    // Lanjut ke pemeriksaan berikutnya, bukan berhenti di dialog: alat belum
    // kepulihkan, jadi yang muncul pesan pilih alat.
    expect(dialog, findsNothing);
    expect(find.textContaining('Pilih alatnya dulu'), findsOneWidget);
    expect(banner, findsOneWidget, reason: 'Penandanya tetap ada.');
  });

  testWidgets('berhasil dimuat: nol banner, simpan tanpa dialog tambahan', (
    tester,
  ) async {
    await buka(tester, _SelaluBerhasil());

    expect(banner, findsNothing);

    await tester.tap(find.text('SIMPAN SEBAGAI DRAFT'));
    await tester.pumpAndSettle();

    expect(dialog, findsNothing);
  });
}

Map<String, dynamic> _sesi() => {
  'id': 72,
  'nomor_sesi': 'DEMO-GAGAL',
  'tanggal_kalibrasi': '2026-09-24T00:00:00.000Z',
  'status': 'draft',
  'desimal': 2,
  'equipment': {'nama_alat': 'pH Meter'},
  'teknisi': {'nama': 'Teknisi Sidik'},
  'hasil': {'keputusan': null},
  'titik': const <Map<String, dynamic>>[],
  'pembacaan_mentah': const <Map<String, dynamic>>[],
};

/// Sinyal putus sekali, lalu pulih.
class _GagalSekali extends MockHistoryService {
  int panggilan = 0;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    panggilan++;
    if (panggilan == 1) throw Exception('simulasi: sinyal putus');

    return CalibrationDetail.fromJson(_sesi());
  }
}

class _SelaluGagal extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      throw Exception('simulasi: server tidak terjangkau');
}

class _SelaluBerhasil extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(_sesi());
}
