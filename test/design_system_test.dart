import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asmo_mobile/core/theme/app_theme.dart';
import 'package:asmo_mobile/widgets/app_button.dart';
import 'package:asmo_mobile/widgets/status_badge.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  group('StatusBadge.fromApi', () {
    testWidgets('PASS & FAIL nampilin ikon, bukan cuma warna', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [StatusBadge.fromApi('PASS'), StatusBadge.fromApi('FAIL')],
          ),
        ),
      );

      expect(find.text('PASS'), findsOneWidget);
      expect(find.text('FAIL'), findsOneWidget);
      // Ikon wajib ada — teknisi buta warna harus tetap bisa bedain.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('status API di-terjemahin ke label Indonesia', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              StatusBadge.fromApi('overdue'),
              StatusBadge.fromApi('menunggu_approval'),
              StatusBadge.fromApi('perlu_revisi'),
            ],
          ),
        ),
      );

      expect(find.text('Jatuh tempo'), findsOneWidget);
      expect(find.text('Menunggu approval'), findsOneWidget);
      expect(find.text('Perlu revisi'), findsOneWidget);
    });

    testWidgets('status asing nggak bikin crash, ditampilin apa adanya', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(StatusBadge.fromApi('status_baru_dari_backend')));

      expect(find.text('status_baru_dari_backend'), findsOneWidget);
    });
  });

  group('AppButton', () {
    testWidgets('bisa dipencet waktu normal', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Simpan', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Simpan'));
      expect(taps, 1);
    });

    testWidgets('waktu loading: nggak bisa dipencet (cegah submit dobel)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          AppButton(label: 'Simpan', isLoading: true, onPressed: () => taps++),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(taps, 0, reason: 'tombol loading nggak boleh ngirim data dua kali');
    });
  });
}
