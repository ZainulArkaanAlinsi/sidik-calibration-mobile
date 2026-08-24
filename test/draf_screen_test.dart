import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/utils/parse_list.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/calibration_history_item.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/history_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/draf/draf_screen.dart';
import 'package:sidik_calibration/services/history_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Layar Draf: rak per jenis alat, punggungnya nyebut kapan disimpen.
///
/// Yang dijaga di sini empat hal yang masing-masing pernah jadi keluhan nyata
/// di layar lain:
///
/// 1. **Kelompoknya beneran per JENIS**, bukan per alat pelanggan. Tiga pH
///    Meter dari tiga PT itu satu rak, bukan tiga.
/// 2. **Cari nyaring**, dan nyaringnya sampai ke kepala rak — rak yang isinya
///    habis nggak boleh nyisa sebagai judul menggantung.
/// 3. **Draf tanpa tanggal kalibrasi TETAP kelihatan.** Kolomnya nullable di
///    backend justru supaya draf boleh disimpen setengah jadi, dan draf tanpa
///    tanggal pernah ilang senyap dari Riwayat & antrean gara-gara jalur baca
///    yang mengandaikan tanggalnya ada (lihat `draf_tanpa_tanggal_test.dart`).
///    Layar baru nggak boleh jadi pintu balik buat bug itu.
/// 4. **Ketukan mbuka lembar yang BENAR**, lengkap sama `sesiId` & `profil`.
///    Tanpa `profil`, lembar Chlorine kebuka pakai formulir pH — 3 titik
///    4/7/10,01 di atas lembar 2 titik — dan angka yang udah diketik teknisi
///    mendarat di baris yang salah.
///
/// Datanya disusun dari JSON MENTAH, bukan lewat konstruktor: jalur
/// `fromJson`-nya yang bikin draf tanpa tanggal ilang, jadi itu yang mesti
/// kelewatan.
Map<String, dynamic> _baris({
  required int id,
  required String namaAlat,
  String? profil,
  String? jenis,
  String? pelanggan,
  Object? tanggal,
  String? diubahPada,
}) => {
  'id': id,
  'status': 'draft',
  'tanggal_kalibrasi': tanggal,
  'equipment': {
    'nama_alat': namaAlat,
    'profil': ?profil,
    'nama_alat_kemampuan': ?jenis,
  },
  'teknisi': {'nama': 'Andi'},
  if (pelanggan != null) 'pelanggan': {'nama': pelanggan},
  'updated_at': ?diubahPada,
};

/// `updated_at` dihitung mundur dari SEKARANG, bukan tanggal mati.
///
/// Layar nulis jaraknya ("2 jam lalu"), jadi tanggal tetap bakal bikin
/// tulisannya berubah tiap hari dan test-nya busuk sendiri dalam seminggu.
String _lalu(Duration jarak) =>
    DateTime.now().toUtc().subtract(jarak).toIso8601String();

final _drafJson = <Map<String, dynamic>>[
  // Tiga pH Meter dari tiga PT — satu rak, karena `profil`-nya sama.
  _baris(
    id: 11,
    namaAlat: 'pH Meter Mettler Toledo',
    profil: 'ph_meter',
    jenis: 'pH Meter',
    pelanggan: 'PT Maju Jaya',
    tanggal: '2026-08-20',
    diubahPada: _lalu(const Duration(hours: 2)),
  ),
  _baris(
    id: 12,
    namaAlat: 'pH Meter Hanna',
    profil: 'ph_meter',
    jenis: 'pH Meter',
    pelanggan: 'PT Sinar Abadi',
    tanggal: '2026-08-19',
    diubahPada: _lalu(const Duration(days: 1, hours: 3)),
  ),
  // Draf TANPA tanggal kalibrasi — sah, dan wajib tetap nongol.
  _baris(
    id: 13,
    namaAlat: 'pH Meter Eutech',
    profil: 'ph_meter',
    jenis: 'pH Meter',
    pelanggan: 'PT Tirta Nusa',
    tanggal: null,
    diubahPada: _lalu(const Duration(minutes: 40)),
  ),
  _baris(
    id: 21,
    namaAlat: 'Chlorine Meter Hanna HI97711',
    profil: 'chlorine_meter',
    jenis: 'Chlorin Meter',
    pelanggan: 'PT Maju Jaya',
    tanggal: '2026-08-18',
    diubahPada: _lalu(const Duration(hours: 5)),
  ),
];

class _ServisDraf implements HistoryService {
  int tarikan = 0;

  @override
  Future<List<CalibrationHistoryItem>> ambilDraf(String token) async {
    tarikan++;
    return parseListAman(_drafJson, CalibrationHistoryItem.fromJson);
  }

  @override
  Future<List<CalibrationHistoryItem>> ambilRiwayat(String token) =>
      ambilDraf(token);

  @override
  Future<List<CalibrationHistoryItem>> ambilAntreanApproval(String token) async =>
      const [];

  @override
  Future<CalibrationDetail> ambilDetail(String token, int id) =>
      MockHistoryService().ambilDetail(token, id);

  @override
  Future<CalibrationDetail> verifikasiPembacaan(String token, int id) =>
      MockHistoryService().verifikasiPembacaan(token, id);
}

Widget _app(HistoryService servis) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(
      InMemoryTokenStorage('mock-token-2'),
    ),
    authServiceProvider.overrideWithValue(MockAuthService()),
    historyServiceProvider.overrideWithValue(servis),
  ],
  child: MaterialApp(
    locale: const Locale('id'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const DrafScreen(),
  ),
);

Future<void> _pasang(
  WidgetTester tester, {
  HistoryService? servis,
  Size ukuran = const Size(1000, 2400),
}) async {
  // Layarnya panjang: dua rak + empat kartu. Di 600px bawaan, kartu terakhir
  // nggak pernah ke-layout dan `findsOneWidget` gagal karena alasan yang nggak
  // ada hubungannya sama yang lagi diuji.
  tester.view.physicalSize = ukuran;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(servis ?? _ServisDraf()));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  testWidgets('draf dikelompokkan per jenis alat, bukan per alat pelanggan', (
    tester,
  ) async {
    await _pasang(tester);

    // Kepala rak = nama JENIS dari lampiran akreditasi, sekali per jenis.
    expect(find.text('pH Meter'), findsOneWidget);
    expect(find.text('Chlorin Meter'), findsOneWidget);

    // Tiga pH Meter dari tiga PT numpuk di satu rak, bukan mekar jadi tiga.
    expect(find.text('3 draf'), findsOneWidget);
    expect(find.text('1 draf'), findsOneWidget);

    // Dan tiap punggungnya tetap nyebut alat + PT-nya sendiri.
    expect(find.text('pH Meter Mettler Toledo'), findsOneWidget);
    expect(find.text('PT Sinar Abadi'), findsOneWidget);
  });

  testWidgets('kapan disimpen ditulis dalam bahasa manusia, bukan timestamp', (
    tester,
  ) async {
    await _pasang(tester);

    expect(find.text('Disimpan 2 jam lalu'), findsOneWidget);
    expect(find.text('Disimpan Kemarin'), findsOneWidget);
    expect(find.text('Disimpan 40 menit lalu'), findsOneWidget);

    // Yang dijaga: NGGAK ada jam mentah di baris mana pun. Itu seluruh alasan
    // `waktuLalu` dibikin kepisah dari `waktuRelatif`.
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('draf tanpa tanggal kalibrasi TETAP muncul di raknya', (
    tester,
  ) async {
    await _pasang(tester);

    // Inti bug lama: barisnya nggak pernah kegambar sama sekali.
    expect(find.text('pH Meter Eutech'), findsOneWidget);

    // Dan dia nggak diturunin ke dasar daftar gara-gara tanggalnya kosong —
    // yang nentuin urutan waktu SIMPAN, dan 40 menit lalu itu yang paling baru.
    final eutech = tester.getTopLeft(find.text('pH Meter Eutech')).dy;
    final mettler = tester
        .getTopLeft(find.text('pH Meter Mettler Toledo'))
        .dy;
    expect(eutech, lessThan(mettler));
  });

  testWidgets('cari nyaring, dan rak yang habis ikut ilang', (tester) async {
    await _pasang(tester);

    await tester.enterText(find.byType(TextField), 'chlorine');
    // Kolomnya di-debounce 400ms — tanpa nunggu, daftarnya masih yang lama.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Chlorine Meter Hanna HI97711'), findsOneWidget);
    expect(find.text('pH Meter Mettler Toledo'), findsNothing);
    // Kepala raknya ikut, bukan nyisa judul yang nggak ada isinya.
    expect(find.text('pH Meter'), findsNothing);
    expect(find.text('Chlorin Meter'), findsOneWidget);
  });

  testWidgets('cari juga kena nama pelanggan', (tester) async {
    await _pasang(tester);

    await tester.enterText(find.byType(TextField), 'tirta');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Draf tanpa tanggal ikut kesaring dengan benar — penyaringnya nggak nyentuh
    // tanggal sama sekali.
    expect(find.text('pH Meter Eutech'), findsOneWidget);
    expect(find.text('pH Meter Hanna'), findsNothing);
  });

  testWidgets('kata yang nggak kena siapa-siapa bilangnya beda dari layar kosong', (
    tester,
  ) async {
    await _pasang(tester);

    await tester.enterText(find.byType(TextField), 'viscometer');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Nggak ada draf yang cocok.'), findsOneWidget);
    expect(find.text('Belum ada draf'), findsNothing);
  });

  testWidgets('ketukan mbuka lembar kerja yang benar — sesiId + profil', (
    tester,
  ) async {
    await _pasang(tester);

    await tester.tap(find.text('Chlorine Meter Hanna HI97711'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final lembar = tester.widget<LembarKerjaScreen>(
      find.byType(LembarKerjaScreen),
    );

    // `sesiId` = nerusin draft yang ADA. Tanpa itu tombolnya cuma bikin sesi
    // kedua yang kosong dan isian lamanya ilang.
    expect(lembar.sesiId, 21);
    // `profil` = formulir yang bener. Jatuh ke default `ph_meter` di sini
    // berarti lembar 2 titik chlorine digambar sebagai 3 titik pH.
    expect(lembar.profil, 'chlorine_meter');
  });

  /// Layar HP beneran, sengaja: `RefreshIndicator` cuma nyaut kalau daftarnya
  /// beneran bisa di-overscroll, dan di jendela 2400px isinya nggak nyampe
  /// setengah layar — gesturnya nggak pernah nyentuh batas atas.
  testWidgets('tarik-segarkan narik ulang daftarnya', (tester) async {
    final servis = _ServisDraf();
    await _pasang(tester, servis: servis, ukuran: const Size(390, 600));

    final sebelum = servis.tarikan;

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(servis.tarikan, greaterThan(sebelum));
  });
}
