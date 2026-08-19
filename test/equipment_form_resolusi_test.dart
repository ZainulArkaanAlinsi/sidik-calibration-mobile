import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/equipment.dart';
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

/// Blok "Resolusi per titik" di form Alat, dari sisi yang cuma kelihatan lewat
/// layar: apa yang KEBACA waktu form dibuka, dan apa yang KEKIRIM waktu tombol
/// simpan dipencet.
///
/// `equipment_resolusi_rentang_test.dart` udah ngunci bentuk datanya di level
/// model. Yang belum kejaga sama sekali: jalur edit di HP: alat yang bandnya
/// diisi lewat panel admin dibuka di form ini, disimpan, dan bandnya harus
/// balik utuh. Waktu form-nya belum megang `resolusi_rentang`, buka-simpan
/// doang udah cukup buat ngosongin band alat tanpa satu pun error muncul —
/// ketahuannya baru waktu sertifikat kecetak dengan desimal & satuan yang
/// salah.
///
/// Barisnya dirender sebagai `Card`, dan form ini nggak punya `Card` lain, jadi
/// urutan `Card` = urutan baris.
class _EquipmentServicePerekam implements EquipmentService {
  /// Alat yang beneran dioper ke service. `null` = form nahan di validasi dan
  /// nggak pernah manggil server.
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

/// Conductivity: baris berkunci `titik`, satuannya campur — `111 mS/cm` secara
/// ANGKA lebih kecil dari `1412 µS/cm` padahal fisiknya hampir 100× lebih
/// besar.
const _conductivity = Equipment(
  id: 11,
  namaAlat: 'Conductivity Meter',
  serialNumber: 'C12345-COND',
  kategori: 'instrumen-analitik',
  status: EquipmentStatus.aktif,
  pelangganId: 1,
  pelangganNama: 'PT Maju Jaya',
  satuan: 'µS/cm',
  resolusi: 0.1,
  toleransi: 1,
  resolusiRentang: [
    ResolusiTitik(titik: 25, satuan: 'µS/cm', resolusi: 0.1),
    ResolusiTitik(titik: 1412, satuan: 'µS/cm', resolusi: 1),
    ResolusiTitik(titik: 111, satuan: 'mS/cm', resolusi: 0.01),
  ],
);

/// Turbidimeter: baris berkunci `maks` (ambang), baris terakhir `maks: null`
/// yang nampung sisa pembacaan.
const _turbidimeter = Equipment(
  id: 9,
  namaAlat: 'Turbidimeter',
  serialNumber: 'TB-01',
  kategori: 'instrumen-analitik',
  status: EquipmentStatus.aktif,
  pelangganId: 1,
  pelangganNama: 'PT Maju Jaya',
  satuan: 'NTU',
  resolusi: 0.01,
  toleransi: 0.5,
  resolusiRentang: [
    ResolusiTitik(maks: 10, satuan: 'NTU', resolusi: 0.01, pakaiMaks: true),
    ResolusiTitik(maks: 100, satuan: 'NTU', resolusi: 0.1, pakaiMaks: true),
    ResolusiTitik(satuan: 'NTU', resolusi: 1, pakaiMaks: true),
  ],
);

void main() {
  /// Form-nya dibuka sebagai rute KEDUA, bukan `home`: `_simpan()` yang sukses
  /// nutup layarnya sendiri (`navigator.pop()`), dan itu cuma sah kalau ada
  /// rute di bawahnya.
  Widget app(Equipment alat, _EquipmentServicePerekam perekam) {
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
                  builder: (_) => EquipmentFormScreen(existing: alat),
                ),
              ),
              child: const Text('BUKA FORM'),
            ),
          ),
        ),
      ),
    );
  }

  /// Form Alat + blok resolusi lebih panjang dari viewport test standar
  /// (800x600), dan `ListView` cuma nge-build item yang deket viewport.
  Future<_EquipmentServicePerekam> buka(
    WidgetTester tester,
    Equipment alat,
  ) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final perekam = _EquipmentServicePerekam();
    await tester.pumpWidget(app(alat, perekam));
    // `MockAuthService.me()` berjeda 600ms — sebelum itu kelar, `bisaInput`
    // masih `false` dan tombol simpannya belum ada.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BUKA FORM'));
    await tester.pumpAndSettle();

    return perekam;
  }

  /// Tiga kolom satu baris resolusi, urut sesuai layar: nilai (titik/ambang),
  /// resolusi, satuan.
  Finder kolom(int baris, int ke) => find.descendant(
    of: find.byType(Card).at(baris),
    matching: find.byType(TextField),
  ).at(ke);

  String teks(WidgetTester tester, Finder f) =>
      tester.widget<TextField>(f).controller!.text;

  Future<void> simpan(WidgetTester tester) async {
    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();
  }

  testWidgets('band Conductivity kebaca di layar apa adanya', (tester) async {
    await buka(tester, _conductivity);

    expect(find.byType(Card), findsNWidgets(3));
    expect(teks(tester, kolom(0, 0)), '25');
    expect(teks(tester, kolom(0, 1)), '0.1');
    expect(teks(tester, kolom(0, 2)), 'µS/cm');
    // Titik 111 satuannya BEDA sendiri — itu justru alasan blok ini ada.
    expect(teks(tester, kolom(2, 0)), '111');
    expect(teks(tester, kolom(2, 2)), 'mS/cm');
  });

  testWidgets('buka lalu simpan tanpa diapa-apain: band balik utuh', (
    tester,
  ) async {
    final perekam = await buka(tester, _conductivity);
    await simpan(tester);

    final band = perekam.terkirim!.resolusiRentang;

    expect(band, hasLength(3));
    expect(band.every((r) => !r.pakaiMaks), isTrue);
    expect([for (final r in band) r.titik], [25.0, 1412.0, 111.0]);
    expect([for (final r in band) r.satuan], ['µS/cm', 'µS/cm', 'mS/cm']);
    expect([for (final r in band) r.resolusi], [0.1, 1.0, 0.01]);
  });

  testWidgets('band Turbidimeter tetap berbentuk ambang, bukan titik', (
    tester,
  ) async {
    final perekam = await buka(tester, _turbidimeter);

    // Golongan terakhir tampil KOSONG — itu baris yang nampung sisa pembacaan
    // di atas band sebelumnya, bukan baris yang belum diisi.
    expect(teks(tester, kolom(2, 0)), '');
    expect(find.text('kosong = golongan terakhir'), findsWidgets);

    await simpan(tester);

    final band = perekam.terkirim!.resolusiRentang;

    expect(band.every((r) => r.pakaiMaks), isTrue);
    expect(band.every((r) => r.titik == null), isTrue);
    expect([for (final r in band) r.maks], [10.0, 100.0, null]);

    final kirim = perekam.terkirim!.toJson()['resolusi_rentang'] as List;

    expect(kirim.every((r) => !(r as Map).containsKey('titik')), isTrue);
    expect((kirim[2] as Map).containsKey('maks'), isTrue);
  });

  testWidgets('hapus baris terakhir kekirim sebagai array kosong', (
    tester,
  ) async {
    final perekam = await buka(
      tester,
      _conductivity.copyWith(
        resolusiRentang: const [
          ResolusiTitik(titik: 25, satuan: 'µS/cm', resolusi: 0.1),
        ],
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);

    await simpan(tester);

    // Kunci `resolusi_rentang` HARUS tetap kekirim: kiriman tanpa kunci itu
    // kebaca "nggak nyentuh band" di backend (`sometimes`), jadi band lamanya
    // balik lagi begitu layarnya di-refresh — baris terakhir nggak akan pernah
    // bisa dihapus dari HP.
    expect(perekam.terkirim!.resolusiRentang, isEmpty);
    expect(perekam.terkirim!.toJson().containsKey('resolusi_rentang'), isTrue);
  });

  testWidgets('ganti bentuk titik → ambang: `titik` nggak ikut kekirim', (
    tester,
  ) async {
    final perekam = await buka(
      tester,
      _conductivity.copyWith(
        resolusiRentang: const [
          ResolusiTitik(titik: 25, satuan: 'µS/cm', resolusi: 0.1),
        ],
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batas atas').last);
    await tester.pumpAndSettle();

    await simpan(tester);

    final baris = perekam.terkirim!.resolusiRentang.single;

    // Di backend band ber-`titik` diperiksa DULUAN dan langsung menang, jadi
    // sisa `titik` bikin `maks`-nya nggak pernah kepakai — diam, tanpa error.
    expect(baris.pakaiMaks, isTrue);
    expect(baris.titik, isNull);
    expect(baris.maks, 25.0);
    expect(baris.toJson().containsKey('titik'), isFalse);
  });

  testWidgets('baris titik tanpa angka ditahan form, nggak dikirim ke server', (
    tester,
  ) async {
    final perekam = await buka(tester, _conductivity);

    await tester.tap(find.text('TAMBAH BARIS RESOLUSI'));
    await tester.pumpAndSettle();
    await tester.enterText(kolom(3, 1), '0.05');

    await simpan(tester);

    // Kalau lolos, yang balik dari backend cuma `resolusi_rentang.3.titik`
    // sebagai satu string ber-indeks yang nggak nunjuk ke baris mana pun di
    // layar.
    expect(perekam.terkirim, isNull);
    expect(find.text('Wajib diisi.'), findsOneWidget);
    expect(
      find.text('Ada baris resolusi yang belum bener di bawah.'),
      findsOneWidget,
    );
  });
}
