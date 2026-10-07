import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/equipment_lookup.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_kartu_baris.dart';
import 'package:sidik_calibration/services/contoh_lembar_kerja_anak_timbangan.dart';

/// Tampilan kartu per keping (susunan kertas Anak Timbangan) cuma TAMPILAN:
/// yang diketik di kartu mendarat di kotak yang sama dengan tabel biasa, jadi
/// payload-nya identik.
void main() {
  LembarKerjaState isianBaru() => LembarKerjaState(
    bentuk: LembarKerja.fromJson(contohBentukLembarKerjaAnakTimbangan()),
    clientRequestId: 'uji-kartu',
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

  BagianLembarKerja bagianHasil(LembarKerjaState isian) =>
      isian.bentuk.bagian.firstWhere((b) => b.kode == 'hasil');

  List<Map<String, dynamic>> kiriman(LembarKerjaState isian) => isian
      .toSubmission(draft: true)
      .measurements
      .map((m) => m.toJson())
      .where((m) => m.containsKey('at_s1'))
      .toList();

  test('bentuk Anak Timbangan dari server menandai kartu per baris', () {
    expect(bagianHasil(isianBaru()).kartuPerBaris, isTrue);
  });

  test('label peran ditulis persis seperti kertas', () {
    expect(
      LembarKerjaKartuBaris.labelPendek('Standard (S1) — penimbangan standar, pertama'),
      'Standard',
    );
    expect(
      LembarKerjaKartuBaris.labelPendek('UUT (T2) — penimbangan alat, kedua'),
      'UUT',
    );
  });

  test('tombol bintang menambah dan mencabut bintang nominal', () {
    expect(LembarKerjaKartuBaris.alihBintang('20'), '20*');
    expect(LembarKerjaKartuBaris.alihBintang(' 20* '), '20');
  });

  testWidgets('isian lewat kartu = isian lewat tabel biasa', (tester) async {
    tester.view.physicalSize = const Size(1200, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lewatKartu = isianBaru();
    final tabel = bagianHasil(lewatKartu).tabel;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LembarKerjaKartuBaris(
              tabel: tabel,
              isian: lewatKartu,
              onBerubah: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('kartu-baris-10')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('kartu-nominal-1')), '20');
    await tester.enterText(find.byKey(const ValueKey('kartu-kb-no_identitas-1')), '20*');
    // SATU kotak per baris Standard/UUT/UUT/Standard — persis kertas lapangan
    // (7 Okt 2026), bukan X1 X2 X3 kertas Rev.0 lama.
    expect(lewatKartu.bentuk.jumlahPengulangan, 1);
    expect(find.byKey(const ValueKey('kartu-t0-1-1')), findsNothing);

    for (var k = 0; k < tabel.length; k++) {
      for (var r = 0; r < 1; r++) {
        await tester.enterText(
          find.byKey(ValueKey('kartu-t$k-1-$r')),
          k == 1 || k == 2 ? '20,0001' : '20',
        );
      }
    }

    // Isian yang sama lewat kotak tabel biasa.
    final lewatTabel = isianBaru();
    final tabelB = bagianHasil(lewatTabel).tabel;
    for (var k = 0; k < tabelB.length; k++) {
      final t = tabelB[k];
      final ts = lewatTabel.titikUntukBaris(lewatTabel.barisTabel(t), 0, t)!;
      if (k == 0) {
        ts.titikCtl.text = '20';
        ts.kotakBarisCtl(t.kunciTabel, 'no_identitas').text = '20*';
      }
      for (var r = 0; r < 1; r++) {
        ts.kotak(t.kunciTabel, 'pembacaan', r).text =
            k == 1 || k == 2 ? '20,0001' : '20';
      }
    }

    expect(kiriman(lewatKartu), kiriman(lewatTabel));
    expect(kiriman(lewatKartu).single['no_identitas'], '20*');

    // Tombol tambah baris ikut ada di tampilan kartu.
    await tester.tap(find.byKey(const ValueKey('tambah-baris')));
    await tester.pump();
    expect(lewatKartu.barisTabel(tabel.first).length, 11);
  });

  // Satuan g/kg (7 Okt 2026): label kartu ikut pilihan teknisi, karena server
  // menghitung dalam satuan itu. Kotak berlabel "(g)" yang diisi angka kg
  // persis bentuk salah ketik sesi produksi KAL/2026/10/0001.
  testWidgets('pilihan satuan kg mengganti label kartu', (tester) async {
    tester.view.physicalSize = const Size(1200, 20000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final isian = isianBaru();
    final tabel = bagianHasil(isian).tabel;
    const kode = 'spesifikasi_alat.anak_timbangan.satuan';

    expect(isian.bentuk.satuanDari, kode);
    expect(isian.satuanTampil, 'g', reason: 'belum dipilih = satuan bawaan lembar');
    expect(isian.pilihanPenentuAngkaKosong.map((f) => f.kode), contains(kode));

    isian.teks[kode]!.text = 'kg';
    expect(isian.satuanTampil, 'kg');
    expect(isian.pilihanPenentuAngkaKosong.map((f) => f.kode), isNot(contains(kode)));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LembarKerjaKartuBaris(tabel: tabel, isian: isian, onBerubah: () {}),
          ),
        ),
      ),
    );

    expect(find.textContaining('(kg)'), findsWidgets);
    expect(find.textContaining('(g)'), findsNothing);
  });
}
