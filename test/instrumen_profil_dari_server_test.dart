import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/category.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/calibration_input_screen.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/services/calibration_service.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// SIAPA yang menentukan lembar kerja: server, bukan tabel di dalam APK.
///
/// Sebelum ini picker nebak profil dari nama alat lewat `_profilKhusus` —
/// ~26 ejaan yang ikut ke-bundel waktu APK dibangun. Konsekuensinya bukan cuma
/// "kurang rapi": begitu admin atau teknisi nambah nama alat baru lewat
/// `POST /api/categories/{kode}/kemampuan`, alat itu MUSTAHIL dapat lembar yang
/// benar — namanya belum pernah ada waktu tabelnya dibekukan, dan tabelnya ada
/// di HP orang, bukan di server.
///
/// Gagalnya tanpa gejala, seperti biasa di jalur ini: tebakan meleset =
/// `null` = form generik, tanpa satu pun error. Teknisi ngisi formulir yang
/// salah dan angkanya tetap masuk.
void main() {
  const suhu = Category(
    kode: 'suhu-dan-kelembapan',
    nama: 'Suhu & Kelembapan',
    satuan: '°C',
  );

  Widget app(List<CalibrationCapability> kemampuan) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(
        // Jeda dinolkan: test ini nggak nguji state loading auth, dan sejak
        // provider datanya ikut `ref.watch(authProvider)`, jeda default bikin
        // timer `me()` hidup lebih lama dari pohon widgetnya.
        MockAuthService(jeda: Duration.zero),
      ),
      categoryServiceProvider.overrideWithValue(
        _StubCategoryService(kemampuan),
      ),
      lembarKerjaServiceProvider.overrideWithValue(MockLembarKerjaService()),
      standardServiceProvider.overrideWithValue(MockStandardService()),
      roomServiceProvider.overrideWithValue(MockRoomService()),
      calibrationServiceProvider.overrideWithValue(MockCalibrationService()),
      equipmentLookupServiceProvider.overrideWithValue(
        MockEquipmentLookupService(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('id'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: InstrumentPickerScreen(kategori: suhu),
    ),
  );

  /// Lembar kerja itu panjang — di layar 800x600 bawaan sebagian isinya ada di
  /// pohon tapi belum kegambar, dan `find.text` cuma lihat yang kegambar.
  void layarPanjang(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 5200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<LembarKerjaScreen> ketuk(WidgetTester tester, String nama) async {
    await tester.tap(find.text(nama));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return tester.widget<LembarKerjaScreen>(find.byType(LembarKerjaScreen));
  }

  group('profil dari server yang menentukan lembar kerja', () {
    testWidgets('nama alat yang MUSTAHIL ditebak tetap dapat lembarnya', (
      tester,
    ) async {
      layarPanjang(tester);

      // Persis kasus yang bikin perubahan ini ada: nama alat yang baru
      // ditambah teknisi. Nol kemiripan sama ejaan mana pun di `_profilKhusus`,
      // jadi jalur tebakan lama pasti pulang `null` dan alatnya jatuh ke form
      // generik. Yang nyelametin cuma `profil` dari server.
      expect(profilLembarKerjaUntuk('Alat Suhu Rakitan Pak Budi'), isNull);

      await tester.pumpWidget(
        app(const [
          CalibrationCapability(
            namaAlat: 'Alat Suhu Rakitan Pak Budi',
            profil: 'tits',
            tanpaCmc: true,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      final layar = await ketuk(tester, 'Alat Suhu Rakitan Pak Budi');
      expect(layar.profil, 'tits');

      // Dua dropdown yang cuma TITS punya — bukti lembarnya beneran kebuka,
      // bukan cuma kode profil yang kebetulan lewat.
      expect(find.text('1. Mode'), findsOneWidget);
      expect(find.text('2. Temperature Type'), findsOneWidget);
    });

    testWidgets('server MENANG atas tebakan nama yang meleset', (tester) async {
      layarPanjang(tester);

      // Test yang paling penting di berkas ini. Namanya memuat "pH Meter", jadi
      // tebakan lama PASTI ngasih `ph_meter` — dan diam-diam salah, karena
      // lab-nya mendaftarkan alat itu sebagai DO Meter. Kalau urutannya kebalik
      // (tebakan dulu, server cadangan), test ini yang bunyi.
      expect(profilLembarKerjaUntuk('pH Meter Portable Baru'), 'ph_meter');

      await tester.pumpWidget(
        app(const [
          CalibrationCapability(
            namaAlat: 'pH Meter Portable Baru',
            profil: 'do_meter',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      final layar = await ketuk(tester, 'pH Meter Portable Baru');
      expect(layar.profil, 'do_meter');
    });
  });

  group('server lama tanpa kunci `profil` tetap jalan', () {
    testWidgets('kartunya balik ke tebakan nama, persis perilaku lama', (
      tester,
    ) async {
      layarPanjang(tester);

      // Respons mentah TANPA `profil` & `tanpa_cmc` sama sekali — bukan
      // `CalibrationCapability` yang dirakit tangan, biar yang diuji beneran
      // jalur parsingnya.
      final detail = CategoryDetail.fromJson(const {
        'kode': 'instrumen-analitik',
        'nama': 'Instrumen Analitik',
        'kemampuan': [
          {'nama_alat': 'pH Meter', 'metode': 'SIDIK-IK-CAL-0506_Rev.6'},
        ],
      });

      expect(detail.kemampuan.single.profil, isNull);
      expect(detail.kemampuan.single.tanpaCmc, isFalse);

      await tester.pumpWidget(app(detail.kemampuan));
      await tester.pumpAndSettle();

      final layar = await ketuk(tester, 'pH Meter');
      expect(layar.profil, 'ph_meter');
    });

    testWidgets('alat tanpa profil & tanpa tebakan lanjut ke form generik', (
      tester,
    ) async {
      layarPanjang(tester);

      await tester.pumpWidget(
        app(const [CalibrationCapability(namaAlat: 'Alat Rakitan Pak Budi')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alat Rakitan Pak Budi'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(CalibrationInputScreen), findsOneWidget);
      expect(find.byType(LembarKerjaScreen), findsNothing);
    });
  });

  group('penanda alat tanpa lantai CMC', () {
    testWidgets('kelihatan di kartunya, bukan cuma di data', (tester) async {
      await tester.pumpWidget(
        app(const [
          CalibrationCapability(
            namaAlat: 'Alat Suhu Rakitan Pak Budi',
            profil: 'tits',
            tanpaCmc: true,
          ),
          CalibrationCapability(
            namaAlat: 'Oven',
            ketidakpastianTerbaik: 1.5,
            satuanKetidakpastian: '°C',
            profil: 'oven',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // Cuma SATU — alat yang punya baris CMC di lampiran akreditasi nggak
      // boleh ikut dipenandai, kalau nggak penandanya jadi bising dan berhenti
      // dibaca orang.
      expect(find.text('Belum ada rentang CMC'), findsOneWidget);
    });

    testWidgets('alatnya TETAP boleh dipilih, cuma nggak boleh diam-diam', (
      tester,
    ) async {
      layarPanjang(tester);

      await tester.pumpWidget(
        app(const [
          CalibrationCapability(
            namaAlat: 'Alat Suhu Rakitan Pak Budi',
            profil: 'tits',
            tanpaCmc: true,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // Penandanya peringatan, bukan kunci: alat baru memang masuk lewat sini,
      // dan menutup jalannya cuma bikin teknisi milih kartu lain yang salah.
      final layar = await ketuk(tester, 'Alat Suhu Rakitan Pak Budi');
      expect(layar.profil, 'tits');
    });
  });

  group('parsing dua field baru tahan bentuk apa pun', () {
    List<CalibrationCapability> parse(List<Map<String, dynamic>> baris) =>
        CategoryDetail.fromJson({
          'kode': 'suhu-dan-kelembapan',
          'nama': 'Suhu & Kelembapan',
          'kemampuan': baris,
        }).kemampuan;

    test('field yang nggak ada = null & false, bukan parsing gagal', () {
      final k = parse([
        {'nama_alat': 'Oven'},
      ]).single;

      expect(k.profil, isNull);
      expect(k.tanpaCmc, isFalse);
    });

    test('bentuk lengkap dari kontrak dibaca apa adanya', () {
      final k = parse([
        {
          'nama_alat': 'Temperature Indicator tanpa Sensor',
          'profil': 'tits',
          'tanpa_cmc': false,
        },
      ]).single;

      expect(k.profil, 'tits');
      expect(k.tanpaCmc, isFalse);
    });

    test('`tanpa_cmc` yang nyampe sebagai 1/0 tetap kebaca', () {
      // Kolom tinyint yang lupa di-`cast` di Eloquent nyampe sebagai angka.
      // `as bool?` bakal ngelempar di situ, dan `parseListAman` nelen
      // lemparannya — kartunya HILANG dari picker, bukan cuma penandanya.
      final k = parse([
        {'nama_alat': 'Alat Baru', 'tanpa_cmc': 1},
        {'nama_alat': 'Oven', 'tanpa_cmc': 0},
      ]);

      expect(k, hasLength(2));
      expect(k.first.tanpaCmc, isTrue);
      expect(k.last.tanpaCmc, isFalse);
    });

    test('`profil` kosong/aneh dianggap form generik, barisnya nggak dibuang', () {
      // String kosong nggak boleh dioper ke `LembarKerjaScreen` — layarnya
      // bakal minta bentuk lembar `''` ke server. Dan tipe yang nggak
      // diharapkan nggak boleh bikin barisnya lenyap diam-diam.
      final k = parse([
        {'nama_alat': 'Alat A', 'profil': ''},
        {'nama_alat': 'Alat B', 'profil': '   '},
        {'nama_alat': 'Alat C', 'profil': 7},
        {'nama_alat': 'Alat D', 'profil': null},
      ]);

      expect(k.map((e) => e.namaAlat), [
        'Alat A',
        'Alat B',
        'Alat C',
        'Alat D',
      ]);
      expect(k.every((e) => e.profil == null), isTrue);
    });

    test('spasi di ujung `profil` dirapetin, bukan dikirim apa adanya', () {
      expect(
        parse([
          {'nama_alat': 'Oven', 'profil': ' oven '},
        ]).single.profil,
        'oven',
      );
    });
  });
}

/// Kategori yang isinya ditentukan test — beda dari [MockCategoryService] yang
/// datanya ikut lampiran akreditasi. Yang mau diuji di sini justru alat yang
/// BELUM ada di lampiran, jadi datanya mesti bisa dikarang per test.
class _StubCategoryService implements CategoryService {
  _StubCategoryService(this.kemampuan);

  final List<CalibrationCapability> kemampuan;

  @override
  Future<List<Category>> daftar(String token) async => const [
    Category(kode: 'suhu-dan-kelembapan', nama: 'Suhu & Kelembapan', satuan: '°C'),
  ];

  @override
  Future<CategoryDetail> detail(String token, String kode) async =>
      CategoryDetail(
        kode: kode,
        nama: 'Suhu & Kelembapan',
        kemampuan: kemampuan,
      );

  /// Berkas ini nguji jalur BACA (kartu → lembar kerja), bukan jalur nambah
  /// alat. Sengaja ngelempar, bukan diam-diam balikin baris kosong: kalau suatu
  /// saat ada test di sini yang nyenggol tombol tambah, yang nongol mesti
  /// lemparan yang nunjuk ke berkas ini, bukan kartu hantu yang bikin bingung.
  @override
  Future<CalibrationCapability> tambahKemampuan(
    String token,
    String kode,
    String namaAlat,
  ) async {
    throw UnimplementedError(
      'stub baca-saja: pakai MockCategoryService buat jalur tambah kemampuan',
    );
  }
}
