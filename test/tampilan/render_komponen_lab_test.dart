// Harness render komponen bersama Lab (Paket 2): galeri semua komponen dalam
// semua keadaannya, pada tiga ukuran gerbang x dua tema.
//
// Ukuran: HP 392 dp, HP sempit 320 dp dengan huruf 1,3x, dan tablet 1280 dp
// (isi dibatasi 720 dp seperti layar sungguhan). Font Inter dan IBM Plex Mono
// dimuat dari aset (`muatFontUji`), jadi lebar teks sama dengan HP.
//
// GAGAL bila: ada luapan atau galat render; ada teks yang kontrasnya < 4,5:1
// (dari pohon widget, bukan sampel piksel); ada sasaran sentuh < 48 dp atau
// sasaran tanpa label; ada teks "kedaluwarsa" atau pemisah " · "; Lajur Bacaan
// memuat kata "selisih". Galeri mengimpor SEMUA komponen, jadi berkas komponen
// tidak pernah yatim dari harness.
//
// PNG hanya bila `SIDIK_PNG_DIR` diisi (folder di luar repo):
//
//   SIDIK_PNG_DIR=/tmp/komponen flutter test test/tampilan/render_komponen_lab_test.dart
//
// Nama: `komponen-lab-<halaman>_<ukuran>_<tema>.png`. Tanpa golden: gambar dari
// mesin non-macOS tidak boleh menjadi acuan (lihat docs/standar-kualitas-desain.md).
// Satu halaman saja: `SIDIK_HALAMAN=lajur,skala`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_spacing.dart';
import 'package:sidik_calibration/core/theme/ukuran_komponen.dart';

import '../support/galeri_komponen.dart';
import '../support/komponen_uji.dart';

enum _Ukuran {
  hp392('hp392', 392, 1.0, 2.0),
  sempit('sempit', 320, 1.3, 2.0),
  tablet('tablet', 1280, 1.0, 1.25);

  const _Ukuran(this.nama, this.lebar, this.skala, this.piksel);
  final String nama;
  final double lebar;
  final double skala;
  final double piksel;
}

/// Tinggi viewport uji: cukup untuk seluruh halaman galeri sekaligus, supaya
/// pedoman sentuh memeriksa semuanya.
const _tinggi = 9000.0;

void main() {
  setUpAll(muatFontUji);

  final folder = Platform.environment['SIDIK_PNG_DIR'];
  if (folder != null) Directory(folder).createSync(recursive: true);
  final hanya = Platform.environment['SIDIK_HALAMAN']?.split(',').toSet();

  for (final u in _Ukuran.values) {
    for (final gelap in const [false, true]) {
      for (final h in galeriHalaman.entries) {
        if (hanya != null && !hanya.contains(h.key)) continue;
        for (final bahasa in const ['id', 'en']) {
          // English hanya di ukuran tersempit, terang: kata Inggris lain
          // panjangnya ("Generation failed", "Superseded by revision").
          if (bahasa == 'en' && !(u == _Ukuran.sempit && !gelap)) continue;
          final tema = gelap ? 'gelap' : 'terang';
          final sufiks = bahasa == 'id' ? '' : '_$bahasa';
          testWidgets(
            'komponen ${h.key} - ${u.nama} - $tema${sufiks.replaceAll('_', ' - ')}',
            (tester) async {
              layarUji(tester, lebar: u.lebar, tinggi: _tinggi);
              final semantik = tester.ensureSemantics();
              final galat = <String>[];
              final kunci = GlobalKey();
              final bawaan = FlutterError.onError;
              try {
                FlutterError.onError = (d) =>
                    galat.add(d.exceptionAsString().split('\n').first);
                try {
                  await tester.pumpWidget(
                    aplikasiUji(
                      SingleChildScrollView(
                        child: RepaintBoundary(
                          key: kunci,
                          child: Builder(
                            builder: (context) => ColoredBox(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: AmbangLab.lebarBaca,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.xl,
                                    ),
                                    child: h.value(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      gelap: gelap,
                      skala: u.skala,
                      bahasa: bahasa,
                      bergulir: false,
                    ),
                  );
                  // Bukan pumpAndSettle: pemutar tombol sibuk berputar terus.
                  await tester.pump();
                  await tester.pump(const Duration(milliseconds: 500));
                  if (folder != null) {
                    final batas = tester.renderObject<RenderRepaintBoundary>(
                      find.byKey(kunci),
                    );
                    await tester.runAsync(() async {
                      final gambar = await batas.toImage(pixelRatio: u.piksel);
                      final data = await gambar.toByteData(
                        format: ui.ImageByteFormat.png,
                      );
                      File(
                        '$folder/komponen-lab-${h.key}_${u.nama}_$tema$sufiks.png',
                      ).writeAsBytesSync(data!.buffer.asUint8List());
                    });
                  }
                } finally {
                  // Kembalikan SEBELUM expect() apa pun.
                  FlutterError.onError = bawaan;
                }
                expect(tester.takeException(), isNull);
                expect(galat.toSet().toList(), isEmpty, reason: 'galat render');

                final semua = semuaTeks(tester, find.byType(Scaffold));
                expect(
                  semua.toLowerCase(),
                  isNot(anyOf(contains('daluwarsa'), contains('adaluarsa'))),
                  reason:
                      'istilah terlarang: pakai "Lewat jadwal" dan '
                      '"Masa berlaku berakhir"',
                );
                expect(
                  semua,
                  isNot(contains(' · ')),
                  reason: 'rangkaian A · B · C',
                );
                if (h.key == 'lajur') {
                  expect(
                    semua.toLowerCase(),
                    isNot(contains('selisih')),
                    reason: 'Lajur tidak menampilkan selisih',
                  );
                }
                expect(
                  pelanggaranKontrasTeks(tester, find.byType(Scaffold)),
                  isEmpty,
                );
                await periksaPedomanSentuh(tester);
              } finally {
                semantik.dispose();
              }
              await tester.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }
  }
}
