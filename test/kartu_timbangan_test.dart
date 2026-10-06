import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_kartu_baris.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_massa.dart';

/// Accuracy Timbangan digambar per titik beban, bacaan MENURUN (z, m, m', z')
/// — susunan kertas dan master (`INPUT DATA!S37`: tiap titik satu blok,
/// bacaannya bertumpuk). Cuma tampilan: payload WAJIB identik dengan tabel.
void main() {
  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerjaTimbangan()),
    clientRequestId: 'uji-kartu-tb',
  )..alat = const EquipmentLookup(
      id: 1,
      namaAlat: 'Timbangan',
      serialNumber: 'UJI-TB',
      kategori: 'massa',
      status: 'aktif',
      satuan: 'kg',
      rangeMax: 100,
      resolusi: 0.02,
    );

  BagianLembarKerja akurasi(LembarKerjaState isian) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == 'akurasi');

  test('bagian Accuracy ditandai kartu vertikal tanpa bintang', () {
    final b = akurasi(isianBaru());
    expect(b.kartuPerBaris, isTrue);
    expect(b.kartuVertikal, isTrue);
    expect(b.kartuSejajar, isFalse);
    expect(b.nominalBerbintang, isFalse);
  });

  testWidgets('bacaan menurun berlabel z/m/m\'/z\', payload = tabel', (tester) async {
    tester.view.physicalSize = const Size(600, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lewatKartu = isianBaru();
    final bagian = akurasi(lewatKartu);
    final tabel = bagian.tabel;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LembarKerjaKartuBaris(
              tabel: tabel,
              isian: lewatKartu,
              onBerubah: () {},
              berbintang: false,
              vertikal: true,
            ),
          ),
        ),
      ),
    );

    for (final l in ['z', 'm', "m'", "z'"]) {
      expect(find.text(l), findsWidgets, reason: 'label bacaan $l tidak tergambar');
    }
    // Menurun: kotak bacaan ke-2 di bawah kotak ke-1, bukan di sebelahnya.
    final y0 = tester.getTopLeft(find.byKey(const ValueKey('kartu-t0-1-0'))).dy;
    final y1 = tester.getTopLeft(find.byKey(const ValueKey('kartu-t0-1-1'))).dy;
    expect(y1, greaterThan(y0));

    await tester.enterText(find.byKey(const ValueKey('kartu-kb-nominal-1')), '10');
    expect(find.byKey(const ValueKey('kartu-nominal-1')), findsOneWidget, reason: 'kunci kepala & kotak per baris bertabrakan');
    final pengulangan = tabel.first.pengulangan.length;
    for (var r = 0; r < pengulangan; r++) {
      await tester.enterText(find.byKey(ValueKey('kartu-t0-1-$r')), '10,0${r + 1}');
    }

    final lewatTabel = isianBaru();
    final t = akurasi(lewatTabel).tabel.first;
    final ts = lewatTabel.titikUntukBaris(lewatTabel.barisTabel(t), 0, t)!;
    ts.kotakBarisCtl(t.kunciTabel, 'nominal').text = '10';
    for (var r = 0; r < pengulangan; r++) {
      ts.kotak(t.kunciTabel, t.kolom.first.kode, r).text = '10,0${r + 1}';
    }

    List<Map<String, dynamic>> kiriman(LembarKerjaState isian) =>
        isian.toSubmission(draft: true).measurements.map((m) => m.toJson()).toList();

    expect(kiriman(lewatKartu), isNotEmpty);
    expect(kiriman(lewatKartu), kiriman(lewatTabel));
  });
}
