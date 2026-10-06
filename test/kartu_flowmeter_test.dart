import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_kartu_baris.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_aliran.dart';

/// Kartu per set point Flowmeter (kertas 0538): Pembacaan UUT Flowrate
/// digambar sub-grid ulangan × durasi, tabel lain sebaris di bawahnya.
///
/// Cuma tampilan: isian lewat kartu WAJIB identik dengan isian lewat tabel.
void main() {
  const kunciVarian = 'spesifikasi_alat.flowmeter.varian_metode';

  for (final e in <String, Map<String, dynamic> Function()>{
    'flowrate': contohBentukLembarKerjaFlowmeterFlowrate,
    'totalizer': contohBentukLembarKerjaFlowmeterTotalizer,
  }.entries) {
    for (final varian in ['ufm', 'gravimetri']) {
      testWidgets('${e.key} $varian: isian lewat kartu = isian lewat tabel', (tester) async {
        tester.view.physicalSize = const Size(900, 20000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        LembarKerjaState isianBaru() {
          final isian = LembarKerjaState(
            bentuk: LembarKerja.fromJson(e.value()),
            clientRequestId: 'uji-kartu-fm',
          )..alat = const EquipmentLookup(
              id: 1,
              namaAlat: 'Flow Meter',
              serialNumber: 'UJI-FM',
              kategori: 'aliran',
              status: 'aktif',
              satuan: 'Lpm',
              rangeMax: 100,
              resolusi: 0.01,
            );
          isian.teks[kunciVarian]?.text = varian;
          return isian;
        }

        List<TabelHasil> tabelKartu(LembarKerjaState isian) {
          final bagian = isian.bentuk.bagian.firstWhere((b) => b.kartuPerBaris);
          return [for (final t in bagian.tabel) if (isian.tabelTampil(t)) t];
        }

        String nilai(int k, int r, int c) => '${k + 1}${r + 1},$c';

        final lewatKartu = isianBaru();
        final tabel = tabelKartu(lewatKartu);
        expect(tabel, isNotEmpty);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LembarKerjaKartuBaris(
                  tabel: tabel,
                  isian: lewatKartu,
                  onBerubah: () {},
                  berbintang: false,
                ),
              ),
            ),
          ),
        );

        await tester.enterText(find.byKey(const ValueKey('kartu-nominal-1')), '50');
        for (var k = 0; k < tabel.length; k++) {
          final t = tabel[k];
          for (var r = 0; r < t.pengulangan.length; r++) {
            if (t.kolom.length == 1) {
              await tester.enterText(find.byKey(ValueKey('kartu-t$k-1-$r')), nilai(k, r, 0));
            } else {
              for (var c = 0; c < t.kolom.length; c++) {
                await tester.enterText(find.byKey(ValueKey('kartu-t$k-1-$r-$c')), nilai(k, r, c));
              }
            }
          }
        }

        final lewatTabel = isianBaru();
        final tabelB = tabelKartu(lewatTabel);
        for (var k = 0; k < tabelB.length; k++) {
          final t = tabelB[k];
          final ts = lewatTabel.titikUntukBaris(lewatTabel.barisTabel(t), 0, t)!;
          if (k == 0) ts.titikCtl.text = '50';
          for (var r = 0; r < t.pengulangan.length; r++) {
            for (var c = 0; c < t.kolom.length; c++) {
              ts.kotak(t.kunciTabel, t.kolom[c].kode, r).text = nilai(k, r, c);
            }
          }
        }

        List<Map<String, dynamic>> kiriman(LembarKerjaState isian) =>
            isian.toSubmission(draft: true).measurements.map((m) => m.toJson()).toList();

        expect(kiriman(lewatKartu), isNotEmpty);
        expect(kiriman(lewatKartu).first['titik_ukur'], 50.0, reason: 'set point dari kartu tidak sampai ke payload');
        expect(kiriman(lewatKartu), kiriman(lewatTabel));
      });
    }
  }
}
