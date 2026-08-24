import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/grid_sensor_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_grid.dart';

/// Layar grid Enclosure kegambar dan bisa diisi.
///
/// Yang diuji bukan pikselnya, tapi tiga hal yang menentukan angka mana
/// mendarat di mana:
///
///  1. **Kolom Channel cuma muncul buat kalibrator berkanal.** Kalau muncul
///     buat Constant/Yokogawa, teknisi mengisi kolom yang nggak ada artinya;
///     kalau hilang buat Recorder, seluruh set point-nya nggak dihitung.
///  2. **Lencana Sensor Acuan menempel di nomor TERKECIL**, dan pindah begitu
///     nomornya diketik ulang — bukan diam di baris pertama.
///  3. **Peringatan muncul sebelum kirim**, bukan sesudah server menolak.
void main() {
  GridSensorBentuk bentuk() => GridSensorBentuk.fromJson({
    'jumlah_sensor_saran': 3,
    'pengulangan': [1, 2, 3, 4, 5],
    'butuh_channel_untuk': 'recorder',
    'baris_indikator': true,
    'baris_suhu_ruang': true,
    'catatan_sensor_acuan':
        'Sensor Acuan = termokopel bernomor TERKECIL yang terisi.',
  })!;

  Future<GridSensorState> pasang(
    WidgetTester tester, {
    String? merk,
  }) async {
    final state = GridSensorState(bentuk: bentuk());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LembarKerjaGrid(
              state: state,
              satuanSuhu: '°C',
              onBerubah: () {},
              merkKalibrator: merk,
            ),
          ),
        ),
      ),
    );
    return state;
  }

  testWidgets('grid kegambar lengkap dengan Indikator & Suhu Ruang', (
    tester,
  ) async {
    await pasang(tester);

    expect(find.text('Set Point 1'), findsOneWidget);
    expect(find.text('No. TC'), findsOneWidget);
    expect(find.text('Indikator'), findsOneWidget);
    expect(find.text('Suhu Ruang'), findsOneWidget);
    expect(find.text('Tambah termokopel'), findsOneWidget);
    expect(find.text('Tambah Set Point'), findsOneWidget);

    // Aturan Sensor Acuan ditampilkan apa adanya dari backend.
    expect(find.textContaining('TERKECIL'), findsOneWidget);

    // Teknisi diberi tahu baris Suhu Ruang belum sampai server — bukan
    // dibiarkan mengira angkanya kesimpan.
    expect(find.textContaining('belum dikirim ke server'), findsOneWidget);
  });

  testWidgets('kolom CH cuma muncul buat kalibrator berkanal', (tester) async {
    await pasang(tester, merk: 'Constant');
    expect(find.text('CH'), findsNothing);

    await pasang(tester, merk: 'Yokogawa');
    expect(find.text('CH'), findsNothing);

    await pasang(tester, merk: 'Graphtech Temperature Recorder');
    expect(find.text('CH'), findsOneWidget);
  });

  testWidgets('lencana Acuan menempel di nomor terkecil, dan ikut pindah', (
    tester,
  ) async {
    await pasang(tester, merk: 'Constant');

    // Baris pertama nomor 11, baris kedua nomor 3 — acuannya baris KEDUA.
    await tester.enterText(find.byKey(const Key('grid_no_1_0')), '11');
    await tester.enterText(find.byKey(const Key('grid_baca_1_0_0')), '15.0');
    await tester.enterText(find.byKey(const Key('grid_no_1_1')), '3');
    await tester.enterText(find.byKey(const Key('grid_baca_1_1_0')), '15.2');
    await tester.pump();

    expect(find.byIcon(Icons.star), findsNWidgets(2)); // 1 lencana + 1 catatan

    // Nomor terkecil diganti jadi yang terbesar — acuannya pindah ke baris 1.
    await tester.enterText(find.byKey(const Key('grid_no_1_1')), '99');
    await tester.pump();
    expect(find.byIcon(Icons.star), findsNWidgets(2));
  });

  testWidgets('peringatan muncul sebelum kirim, bukan sesudah server nolak', (
    tester,
  ) async {
    await pasang(tester, merk: 'Constant');

    // Satu termokopel, dua pembacaan, Indikator kosong — tiga alasan sekaligus.
    await tester.enterText(find.byKey(const Key('grid_no_1_0')), '3');
    await tester.enterText(find.byKey(const Key('grid_baca_1_0_0')), '15.0');
    await tester.enterText(find.byKey(const Key('grid_baca_1_0_1')), '15.1');
    await tester.pump();

    expect(
      find.textContaining('nggak ikut dihitung'),
      findsOneWidget,
    );
    expect(find.textContaining('Minimal 2'), findsOneWidget);
    expect(find.textContaining('kurang dari 4'), findsOneWidget);

    // Nadanya ngasih tahu, bukan ngunci: set point-nya tetap tersimpan.
    expect(find.textContaining('tetap TERSIMPAN'), findsOneWidget);
  });

  testWidgets('tambah & hapus set point', (tester) async {
    final state = await pasang(tester, merk: 'Constant');
    expect(find.text('Set Point 2'), findsNothing);

    await tester.tap(find.byKey(const Key('grid_tambah_set_point')));
    await tester.pump();
    expect(find.text('Set Point 2'), findsOneWidget);
    expect(state.setPoint, hasLength(2));

    // Tombol hapus baru muncul begitu set point-nya lebih dari satu.
    // Kartu kedua jatuh di luar layar uji, jadi digulir dulu — kalau nggak,
    // tap-nya meleset dan testnya gagal karena alasan yang bukan bug widget.
    final hapus = find.byIcon(Icons.delete_outline).last;
    await tester.ensureVisible(hapus);
    await tester.pump();
    await tester.tap(hapus);
    await tester.pump();
    expect(state.setPoint, hasLength(1), reason: 'state harus berkurang');
    expect(find.text('Set Point 2'), findsNothing, reason: 'UI harus ikut');
  });

  testWidgets('tambah termokopel menambah baris di set point itu', (
    tester,
  ) async {
    final state = await pasang(tester, merk: 'Constant');
    expect(state.setPoint.first.sensor, hasLength(3));

    await tester.tap(find.byKey(const Key('grid_tambah_sensor_1')));
    await tester.pump();

    expect(state.setPoint.first.sensor, hasLength(4));
    expect(find.byKey(const Key('grid_no_1_3')), findsOneWidget);
  });

  testWidgets('angka yang diketik sampai ke payload', (tester) async {
    final state = await pasang(tester, merk: 'Graphtech Temperature Recorder');

    await tester.enterText(find.byKey(const Key('grid_titik_1')), '66.8');
    await tester.enterText(find.byKey(const Key('grid_no_1_0')), '1');
    await tester.enterText(find.byKey(const Key('grid_ch_1_0')), '1');
    for (var i = 0; i < 4; i++) {
      await tester.enterText(
        find.byKey(Key('grid_baca_1_0_$i')),
        '66.8',
      );
    }
    await tester.enterText(find.byKey(const Key('grid_no_1_1')), '2');
    for (var i = 0; i < 4; i++) {
      await tester.enterText(
        find.byKey(Key('grid_baca_1_1_$i')),
        '66.9',
      );
    }
    await tester.enterText(find.byKey(const Key('grid_ch_1_1')), '2');
    await tester.enterText(find.byKey(const Key('grid_indikator_1_0')), '66.85');
    await tester.pump();

    final payload = state.payload(satuan: '°C', pakaiChannel: true);
    expect(payload, hasLength(1));
    expect(payload.first['titik_ukur'], 66.8);
    expect(payload.first['indikator'], [66.85, null, null, null, null]);

    final grid = payload.first['sensor_grid'] as List<dynamic>;
    expect(grid, hasLength(2));
    expect((grid[0] as Map)['no'], 1);
    expect((grid[0] as Map)['channel'], 1);
    expect((grid[0] as Map)['pembacaan'], [66.8, 66.8, 66.8, 66.8, null]);
    expect((grid[1] as Map)['channel'], 2);
  });
}
