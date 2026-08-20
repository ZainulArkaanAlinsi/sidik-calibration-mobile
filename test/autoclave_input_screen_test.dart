import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sidik_calibration/models/autoclave_hasil.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/providers/autoclave_provider.dart';
import 'package:sidik_calibration/providers/auth_provider.dart';
import 'package:sidik_calibration/providers/calibration_input_provider.dart';
import 'package:sidik_calibration/screens/calibration/autoclave_input_screen.dart';
import 'package:sidik_calibration/services/autoclave_service.dart';
import 'package:sidik_calibration/services/equipment_lookup_service.dart';
import 'package:sidik_calibration/services/token_storage.dart';

/// Service palsu — Autoklaf nggak ngitung di mobile. Nyimpen payload terakhir
/// biar test bisa mastiin bentuk & identitas yang dikirim benar.
class _FakeAutoclaveService implements AutoclaveService {
  Map<String, dynamic>? pratinjauTerakhir;
  Map<String, dynamic>? simpanTerakhir;

  @override
  Future<AutoclaveHasil> pratinjau(String token, Map<String, dynamic> p) async {
    pratinjauTerakhir = p;
    return AutoclaveHasil.fromJson({
      'data': {
        'set_point': 121.0,
        'suhu': {
          'indikator_rata': 121.0,
          'sensor': [
            {'no': 1, 'standar_terkoreksi': 121.396, 'koreksi': 0.396, 'delta_t': 0.02},
          ],
          'kestabilan': 0.045,
          'keseragaman': 0.464,
          'variasi': 0.10,
          'k': 1.9713602363081708,
          'u95': 0.4419439029528431,
        },
      },
    });
  }

  @override
  Future<int> simpan(String token, Map<String, dynamic> p) async {
    simpanTerakhir = p;
    return 7;
  }
}

class _FakeEquipmentLookup implements EquipmentLookupService {
  @override
  Future<List<EquipmentLookup>> cari(String token,
      {String? search, String? kategori}) async {
    return [
      const EquipmentLookup(
        id: 42,
        namaAlat: 'Autoclave',
        serialNumber: 'DR-0000173',
        kategori: 'instrumen-analitik',
        status: 'aktif',
      ),
    ];
  }
}

Widget _bungkus(_FakeAutoclaveService fake) {
  return ProviderScope(
    overrides: [
      autoclaveServiceProvider.overrideWithValue(fake),
      equipmentLookupServiceProvider.overrideWithValue(_FakeEquipmentLookup()),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage('mock-token')),
    ],
    child: const MaterialApp(home: AutoclaveInputScreen()),
  );
}

void main() {
  /// Lebar HP beneran. Ini yang selama ini nggak pernah diuji: semua test
  /// Autoklaf lain pakai 1400 px, dan di lebar itu kisi suhunya kelihatan
  /// baik-baik saja walau di HP tiap kotak angkanya cuma ~50 dp.
  void hp(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void besar(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 7000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('render identitas + input + dua tombol', (tester) async {
    besar(tester);
    await tester.pumpWidget(_bungkus(_FakeAutoclaveService()));
    await tester.pumpAndSettle();

    expect(find.text('Identitas Kalibrasi'), findsOneWidget);
    expect(find.text('1. Set Point'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hitung'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Simpan & Kirim'), findsOneWidget);
  });

  testWidgets('isi angka → Hitung → panel hasil suhu kerender', (tester) async {
    besar(tester);
    final fake = _FakeAutoclaveService();
    await tester.pumpWidget(_bungkus(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ac_setpoint')), '121');
    // Satu pembacaan tekanan cukup buat blok tekanan ikut (uut default kosong,
    // jadi isi juga UUT Setting lewat label).
    await tester.enterText(find.widgetWithText(TextField, 'UUT Setting'), '0.112');
    await tester.enterText(find.byKey(const Key('ac_p0')), '1.231');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Hitung'));
    await tester.pumpAndSettle();

    expect(fake.pratinjauTerakhir, isNotNull);
    expect(fake.pratinjauTerakhir!.containsKey('tekanan'), isTrue);
    expect(find.text('A) Sebaran Suhu'), findsOneWidget);
    expect(find.textContaining('0.464'), findsWidgets);
  });

  testWidgets('Simpan tanpa pilih alat → error, service tidak dipanggil',
      (tester) async {
    besar(tester);
    final fake = _FakeAutoclaveService();
    await tester.pumpWidget(_bungkus(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ac_setpoint')), '121');
    await tester.enterText(find.widgetWithText(TextField, 'UUT Setting'), '0.112');
    await tester.enterText(find.byKey(const Key('ac_p0')), '1.231');

    await tester.tap(find.widgetWithText(FilledButton, 'Simpan & Kirim'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pilih Alat'), findsOneWidget);
    expect(fake.simpanTerakhir, isNull);
  });

  testWidgets('pilih alat → Simpan → payload bawa equipment_id + data ukur',
      (tester) async {
    besar(tester);
    final fake = _FakeAutoclaveService();
    await tester.pumpWidget(_bungkus(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ac_setpoint')), '121');
    await tester.enterText(find.widgetWithText(TextField, 'UUT Setting'), '0.112');
    await tester.enterText(find.byKey(const Key('ac_p0')), '1.231');

    // Pilih alat dari dropdown.
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autoclave — DR-0000173').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Simpan & Kirim'));
    await tester.pumpAndSettle();

    expect(fake.simpanTerakhir, isNotNull);
    expect(fake.simpanTerakhir!['equipment_id'], 42);
    expect(fake.simpanTerakhir!['set_point'], 121.0);
    expect(fake.simpanTerakhir!.containsKey('tekanan'), isTrue);
    expect(fake.simpanTerakhir!.containsKey('tanggal_kalibrasi'), isTrue);
  });

  /// Layar ini dipakai teknisi di HP, bukan di laptop.
  ///
  /// Flutter melaporkan tata letak yang meluber sebagai exception waktu test,
  /// jadi sekadar merendernya di lebar HP sudah menangkap kisi yang terlalu
  /// sempit, label yang kepotong, dan baris yang nggak muat. Sebelum ada test
  /// ini, kisi suhu 5 titik waktu diperas jadi ~50 dp per kotak dan nggak ada
  /// satu pun test yang merah.
  testWidgets('kerender di lebar HP tanpa tata letak yang meluber', (
    tester,
  ) async {
    hp(tester);
    await tester.pumpWidget(_bungkus(_FakeAutoclaveService()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Identitas Kalibrasi'), findsOneWidget);
  });

  /// Kotak angka wajib cukup lebar buat diketik DAN diperiksa ulang. Angka di
  /// lembar ini berkoma empat desimal (mis. `1.231`); kotak yang lebih sempit
  /// dari ini bikin isinya kepotong waktu dibaca lagi sebelum dikirim.
  testWidgets('kotak angka di kisi suhu punya lebar yang layak', (
    tester,
  ) async {
    hp(tester);
    await tester.pumpWidget(_bungkus(_FakeAutoclaveService()));
    await tester.pumpAndSettle();

    final lebar = tester.getSize(find.byKey(const Key('ac_p0'))).width;
    expect(lebar, greaterThan(60));
  });
}
