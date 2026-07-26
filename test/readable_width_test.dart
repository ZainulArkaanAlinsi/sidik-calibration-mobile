import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/widgets/readable_width.dart';

/// Bikin harness selebar [lebar] lalu balikin lebar anak di dalam
/// [ReadableWidth] — itu yang bener-bener nentuin isi layar melar atau nggak.
Future<double> _lebarIsi(
  WidgetTester tester,
  double lebar, {
  double? maksimum,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(Size(lebar, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: ReadableWidth(
        maksimum: maksimum ?? 1040,
        child: SizedBox.expand(key: key),
      ),
    ),
  );

  return tester.getSize(find.byKey(key)).width;
}

void main() {
  group('ReadableWidth', () {
    testWidgets('di lebar HP nggak ngapa-ngapain', (tester) async {
      // 400 < 1040, jadi batasnya nggak pernah kepakai dan tata letaknya
      // persis kayak sebelum widget ini ada. Ini yang bikin dia aman dipasang
      // di layar yang dipakai HP maupun desktop.
      expect(await _lebarIsi(tester, 400), 400);
    });

    testWidgets('pas di ambang batas masih penuh', (tester) async {
      expect(await _lebarIsi(tester, 1040), 1040);
    });

    testWidgets('di jendela desktop isinya berhenti melar', (tester) async {
      expect(await _lebarIsi(tester, 1440), 1040);
    });

    testWidgets('jendela super lebar tetap kepotong di batas yang sama', (
      tester,
    ) async {
      expect(await _lebarIsi(tester, 2560), 1040);
    });

    testWidgets('batasnya bisa disetel per layar', (tester) async {
      expect(await _lebarIsi(tester, 1440, maksimum: 700), 700);
    });

    testWidgets('isinya ditengahkan, bukan nempel kiri', (tester) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(1440, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ReadableWidth(child: SizedBox.expand(key: key)),
        ),
      );

      // (1440 - 1040) / 2 = 200 di kiri, dan kanannya harus sama.
      final kiri = tester.getTopLeft(find.byKey(key)).dx;
      final kanan = 1440 - tester.getTopRight(find.byKey(key)).dx;
      expect(kiri, 200);
      expect(kanan, kiri);
    });
  });
}
