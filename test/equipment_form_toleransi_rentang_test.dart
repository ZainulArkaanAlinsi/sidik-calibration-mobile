import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart'
    show categoryServiceProvider;
import 'package:sidik_calibration/providers/equipment_provider.dart';
import 'package:sidik_calibration/providers/master_data_provider.dart'
    show customerLookupServiceProvider;
import 'package:sidik_calibration/screens/equipment/equipment_form_screen.dart';
import 'package:sidik_calibration/services/category_service.dart';
import 'package:sidik_calibration/services/customer_lookup_service.dart';
import 'package:sidik_calibration/services/equipment_service.dart';
import 'package:sidik_calibration/services/mock_auth_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';
import 'support/simpanan_tiruan.dart';
import 'package:sidik_calibration/widgets/app_text_field.dart';

/// Form Tambah Alat, dua hal yang menghambat teknisi di lapangan:
///
/// **Satu — toleransi yang diwajibkan buat alat yang nggak divonis.** Form ini
/// dulu minta `toleransi` buat SEMUA alat, alasannya "alat tanpa toleransi
/// nggak bisa dikalibrasi — 422 belakangan". Alasan itu keliru buat 15 dari 20
/// profil: masternya berhenti di `U95%` tanpa batas keberterimaan, dan
/// validator server sengaja melewatinya, jadi 422-nya nggak pernah datang. Yang
/// datang justru teknisi MENGARANG angka toleransi — mengarang kriteria
/// kelulusan.
///
/// **Dua — rentang yang diketik ulang dari kertas.** Rentang min/maks tiap
/// jenis alat ditentukan PT Sidik dan sudah ada di lampiran akreditasi yang
/// dikirim server tiap kali kategori dibuka. Teknisi nggak perlu menyalinnya
/// lagi.
class _EquipmentServicePerekam implements EquipmentService {
  Equipment? terkirim;

  @override
  Future<EquipmentPage> daftar(
    String token, {
    String? search,
    String? kategori,
    String? status,
    int page = 1,
  }) async => const EquipmentPage(items: [], currentPage: 1, lastPage: 1);

  @override
  Future<Equipment> simpan(String token, Equipment data) async {
    terkirim = data;
    return data;
  }

  @override
  Future<Equipment> ubah(String token, Equipment data) async {
    terkirim = data;
    return data;
  }

  @override
  Future<void> hapus(String token, int id) async {}
}

void main() {
  pasangSimpananTiruan();

  Widget app(
    _EquipmentServicePerekam perekam, {
    String? kategori,
    String? namaKemampuan,
  }) {
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(
          InMemoryTokenStorage('mock-token-1'),
        ),
        authServiceProvider.overrideWithValue(MockAuthService()),
        equipmentServiceProvider.overrideWithValue(perekam),
        categoryServiceProvider.overrideWithValue(MockCategoryService()),
        customerLookupServiceProvider.overrideWithValue(
          MockCustomerLookupService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EquipmentFormScreen(
                    kategoriAwal: kategori,
                    namaAlatKemampuanAwal: namaKemampuan,
                  ),
                ),
              ),
              child: const Text('BUKA FORM'),
            ),
          ),
        ),
      ),
    );
  }

  Future<_EquipmentServicePerekam> buka(
    WidgetTester tester, {
    String? kategori,
    String? namaKemampuan,
  }) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final perekam = _EquipmentServicePerekam();
    await tester.pumpWidget(
      app(perekam, kategori: kategori, namaKemampuan: namaKemampuan),
    );
    // `MockAuthService.me()` berjeda 600ms — sebelum itu kelar `bisaInput`
    // masih false dan tombol simpannya belum ada.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BUKA FORM'));
    await tester.pumpAndSettle();

    return perekam;
  }

  /// Kotak isian yang labelnya [label]. Labelnya `AppTextField` itu `Text`
  /// terpisah DI ATAS `TextField`-nya (dan di-uppercase pas dirender), bukan
  /// `labelText` di dalam dekorasinya — jadi dialamatin lewat widget-nya.
  Finder kotak(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
    matching: find.byType(TextField),
  );

  String isi(WidgetTester tester, String label) =>
      tester.widget<TextField>(kotak(label)).controller!.text;

  Future<void> simpan(WidgetTester tester) async {
    // Viewport test-nya sengaja 6000px — form ini panjang, dan `ListView`
    // cuma nge-build item yang deket viewport.
    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();
  }

  group('toleransi cuma diwajibkan buat alat yang DIVONIS PASS/FAIL', () {
    testWidgets('Thermocouple: toleransi kosong bukan error', (tester) async {
      await buka(
        tester,
        kategori: 'suhu-dan-kelembapan',
        namaKemampuan: 'Thermocouple',
      );

      await simpan(tester);

      expect(find.text('Toleransi wajib diisi.'), findsNothing);
      // Kalimat di bawah kotaknya ikut ganti — yang lama ("alat tanpa toleransi
      // nggak bisa dikalibrasi") bukan cuma nggak akurat, dia MENYURUH.
      expect(find.textContaining('Boleh dikosongin'), findsOneWidget);
      expect(
        find.textContaining('nggak bisa dikalibrasi'),
        findsNothing,
      );
    });

    testWidgets('pH Meter: toleransi kosong TETAP error', (tester) async {
      // Jaga arah sebaliknya. Lima dari dua puluh profil beneran divonis, dan
      // di situ toleransi yang kelewat itu angka yang nentuin PASS/FAIL.
      await buka(
        tester,
        kategori: 'instrumen-analitik',
        namaKemampuan: 'pH Meter',
      );

      await simpan(tester);

      expect(find.text('Toleransi wajib diisi.'), findsOneWidget);
      expect(find.textContaining('nggak bisa dikalibrasi'), findsOneWidget);
    });

    testWidgets('jenis alat belum dipilih: tetap diwajibkan', (tester) async {
      // Bawaan aman. Selama jawabannya belum ada, perilaku lama yang berlaku.
      await buka(tester);
      await simpan(tester);

      expect(find.text('Toleransi wajib diisi.'), findsOneWidget);
    });

    testWidgets('ganti jenis alat: error toleransi lama nggak nyangkut', (
      tester,
    ) async {
      await buka(
        tester,
        kategori: 'instrumen-analitik',
        namaKemampuan: 'pH Meter',
      );
      await simpan(tester);
      expect(find.text('Toleransi wajib diisi.'), findsOneWidget);

      // Pindah ke alat yang nggak divonis lewat dropdown-nya.
      await tester.tap(find.text('pH Meter').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spectrophotometer').last);
      await tester.pumpAndSettle();

      expect(find.text('Toleransi wajib diisi.'), findsNothing);
    });
  });

  group('rentang keisi otomatis dari data master PT Sidik', () {
    testWidgets('Thermocouple: 3 golongan CMC jadi -20-600 °C', (tester) async {
      await buka(
        tester,
        kategori: 'suhu-dan-kelembapan',
        namaKemampuan: 'Thermocouple',
      );

      expect(isi(tester, 'Rentang min.'), '-20');
      expect(isi(tester, 'Rentang maks.'), '600');
      expect(isi(tester, 'Satuan'), '°C');
      expect(find.textContaining('Terisi otomatis'), findsOneWidget);
    });

    testWidgets('Termometer Gelas: 0-200 °C', (tester) async {
      await buka(
        tester,
        kategori: 'suhu-dan-kelembapan',
        namaKemampuan: 'Termometer Gelas',
      );

      expect(isi(tester, 'Rentang min.'), '0');
      expect(isi(tester, 'Rentang maks.'), '200');
      expect(isi(tester, 'Satuan'), '°C');
    });

    testWidgets('dipilih dari dropdown, bukan cuma yang dibawa lembar kerja', (
      tester,
    ) async {
      await buka(tester, kategori: 'suhu-dan-kelembapan');

      expect(isi(tester, 'Rentang min.'), '');

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furnace').last);
      await tester.pumpAndSettle();

      expect(isi(tester, 'Rentang min.'), '300');
      expect(isi(tester, 'Rentang maks.'), '1000');
      expect(isi(tester, 'Satuan'), '°C');
    });

    testWidgets('Oven: batas bawah "ambient" nggak jadi nol', (tester) async {
      // Nol itu SUHU. Kalau "ambient" dibaca nol, rentang alatnya berubah jadi
      // 0-300 °C — dan angka itu ikut ke sertifikat.
      await buka(
        tester,
        kategori: 'suhu-dan-kelembapan',
        namaKemampuan: 'Oven',
      );

      expect(isi(tester, 'Rentang min.'), '');
      expect(isi(tester, 'Rentang maks.'), '300');
    });

    testWidgets('angka yang udah diketik teknisi NGGAK ditimpa', (
      tester,
    ) async {
      await buka(tester, kategori: 'suhu-dan-kelembapan');

      await tester.enterText(kotak('Rentang maks.'), '250');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furnace').last);
      await tester.pumpAndSettle();

      // Batas bawahnya kosong → boleh diisi. Batas atasnya diketik teknisi →
      // alat pelanggannya mungkin emang cuma sampai 250, dan itu yang benar.
      expect(isi(tester, 'Rentang min.'), '300');
      expect(isi(tester, 'Rentang maks.'), '250');
    });
  });

  group('dua besaran: sistem NGGAK milihin, teknisi yang pencet', () {
    testWidgets('Thermohygrometer: nggak diisi otomatis, disodorin 2 tombol', (
      tester,
    ) async {
      await buka(
        tester,
        kategori: 'suhu-dan-kelembapan',
        namaKemampuan: 'Thermohygrometer',
      );

      // Kolom rentang alat cuma sepasang. Digabung, dia jadi 15-90 tanpa
      // satuan — angka yang nggak pernah ada di master mana pun.
      expect(isi(tester, 'Rentang min.'), '');
      expect(isi(tester, 'Rentang maks.'), '');
      expect(find.textContaining('Terisi otomatis'), findsNothing);

      expect(find.text('Suhu · 15–50 °C'), findsOneWidget);
      expect(find.text('Kelembapan · 30–90 %RH'), findsOneWidget);
    });

    testWidgets('pencet tombol kelembapan → 30-90 %RH masuk', (tester) async {
      await buka(
        tester,
        kategori: 'suhu-dan-kelembapan',
        namaKemampuan: 'Thermohygrometer',
      );

      await tester.tap(find.text('Kelembapan · 30–90 %RH'));
      await tester.pumpAndSettle();

      expect(isi(tester, 'Rentang min.'), '30');
      expect(isi(tester, 'Rentang maks.'), '90');
      expect(isi(tester, 'Satuan'), '%RH');
    });

    testWidgets('salah pencet masih bisa diralat ke tombol satunya', (
      tester,
    ) async {
      await buka(
        tester,
        kategori: 'suhu-dan-kelembapan',
        namaKemampuan: 'Thermohygrometer',
      );

      await tester.tap(find.text('Kelembapan · 30–90 %RH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suhu · 15–50 °C'));
      await tester.pumpAndSettle();

      expect(isi(tester, 'Rentang min.'), '15');
      expect(isi(tester, 'Rentang maks.'), '50');
      expect(isi(tester, 'Satuan'), '°C');
    });
  });

  testWidgets('alat suhu kesimpan tanpa toleransi, rentangnya ikut kekirim', (
    tester,
  ) async {
    // Ujungnya: bukan cuma error yang ilang dari layar, tapi alatnya beneran
    // sampai ke server.
    final perekam = await buka(
      tester,
      kategori: 'suhu-dan-kelembapan',
      namaKemampuan: 'Thermocouple',
    );

    await tester.enterText(kotak('Nama alat'), 'Thermocouple Fluke 51-II');
    await tester.enterText(kotak('Nomor seri'), 'TC-99887');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih pelanggan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PT Maju Jaya').last);
    await tester.pumpAndSettle();

    await simpan(tester);

    final alat = perekam.terkirim;
    expect(alat, isNotNull, reason: 'form nahan di validasi, nggak kekirim');
    expect(alat!.toleransi, isNull);
    expect(alat.namaAlatKemampuan, 'Thermocouple');
    expect(alat.rangeMin, -20);
    expect(alat.rangeMax, 600);
    expect(alat.satuan, '°C');
  });
}
