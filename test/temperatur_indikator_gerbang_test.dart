import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/category.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/providers/lembar_kerja_provider.dart';
import 'package:sidik_calibration/screens/calibration/instrument_picker_screen.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/calibration/temperatur_indikator_gerbang_screen.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/lembar_kerja_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/room_service.dart';
import 'package:sidik_calibration/services/standard_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// GERBANG Temperatur Indikator — satu pintu, dua isi lembar yang beda total.
///
/// Permintaan pemilik proyek (Agu 2026): "pas sebelum masuk ke dalam temperature
/// indikator nya ada 2 pilihan ... dan itu MAIN LOGIC nya. Jadi kalo semisal nya
/// dipilihnya ini, berarti semua isinya ngikutin yang dipilih."
///
/// Yang dijaga berkas ini tiga hal yang gagalnya SAMA-SAMA tanpa gejala:
///
///  1. Dua nama alat dengan ejaan beda bahasa — lampiran akreditasi LK-285-IDN
///     no. 1 nulis "Temperature Indicator tanpa Sensor" (Inggris), no. 2 nulis
///     "Temperatur Indikator dengan Sensor" (Indonesia) — dua-duanya mesti
///     mendarat di gerbang. Kalau satu lolos sendirian, dia masuk lembar apa
///     adanya tanpa pernah nanya sensornya ikut atau nggak.
///  2. Pilihan di gerbang mesti kebawa utuh ke lembar berikutnya. Milih "dengan
///     sensor" terus dapat lembar TITS itu formulir yang salah yang tetap bisa
///     diisi sampai selesai.
///  3. Varian yang lembarnya BELUM ada di server nggak boleh dibuka. Backend
///     nggak nolak profil asing — dia jatuh ke pH Meter (`kontrak-api.md` §4),
///     jadi "coba dulu siapa tau jalan" hasilnya lembar pH berjudul Temperatur
///     Indikator, tanpa satu pun error.
void main() {
  const suhu = Category(
    kode: 'suhu-dan-kelembapan',
    nama: 'Suhu & Kelembapan',
    satuan: '°C',
  );

  /// Ejaan lampiran akreditasi, apa adanya.
  const namaTits = 'Temperature Indicator tanpa Sensor';
  const namaTids = 'Temperatur Indikator dengan Sensor';

  Widget app(List<CalibrationCapability> kemampuan) => ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token-1'),
      ),
      authServiceProvider.overrideWithValue(MockAuthService()),
      categoryServiceProvider.overrideWithValue(
        _StubCategoryService(kemampuan),
      ),
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
      home: const InstrumentPickerScreen(kategori: suhu),
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

  group('ejaan nama alat → gerbang', () {
    test('dua ejaan lampiran akreditasi dikenali, varian-nya bener', () {
      expect(
        varianTemperaturIndikator(namaTits),
        VarianTemperaturIndikator.tanpaSensor,
      );
      expect(
        varianTemperaturIndikator(namaTids),
        VarianTemperaturIndikator.denganSensor,
      );
    });

    test('bahasa boleh nyampur, huruf besar/kecil & spasi dobel nggak ngaruh', () {
      // Yang dicocokin BENTUK namanya, bukan daftar ejaan. Empat campuran ini
      // semuanya beneran muncul di dokumen lab: lampiran akreditasi, judul
      // lembar kerja, dan sertifikat nulisnya beda-beda.
      for (final nama in [
        'Temperatur Indicator Tanpa Sensor',
        'Temperature Indikator tanpa sensor',
        '  TEMPERATURE   INDICATOR  TANPA SENSOR ',
      ]) {
        expect(
          varianTemperaturIndikator(nama),
          VarianTemperaturIndikator.tanpaSensor,
          reason: '"$nama" mestinya kebaca tanpa sensor',
        );
      }

      for (final nama in [
        'Temperature Indicator dengan Sensor',
        'TEMPERATUR INDIKATOR DENGAN SENSOR',
        'Temperatur  Indikator   dengan  Sensor',
      ]) {
        expect(
          varianTemperaturIndikator(nama),
          VarianTemperaturIndikator.denganSensor,
          reason: '"$nama" mestinya kebaca dengan sensor',
        );
      }
    });

    test('embel-embel merk di ekor nama nggak bikin lepas', () {
      // Nama alat pelanggan rutin dapat tambahan merk. Sama alasannya kayak
      // `profilLembarKerjaUntuk` yang nerima kunci nempel di tengah.
      expect(
        varianTemperaturIndikator('Temperature Indicator tanpa Sensor Fluke 1524'),
        VarianTemperaturIndikator.tanpaSensor,
      );
    });

    test('alat suhu LAIN nggak ikut kesedot ke gerbang', () {
      // Ketiganya tetangga sebaris di lampiran akreditasi & di kategori yang
      // sama. Kalau salah satu ikut kesedot, teknisi yang mau kalibrasi
      // Termometer Gelas malah ditanya sensornya ikut apa nggak.
      for (final nama in [
        'Temperature Calibrator',
        'Temperatur Transmitter',
        'Termometer Gelas',
        'Oven',
        'pH Meter',
      ]) {
        expect(namaTemperaturIndikator(nama), isFalse, reason: nama);
      }
    });

    test('dua nama TI satu kunci kartu, alat lain kuncinya nama sendiri', () {
      expect(kunciKartuAlat(namaTits), kunciKartuAlat(namaTids));
      expect(kunciKartuAlat(namaTits), kKunciKartuTemperaturIndikator);
      expect(kunciKartuAlat('Oven'), 'Oven');
    });
  });

  group('layar pilih alat: satu pintu, bukan dua kartu', () {
    testWidgets('dua nama alat jadi SATU kartu "Temperatur Indikator"', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const [
          CalibrationCapability(namaAlat: namaTits, profil: 'tits'),
          CalibrationCapability(namaAlat: namaTids, profil: 'tids'),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Temperatur Indikator'), findsOneWidget);
      // Nama panjang mana pun nggak boleh kelihatan lagi di daftar: dua kartu
      // di situ artinya teknisi milih varian dari daftar alat, dan yang satu
      // langsung nyeret dia ke lembar tanpa keterangan bedanya apa.
      expect(find.text(namaTits), findsNothing);
      expect(find.text(namaTids), findsNothing);
    });

    testWidgets('kartu dari baris ejaan Inggris mendarat di gerbang', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const [CalibrationCapability(namaAlat: namaTits, profil: 'tits')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Temperatur Indikator'));
      await tester.pumpAndSettle();

      expect(find.byType(TemperaturIndikatorGerbangScreen), findsOneWidget);
      expect(find.byType(LembarKerjaScreen), findsNothing);
    });

    testWidgets('kartu dari baris ejaan Indonesia mendarat di gerbang juga', (
      tester,
    ) async {
      // Test kembarannya di atas — dan justru yang ini yang gampang lolos:
      // ejaannya beda BAHASA, jadi pencocokan berbasis daftar ejaan bakal
      // ngelewatin dia dan kartunya langsung mbuka lembar.
      await tester.pumpWidget(
        app(const [CalibrationCapability(namaAlat: namaTids, profil: 'tids')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Temperatur Indikator'));
      await tester.pumpAndSettle();

      expect(find.byType(TemperaturIndikatorGerbangScreen), findsOneWidget);
      expect(find.byType(LembarKerjaScreen), findsNothing);
    });

    testWidgets('alat suhu lain di kategori yang sama tetap kartu sendiri', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const [
          CalibrationCapability(namaAlat: namaTits, profil: 'tits'),
          CalibrationCapability(namaAlat: namaTids, profil: 'tids'),
          CalibrationCapability(namaAlat: 'Oven', profil: 'oven'),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Temperatur Indikator'), findsOneWidget);
      expect(find.text('Oven'), findsOneWidget);
    });
  });

  group('pilihan di gerbang kebawa ke lembar', () {
    Future<void> bukaGerbang(
      WidgetTester tester,
      List<CalibrationCapability> kemampuan,
    ) async {
      await tester.pumpWidget(app(kemampuan));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temperatur Indikator'));
      await tester.pumpAndSettle();
    }

    testWidgets('dua pilihannya kelihatan, lengkap sama bedanya', (
      tester,
    ) async {
      await bukaGerbang(tester, const [
        CalibrationCapability(namaAlat: namaTits, profil: 'tits'),
        CalibrationCapability(namaAlat: namaTids, profil: 'tids'),
      ]);

      expect(find.text('Tanpa Sensor'), findsOneWidget);
      expect(find.text('Dengan Sensor'), findsOneWidget);
      // Keterangannya bukan hiasan: itu satu-satunya tempat teknisi bisa tau
      // bedanya sebelum milih.
      expect(find.textContaining('sensor tiruan'), findsOneWidget);
      expect(find.textContaining('satu rangkaian'), findsOneWidget);
    });

    testWidgets('"tanpa sensor" mbuka profil tits', (tester) async {
      layarPanjang(tester);
      await bukaGerbang(tester, const [
        CalibrationCapability(namaAlat: namaTits, profil: 'tits'),
        CalibrationCapability(namaAlat: namaTids, profil: 'tids'),
      ]);

      await tester.tap(find.text('Tanpa Sensor'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final layar = tester.widget<LembarKerjaScreen>(
        find.byType(LembarKerjaScreen),
      );
      expect(layar.profil, 'tits');
      // Judulnya ikut nama alat dari SERVER, bukan label pilihan di gerbang —
      // yang nyambung ke baris CMC itu ejaan lampiran akreditasi.
      expect(layar.judulTambahan, namaTits);
    });

    testWidgets('"dengan sensor" mbuka profil tids, bukan tits', (tester) async {
      layarPanjang(tester);
      await bukaGerbang(tester, const [
        CalibrationCapability(namaAlat: namaTits, profil: 'tits'),
        CalibrationCapability(namaAlat: namaTids, profil: 'tids'),
      ]);

      await tester.tap(find.text('Dengan Sensor'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final layar = tester.widget<LembarKerjaScreen>(
        find.byType(LembarKerjaScreen),
      );
      expect(layar.profil, 'tids');
      expect(layar.judulTambahan, namaTids);
    });

    testWidgets('urutan baris di daftar kemampuan nggak nentuin apa-apa', (
      tester,
    ) async {
      layarPanjang(tester);
      // TIDS duluan — kalau pilihan varian diam-diam ngikut baris pertama,
      // "Tanpa Sensor" bakal mbuka lembar TIDS di sini.
      await bukaGerbang(tester, const [
        CalibrationCapability(namaAlat: namaTids, profil: 'tids'),
        CalibrationCapability(namaAlat: namaTits, profil: 'tits'),
      ]);

      await tester.tap(find.text('Tanpa Sensor'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        tester.widget<LembarKerjaScreen>(find.byType(LembarKerjaScreen)).profil,
        'tits',
      );
    });

    testWidgets('server lama tanpa kunci `profil` tetap mbuka lembar TITS', (
      tester,
    ) async {
      layarPanjang(tester);

      // Respons mentah TANPA `profil` sama sekali — bukan `CalibrationCapability`
      // yang dirakit tangan, biar yang diuji beneran jalur parsingnya.
      final detail = CategoryDetail.fromJson(const {
        'kode': 'suhu-dan-kelembapan',
        'nama': 'Suhu & Kelembapan',
        'kemampuan': [
          {'nama_alat': namaTits, 'metode': 'SIDIK-IK-CAL-0502_Rev.3'},
          {'nama_alat': namaTids, 'metode': 'SIDIK-IK-CAL-0503_Rev.6'},
        ],
      });
      expect(detail.kemampuan.every((k) => k.profil == null), isTrue);

      await bukaGerbang(tester, detail.kemampuan);
      await tester.tap(find.text('Tanpa Sensor'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // TITS udah ada di server lama, jadi jaring tebakan-dari-nama
      // (`profilLembarKerjaUntuk`) yang nolongin — persis perilaku sepuluh alat
      // lain waktu APK baru ketemu server lama.
      expect(
        tester.widget<LembarKerjaScreen>(find.byType(LembarKerjaScreen)).profil,
        'tits',
      );
    });
  });

  group('varian yang lembarnya belum ada di server', () {
    testWidgets('ditandai, bukan disembunyiin', (tester) async {
      // Keadaan hari ini di backend: baris kemampuannya udah ada di lampiran
      // akreditasi, tapi `TidsProfile` belum jadi — jadi `profil`-nya null.
      await tester.pumpWidget(
        app(const [
          CalibrationCapability(namaAlat: namaTits, profil: 'tits'),
          CalibrationCapability(namaAlat: namaTids),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temperatur Indikator'));
      await tester.pumpAndSettle();

      // Pilihannya tetap kelihatan — yang ilang bikin teknisi ngira alatnya
      // nggak didukung sama sekali terus nyari kartu lain yang salah.
      expect(find.text('Dengan Sensor'), findsOneWidget);
      expect(find.text('Belum ada di server ini'), findsOneWidget);
    });

    testWidgets('diketuk nggak mbuka lembar apa pun, cuma ngomong', (
      tester,
    ) async {
      layarPanjang(tester);
      await tester.pumpWidget(
        app(const [
          CalibrationCapability(namaAlat: namaTits, profil: 'tits'),
          CalibrationCapability(namaAlat: namaTids),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temperatur Indikator'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dengan Sensor'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Yang paling penting di berkas ini. Backend NGGAK nolak profil asing —
      // `profil=tids` di server yang belum punya profilnya balik lembar pH
      // Meter (`CalibrationProfileRegistry::default()`), tanpa satu pun error.
      // Jadi mbuka "siapa tau jalan" hasilnya teknisi ngisi lembar pH tiga
      // titik di atas alat suhu, dan angkanya tetap masuk.
      expect(find.byType(LembarKerjaScreen), findsNothing);
      expect(find.byType(TemperaturIndikatorGerbangScreen), findsOneWidget);
      expect(find.textContaining('belum ada di server'), findsOneWidget);
    });

    testWidgets('yang satunya TETAP bisa dibuka — nggak ikut kekunci', (
      tester,
    ) async {
      layarPanjang(tester);
      await tester.pumpWidget(
        app(const [
          CalibrationCapability(namaAlat: namaTits, profil: 'tits'),
          CalibrationCapability(namaAlat: namaTids),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temperatur Indikator'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tanpa Sensor'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        tester.widget<LembarKerjaScreen>(find.byType(LembarKerjaScreen)).profil,
        'tits',
      );
    });
  });
}

/// Kategori yang isinya ditentukan test — beda dari [MockCategoryService] yang
/// datanya ikut lampiran akreditasi. Yang diadu di sini justru keadaan server
/// yang beda-beda (punya `profil`, belum punya, cuma punya satu nama), jadi
/// datanya mesti bisa dikarang per test.
class _StubCategoryService implements CategoryService {
  _StubCategoryService(this.kemampuan);

  final List<CalibrationCapability> kemampuan;

  @override
  Future<List<Category>> daftar(String token) async => const [
    Category(
      kode: 'suhu-dan-kelembapan',
      nama: 'Suhu & Kelembapan',
      satuan: '°C',
    ),
  ];

  @override
  Future<CategoryDetail> detail(String token, String kode) async =>
      CategoryDetail(
        kode: kode,
        nama: 'Suhu & Kelembapan',
        kemampuan: kemampuan,
      );

  /// Berkas ini nguji jalur BACA (kartu → gerbang → lembar), bukan jalur nambah
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
