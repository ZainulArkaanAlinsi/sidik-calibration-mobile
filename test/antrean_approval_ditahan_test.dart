import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/perhitungan_provider.dart';
import 'package:sidik_calibration/screens/admin/antrean_approval_screen.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/perhitungan_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

import 'support/antrean_ditahan_uji.dart';
import 'support/riwayat_ditahan_uji.dart';

/// Setujui di KARTU Antrean Approval untuk jenis alat yang penerbitannya
/// ditahan (PR #280). Layar Perhitungan sudah punya banner dan dialog; kartu
/// antrean adalah satu-satunya jalur approve lain, dan dulu jatuh ke SnackBar
/// ~370 karakter SETELAH admin mengetik Order Number dan No. Sertifikat.
///
/// Badan 422 disalin dari API NYATA (uji kontrak 19 Nov 2026,
/// `kontrak/hasil/dart-ditahan.json` DT-P-proving_ring).
void main() {
  testWidgets('422 profil_ditahan di kartu antrean: dialog yang terbaca, '
      'bukan SnackBar; kartu tetap menunggu keputusan', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final approval = ApprovalDitahanUji();
    final antrean = AntreanSatuUji();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          historyServiceProvider.overrideWithValue(antrean),
          approvalServiceProvider.overrideWithValue(approval),
          perhitunganServiceProvider.overrideWithValue(
            MockPerhitunganService(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AntreanApprovalScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Admin mengetik nomor seperti biasa, lalu server menahan.
    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('isian-nomor-sertifikat')),
      'CAL/KT/H-proving_ring',
    );
    await tester.tap(find.byKey(const ValueKey('simpan-setujui')));
    await tester.pumpAndSettle();

    expect(approval.panggilan, 1);
    expect(
      find.byKey(const ValueKey('dialog-penerbitan-ditahan')),
      findsOneWidget,
    );
    expect(find.text('Penerbitan sertifikat ditahan'), findsOneWidget);
    expect(find.text(alasanProvingRingUji), findsWidgets);
    expect(find.text('Rujukan TM: TM-4'), findsWidgets);
    // Bukan lagi kalimat server ~370 karakter di SnackBar.
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tutup-dialog-ditahan')));
    await tester.pumpAndSettle();

    // Status sesi tidak berubah: kartu masih ada dan Setujui masih tersedia.
    expect(
      find.byKey(const ValueKey('dialog-penerbitan-ditahan')),
      findsNothing,
    );
    expect(find.text('Proving Ring'), findsWidgets);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // Detail sesi dibaca ulang sesudah penahanan terungkap: Setujui yang
    // berikutnya mengambilnya dari server lagi (bukan dari salinan lama).
    final sebelum = antrean.panggilDetail;
    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    expect(antrean.panggilDetail, greaterThan(sebelum));
  });
}
