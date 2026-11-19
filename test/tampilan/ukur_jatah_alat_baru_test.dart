// Pengukur tinggi NYATA yang tersedia untuk panel "Alat baru" (dan kartu
// "Maksud Anda?") di lembar yang dibuka dari foto. Dasar ambang "layar sempit"
// paket OCR-SEMPIT: angkanya diukur dari LembarKerjaScreen sungguhan (kerangka
// lembar beku: legenda, banner, bilah bawah) pada tiap ukuran/skala huruf, tanpa
// dan dengan papan ketik, bukan ditebak.
//
//   SIDIK_UKUR=1 SIDIK_UKUR_KELUAR=<berkas.tsv> flutter test \
//     test/tampilan/ukur_jatah_alat_baru_test.dart
//
// Tanpa SIDIK_UKUR semua tes di sini dilewati (ini alat ukur, bukan penjaga).
// Asumsi layar: bilah status 24 dp, bilah gestur bawah 16 dp, papan ketik 280 dp
// (HP) / 320 dp (tablet). Kolom keluaran dijelaskan di baris judul.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sidik_calibration/core/theme/beku_lembar_kerja.dart';
import 'package:sidik_calibration/screens/calibration/lembar_kerja_screen.dart';
import 'package:sidik_calibration/screens/pindai/blok_identitas_foto.dart';

import '../support/dunia_lembar_foto_uji.dart';
import '../support/simpanan_tiruan.dart';

/// (lebar, tinggi, skala huruf, tinggi papan ketik) yang diukur.
const _grid = <(double, double, double, double)>[
  // Empat ukuran acuan paket.
  (320, 640, 2.0, 280),
  (360, 640, 1.3, 280),
  (392, 852, 1.0, 280),
  (600, 900, 1.0, 320),
  // Sekitarnya: batas mana yang masih lega.
  (320, 568, 1.0, 260),
  (320, 640, 1.0, 280),
  (320, 640, 1.3, 280),
  (320, 640, 1.5, 280),
  (360, 640, 1.0, 280),
  (360, 640, 1.15, 280),
  (360, 640, 1.5, 280),
  (360, 640, 2.0, 280),
  (360, 800, 1.0, 280),
  (360, 800, 1.3, 280),
  (360, 800, 1.5, 280),
  (360, 800, 2.0, 280),
  (392, 852, 1.15, 280),
  (392, 852, 1.3, 280),
  (392, 852, 1.5, 280),
  (392, 852, 2.0, 280),
  (411, 891, 1.0, 280),
  (411, 891, 1.5, 280),
  (411, 891, 2.0, 280),
  (600, 900, 1.3, 320),
  (600, 900, 1.5, 320),
  (600, 900, 2.0, 320),
  (840, 360, 1.0, 200),
  (840, 360, 1.3, 200),
];

void main() {
  pasangSimpananTiruan();

  final keluar = Platform.environment['SIDIK_UKUR_KELUAR'];
  final lewati = Platform.environment['SIDIK_UKUR'] == null
      ? 'alat ukur: nyalakan dengan SIDIK_UKUR=1'
      : null;
  final baris = <String>[];

  setUpAll(() async {
    await muatFontUji();
    await initializeDateFormatting('id');
    baris.add(
      [
        'lebar',
        'tinggi',
        'huruf',
        'keadaan',
        'papan',
        // jatah = tinggiMaks yang diberikan lembar ke blok
        'jatah',
        // tinggi isi alami (tanpa batas) dan tinggi yang tampak di layar
        'isi_alami',
        'tampak',
        // sisa untuk lembar di bawah blok
        'sisa_lembar',
        // tombol utama (Buat dan lanjut / pilihan pertama) terlihat di layar?
        'tombol_terlihat',
      ].join('\t'),
    );
  });

  tearDownAll(() {
    final isi = baris.join('\n');
    if (keluar != null) File(keluar).writeAsStringSync('$isi\n');
    stdout.writeln(isi);
  });

  Future<void> ukur(
    WidgetTester tester, {
    required String keadaan,
    required DuniaLembarFoto dunia,
    required (double, double, double, double) g,
    required bool papan,
    required Key kunciIsi,
    required Key kunciTombol,
  }) async {
    final (lebar, tinggi, huruf, tinggiPapan) = g;
    tester.view.physicalSize = Size(lebar * 2, tinggi * 2);
    tester.view.devicePixelRatio = 2.0;
    // Bilah status 24 dp di atas, gestur 16 dp di bawah (hilang di bawah papan).
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 32);
    tester.view.padding = FakeViewPadding(top: 48, bottom: papan ? 0 : 32);
    tester.view.viewInsets = FakeViewPadding(
      bottom: papan ? tinggiPapan * 2 : 0,
    );
    addTearDown(tester.view.reset);

    final u = UkuranUji('u', lebar, tinggi, huruf);
    final kunci = GlobalKey();
    await tester.pumpWidget(
      appUji(
        home: BekuLembarKerja(
          child: LembarKerjaScreen(
            profil: 'ph_meter',
            judulTambahan: 'pH Meter',
            dariFoto: bekalFotoUji(kertasUji),
          ),
        ),
        dunia: dunia,
        u: u,
        kunci: kunci,
      ),
    );
    await tungguUji(tester, () => dunia.mesin!.dipanggil > 0, maks: 80);
    await tungguUji(
      tester,
      () => find.byKey(kunciIsi).evaluate().isNotEmpty,
      maks: 30,
    );
    await tenangUji(tester);
    await bersihkanSnackUji(tester);

    final blok = tester.widget<BlokIdentitasFoto>(
      find.byType(BlokIdentitasFoto),
    );
    final jatah = blok.tinggiMaks;
    final adaIsi = find.byKey(kunciIsi).evaluate().isNotEmpty;
    final alami = adaIsi ? tester.getSize(find.byKey(kunciIsi)).height : -1;
    final tampak = tester.getSize(find.byKey(BlokIdentitasFoto.kunci)).height;
    final sisa = jatah - tampak;

    var terlihat = false;
    final tombol = find.byKey(kunciTombol);
    if (tombol.evaluate().isNotEmpty) {
      final r = tester.getRect(tombol.first);
      final blokR = tester.getRect(find.byKey(BlokIdentitasFoto.kunci));
      // Terlihat penuh di dalam kotak blok (bukan terpotong gulir blok).
      terlihat = r.top >= blokR.top - 0.5 && r.bottom <= blokR.bottom + 0.5;
    }

    baris.add(
      [
        lebar,
        tinggi,
        huruf,
        keadaan,
        papan ? 'buka' : 'tutup',
        jatah.toStringAsFixed(1),
        alami.toStringAsFixed(1),
        tampak.toStringAsFixed(1),
        sisa.toStringAsFixed(1),
        terlihat ? 'ya' : 'tidak',
      ].join('\t'),
    );
    expect(tester.takeException(), isNull);
  }

  for (final g in _grid) {
    for (final papan in [false, true]) {
      testWidgets(
        'panel alat baru ${g.$1.toInt()}x${g.$2.toInt()} huruf ${g.$3} '
        'papan=${papan ? 'buka' : 'tutup'}',
        (tester) async {
          await ukur(
            tester,
            keadaan: 'alat-baru',
            dunia: DuniaLembarFoto(mesin: MesinBacaUji()),
            g: g,
            papan: papan,
            kunciIsi: BlokIdentitasFoto.kunciPanelBaru,
            kunciTombol: BlokIdentitasFoto.kunciBuatLanjut,
          );
        },
        skip: lewati != null,
      );
    }
  }

  // "Maksud Anda?" pada empat ukuran acuan (tiga pilihan, nama panjang).
  for (final g in _grid.take(4)) {
    testWidgets(
      'maksud anda ${g.$1.toInt()}x${g.$2.toInt()} huruf ${g.$3}',
      (tester) async {
        await ukur(
          tester,
          keadaan: 'maksud-anda',
          dunia: DuniaLembarFoto(
            mesin: MesinBacaUji(),
            alat: [
              alatMiripUji(21, 'B628755901'),
              alatMiripUji(22, 'B628755800'),
              alatMiripUji(23, 'B628755910'),
            ],
          ),
          g: g,
          papan: false,
          kunciIsi: BlokIdentitasFoto.kunciMirip,
          kunciTombol: BlokIdentitasFoto.kunciPilihMirip(21),
        );
      },
      skip: lewati != null,
    );
  }
}
