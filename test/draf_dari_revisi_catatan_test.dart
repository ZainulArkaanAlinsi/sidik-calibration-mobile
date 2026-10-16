import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/parse_list.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/models/lembar_kerja_submission.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/alur/alur_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/draf/draf_screen.dart';
import 'package:sidik_calibration/screens/history/calibration_detail_screen.dart';
import 'package:sidik_calibration/screens/history/history_screen.dart';
import 'package:sidik_calibration/services/approval_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/mock_store.dart';
import 'package:sidik_calibration/services/pdf_downloader.dart';
import 'package:sidik_calibration/services/pengirim_draf_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Draf yang lahir dari lembar `perlu_revisi` tetap membawa catatan admin.
///
/// ## Yang berubah di server
///
/// API berhenti mengosongkan `catatan_revisi` & `revisi_field` waktu lembar
/// `perlu_revisi` disimpan sebagai draf (`status: draft`). Keduanya baru
/// dikosongkan saat lembar dikirim ulang (`menunggu_approval`), disetujui, atau
/// oleh admin. Sinkron draf offline selalu mengirim `status: draft`.
///
/// ## Yang ditutup berkas ini
///
/// Layar Riwayat, Alur Kerja, dan detail sesi cuma menampilkan catatan kalau
/// `status == perluRevisi`. Begitu teknisi menekan Simpan Draf, sesinya jadi
/// `draft` dan catatannya hilang dari layar — padahal masih ada di respons dan
/// belum dibetulkan.
///
/// Dijaga dua arah: draf BERCATATAN menampilkan catatan & penanda, draf BIASA
/// tidak menampilkan apa pun (pita yang selalu nongol berhenti dibaca).
///
/// Bentuk respons disalin dari `CalibrationResource::toArray()` di repo API
/// (`catatan_revisi`, `revisi_field`) — dipakai `GET /calibrations` dan
/// `GET /calibrations/{id}` yang sama.
const _catatan =
    'Suhu awal 19,8 nggak masuk rentang IK (20±2). '
    'Ulangi pembacaannya sesudah alatnya settle 15 menit.';

const _idRevisi = 71;
const _idBiasa = 72;

Map<String, dynamic> _sesi({
  required int id,
  required String namaAlat,
  String status = 'draft',
  String? catatan,
  List<String> field = const [],
}) => {
  'id': id,
  'nomor_sesi': 'KAL/2026/10/00$id',
  'status': status,
  'tanggal_kalibrasi': '2026-10-14',
  'desimal': 2,
  'equipment': {
    'nama_alat': namaAlat,
    'profil': 'ph_meter',
    'nama_alat_kemampuan': 'pH Meter',
  },
  'teknisi': {'nama': 'Andi'},
  'hasil': {'keputusan': null},
  'catatan_revisi': catatan,
  'revisi_field': field,
  'titik': const <Map<String, dynamic>>[],
  'pembacaan_mentah': const <Map<String, dynamic>>[],
};

/// Draf bekas `perlu_revisi`: catatan + kolom yang ditandai masih terbawa.
final _drafRevisi = _sesi(
  id: _idRevisi,
  namaAlat: 'pH Meter Hanna',
  catatan: _catatan,
  field: const ['alat_serial_number'],
);

/// Draf biasa yang belum pernah dikirim: dua kuncinya kosong.
final _drafBiasa = _sesi(id: _idBiasa, namaAlat: 'pH Meter Eutech');

class _Servis implements HistoryService {
  final _semua = [_drafRevisi, _drafBiasa];

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async =>
      parseListAman(_semua, CalibrationHistoryItem.fromJson);

  @override
  Future<List<CalibrationHistoryItem>> ambilDraf(String token) =>
      ambilRiwayat(token);

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async => const [];

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(_semua.firstWhere((s) => s['id'] == id));

  @override
  Future<CalibrationDetail> verifikasiPembacaan(String token, int id) =>
      ambilDetail(token, id);
}

Future<void> _pasang(
  WidgetTester tester,
  Widget home, {
  Size ukuran = const Size(400, 2400),
}) async {
  tester.view.physicalSize = ukuran;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        historyServiceProvider.overrideWithValue(_Servis()),
        approvalServiceProvider.overrideWithValue(MockApprovalService()),
        pdfDownloaderProvider.overrideWithValue(MockPdfDownloader()),
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
        home: home,
      ),
    ),
  );
  // Lewatin jeda 600 ms `MockAuthService.me()` — DUA kali: di layar detail
  // `authProvider` baru dibaca sesudah sesinya termuat (tombol Lanjutkan
  // draf), jadi timernya baru mulai sesudah putaran pertama.
  for (var i = 0; i < 2; i++) {
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }
}

/// Lembar Conductivity kecil — cukup buat menguji kode sel revisi
/// (`sel:<tahap>:<titik_ukur>:<kolom>:<pembacaan_ke>`, `KodeSelRevisi` di API).
LembarKerja _lembarConductivity() => LembarKerja.fromJson({
  'kode_dokumen': 'SIDIK-IK-CAL-0507_Rev.6',
  'judul': 'Calibration Worksheet - Conductivity Meter',
  'untuk': 'teknisi',
  'jumlah_pengulangan': 5,
  'satuan_campuran': true,
  'bagian': [
    {
      'kode': 'hasil',
      'judul': 'CALIBRATION RESULT',
      'tabel': [
        {
          'tahap': 'sesudah_adjustment',
          'judul': 'After adjustment Reading',
          'kolom': [
            {'kode': 'pembacaan', 'label': 'nilai', 'tipe': 'angka'},
          ],
          'pengulangan': [1, 2, 3, 4, 5],
          'baris': [
            {'titik_ukur': 25, 'label': '25', 'satuan': 'µS/cm'},
            {'titik_ukur': 1412, 'label': '1412', 'satuan': 'µS/cm'},
          ],
        },
      ],
    },
  ],
});

void main() {
  group('aturan tampil catatan revisi', () {
    test('draf bercatatan tampil, draf biasa tidak', () {
      expect(catatanRevisiTampil(CalibrationStatus.draft, _catatan), isTrue);
      expect(catatanRevisiTampil(CalibrationStatus.draft, null), isFalse);
      expect(catatanRevisiTampil(CalibrationStatus.draft, '   '), isFalse);
    });

    test('perlu_revisi tetap tampil seperti sebelumnya', () {
      expect(
        catatanRevisiTampil(CalibrationStatus.perluRevisi, _catatan),
        isTrue,
      );
    });

    test('sesi yang sudah dikirim/disetujui tidak memajang catatan lama', () {
      // Server mengosongkan catatannya di dua status ini; kalau suatu respons
      // masih membawanya, itu sisa — bukan permintaan yang masih berlaku.
      expect(
        catatanRevisiTampil(CalibrationStatus.menungguApproval, _catatan),
        isFalse,
      );
      expect(
        catatanRevisiTampil(CalibrationStatus.disetujui, _catatan),
        isFalse,
      );
    });

    test('respons daftar & detail draf bercatatan kebaca lewat fromJson', () {
      final baris = CalibrationHistoryItem.fromJson(_drafRevisi);
      final detail = CalibrationDetail.fromJson(_drafRevisi);

      expect(baris.status, CalibrationStatus.draft);
      expect(baris.bawaCatatanRevisi, isTrue);
      expect(detail.bawaCatatanRevisi, isTrue);
      expect(detail.isianTeknisi!.revisiField, {'alat_serial_number'});

      expect(
        CalibrationHistoryItem.fromJson(_drafBiasa).bawaCatatanRevisi,
        isFalse,
      );
      expect(CalibrationDetail.fromJson(_drafBiasa).bawaCatatanRevisi, isFalse);
    });
  });

  group('penanda sel dari draf bercatatan', () {
    test('kode sel di revisi_field draf tetap nandain kotaknya', () {
      final detail = CalibrationDetail.fromJson(
        _sesi(
          id: _idRevisi,
          namaAlat: 'Conductivity Meter',
          catatan: 'Repeat 3 di titik 1412 komanya kegeser.',
          field: const ['sel:sesudah_adjustment:1412:pembacaan:3'],
        ),
      );
      final isian = LembarKerjaState(
        bentuk: _lembarConductivity(),
        clientRequestId: 'tes-draf-revisi',
      )..muatDariSesi(detail.isianTeknisi!);

      expect(isian.adaRevisi, isTrue);
      // Repeat 3 (1-based di server) = index 2 di layar.
      expect(
        isian.tandaSel(1412, 'sesudah_adjustment', 'pembacaan', 2),
        TandaSel.revisi,
      );
      expect(
        isian.tandaSel(1412, 'sesudah_adjustment', 'pembacaan', 1),
        TandaSel.tidakAda,
      );
    });

    test('draf biasa nggak nandain satu kotak pun', () {
      final isian = LembarKerjaState(
        bentuk: _lembarConductivity(),
        clientRequestId: 'tes-draf-biasa',
      )..muatDariSesi(CalibrationDetail.fromJson(_drafBiasa).isianTeknisi!);

      expect(isian.adaRevisi, isFalse);
      expect(isian.selRevisi, isEmpty);
    });
  });

  group('layar', () {
    testWidgets('Riwayat: catatan muncul di draf bercatatan saja', (
      tester,
    ) async {
      await _pasang(tester, const HistoryScreen());

      expect(find.text('pH Meter Eutech'), findsOneWidget);
      expect(find.text('Catatan revisi: $_catatan'), findsOneWidget);
      // Draf biasa tidak ikut menampilkan baris catatan kosong.
      expect(find.textContaining('Catatan revisi:'), findsOneWidget);
    });

    testWidgets('Draf: rak menandai draf yang lahir dari revisi', (
      tester,
    ) async {
      await _pasang(tester, const DrafScreen());

      expect(find.text('pH Meter Eutech'), findsOneWidget);
      expect(find.text('Catatan revisi: $_catatan'), findsOneWidget);
      expect(find.textContaining('Catatan revisi:'), findsOneWidget);
    });

    testWidgets('detail sesi draf bercatatan: catatan tampil', (tester) async {
      await _pasang(
        tester,
        const CalibrationDetailScreen(calibrationId: _idRevisi),
      );

      expect(find.text('Catatan revisi: $_catatan'), findsOneWidget);
    });

    testWidgets('detail sesi draf biasa: tidak ada catatan', (tester) async {
      await _pasang(
        tester,
        const CalibrationDetailScreen(calibrationId: _idBiasa),
      );

      expect(find.textContaining('Catatan revisi:'), findsNothing);
    });

    testWidgets('Alur Kerja: panel tahapan draf bercatatan memuat catatan', (
      tester,
    ) async {
      await _pasang(
        tester,
        const AlurKerjaScreen(),
        ukuran: const Size(400, 900),
      );

      await tester.tap(find.text('pH Meter Hanna'));
      await tester.pumpAndSettle();

      expect(find.text('Dibalikin admin: $_catatan'), findsOneWidget);
    });

    testWidgets('Alur Kerja: panel tahapan draf biasa tanpa catatan', (
      tester,
    ) async {
      await _pasang(
        tester,
        const AlurKerjaScreen(),
        ukuran: const Size(400, 900),
      );

      await tester.tap(find.text('pH Meter Eutech'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Dibalikin admin:'), findsNothing);
    });

    testWidgets('lembar kerja draf bercatatan: banner + kolom bertanda', (
      tester,
    ) async {
      await _pasang(
        tester,
        const LembarKerjaScreen(profil: 'ph_meter', sesiId: _idRevisi),
        ukuran: const Size(1400, 20000),
      );

      expect(
        find.text(
          'Admin ngembaliin lembar kerja ini. Kolom yang ditandai di bawah '
          'yang perlu dibetulin.',
        ),
        findsOneWidget,
      );
      expect(find.text(_catatan), findsOneWidget);
      expect(find.text('Diminta admin dibetulin'), findsOneWidget);
    });

    testWidgets('lembar kerja draf biasa: tanpa banner & tanpa penanda', (
      tester,
    ) async {
      await _pasang(
        tester,
        const LembarKerjaScreen(profil: 'ph_meter', sesiId: _idBiasa),
        ukuran: const Size(1400, 20000),
      );

      expect(
        find.textContaining('Admin ngembaliin lembar kerja'),
        findsNothing,
      );
      expect(find.text('Diminta admin dibetulin'), findsNothing);
    });
  });

  group('mode mock meniru server', () {
    setUp(MockStore.instance.reset);
    tearDown(MockStore.instance.reset);

    int sesiDitolak() {
      final id = MockStore.instance.tambahSesi(
        namaAlat: 'pH Meter (sesi baru)',
        namaTeknisi: 'Teknisi',
      );
      MockStore.instance.tolak(id, _catatan);
      return id;
    }

    CalibrationHistoryItem baris(int id) =>
        MockStore.instance.sesi.firstWhere((s) => s.id == id);

    test('Simpan Draf di lembar revisi: jadi draf, catatan tetap', () async {
      final id = sesiDitolak();

      await MockLembarKerjaService().perbarui(
        'mock-token-2',
        id,
        const LembarKerjaSubmission(
          equipmentId: 1,
          clientRequestId: 'tes-simpan-draf-revisi',
          simpanSebagaiDraft: true,
        ),
      );

      expect(baris(id).status, CalibrationStatus.draft);
      expect(baris(id).catatanRevisi, _catatan);
      expect(baris(id).bawaCatatanRevisi, isTrue);

      // Rak Draf mode mock ikut menampilkannya, lengkap dengan catatannya.
      final draf = await MockHistoryService().ambilDraf('mock-token-2');
      expect(draf.singleWhere((s) => s.id == id).catatanRevisi, _catatan);
    });

    test(
      'sinkron draf offline (selalu status draft) juga mempertahankan catatan',
      () async {
        final id = sesiDitolak();

        await MockPengirimDrafService().perbarui(
          'mock-token-2',
          matriks: false,
          id: id,
          body: const {'status': 'draft'},
        );

        expect(baris(id).status, CalibrationStatus.draft);
        expect(baris(id).catatanRevisi, _catatan);
      },
    );

    test('kirim ulang: menunggu approval, catatan dikosongkan', () async {
      final id = sesiDitolak();

      await MockLembarKerjaService().perbarui(
        'mock-token-2',
        id,
        const LembarKerjaSubmission(
          equipmentId: 1,
          clientRequestId: 'tes-kirim-ulang',
          simpanSebagaiDraft: false,
        ),
      );

      expect(baris(id).status, CalibrationStatus.menungguApproval);
      expect(baris(id).catatanRevisi, isNull);
    });

    test('sesi yang sudah disetujui nggak dimundurkan', () {
      final id = MockStore.instance.tambahSesi(
        namaAlat: 'pH Meter (sesi baru)',
        namaTeknisi: 'Teknisi',
      );
      MockStore.instance.setujui(id);

      MockStore.instance.perbarui(id, draft: true);

      expect(baris(id).status, CalibrationStatus.disetujui);
    });

    test('simpan draf gagal → status di store nggak berubah', () async {
      final id = sesiDitolak();

      await expectLater(
        MockLembarKerjaService(gagal: true).perbarui(
          'mock-token-2',
          id,
          const LembarKerjaSubmission(
            equipmentId: 1,
            clientRequestId: 'tes-gagal',
            simpanSebagaiDraft: true,
          ),
        ),
        throwsException,
      );

      expect(baris(id).status, CalibrationStatus.perluRevisi);
      expect(baris(id).catatanRevisi, _catatan);
    });
  });
}
