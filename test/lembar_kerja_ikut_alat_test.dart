import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Bentuk lembar kerja harus ngikut ALAT yang dipilih, bukan cuma jenis alatnya.
///
/// `equipmentId` di kunci provider dulu dipatok `null` — komentarnya sendiri
/// bilang "plumbing-nya siap sampai service, tapi penyambungannya belum". Jadi
/// backend SELALU ngirim bentuk generik.
///
/// Buat Conductivity itu bukan soal kosmetik: bentuk generik keluar 4 baris
/// dengan dua varian titik tengah (`1412 µS/cm` dan `1,412 mS/cm`) yang saling
/// ngunci, sementara alat pelanggan cuma punya salah satunya. Sesi 53
/// (12 Agt 2026) kejeblos persis di situ — teknisi ngisi 1413 di baris
/// `1,412 mS/cm`, baris yang buat alat itu nggak ada, dan backend ngitung
/// Error 1413 − 1,412 = 1411,588 lalu ngirimnya ke admin.
void main() {
  Widget app(MockLembarKerjaService service, {String profil = 'ph_meter'}) {
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        lembarKerjaServiceProvider.overrideWithValue(service),
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
        home: LembarKerjaScreen(profil: profil),
      ),
    );
  }

  Future<void> muat(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  Future<void> pilihAlat(WidgetTester tester) async {
    await tester.tap(find.text('Pilih alat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pH Meter Mettler Toledo · B628755900').last);
    await tester.pumpAndSettle();
  }

  testWidgets('bentuk pertama ditarik tanpa alat — belum ada yang dipilih', (
    tester,
  ) async {
    final service = MockLembarKerjaService();
    await muat(tester, app(service));

    // Bisa lebih dari sekali: provider-nya `watch(authProvider)`, dan auth
    // beres belakangan. Yang dikunci di sini isinya, bukan jumlahnya.
    expect(service.equipmentIdDiminta, everyElement(isNull));
  });

  testWidgets('milih alat narik ulang bentuk PAKAI equipment_id', (
    tester,
  ) async {
    final service = MockLembarKerjaService();
    await muat(tester, app(service));

    final sebelum = service.equipmentIdDiminta.length;
    await pilihAlat(tester);

    // 14 = pH Meter Mettler Toledo di MockEquipmentLookupService.
    expect(service.equipmentIdDiminta.last, 14);
    expect(
      service.equipmentIdDiminta.length,
      greaterThan(sebelum),
      reason: 'milih alat harus narik bentuk baru, bukan pakai yang generik',
    );
  });

  testWidgets('milih alat yang sama nggak narik bentuk berulang-ulang', (
    tester,
  ) async {
    final service = MockLembarKerjaService();
    await muat(tester, app(service));
    await pilihAlat(tester);

    final sesudahPilih = service.equipmentIdDiminta.length;

    // Tiap ketikan di formulir manggil `onBerubah`; yang di atas mesti nyaring
    // sendiri kalau id-nya nggak berubah. Tanpa penyaring itu, tiap huruf yang
    // diketik teknisi bikin satu permintaan bentuk ke backend.
    await tester.enterText(find.byType(TextField).first, 'ABC-123');
    await tester.pumpAndSettle();

    expect(service.equipmentIdDiminta.length, sesudahPilih);
  });

  testWidgets('formulir & alat yang dipilih tetap ada sesudah bentuk ditukar', (
    tester,
  ) async {
    final service = MockLembarKerjaService();
    await muat(tester, app(service));
    await pilihAlat(tester);

    // Ganti alat = kunci provider baru = mulai dari `loading`. Kalau layar
    // balik jadi spinner, `_Form` ke-unmount dan SELURUH isian ilang —
    // termasuk alat yang barusan dipilih.
    expect(find.byType(TextField), findsWidgets);
    expect(
      find.text('pH Meter Mettler Toledo · B628755900'),
      findsWidgets,
      reason: 'alat yang barusan dipilih nggak boleh ilang dari dropdown',
    );
  });
}
