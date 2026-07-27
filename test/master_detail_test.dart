import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/screens/history/history_screen.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/widgets/master_detail_pane.dart';

Widget _app() {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      historyServiceProvider.overrideWithValue(MockHistoryService()),
      approvalServiceProvider.overrideWithValue(MockApprovalService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HistoryScreen(),
    ),
  );
}

Future<void> _ukuran(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('MasterDetailPane', () {
    Widget harness({required Widget? detail, required double lebar}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: lebar,
            child: MasterDetailPane(
              master: (_, panelGanda) =>
                  Text(panelGanda ? 'ganda' : 'tunggal'),
              detail: detail,
              kosong: const Text('belum dipilih'),
            ),
          ),
        ),
      );
    }

    testWidgets('sempit → master doang, panel kanan nggak dirender sama sekali',
        (tester) async {
      await _ukuran(tester, const Size(600, 800));
      await tester.pumpWidget(
        harness(detail: const Text('detail'), lebar: 600),
      );

      expect(find.text('tunggal'), findsOneWidget);
      // Bukan cuma ketutupan — detailnya emang nggak boleh dibangun, biar
      // provider-nya nggak ikut kepanggil di HP.
      expect(find.text('detail'), findsNothing);
      expect(find.text('belum dipilih'), findsNothing);
    });

    testWidgets('lebar → master dikasih tau lagi mode panel ganda',
        (tester) async {
      await _ukuran(tester, const Size(1200, 800));
      await tester.pumpWidget(harness(detail: null, lebar: 1200));

      expect(find.text('ganda'), findsOneWidget);
    });

    testWidgets('lebar tanpa pilihan → placeholder, bukan panel kosong melompong',
        (tester) async {
      await _ukuran(tester, const Size(1200, 800));
      await tester.pumpWidget(harness(detail: null, lebar: 1200));

      expect(find.text('belum dipilih'), findsOneWidget);
    });

    testWidgets('lebar dengan pilihan → detail gantiin placeholder',
        (tester) async {
      await _ukuran(tester, const Size(1200, 800));
      await tester.pumpWidget(
        harness(detail: const Text('detail'), lebar: 1200),
      );

      expect(find.text('detail'), findsOneWidget);
      expect(find.text('belum dipilih'), findsNothing);
    });
  });

  group('Riwayat: panel ganda vs satu panel', () {
    testWidgets('di HP tap kartu → PUSH layar detail, bukan panel',
        (tester) async {
      await _ukuran(tester, const Size(400, 800));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Satu panel: nggak ada placeholder sama sekali.
      expect(find.byType(PanePlaceholder), findsNothing);
      expect(find.byType(CalibrationDetailScreen), findsNothing);

      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();

      expect(find.byType(CalibrationDetailScreen), findsOneWidget);
      // Ke-push, jadi ada jalan balik.
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('di desktop tap kartu → detail kebuka di panel, daftar tetap ada',
        (tester) async {
      await _ukuran(tester, const Size(1240, 860));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byType(PanePlaceholder), findsOneWidget);

      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();

      expect(find.byType(CalibrationDetailScreen), findsOneWidget);
      expect(find.byType(PanePlaceholder), findsNothing);
      // Inti panel ganda: daftarnya NGGAK ketimpa, masih kelihatan.
      expect(find.byType(Card), findsWidgets);
      // Dan nggak ada yang di-push, jadi nggak ada tombol back.
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('ganti pilihan nggak numpuk halaman', (tester) async {
      await _ukuran(tester, const Size(1240, 860));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Card).at(1));
      await tester.pumpAndSettle();

      // Kalau ini kebablasan jadi push, bakal ada dua detail bertumpuk.
      expect(find.byType(CalibrationDetailScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });
  });
}
