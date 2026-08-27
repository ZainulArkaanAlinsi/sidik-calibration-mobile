import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/pdf_downloader.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// **`status_standar` beneran kegambar, bukan cuma dipulangkan server.**
///
/// ## Yang hilang sebelum ini
///
/// Blok `status_standar` sudah ikut `GET /api/calibrations/{id}` sejak
/// 25 Jul 2026 — lengkap dengan `ringkasan`, `pesan` siap tampil, dan rincian
/// per standar. Waktu diaudit 27 Agt 2026, **nol berkas di `lib/` membacanya**.
/// Server tahu sertifikat standarnya kadaluarsa, menuliskannya di respons,
/// lalu tidak ada satu pun yang menggambarnya.
///
/// Yang hilang bukan sertifikat salah terbit — validator server tetap menahan.
/// Yang hilang WAKTU: teknisi mengerjakan lembar sampai selesai, mengirim,
/// lalu baru tahu ditolak karena sertifikat standarnya lewat tiga hari lalu.
///
/// ## Kenapa dua arah
///
/// Menegakkan cuma "banner-nya muncul" bikin `pesan == null` bisa ikut
/// menggambar pita — dan pita berwarna yang SELALU nongol berhenti dibaca
/// orang, persis pola yang bikin peringatan sungguhan tenggelam. Jadi
/// dijaga dua-duanya: ada masalah → banner, semua aman → nol piksel.
void main() {
  Future<void> buka(WidgetTester tester, HistoryService service) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          historyServiceProvider.overrideWithValue(service),
          approvalServiceProvider.overrideWithValue(MockApprovalService()),
          pdfDownloaderProvider.overrideWithValue(MockPdfDownloader()),
        ],
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalibrationDetailScreen(calibrationId: 72),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('standar kadaluarsa: kalimat server dipakai APA ADANYA', (
    tester,
  ) async {
    await buka(tester, _HistoryExpired());

    // Bukan terjemahan, bukan susunan sendiri. Kalimat yang sama tercetak di
    // lembar kerja fisik, dan admin mengadu layar ke kertas di mejanya — dua
    // kalimat dari satu keadaan yang berbeda karena salah satunya diedit itu
    // yang bikin orang berhenti percaya keduanya.
    expect(find.text('ONE OR MORE STANDARD EXPIRED'), findsOneWidget);

    // Hari NEGATIF ditulis sebagai "lewat N hari", bukan "−3 hari lagi":
    // yang terakhir mesti diterjemahkan sendiri oleh yang membacanya, di layar
    // yang justru dipakai buru-buru.
    expect(
      find.textContaining('lewat 3 hari'),
      findsOneWidget,
      reason: 'Rincian standar yang bermasalah wajib nyebut berapa harinya.',
    );

    // Standar yang MASIH berlaku nggak ikut dirinci — daftar tujuh baris yang
    // enam di antaranya hijau bikin yang merah justru susah kelihatan.
    expect(find.textContaining('pH Buffer Solution 7'), findsNothing);
  });

  testWidgets('standar mepet kadaluarsa: pesan & hitungan majunya', (
    tester,
  ) async {
    await buka(tester, _HistoryWarning());

    expect(find.text('ONE OR MORE STANDARD NEAR EXPIRY'), findsOneWidget);
    expect(find.textContaining('habis 12 hari lagi'), findsOneWidget);
  });

  testWidgets('semua standar aman: nol piksel, bukan pita hijau', (
    tester,
  ) async {
    await buka(tester, _HistoryValid());

    expect(
      find.textContaining('STANDARD'),
      findsNothing,
      reason: 'Pita yang selalu nongol berhenti dibaca — lalu yang beneran '
          'penting ikut tenggelam.',
    );
  });

  testWidgets('server lama tanpa `status_standar` nggak bikin layar mati', (
    tester,
  ) async {
    await buka(tester, _HistoryTanpaBlok());

    // Nggak ada blok sama sekali itu keadaan yang sah (respons lama), dan
    // bedanya penting dari "sudah dicek, semuanya aman" — dua-duanya nggak
    // menggambar banner, tapi cuma yang ini boleh terjadi tanpa server bilang
    // apa-apa.
    expect(find.textContaining('STANDARD'), findsNothing);
    expect(
      find.textContaining('DEMO-LAMA'),
      findsWidgets,
      reason: 'Layarnya mesti tetap kegambar utuh, bukan cuma banner-nya yang hilang.',
    );
  });

  testWidgets('kepala LEMBAR KERJA juga dapat banner-nya, bukan cuma layar detail', (
    tester,
  ) async {
    // Ini penempatan yang disebut kontrak (`banner kepala lembar kerja`), dan
    // yang paling menghemat waktu: teknisi tahu sertifikat standarnya lewat
    // SEBELUM lembarnya diisi, bukan sesudah dikirim dan ditolak.
    //
    // Datanya numpang respons yang SAMA — `_muatSesiLama` sudah menarik
    // `calibrationDetailProvider` buat mengisi ulang formulir, jadi banner ini
    // nggak nambah satu pun permintaan.
    tester.view.physicalSize = const Size(1400, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            InMemoryTokenStorage('mock-token-1'),
          ),
          authServiceProvider.overrideWithValue(MockAuthService()),
          historyServiceProvider.overrideWithValue(_HistoryExpired()),
          lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
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
          home: const LembarKerjaScreen(profil: 'ph_meter', sesiId: 72),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('ONE OR MORE STANDARD EXPIRED'), findsOneWidget);
  });
}
Map<String, dynamic> _sesi({
  Map<String, dynamic>? statusStandar,
  String nomor = 'DEMO-STD',
}) => {
  'id': 72,
  'nomor_sesi': nomor,
  'tanggal_kalibrasi': '2026-08-26T00:00:00.000Z',
  'status': 'disetujui',
  'desimal': 2,
  'equipment': {'nama_alat': 'pH Meter'},
  'teknisi': {'nama': 'Teknisi Sidik'},
  'hasil': {'keputusan': null},
  // Kuncinya DIBUANG kalau null, bukan dikirim bernilai null — itu yang bikin
  // kasus "server lama" beda dari "sudah dicek, semuanya aman".
  'status_standar': ?statusStandar,
  'titik': [
    {
      'titik_ke': 1,
      'titik_ukur': 4.01,
      'satuan': 'pH',
      'desimal': 2,
      'rata_rata': 4.02,
    },
  ],
  'pembacaan_mentah': const <Map<String, dynamic>>[],
};

class _HistoryExpired extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(
        _sesi(
          statusStandar: {
            'ringkasan': 'expired',
            'pesan': 'ONE OR MORE STANDARD EXPIRED',
            'standar': [
              {
                'id': 10,
                'nama': 'pH Buffer Solution 7',
                'status': 'valid',
                'hari_menuju_kadaluarsa': 190,
              },
              {
                'id': 12,
                'nama': 'Termometer & Sensor Std.',
                'status': 'expired',
                'hari_menuju_kadaluarsa': -3,
              },
            ],
          },
        ),
      );
}

class _HistoryWarning extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(
        _sesi(
          statusStandar: {
            'ringkasan': 'warning',
            'pesan': 'ONE OR MORE STANDARD NEAR EXPIRY',
            'standar': [
              {
                'id': 12,
                'nama': 'Termometer & Sensor Std.',
                'status': 'warning',
                'hari_menuju_kadaluarsa': 12,
              },
            ],
          },
        ),
      );
}

/// Server sudah ngecek, semuanya berlaku — `pesan` null.
class _HistoryValid extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(
        _sesi(
          statusStandar: {
            'ringkasan': 'valid',
            'pesan': null,
            'standar': [
              {
                'id': 10,
                'nama': 'pH Buffer Solution 7',
                'status': 'valid',
                'hari_menuju_kadaluarsa': 190,
              },
            ],
          },
        ),
      );
}

/// Respons lama: bloknya nggak ada sama sekali.
class _HistoryTanpaBlok extends MockHistoryService {
  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(_sesi(nomor: 'DEMO-LAMA'));
}