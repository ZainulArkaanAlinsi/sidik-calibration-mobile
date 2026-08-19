import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/models/autoclave_hasil.dart';
import 'package:sidik_calibration/providers/autoclave_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/screens/calibration/autoclave_input_screen.dart';
import 'package:sidik_calibration/services/autoclave_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Service palsu — Autoklaf nggak ngitung di mobile, jadi test flow cukup
/// mastiin: isi angka → tekan Hitung → panel hasil dari backend kerender.
class _FakeAutoclaveService implements AutoclaveService {
  Map<String, dynamic>? terakhir;

  @override
  Future<AutoclaveHasil> pratinjau(
    String token,
    Map<String, dynamic> payload,
  ) async {
    terakhir = payload;
    return AutoclaveHasil.fromJson({
      'data': {
        'set_point': 121.0,
        'suhu': {
          'indikator_rata': 121.0,
          'sensor': [
            {
              'no': 1,
              'standar_terkoreksi': 121.396,
              'koreksi': 0.396,
              'delta_t': 0.02,
            },
          ],
          'kestabilan': 0.045,
          'keseragaman': 0.464,
          'variasi': 0.10,
          'k': 1.9713602363081708,
          'u95': 0.4419439029528431,
        },
      },
    });
  }
}

Widget _bungkus(_FakeAutoclaveService fake) {
  return ProviderScope(
    overrides: [
      autoclaveServiceProvider.overrideWithValue(fake),
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token'),
      ),
    ],
    child: const MaterialApp(home: AutoclaveInputScreen()),
  );
}

void main() {
  // Layar tinggi (ListView) — viewport besar biar semua anak kerender tanpa
  // scroll, jadi tombol Hitung & panel hasil ketemu finder.
  void besar(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('isi angka → Hitung → panel hasil suhu kerender', (tester) async {
    besar(tester);
    final fake = _FakeAutoclaveService();
    await tester.pumpWidget(_bungkus(fake));

    // Field ke-0 = Set Point (prefilled 121), ke-1 = Disk 1 titik waktu 1.
    await tester.enterText(find.byType(TextField).at(1), '121.27');
    await tester.tap(find.widgetWithText(FilledButton, 'Hitung'));
    await tester.pumpAndSettle();

    expect(fake.terakhir, isNotNull);
    expect(fake.terakhir!['set_point'], 121.0);
    expect(fake.terakhir!.containsKey('suhu'), isTrue);

    expect(find.text('A) Sebaran Suhu'), findsOneWidget);
    expect(find.text('B) Kinerja Autoklaf'), findsOneWidget);
    // Keseragaman 0,464 — nilai keputusan final (bukan 0,466 master lama).
    expect(find.textContaining('0.464'), findsWidgets);
  });

  testWidgets('tanpa Set Point → error, nggak manggil service', (tester) async {
    besar(tester);
    final fake = _FakeAutoclaveService();
    await tester.pumpWidget(_bungkus(fake));

    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Hitung'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Set Point wajib'), findsOneWidget);
    expect(fake.terakhir, isNull);
  });
}
