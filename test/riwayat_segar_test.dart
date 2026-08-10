import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/screens/history/history_screen.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Riwayat harus jujur soal keputusan yang diambil di PERANGKAT LAIN.
///
/// 10 Agt 2026: sesi ditolak lewat HP, jendela macOS tetap nulis "Menunggu
/// approval" lengkap dengan tombol SETUJUI/TOLAK — padahal endpoint daftarnya
/// udah balikin `perlu_revisi`. Panel detail di sebelahnya bener, karena dia
/// diambil segar tiap kartu diklik; daftarnya diambil sekali waktu layar
/// dibuka dan nggak pernah lagi.
///
/// Yang mestinya ngabarin itu broadcast realtime, tapi `realtimeSyncProvider`
/// jatuh ke `MockRealtimeService` begitu kunci Reverb kosong — keadaan normal
/// di dev. Jadi jalur segarnya nggak boleh cuma realtime.
class _ServisBerubah implements HistoryService {
  _ServisBerubah();

  /// Berapa kali DAFTAR RIWAYAT ditarik. Sengaja nggak kena panggilan antrean
  /// approval, yang lewat endpoint lain dan bikin hitungannya nggak kebaca.
  int tarikan = 0;

  /// Disetel test buat meniru orang lain yang nolak sesi ini di perangkat lain,
  /// tanpa app ini dikasih tau apa-apa.
  bool ditolakDiTempatLain = false;

  List<CalibrationHistoryItem> _isi() => [
    CalibrationHistoryItem(
      id: 38,
      namaAlat: 'pH Meter',
      namaTeknisi: 'Dimas Rahardjo',
      tanggalKalibrasi: DateTime(2026, 8, 9),
      status: ditolakDiTempatLain
          ? CalibrationStatus.perluRevisi
          : CalibrationStatus.menungguApproval,
    ),
  ];

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async {
    tarikan++;
    return _isi();
  }

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async => _isi()
      .where((s) => s.status == CalibrationStatus.menungguApproval)
      .toList();

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) =>
      MockHistoryService().ambilDetail(token, id);
}

Widget _app(HistoryService servis) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      historyServiceProvider.overrideWithValue(servis),
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

void main() {
  group('daftar riwayat nggak boleh basi', () {
    testWidgets('balik ke app → daftar ditarik ulang, badge ikut berubah', (
      tester,
    ) async {
      final servis = _ServisBerubah();
      await tester.pumpWidget(_app(servis));

      // Ditunggu sampai BENERAN diam duluan. `MockAuthService.me` punya jeda
      // 600ms, dan `HistoryController.build` nge-`watch` auth — jadi auth yang
      // baru kelar itu sendiri mancing satu tarikan lagi. Tanpa disetelin di
      // sini, tarikan itu yang kebaca sebagai "resume jalan", dan tesnya tetap
      // hijau walau perbaikannya dicabut. Sempat kejadian pas nulis tes ini.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Menunggu approval'), findsOneWidget);

      final sebelum = servis.tarikan;

      // Orang lain nolak sesi ini di HP; jendela ini nggak dikasih tau apa-apa
      // (realtime mati), lalu jendelanya diklik lagi.
      servis.ditolakDiTempatLain = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Yang dijaga hasilnya, bukan angka pastinya: `muatUlang()` manggil
      // `build()` yang nge-`watch` auth lagi, jadi hitungannya nggak stabil.
      expect(servis.tarikan, greaterThan(sebelum));
      expect(find.text('Menunggu approval'), findsNothing);
      expect(find.text('Perlu revisi'), findsOneWidget);
    });

    /// `RefreshIndicator` cuma jalan lewat gestur TARIK, dan mouse nggak punya
    /// gestur itu — jadi tanpa tombol ini desktop nggak punya cara nyegerin
    /// daftar sama sekali selain app-nya dimatiin.
    testWidgets('tombol segarkan di AppBar narik ulang daftarnya', (
      tester,
    ) async {
      final servis = _ServisBerubah();
      await tester.pumpWidget(_app(servis));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final sebelum = servis.tarikan;

      servis.ditolakDiTempatLain = true;
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(servis.tarikan, greaterThan(sebelum));
      expect(find.text('Menunggu approval'), findsNothing);
      expect(find.text('Perlu revisi'), findsOneWidget);
    });
  });

  /// Nilai di blok kondisi lingkungan harus tetap NEMPEL sama labelnya, berapa
  /// pun lebar panelnya.
  ///
  /// Dulu labelnya `Expanded`, jadi nilainya kedorong ke tepi kanan kartu. Di
  /// HP nggak kelihatan salah (kartunya sempit); di panel kanan desktop ~800px
  /// angkanya nyaris di ujung layar dan dilaporkan sebagai "nilai suhu &
  /// kelembabannya kosong" — padahal dirender, cuma nggak kejangkau mata.
  group('kondisi lingkungan di panel lebar', () {
    testWidgets('nilai nggak kelempar ke tepi kanan', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(
              InMemoryTokenStorage('mock-token-1'),
            ),
            authServiceProvider.overrideWithValue(MockAuthService()),
            historyServiceProvider.overrideWithValue(MockHistoryService()),
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

      final label = find.text('Suhu ruang');
      expect(label, findsOneWidget);

      // Nilainya diambil dari baris yang sama — apa pun angkanya, dia harus
      // mulai dalam satu kolom label dari kirinya, bukan di seberang kartu.
      final kiriLabel = tester.getTopLeft(label).dx;
      final barisSuhu = find.ancestor(of: label, matching: find.byType(Row));
      final nilai = find.descendant(
        of: barisSuhu.first,
        matching: find.byType(Text),
      );

      expect(nilai, findsNWidgets(2));
      final kiriNilai = tester.getTopLeft(nilai.last).dx;

      expect(
        kiriNilai - kiriLabel,
        lessThan(240),
        reason: 'nilai kejauhan dari labelnya — kolom label melar lagi',
      );
    });
  });
}
