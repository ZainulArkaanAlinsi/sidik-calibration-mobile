import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/core/config/app_config.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'package:sidik_calibration/services/worksheet_scan_service.dart';

/// **UI pindai NYALA — tapi cuma di lembar yang beneran bisa dipindai.**
///
/// ## Kenapa berkas ini ada
///
/// Enam belas berkas test masih nyebut pindai, tapi sepuluh di antaranya
/// nguji LAYANANNYA langsung (`pindai_lembar`, `peta_tabel_foto`,
/// `jalankan_pindai`) — nggak satu pun lewat layar. Artinya `flutter test`
/// hijau bukan bukti tombolnya ada ATAU nggak ada: kalau salah satu dari dua
/// titik render kelewat, semua tetap hijau.
///
/// Dua titik render itu:
///
///  - `PINDAI LEMBAR KERJA` — sekali di atas tabel, dari `_Bagian`;
///  - `FOTO TABEL INI` — sekali di ATAS SETIAP tabel, dari `LembarKerjaTabel`.
///
/// ## Yang berubah 25 Agt 2026
///
/// Saklarnya dinyalain lagi atas keputusan pemilik proyek — membalik
/// permintaan 3. Jadi yang dijaga di sini kebalik juga: dulu KETIADAAN
/// tombolnya, sekarang KEHADIRANNYA plus **gerbang yang bikin dia nggak
/// muncul di lembar yang salah.**
///
/// Tiga hal yang dijaga, dan yang ketiga yang paling gampang lolos:
///
///  1. Bawaannya NYALA (`AppConfig.pindaiLembarAktif`), tanpa perlu
///     `--dart-define`.
///  2. Saklarnya masih SAKLAR — dimatiin, dua-duanya hilang lagi.
///  3. `FOTO TABEL INI` ikut gerbang `pindai_foto` dari server. Lembar
///     Autoklaf (matriks 7 besaran × 5 titik waktu) nggak muat di bentuk
///     "titik ukur × Repeat", dan jalur AI Vision buat lembar itu nggak balik
///     error — dia balik ANGKA NGAWUR YANG KELIHATAN WAJAR. Itu kegagalan
///     yang paling mahal di fitur ini.
///
/// ## Yang berubah 27 Agt 2026: gerbangnya jadi DUA
///
/// `pindai_foto` sekarang membawa `didukung` (jalur cloud, fotonya keluar HP)
/// dan `lokal` (tombol ini, ML Kit di perangkat) terpisah. Yang menentukan
/// tombolnya `lokal`; `didukung` cuma jadi cadangan buat server lama yang
/// belum kenal kuncinya. Grup test terakhir di berkas ini yang menjaga
/// bedanya — dan bedanya bukan kosmetik: menyatukannya lagi berarti
/// menyalakan tombol TIDS harus dibayar dengan mengizinkan fotonya dikirim
/// ke penyedia AI pihak ketiga.
///
void main() {
  /// Viewport dibikin raksasa biar SELURUH lembar ke-build sekaligus.
  ///
  /// Ini bukan kosmetik: `ListView` cuma nge-build yang deket layar, dan
  /// tombol yang belum ke-build kelihatannya sama persis kayak tombol yang
  /// emang nggak digambar — `findsNothing`-nya bakal hijau bohongan.
  /// Lebarnya sengaja di bawah ambang dua kolom (1100): ini mode halaman,
  /// yang dipakai teknisi di HP.
  void perbesarViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 14000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app({required bool pindaiAktif, bool didukung = true, bool? lokal}) =>
      ProviderScope(
    overrides: [
      // Waktu NYALA, providernya sengaja NGGAK di-override sama sekali: yang
      // diuji test pertama itu nilai BAWAANNYA, jadi dia harus lewat jalur
      // yang sama persis dengan produksi (`AppConfig.pindaiLembarAktif`).
      // `overrideWithValue(true)` cuma bakal nguji override-nya sendiri.
      if (!pindaiAktif) pindaiLembarAktifProvider.overrideWithValue(false),
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      lembarKerjaServiceProvider.overrideWithValue(
        MockLembarKerjaService(
          fotoTabelDidukung: didukung,
          fotoTabelLokal: lokal,
        ),
      ),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
      // Bawaannya `siap_pindai: false` — sama kayak server sekarang. Sengaja:
      // biar kelihatan bedanya "tombolnya MATI" (lembar belum siap dipindai)
      // sama "tombolnya NGGAK ADA" (saklar UI-nya mati).
      worksheetScanServiceProvider.overrideWithValue(MockWorksheetScanService()),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LembarKerjaScreen(profil: 'ph_meter'),
    ),
  );

  /// Buka layar sampai halaman yang ada tabelnya.
  ///
  /// `pumpAndSettle` doang nggak cukup: `MockAuthService.me()` jeda 600 ms
  /// lewat `Future.delayed`, dan timer kayak gitu nggak ngejadwalin frame.
  ///
  /// Loop `LANJUT KE HALAMAN BERIKUTNYA`-nya jaring pengaman: bentuk pH mock
  /// sekarang satu halaman, tapi lembar aslinya dua — dan tombol yang diuji
  /// ada di halaman yang ada tabelnya.
  Future<void> bukaSampaiTabel(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final lanjut = find.text('LANJUT KE HALAMAN BERIKUTNYA');
    while (lanjut.evaluate().isNotEmpty) {
      await tester.tap(lanjut);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('saklar bawaan NYALA — dan yang tersisa cuma FOTO TABEL INI', (
    tester,
  ) async {
    // Bawaannya NYALA, dan itu bagian dari yang dijaga: begitu ada yang
    // ngubah `defaultValue`-nya balik jadi false, yang jebol duluan baris ini
    // — bukan teknisi yang tiba-tiba kehilangan tombol di lapangan.
    expect(
      AppConfig.pindaiLembarAktif,
      isTrue,
      reason: 'UI pindai harusnya nyala tanpa perlu --dart-define',
    );

    perbesarViewport(tester);
    await bukaSampaiTabel(tester, app(pindaiAktif: true));

    // DICABUT PERMANEN 26 Agt 2026 atas permintaan pemilik lab. Ini bukan
    // "kebetulan lagi nggak kegambar" — baris ini yang menahan tombolnya
    // balik lewat revert atau salin-tempel dari lembar lain.
    expect(
      find.text('PINDAI LEMBAR KERJA'),
      findsNothing,
      reason: 'Tombol pindai lembar penuh sudah dicabut permanen dari SEMUA lembar.',
    );

    // Satu per TABEL, bukan satu per lembar — pH punya Before & After.
    expect(find.text('FOTO TABEL INI'), findsNWidgets(2));
  });

  testWidgets('saklarnya masih SAKLAR — dimatiin, FOTO TABEL INI hilang', (
    tester,
  ) async {
    perbesarViewport(tester);
    await bukaSampaiTabel(tester, app(pindaiAktif: false));

    // Lembarnya beneran kebangun — tanpa jangkar ini, dua `findsNothing` di
    // bawah bisa hijau gara-gara layarnya kosong/gagal muat.
    expect(find.text('Before adjustment Reading'), findsOneWidget);
    expect(find.text('After adjustment Reading'), findsOneWidget);

    expect(find.text('PINDAI LEMBAR KERJA'), findsNothing);
    expect(find.text('FOTO TABEL INI'), findsNothing);
  });

  testWidgets(
    'dua gerbang mati (server lama, didukung: false): FOTO TABEL INI ilang',
    (tester) async {
      perbesarViewport(tester);
      await bukaSampaiTabel(
        tester,
        app(pindaiAktif: true, didukung: false),
      );

      // Lembarnya kebangun.
      expect(find.text('Before adjustment Reading'), findsOneWidget);

      expect(
        find.text('FOTO TABEL INI'),
        findsNothing,
        reason:
            'Kertas Autoklaf nggak muat di bentuk "titik x Repeat". Jalur AI '
            'Vision buat lembar itu nggak balik error — dia balik angka '
            'ngawur yang kelihatan wajar.',
      );

      // Dulu di sini OCR template lokal TETAP ADA sebagai jalur cadangan —
      // gerbangnya beda (`siap_pindai` per template, bukan bentuk kertas).
      // Tombolnya sudah dicabut permanen, jadi kertas yang nggak muat di
      // bentuk "titik x Repeat" sekarang NGGAK punya jalur kamera sama
      // sekali. Konsekuensi yang ditanggung sadar; lihat komentar di
      // `lembar_kerja_screen.dart`.
      expect(find.text('PINDAI LEMBAR KERJA'), findsNothing);
    },
  );

  /// **Dua gerbang, dan yang menyalakan tombol yang LOKAL.**
  ///
  /// Ini regresi yang beneran kejadian, bukan kasus karangan. Tombol TIDS
  /// dinyalakan (27 Agt 2026) dengan menaikkan `didukung` — satu-satunya
  /// gerbang yang ada waktu itu. Yang ikut kebawa: lembar TIDS jadi memenuhi
  /// syarat dikirim ke `raw-measurements/extract-from-photo`, endpoint yang
  /// MENGIRIM FOTO LEMBAR KERJA PELANGGAN KE LAYANAN PIHAK KETIGA, begitu
  /// Vision di server nyala. Nggak ada yang berniat begitu; gerbangnya cuma
  /// kebetulan satu.
  ///
  /// Sekarang server mengirim keduanya, dan TIDS hidup di kombinasi
  /// `didukung: false` + `lokal: true`. Kalau layar balik membaca `didukung`,
  /// yang jebol BUKAN keamanannya — yang jebol tombolnya, hilang dari lembar
  /// TIDS tanpa satu pun error. Dua-duanya arah yang mahal, jadi dua-duanya
  /// dijaga di sini.
  group('gerbang lokal vs cloud', () {
    testWidgets('didukung: false + lokal: true → tombolnya TETAP ADA', (
      tester,
    ) async {
      perbesarViewport(tester);
      await bukaSampaiTabel(
        tester,
        app(pindaiAktif: true, didukung: false, lokal: true),
      );

      expect(find.text('Before adjustment Reading'), findsOneWidget);

      expect(
        find.text('FOTO TABEL INI'),
        findsNWidgets(2),
        reason:
            'Itu kombinasi TIDS. Layar yang masih baca `didukung` bikin '
            'tombolnya ilang dari lembar itu tanpa satu pun error.',
      );
    });

    testWidgets('didukung: true + lokal: false → tombolnya HILANG', (
      tester,
    ) async {
      perbesarViewport(tester);
      await bukaSampaiTabel(
        tester,
        app(pindaiAktif: true, didukung: true, lokal: false),
      );

      expect(find.text('Before adjustment Reading'), findsOneWidget);

      expect(
        find.text('FOTO TABEL INI'),
        findsNothing,
        reason:
            'Arah sebaliknya, dan ini yang bikin `lokal` beneran gerbang: '
            'kalau layar masih baca `didukung`, test ini yang jebol duluan.',
      );
    });

    testWidgets('server lama (cuma kirim didukung) tetap dimengerti', (
      tester,
    ) async {
      // APK baru ketemu server lama itu keadaan normal, bukan kasus pojok —
      // lab nge-update HP-nya duluan. Tanpa jatuh balik ke `didukung`, SEMUA
      // tombol foto ilang di lapangan begitu APK-nya naik.
      perbesarViewport(tester);
      await bukaSampaiTabel(tester, app(pindaiAktif: true, didukung: true));

      expect(find.text('FOTO TABEL INI'), findsNWidgets(2));
    });
  });

  /// Aturan parsing-nya sendiri, tanpa lewat layar.
  ///
  /// Yang di atas nguji lembar pH lewat `MockLembarKerjaService`, jadi dia
  /// nggak bisa menyuapkan `pindai_foto` yang bentuknya rusak — dan justru di
  /// situ bawaan yang salah paling mahal: `pindai_foto` yang bukan Map, atau
  /// nilai yang bukan bool, nggak boleh bikin tombolnya ilang diam-diam.
  group('bacaan penanda pindai_foto', () {
    bool baca(Object? pindaiFoto) => LembarKerja.fromJson(<String, dynamic>{
      'judul': 'uji',
      'bagian': const <dynamic>[],
      'pindai_foto': ?pindaiFoto,
    }).fotoTabelDidukung;

    test('`lokal` menang atas `didukung`, dua arah', () {
      expect(baca(<String, dynamic>{'didukung': false, 'lokal': true}), isTrue);
      expect(baca(<String, dynamic>{'didukung': true, 'lokal': false}), isFalse);
    });

    test('tanpa `lokal` → jatuh ke `didukung`', () {
      expect(baca(<String, dynamic>{'didukung': false}), isFalse);
      expect(baca(<String, dynamic>{'didukung': true}), isTrue);
    });

    test('penanda hilang atau cacat → NYALA, bukan mati', () {
      // Salah di sisi yang aman: tombolnya muncul, dan jangkar `PetaTabelFoto`
      // yang menolak kalau kertasnya emang nggak cocok. Mati diam-diam bikin
      // teknisi kehilangan kamera tanpa satu pun keterangan.
      expect(baca(null), isTrue);
      expect(baca('bukan map'), isTrue);
      expect(baca(const <String, dynamic>{}), isTrue);
      expect(baca(<String, dynamic>{'lokal': 'ya', 'didukung': 1}), isTrue);
    });
  });
}
