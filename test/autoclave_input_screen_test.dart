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
import 'package:sidik_calibration/services/standard_service.dart';
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
            {
              'no': 1,
              'standar_terkoreksi': 121.396,
              'koreksi': 0.396,
              'delta_t': 0.02,
            },
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
  Future<List<EquipmentLookup>> cari(
    String token, {
    String? search,
    String? kategori,
  }) async {
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
      // Layar narik master standar cuma buat mapping unit thermohygro ke
      // `standard_id`. Dipalsuin biar test nggak nyentuh jaringan.
      standardServiceProvider.overrideWithValue(MockStandardService()),
      equipmentLookupServiceProvider.overrideWithValue(_FakeEquipmentLookup()),
      tokenStorageProvider.overrideWithValue(
        InMemoryTokenStorage('mock-token'),
      ),
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

    expect(find.text('General Information'), findsOneWidget);
    expect(find.text('Data Result'), findsOneWidget);
    expect(find.text('Set Point (°C)'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hitung'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Simpan & Kirim'), findsOneWidget);
  });

  testWidgets('isi angka → Hitung → panel hasil suhu kerender', (tester) async {
    besar(tester);
    final fake = _FakeAutoclaveService();
    await tester.pumpWidget(_bungkus(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ac_setpoint')), '121');
    // Bacaan UUT diambil dari baris kertas "Indikator Pressure", bukan kolom
    // "UUT Setting" karangan — kertasnya nggak punya kolom itu.
    await tester.enterText(find.byKey(const Key('ac_indikator_p0')), '0.112');
    await tester.enterText(find.byKey(const Key('ac_p0')), '1.231');

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Hitung'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hitung'));
    await tester.pumpAndSettle();

    expect(fake.pratinjauTerakhir, isNotNull);
    expect(fake.pratinjauTerakhir!.containsKey('tekanan'), isTrue);
    expect(find.text('A) Sebaran Suhu'), findsOneWidget);
    expect(find.textContaining('0.464'), findsWidgets);
  });

  /// Lembar di layar diadu BARIS PER BARIS ke kertas
  /// `SIDIK-FM-CAL-0539_Rev.4`. Bentuk sebelumnya numpang lembar pH: dua baris
  /// kertas (`Indikator Pressure`, `Tekanan atm awal`) nggak ada tempatnya, dan
  /// baris ke-5 di layar itu Suhu Ruang padahal di kertas baris ke-5 itu
  /// Indikator Pressure. Teknisi nyalin sambil megang kertas — geser satu baris
  /// berarti tekanan manometer masuk ke kolom suhu.
  testWidgets('tabel Data Result urut sama kayak kertas Rev.4', (tester) async {
    besar(tester);
    await tester.pumpWidget(_bungkus(_FakeAutoclaveService()));
    await tester.pumpAndSettle();

    for (final label in [
      'Receive Date',
      'Customer',
      'Addresss',
      'Calibration Date',
      'Location of Calibration',
      'Equipment Name',
      'Manufacturer',
      'Type',
      'SN',
      'Range Temp.',
      'Resolution Temp.',
      'Range Pressure',
      'Resolution Pressure',
      'Calibration Result for Temperature & Pressure',
      'Pengukuran Berulang UUT Selama Proses Sterilisasi',
      'Time',
      'Temp. Disk 1 (°C)',
      'Temp. Disk 2 (°C)',
      'Temp. Disk 3 (°C)',
      'Indikator Suhu (°C)',
      'Indikator Pressure (MPa)',
      'Tekanan atm awal (MPa)',
      'Suhu Ruang (°C)',
      'Standard Used:',
      'Temperature Calibrator -Technosoft (Disk 1,2,3)',
      'Pressure Disk Logger-Technosoft',
      'Catatan:',
      'Calibrated by:',
      'Corrected by:',
    ]) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: 'Kertas punya "$label".',
      );
    }

    // Lima kolom waktu, dan jam beneran — bukan nomor urut W1..W5.
    expect(find.byKey(const Key('ac_waktu0')), findsOneWidget);
    expect(find.text('W1'), findsNothing);
  });

  /// Baris kertas "Indikator Pressure" itu yang jadi bacaan UUT. Layar nggak
  /// boleh ngerata-rata kelima kolomnya sendiri — backend yang mutusin, dan
  /// nolak kalau kolomnya beda-beda.
  testWidgets('payload bawa baris kertas, bukan uut_setting karangan', (
    tester,
  ) async {
    besar(tester);
    final fake = _FakeAutoclaveService();
    await tester.pumpWidget(_bungkus(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ac_setpoint')), '121');
    await tester.enterText(find.byKey(const Key('ac_waktu0')), '02:00:00');
    await tester.enterText(find.byKey(const Key('ac_indikator_p0')), '0.112');
    await tester.enterText(find.byKey(const Key('ac_p0')), '1.231');

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Hitung'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hitung'));
    await tester.pumpAndSettle();

    final kirim = fake.pratinjauTerakhir!;
    expect((kirim['waktu'] as List).first, '02:00:00');
    final tekanan = kirim['tekanan'] as Map<String, dynamic>;
    expect(tekanan.containsKey('uut_setting'), isFalse);
    expect((tekanan['indikator_pressure'] as List).first, 0.112);
    expect(tekanan.containsKey('tekanan_atm_awal'), isTrue);
  });

  testWidgets('Simpan tanpa pilih alat → error, service tidak dipanggil', (
    tester,
  ) async {
    besar(tester);
    final fake = _FakeAutoclaveService();
    await tester.pumpWidget(_bungkus(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ac_setpoint')), '121');
    await tester.enterText(find.byKey(const Key('ac_indikator_p0')), '0.112');
    await tester.enterText(find.byKey(const Key('ac_p0')), '1.231');

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Simpan & Kirim'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan & Kirim'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pilih Alat'), findsOneWidget);
    expect(fake.simpanTerakhir, isNull);
  });

  testWidgets('pilih alat → Simpan → payload bawa equipment_id + data ukur', (
    tester,
  ) async {
    besar(tester);
    final fake = _FakeAutoclaveService();
    await tester.pumpWidget(_bungkus(fake));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('ac_setpoint')), '121');
    await tester.enterText(find.byKey(const Key('ac_indikator_p0')), '0.112');
    await tester.enterText(find.byKey(const Key('ac_p0')), '1.231');

    // Pilih alat dari dropdown.
    await tester.tap(find.byKey(const Key('ac_equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autoclave — DR-0000173').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Simpan & Kirim'),
    );
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
