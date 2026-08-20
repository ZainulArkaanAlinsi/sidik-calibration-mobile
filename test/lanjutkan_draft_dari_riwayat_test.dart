import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Draft yang disimpen teknisi harus bisa DITERUSIN, bukan cuma dibaca.
///
/// **Jalan buntu nyata.** Tombol "SIMPAN SEBAGAI DRAFT" itu janji "lanjut
/// nanti", dan `PUT /api/calibrations/{id}` di kontrak emang nyebut "nerusin
/// draft" (`docs/kontrak-api.md` §4). Tapi di layar detail, status `draft`
/// nggak pernah masuk daftar status yang dikasih tombol buka-lembar — jadi
/// lembar setengah jadi kebuka sebagai halaman baca-doang.
///
/// Satu-satunya pintu yang ada cuma layar Alur Kerja, dan di HP menu itu cuma
/// muncul buat admin (`main_shell.dart`) — jadi buat teknisi, yang justru
/// paling butuh, draftnya beneran nggak ada jalan lanjutnya.
class _ServiceDraft extends MockHistoryService {
  _ServiceDraft({required this.status});

  final CalibrationStatus status;

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    final asli = await super.ambilDetail(token, id);

    return CalibrationDetail(
      id: asli.id,
      namaAlat: asli.namaAlat,
      namaTeknisi: asli.namaTeknisi,
      tanggalKalibrasi: asli.tanggalKalibrasi,
      status: status,
    );
  }
}

/// Pasang layar detail sebagai [token] (`mock-token-2` = teknisi Andi).
///
/// Urutan pump-nya nggak bisa dibalik. Tombolnya baru nge-`watch` `authProvider`
/// SESUDAH detail sesi kemuat dan isinya ke-build, jadi jeda 600 ms
/// `MockAuthService.me()` mulainya di situ — bukan di awal. Kalau 700 ms-nya
/// dilewatin duluan, timernya nyangkut waktu tree dibuang dan test-nya gagal
/// dengan "A Timer is still pending". Sama kayak `certificate_test`.
Future<void> _pasang(
  WidgetTester tester, {
  required CalibrationStatus status,
  required String token,
}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(token)),
        authServiceProvider.overrideWithValue(MockAuthService()),
        historyServiceProvider.overrideWithValue(_ServiceDraft(status: status)),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CalibrationDetailScreen(calibrationId: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('teknisi bisa nerusin draftnya sendiri dari layar detail', (
    tester,
  ) async {
    await _pasang(
      tester,
      status: CalibrationStatus.draft,
      token: 'mock-token-2',
    );

    expect(find.text('LANJUTKAN DRAFT'), findsOneWidget);

    await tester.tap(find.text('LANJUTKAN DRAFT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Inti test: lembarnya kebuka DENGAN `sesiId` — tanpa itu tombolnya cuma
    // bikin sesi kedua yang kosong, dan isian yang tadi ditinggal di draft
    // hilang buat selamanya.
    final lembar = tester.widget<LembarKerjaScreen>(
      find.byType(LembarKerjaScreen),
    );
    expect(lembar.sesiId, 1);
  });

  testWidgets('admin juga dapat pintu yang sama di draft', (tester) async {
    await _pasang(
      tester,
      status: CalibrationStatus.draft,
      token: 'mock-token-1',
    );

    expect(find.text('LANJUTKAN DRAFT'), findsOneWidget);
  });

  testWidgets('teknisi TETAP nggak dikasih tombol di menunggu_approval', (
    tester,
  ) async {
    await _pasang(
      tester,
      status: CalibrationStatus.menungguApproval,
      token: 'mock-token-2',
    );

    // Bukan kelalaian: backend nolak teknisi di status ini dengan 422, dan
    // mancing orang ke tombol yang pasti ditolak bikin dia ngira app-nya rusak.
    expect(find.text('EDIT LEMBAR'), findsNothing);
    expect(find.text('LANJUTKAN DRAFT'), findsNothing);
  });
}
