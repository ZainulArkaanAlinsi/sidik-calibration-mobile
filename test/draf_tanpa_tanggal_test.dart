import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/parse_list.dart';
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

/// Draf tanpa tanggal kalibrasi harus TETAP kelihatan.
///
/// **Kenapa test ini ada.** Kolom `tanggal_kalibrasi` di backend nullable sejak
/// migrasi `make_tanggal_kalibrasi_nullable_on_calibration_sessions_table` —
/// justru supaya draf boleh disimpen setengah jadi. Tapi dua model BACA
/// (`CalibrationHistoryItem` & `CalibrationDetail`) masih maksa
/// `DateTime.parse(json['tanggal_kalibrasi'] as String)`.
///
/// Cast `null as String` melempar, [parseListAman] nelen lemparannya, dan
/// barisnya dilewat. Hasilnya: dashboard ngitung draf itu (angkanya dari
/// `count()` di backend), sementara Riwayat & antrean nggak nampilinnya sama
/// sekali. Dua angka di satu app yang saling membantah — dan nggak ada satu pun
/// pesan error, di layar maupun di log, yang bisa dikejar.
///
/// Nggak kekejar test lama karena semua mock ngisi `tanggalKalibrasi` lewat
/// konstruktor pakai `DateTime` beneran, jadi `fromJson` yang salah itu nggak
/// pernah kelewatan jalur mock. Makanya di sini yang diadu JSON mentahnya.
void main() {
  /// Bentuk baris `GET /api/calibrations`, dipangkas ke kunci yang dibaca
  /// `fromJson`. Bersarangnya dipertahankan persis kayak respons asli.
  Map<String, dynamic> baris(int id, {Object? tanggal, bool adaTanggal = true}) {
    return {
      'id': id,
      'status': 'draft',
      if (adaTanggal) 'tanggal_kalibrasi': ?tanggal,
      'equipment': {'nama_alat': 'Oven Memmert UN55'},
      'teknisi': {'nama': 'Andi'},
    };
  }

  group('parseListAman nggak boleh ngebuang draf tanpa tanggal', () {
    test('kunci tanggal_kalibrasi HILANG → item tetap ikut', () {
      final hasil = parseListAman(
        [baris(101, adaTanggal: false)],
        CalibrationHistoryItem.fromJson,
      );

      expect(hasil, hasLength(1));
      expect(hasil.single.id, 101);
      expect(hasil.single.tanggalKalibrasi, isNull);
      // Sisa barisnya tetap kebaca — yang kosong cuma tanggalnya.
      expect(hasil.single.namaAlat, 'Oven Memmert UN55');
      expect(hasil.single.status, CalibrationStatus.draft);
    });

    test('tanggal_kalibrasi bernilai null eksplisit → item tetap ikut', () {
      final hasil = parseListAman(
        [
          <String, dynamic>{
            ...baris(102, adaTanggal: false),
            'tanggal_kalibrasi': null,
          },
        ],
        CalibrationHistoryItem.fromJson,
      );

      expect(hasil, hasLength(1));
      expect(hasil.single.id, 102);
      expect(hasil.single.tanggalKalibrasi, isNull);
    });

    test('sesi bertanggal ikut apa adanya, satu daftar sama draf kosong', () {
      // Ini bentuk kegagalan yang beneran kejadian: daftar campuran, dan yang
      // ilang cuma draf-nya. Jumlah baris yang balik (2, bukan 3) itu persis
      // selisih yang bikin dashboard & Riwayat beda angka.
      final hasil = parseListAman(
        [
          baris(101, adaTanggal: false),
          baris(102, tanggal: null),
          baris(103, tanggal: '2026-08-20'),
        ],
        CalibrationHistoryItem.fromJson,
      );

      expect(hasil.map((e) => e.id), [101, 102, 103]);
      expect(hasil[2].tanggalKalibrasi, DateTime(2026, 8, 20));
    });

    test('tanggal bertipe aneh dibaca null, bukan ngebuang barisnya', () {
      // `as String?` bakal melempar di sini dan barisnya ilang lagi — persis
      // cara bug-nya balik lewat pintu belakang.
      final hasil = parseListAman(
        [baris(104, tanggal: 20260820)],
        CalibrationHistoryItem.fromJson,
      );

      expect(hasil, hasLength(1));
      expect(hasil.single.tanggalKalibrasi, isNull);
    });
  });

  group('CalibrationDetail juga kebuka tanpa tanggal', () {
    test('detail draf tanpa tanggal ke-parse, bukan melempar', () {
      final detail = CalibrationDetail.fromJson(baris(101, adaTanggal: false));

      expect(detail.id, 101);
      expect(detail.tanggalKalibrasi, isNull);
      expect(detail.namaTeknisi, 'Andi');
    });

    test('detail bertanggal tetap kebaca apa adanya', () {
      final detail = CalibrationDetail.fromJson(
        baris(103, tanggal: '2026-08-20'),
      );

      expect(detail.tanggalKalibrasi, DateTime(2026, 8, 20));
    });
  });

  group('layar nampilin "—", bukan crash & bukan tanggal karangan', () {
    testWidgets('Riwayat: draf tanpa tanggal muncul sebagai baris', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Barisnya ADA — ini inti bug-nya: dulu kartunya nggak pernah kegambar.
      expect(find.text('Oven Memmert UN55'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);

      // Dan tanggalnya ngaku kosong. Bukan hari ini, bukan 1 Jan 1970.
      expect(find.text('Andi · —'), findsOneWidget);
      expect(find.textContaining(_hariIni), findsNothing);
    });

    testWidgets('Detail: layarnya kebuka, tanggalnya "—"', (tester) async {
      await tester.pumpWidget(_app(home: const CalibrationDetailScreen(calibrationId: 101)));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Oven Memmert UN55'), findsOneWidget);
      expect(find.text('Andi · —'), findsOneWidget);
      expect(find.textContaining(_hariIni), findsNothing);
    });
  });
}

/// Tanggal hari ini dalam format kartu Riwayat (`d MMM yyyy`, locale id) —
/// dipakai buat mastiin layar nggak diam-diam ngarang "hari ini" waktu
/// tanggalnya kosong.
String get _hariIni {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final n = DateTime.now();
  return '${n.day} ${bulan[n.month - 1]} ${n.year}';
}

/// Riwayat & detail yang isinya SATU draf tanpa tanggal, disusun dari JSON
/// mentah — bukan lewat konstruktor. Jalur `fromJson`-nya yang mau diuji.
class _SatuDrafTanpaTanggal implements HistoryService {
  static final _json = <String, dynamic>{
    'id': 101,
    'status': 'draft',
    'tanggal_kalibrasi': null,
    'equipment': {'nama_alat': 'Oven Memmert UN55'},
    'teknisi': {'nama': 'Andi'},
  };

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) async =>
      parseListAman([_json], CalibrationHistoryItem.fromJson);

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(
    String token,
  ) async => ambilRiwayat(token);

  @override
  Future<List<CalibrationHistoryItem>> ambilDraf(String token) =>
      ambilRiwayat(token);

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) async =>
      CalibrationDetail.fromJson(_json);

  @override
  Future<CalibrationDetail> verifikasiPembacaan(String token, int id) =>
      ambilDetail(token, id);
}

Widget _app({Widget home = const HistoryScreen()}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      historyServiceProvider.overrideWithValue(_SatuDrafTanpaTanggal()),
      approvalServiceProvider.overrideWithValue(MockApprovalService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}
