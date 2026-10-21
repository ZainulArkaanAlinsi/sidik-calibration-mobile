import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/services/kabar_server_lambat.dart';
import 'package:sidik_calibration/widgets/kabar_server_lambat.dart';

/// Server Render yang bangun dari tidur: layar tidak boleh tampak beku.
void main() {
  test('jawaban cepat tidak memunculkan kabar', () async {
    var kabar = 0;
    final h = await kabariBilaLambat(
      Future.value(7),
      lambat: () => kabar++,
      setelah: const Duration(milliseconds: 50),
    );

    expect(h, 7);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(kabar, 0, reason: 'jamnya dibatalkan begitu jawaban datang');
  });

  test('jawaban lambat: kabar SEKALI, hasil tetap diteruskan', () async {
    var kabar = 0;
    final c = Completer<int>();
    final f = kabariBilaLambat(
      c.future,
      lambat: () => kabar++,
      setelah: const Duration(milliseconds: 20),
    );

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(kabar, 1);
    c.complete(3);
    expect(await f, 3);
    expect(kabar, 1);
  });

  test('galat diteruskan apa adanya (tidak diulang, tidak ditelan)', () async {
    await expectLater(
      kabariBilaLambat<void>(Future.error(StateError('x')), lambat: () {}),
      throwsA(isA<StateError>()),
    );
  });

  test('ambang bawaan 8-10 detik', () {
    expect(ambangKabarServerLambat.inSeconds, inInclusiveRange(8, 10));
  });

  testWidgets('widget: kosong dulu, kalimatnya muncul sesudah ambang', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('id'),
        home: Scaffold(body: KabarServerLambat()),
      ),
    );

    expect(find.textContaining('Server sedang dinyalakan'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('Server sedang dinyalakan'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('Server sedang dinyalakan'), findsOneWidget);
  });
}
