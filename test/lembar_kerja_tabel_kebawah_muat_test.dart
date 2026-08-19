import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/models/lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_state.dart';
import 'package:sidik_calibration/screens/calibration/widgets/lembar_kerja_tabel.dart';

/// Tabel Conductivity bentuk KERTASNYA — Repeat turun ke bawah, slot larutan
/// berjajar ke kanan (`SIDIK-FM-CAL-0510`).
///
/// `lembar_kerja_tabel_muat_test.dart` sudah menjaga bentuk pH, tapi bentuk ini
/// lewat cabang yang lain sama sekali (`_TabelKeBawah`) — beda kepala, beda
/// kolom nempel, dan punya pilihan satuan yang nggak ada di bentuk satunya.
/// Cabang itu nggak pernah dirender satu tes pun, dan keenam ukuran kepalanya
/// dipatok mati: kepala slot 46px, baris resolusi 28px, kepala satuan 30px,
/// kolom Repeat 72px.
///
/// Yang kejadian di HP: tujuh kotak meluber sekaligus — dua pil pilihan satuan
/// minta 265px di kolom 156px, `Resolusi: 0,01 mS/cm` butuh dua baris di kotak
/// setinggi satu, dan kata `Repeat` sendiri nggak muat di kolomnya. Nggak satu
/// pun ngasih error; yang kelihatan cuma tabel berantakan.
void main() {
  LembarKerja lembarRev5() => LembarKerja.fromJson({
    'kode_dokumen': 'SIDIK-FM-CAL-0510_Rev.5',
    'judul': 'Calibration Worksheet - Conductivity Meter',
    'untuk': 'teknisi',
    'jumlah_pengulangan': 5,
    'satuan': null,
    'satuan_campuran': true,
    'suhu_wajib': true,
    'satuan_suhu': '°C',
    'bagian': [
      {
        'kode': 'hasil',
        'judul': 'CALIBRATION RESULT',
        'tabel': [
          {
            'tahap': 'sesudah_adjustment',
            'judul': 'After adjustment Reading',
            'judul_nilai': 'Solution Standard',
            'sumbu_pengulangan': 'baris',
            'kolom': [
              {'kode': 'pembacaan', 'label': 'Reading', 'tipe': 'angka'},
              {'kode': 'suhu', 'label': '°C', 'tipe': 'angka', 'satuan': '°C'},
            ],
            'pengulangan': [1, 2, 3, 4, 5],
            'baris': [
              {'titik_ukur': 25, 'label': '25', 'satuan': 'µS/cm', 'resolusi': 0.1, 'desimal': 1},
              {'titik_ukur': 1412, 'label': '1412', 'satuan': 'µS/cm', 'resolusi': 1, 'desimal': 0, 'eksklusif_dengan': 1.412},
              {'titik_ukur': 1.412, 'label': '1,412', 'satuan': 'mS/cm', 'resolusi': 0.001, 'desimal': 3, 'eksklusif_dengan': 1412},
              {'titik_ukur': 111, 'label': '111', 'satuan': 'mS/cm', 'resolusi': 0.01, 'desimal': 2},
            ],
            // Tulisan kertas ≠ titik yang dihitung: kertas Rev.5 masih nominal
            // botol lama, master sudah pindah ke 25/1412/111.
            'slot_cetak': [
              {'label': '84', 'varian': null, 'titik_ukur': [25], 'satuan': 'µS/cm', 'resolusi': 0.1, 'desimal': 1},
              {'label': '1413 µS', 'varian': '1.413 mS', 'titik_ukur': [1412, 1.412], 'satuan': 'µS/cm', 'resolusi': 1, 'desimal': 0},
              {'label': '5000 µS', 'varian': '5 mS', 'titik_ukur': [111], 'satuan': 'mS/cm', 'resolusi': 0.01, 'desimal': 2},
              {'label': '80000 µS', 'varian': '80 mS', 'titik_ukur': <double>[]},
            ],
          },
        ],
      },
    ],
  });

  Future<LembarKerjaState> render(
    WidgetTester tester, {
    required Size layar,
    double skalaTeks = 1.0,
  }) async {
    tester.view.physicalSize = layar;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final bentuk = lembarRev5();
    final isian = LembarKerjaState(
      bentuk: bentuk,
      clientRequestId: 'tes-muat-kebawah',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(skalaTeks)),
              child: SingleChildScrollView(
                child: LembarKerjaTabel(
                  tabel: bentuk.bagian.first.tabel.first,
                  isian: isian,
                  onBerubah: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    return isian;
  }

  /// HP paling sempit yang realistis dipakai teknisi di lapangan.
  const layarSempit = Size(360, 800);

  testWidgets('seluruh kepala muat di HP sempit', (tester) async {
    await render(tester, layar: layarSempit);

    expect(tester.takeException(), isNull);

    // Yang tercetak di kertas beneran kegambar, bukan cuma nggak error.
    expect(find.text('1413 µS'), findsOneWidget);
    expect(find.text('1.413 mS'), findsOneWidget);
    expect(find.textContaining('Resolusi:'), findsNWidgets(4));
    expect(find.text('Solution Standard'), findsOneWidget);
  });

  /// Teks sistem diperbesar itu setelan yang lumrah dipakai teknisi lapangan,
  /// dan ukuran yang dipatok mati nggak ikut membesar sama sekali.
  testWidgets('tetap muat waktu teks sistem diperbesar', (tester) async {
    await render(tester, layar: layarSempit, skalaTeks: 1.3);

    expect(tester.takeException(), isNull);
  });

  /// Slot mati (`80000 µS` — dicentang di kertas, barisnya belum ada di master)
  /// dan kolom nempel `Repeat` dua-duanya di kepala yang sama.
  testWidgets('slot tanpa larutan & kolom Repeat nggak meluber', (
    tester,
  ) async {
    await render(tester, layar: const Size(320, 640));

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        AppLocalizations.of(
          tester.element(find.byType(LembarKerjaTabel)),
        ).lkSlotTanpaLarutan,
      ),
      findsOneWidget,
    );
  });

  /// Pilihan satuannya bukan hiasan: yang kepilih nentuin angka yang diketik
  /// masuk ke titik `1412` (µS/cm) atau `1,412` (mS/cm). Waktu pilnya diganti
  /// dari `ChoiceChip` jadi gambar sendiri, ini yang gampang ikut hilang.
  testWidgets('milih satuan mS mindahin isian ke titik pasangannya', (
    tester,
  ) async {
    final isian = await render(tester, layar: layarSempit);

    await tester.tap(find.text('1.413 mS'));
    await tester.pump();

    // Kotak isian digambar per SLOT, bukan per baris: slot `84` duluan penuh
    // (5 Repeat × 2 kolom), baru slot `1413 µS`. Jadi kotak pembacaan Repeat 1
    // di slot kedua ada di urutan ke-10.
    const kotakSlotKeduaRepeat1 = 1 * 5 * 2;

    await tester.enterText(
      find.byType(TextField).at(kotakSlotKeduaRepeat1),
      '1,412',
    );
    await tester.pump();

    expect(
      isian.titik[1.412]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      '1,412',
    );
    expect(
      isian.titik[1412]!.kotak('sesudah_adjustment', 'pembacaan', 0).text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
