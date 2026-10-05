import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/calibration_detail.dart';
import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_kartu_baris.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_anak_timbangan.dart';

/// Bintang di NOMINAL (`20*`) — cara kertas Anak Timbangan membedakan keping
/// kedua bernominal sama (keputusan pemilik 6 Okt 2026). Angkanya tetap 20 g;
/// bintangnya dikirim terpisah sebagai `measurements[].bintang`.
void main() {
  const peran = ['at_s1', 'at_t1', 'at_t2', 'at_s2'];

  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerjaAnakTimbangan()),
    clientRequestId: 'uji-bintang',
  )..alat = const EquipmentLookup(
      id: 36,
      namaAlat: 'Anak Timbangan',
      serialNumber: 'DEMO-AT-001',
      kategori: 'massa',
      status: 'aktif',
      satuan: 'g',
      rangeMax: 500,
      resolusi: 0.0001,
    );

  List<TabelHasil> tabelHasil(LembarKerjaState isian) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == 'hasil').tabel;

  void isiKeping(LembarKerjaState isian, int i, String nominal) {
    final tabel = tabelHasil(isian);
    for (var k = 0; k < tabel.length; k++) {
      final t = tabel[k];
      final ts = isian.titikUntukBaris(isian.barisTabel(t), i, t)!;
      if (k == 0) ts.titikCtl.text = nominal;
      for (var r = 0; r < 3; r++) {
        ts.kotak(t.kunciTabel, 'pembacaan', r).text = '20';
      }
    }
  }

  List<Map<String, dynamic>> kiriman(LembarKerjaState isian) => isian
      .toSubmission(draft: true)
      .measurements
      .map((m) => m.toJson())
      .where((m) => m.containsKey('at_s1'))
      .toList();

  test('nominal 20* terkirim sebagai 20 g + bintang', () {
    final isian = isianBaru();
    isiKeping(isian, 0, '20');
    isiKeping(isian, 1, '20*');

    final kirim = kiriman(isian);

    expect(kirim, hasLength(2));
    expect(kirim[0]['titik_ukur'], 20.0);
    expect(kirim[0]['bintang'], isFalse);
    expect(kirim[1]['titik_ukur'], 20.0, reason: 'bintang ikut terbaca sebagai bagian angka');
    expect(kirim[1]['bintang'], isTrue);
  });

  test('draft dibuka ulang: bintang kembali menempel di nominal keping yang benar', () {
    final asal = isianBaru();
    isiKeping(asal, 0, '20');
    isiKeping(asal, 1, '20*');
    final kirimAsal = kiriman(asal);

    final mentah = <RawMeasurement>[];
    final bintangServer = <String, bool>{};
    var id = 1;
    for (var k = 0; k < kirimAsal.length; k++) {
      final m = kirimAsal[k];
      if (m['bintang'] == true) bintangServer['${k + 1}'] = true;
      for (final p in peran) {
        final nilai = (m[p] as List).cast<double>();
        for (var r = 0; r < nilai.length; r++) {
          mentah.add(RawMeasurement(
            id: id++,
            titikKe: k + 1,
            titikUkur: (m['titik_ukur'] as num).toDouble(),
            pembacaanKe: r + 1,
            sensorKe: 1,
            pembacaan: nilai[r],
            peranSensor: p,
            inputSource: 'manual',
            isVerified: true,
          ));
        }
      }
    }

    final detail = IsianTeknisi.fromJson({
      'spesifikasi_alat': {
        'anak_timbangan': {'bintang': bintangServer},
      },
    });

    for (final spesifikasiDulu in [true, false]) {
      final pulih = isianBaru();
      if (spesifikasiDulu) pulih.muatDariSesi(detail);
      expect(pulih.terapkanPembacaan(mentah), 0);
      if (!spesifikasiDulu) pulih.muatDariSesi(detail);

      final t = tabelHasil(pulih).first;
      expect(
        pulih.titikUntukBaris(pulih.barisTabel(t), 1, t)!.titikCtl.text,
        '20*',
        reason: 'bintang hilang waktu draft dibuka ulang (spesifikasi dulu: $spesifikasiDulu)',
      );
      expect(kiriman(pulih), kirimAsal);
    }
  });

  testWidgets('tombol bintang di kartu mengubah nominal jadi 20*', (tester) async {
    tester.view.physicalSize = const Size(1200, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final isian = isianBaru();
    isiKeping(isian, 0, '20');
    final tabel = tabelHasil(isian);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: LembarKerjaKartuBaris(
                tabel: tabel,
                isian: isian,
                onBerubah: () => setState(() {}),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nominal AT (g)'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('kartu-bintang-1')));
    await tester.pump();

    final ts = isian.titikUntukBaris(isian.barisTabel(tabel.first), 0, tabel.first)!;
    expect(ts.titikCtl.text, '20*');
    expect(kiriman(isian).single['bintang'], isTrue);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}
