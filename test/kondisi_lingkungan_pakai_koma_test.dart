import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/history/certificate_screen.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pdf_downloader.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Satu layar, satu gaya angka (BUG-021).
///
/// `_angka()` di `certificate_screen` memanggil `toStringAsFixed` langsung —
/// separator titik bawaan Dart — sementara tabel hasil di layar yang **sama**
/// memakai `formatSertifikat` (koma), yang sudah diimpor di berkas itu juga.
///
/// Hasilnya satu layar menampilkan dua gaya sekaligus: "21,0 mm" di tabel
/// hasil, dan "21.0 °C ± 1.7 °C" di blok Kondisi Lingkungan tepat di atasnya.
///
/// Aturannya sudah ditulis di `angka.dart`: layar sertifikat pakai koma.
/// Dampaknya terbatas di dalam app — field ini tidak ikut dicetak di PDF
/// sertifikat pelanggan — tapi yang dinilai teknisi dari layar ini justru
/// kesamaan dengan kertas yang dia pegang.
///
/// Angkanya disalin dari sesi 012-CAL-524, sama seperti
/// `ph_detail_response_test.dart`.

/// Cuma `ambilDetail` yang diganti; sisanya tetap perilaku mock bawaan, jadi
/// berkas ini tidak menyentuh fixture bersama yang dipakai test lain.
class _DetailBerlingkungan extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson({
        'id': 1,
        'status': 'disetujui',
        'tanggal_kalibrasi': '2024-05-26T00:00:00Z',
        'equipment': {'nama_alat': 'pH Meter'},
        'teknisi': {'nama': 'DR'},
        'hasil': {'keputusan': 'PASS'},
        'suhu_ruang': 21.4,
        'kelembaban': 54.5,
        'kondisi_lingkungan': {
          'suhu': {
            'awal': 21.3,
            'akhir': 21.5,
            'rata_rata': 21.4,
            'u95': 1.7117,
            'satuan': '°C',
          },
          'kelembaban': {
            'awal': 53,
            'akhir': 56,
            'rata_rata': 54.5,
            'u95': 5.6604,
            'satuan': '%RH',
          },
        },
        'titik': const [],
      });
}

Widget _app() {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      historyServiceProvider.overrideWithValue(_DetailBerlingkungan()),
      approvalServiceProvider.overrideWithValue(MockApprovalService()),
      pdfDownloaderProvider.overrideWithValue(MockPdfDownloader()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CertificateScreen(calibrationId: 1),
    ),
  );
}

void main() {
  /// Layarnya `ListView`: yang di bawah lipatan belum di-build, jadi
  /// `find` tidak akan menemukannya. Dua blok yang diuji di sini duduk
  /// berjauhan, jadi viewport-nya dibesarkan — sama seperti
  /// `calibration_input_test.dart`.
  void perbesarViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('blok Kondisi Lingkungan pakai koma, bukan titik', (
    tester,
  ) async {
    perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Layar ini nge-`watch` `authProvider` buat mutusin tombol "Kirim ke
    // pelanggan" muncul apa nggak, dan watch-nya baru kejadian SESUDAH detail
    // sesinya kemuat. Kalau jeda `MockAuthService` nggak dilewatin, timernya
    // nyangkut waktu tree dibuang. Sama persis dengan `certificate_test.dart`.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Inti bug-nya: sebelum diperbaiki yang tampil "21.4 °C ± 1.7 °C".
    //
    // `findsWidgets`, bukan `findsOneWidget` — suhu 21,4 muncul di DUA blok:
    // baris Env. Condition di `_IdentitasSesi` dan ringkasan sesi di
    // `_Ringkasan`. Dua-duanya dulu bertitik; keduanya diperbaiki.
    expect(
      find.textContaining('21,4 °C'),
      findsWidgets,
      reason: 'Suhu masih pakai separator titik di layar sertifikat.',
    );

    // Yang berikut khas satu blok saja, jadi jumlahnya pasti.
    expect(find.textContaining('± 1,7 °C'), findsOneWidget);
    expect(find.textContaining('54,50 %RH'), findsOneWidget);
    expect(find.textContaining('± 5,7 %RH'), findsOneWidget);

    // Blok ringkasan sesi — instans kedua dari bug yang sama, 400 baris di
    // bawah yang disebut laporan audit.
    expect(find.textContaining('21,4 °C · 54,5 %RH'), findsOneWidget);
  });

  testWidgets('nggak ada satu pun angka bertitik yang tersisa di layar itu', (
    tester,
  ) async {
    perbesarViewport(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    // Assert per-nilai di atas bisa hijau sementara nilai lain masih bertitik
    // — dan itu bukan kekhawatiran teoretis: penjaring inilah yang menemukan
    // instans kedua bug ini di `_Ringkasan`, yang tidak disebut laporan audit.
    // Yang diadu di sini SELURUH teks yang membawa satuan lingkungan.
    final bertitik = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains('°C') || s.contains('%RH'))
        .where((s) => RegExp(r'\d\.\d').hasMatch(s))
        .toList();

    expect(
      bertitik,
      isEmpty,
      reason: 'Masih ada angka bertitik di blok Kondisi Lingkungan: $bertitik',
    );
  });
}
