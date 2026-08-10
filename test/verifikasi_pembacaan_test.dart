import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Sesi yang pembacaannya dari kamera **tersandera** sampai teknisi ngonfirmasi.
///
/// **Jalan buntu nyata, ketemu 7 Agt 2026.** Pembacaan hasil foto disimpen
/// `is_verified: false`, dan pemeriksaan admin nolak nerbitin sertifikat selama
/// masih ada yang belum dikonfirmasi (`ocr_belum_diverifikasi`). Layar detail
/// UDAH lama nampilin peringatannya — tapi nggak ada satu pun tombol yang
/// manggil `POST /calibrations/{id}/measurements/verify`. Jadi admin mencet
/// Approve dan ditolak terus, sementara teknisi nggak punya cara mbuka.
///
/// Yang diuji di sini bukan peringatannya (itu udah ada dari dulu), tapi bahwa
/// tombolnya BENERAN nembak endpoint-nya. Tombol yang cuma nyembunyiin
/// peringatan justru lebih berbahaya daripada nggak ada tombol sama sekali.
class _ServiceUjiVerifikasi extends MockHistoryService {
  _ServiceUjiVerifikasi();

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async {
    final asli = await super.ambilDetail(token, id);

    return CalibrationDetail(
      id: asli.id,
      namaAlat: asli.namaAlat,
      status: asli.status,
      tanggalKalibrasi: asli.tanggalKalibrasi,
      namaTeknisi: asli.namaTeknisi,
      perluVerifikasi: diverifikasi.isEmpty,
    );
  }
}

void main() {
  testWidgets('tombol konfirmasi pembacaan nembak endpoint verify', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = _ServiceUjiVerifikasi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('token-uji'),
          ),
          historyServiceProvider.overrideWithValue(service),
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

    // Peringatannya tampil, DAN ada jalan keluarnya.
    expect(find.text('Saya sudah cek angkanya'), findsOneWidget);

    await tester.tap(find.text('Saya sudah cek angkanya'));
    await tester.pumpAndSettle();

    // Inti test: endpoint-nya beneran dipanggil buat sesi yang benar.
    expect(
      service.diverifikasi,
      contains(1),
      reason: 'tombolnya nggak manggil verify — admin bakal keblokir terus',
    );
  });
}
