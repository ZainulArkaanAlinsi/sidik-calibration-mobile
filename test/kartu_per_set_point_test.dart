import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_kartu_baris.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_gaya.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_suhu.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_tekanan.dart';

/// Kartu per set point (revisi lapangan #6) di lembar selain Anak Timbangan:
/// Tekanan (UP | DOWN), UTM (0/90/180/270°), Proving Ring (UP | DOWN),
/// Thermohygro (Standard | UUT).
///
/// Cuma tampilan: yang diketik lewat kartu WAJIB mendarat di kotak yang sama
/// dengan tabel biasa, jadi payload-nya identik — dan di layar lebar tabelnya
/// berdampingan seperti satu baris kertas.
void main() {
  final kasus = <String, Map<String, dynamic> Function()>{
    'pressure_gauge': contohBentukLembarKerjaPressureGauge,
    'utm': contohBentukLembarKerjaUtm,
    'proving_ring': contohBentukLembarKerjaProvingRing,
    'thermohygro': contohBentukLembarKerjaThermohygro,
  };

  LembarKerjaState isianBaru(Map<String, dynamic> Function() bentuk) => LembarKerjaState(
    bentuk: LembarKerja.fromJson(bentuk()),
    clientRequestId: 'uji-kartu-sp',
  )..alat = const EquipmentLookup(
      id: 1,
      namaAlat: 'Alat Uji',
      serialNumber: 'UJI-001',
      kategori: 'umum',
      status: 'aktif',
      satuan: '',
      rangeMax: 1000,
      resolusi: 0.01,
    );

  BagianLembarKerja bagianKartu(LembarKerjaState isian) =>
      isian.bentuk.bagian.firstWhere((b) => b.kartuPerBaris);

  List<Map<String, dynamic>> kiriman(LembarKerjaState isian) => isian
      .toSubmission(draft: true)
      .measurements
      .map((m) => m.toJson())
      .toList();

  for (final e in kasus.entries) {
    test('${e.key}: bagian hasil ditandai kartu sejajar tanpa bintang', () {
      final bagian = bagianKartu(isianBaru(e.value));

      expect(bagian.kartuSejajar, isTrue);
      expect(bagian.nominalBerbintang, isFalse);
      expect(bagian.tabel.length, greaterThanOrEqualTo(2));
    });

    testWidgets('${e.key}: isian lewat kartu = isian lewat tabel, berdampingan', (tester) async {
      tester.view.physicalSize = const Size(1400, 20000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lewatKartu = isianBaru(e.value);
      final bagian = bagianKartu(lewatKartu);
      final tabel = bagian.tabel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LembarKerjaKartuBaris(
                tabel: tabel,
                isian: lewatKartu,
                onBerubah: () {},
                sejajar: bagian.kartuSejajar,
                berbintang: bagian.nominalBerbintang,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('kartu-baris-1')), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing, reason: 'bintang cuma milik Anak Timbangan');

      final acuan = tabel.first;
      final ditentukan = lewatKartu.barisTabel(acuan).first.titikDitentukan;
      if (!ditentukan) {
        await tester.enterText(find.byKey(const ValueKey('kartu-nominal-1')), '10');
      }

      // Berdampingan: kotak tabel pertama dan kedua sebaris (y sama).
      final y0 = tester.getTopLeft(find.byKey(const ValueKey('kartu-t0-1-0'))).dy;
      final y1 = tester.getTopLeft(find.byKey(const ValueKey('kartu-t1-1-0'))).dy;
      expect(y1, y0, reason: 'di layar lebar tabel-tabelnya harus berdampingan');

      for (var k = 0; k < tabel.length; k++) {
        for (var r = 0; r < tabel[k].pengulangan.length; r++) {
          await tester.enterText(find.byKey(ValueKey('kartu-t$k-1-$r')), '${10 + k},${r + 1}');
        }
      }

      final lewatTabel = isianBaru(e.value);
      final tabelB = bagianKartu(lewatTabel).tabel;
      for (var k = 0; k < tabelB.length; k++) {
        final t = tabelB[k];
        final ts = lewatTabel.titikUntukBaris(lewatTabel.barisTabel(t), 0, t)!;
        if (k == 0 && !ditentukan) ts.titikCtl.text = '10';
        for (var r = 0; r < t.pengulangan.length; r++) {
          ts.kotak(t.kunciTabel, t.kolom.first.kode, r).text = '${10 + k},${r + 1}';
        }
      }

      expect(kiriman(lewatKartu), isNotEmpty);
      expect(kiriman(lewatKartu), kiriman(lewatTabel));
    });
  }
}
