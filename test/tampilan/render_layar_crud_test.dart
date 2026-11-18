// Harness render layar CRUD lab: tiap keadaan (memuat, daftar, kosong, galat,
// dialog, formulir, lembar pemilih) pada lima lebar (320, 360, 392, 600,
// 840 dp) dan dua tema. GAGAL bila ada luapan (RenderFlex overflow) atau galat
// render lain. PNG hanya ditulis bila `SIDIK_PNG_DIR` diisi (folder di LUAR
// repo):
//
//   SIDIK_PNG_DIR=/tmp/crud flutter test test/tampilan/render_layar_crud_test.dart
//
// Penyaring opsional (boleh beberapa, dipisah koma):
// `SIDIK_LAYAR=order-daftar,hub`, `SIDIK_UKURAN=320,392`,
// `SIDIK_SKALA=1.0,1.3,2.0` (skala huruf, boleh beberapa dipisah koma; bawaan
// 1.0). Skala selain 1.0 hanya dipotret di lebar 320 dan 392 dp (kombinasi
// terburuk dan lebar HP umum); skala 1.0 di semua lebar.
//
// Tidak ada golden baseline: gambar dari mesin non-macOS tidak boleh menjadi
// acuan (lihat test/flutter_test_config.dart). Tes ini menjaga LUAPAN.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/crud_uji.dart';
import '../support/layar_crud_uji.dart';
import '../support/super_admin_uji.dart' show muatFontSa, selesaikan;

void main() {
  setUpAll(muatFontSa);

  const ukuran = <(String, double, double)>[
    ('320', 320, 640),
    ('360', 360, 740),
    ('392', 392, 852),
    ('600', 600, 960),
    ('840', 840, 600),
  ];

  final folder = Platform.environment['SIDIK_PNG_DIR'];
  if (folder != null) Directory(folder).createSync(recursive: true);
  final hanyaLayar = Platform.environment['SIDIK_LAYAR'];
  final hanyaUkuran = Platform.environment['SIDIK_UKURAN'];
  final daftarSkala = [
    for (final t in (Platform.environment['SIDIK_SKALA'] ?? '1.0').split(','))
      ?double.tryParse(t.trim()),
  ];

  for (final skala in daftarSkala) {
  final akhiran = skala == 1.0 ? '' : '-x$skala';
  for (final k in [...layarMatriksCrud, ...keadaanLainCrud]) {
    if (hanyaLayar != null && !hanyaLayar.split(',').contains(k.nama)) {
      continue;
    }
    for (final (kode, lebar, tinggi) in ukuran) {
      if (hanyaUkuran != null && !hanyaUkuran.split(',').contains(kode)) {
        continue;
      }
      if (skala != 1.0 && kode != '320' && kode != '392') continue;
      for (final gelap in const [false, true]) {
        final tema = gelap ? 'gelap' : 'terang';
        testWidgets('${k.nama} - $kode - $tema x$skala', (tester) async {
          final kunci = GlobalKey();
          // Untuk PNG, bayangan digambar sungguhan (bawaan flutter_test:
          // kotak hitam keras). Harus dikembalikan sebelum tes selesai.
          if (folder != null) debugDisableShadows = false;
          const piksel = 2.0;
          tester.view.physicalSize = Size(lebar * piksel, tinggi * piksel);
          tester.view.devicePixelRatio = piksel;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          try {
            await tester.pumpWidget(
              bungkusCrud(
                k.layar(),
                lapisan: k.lapisan(),
                token: k.token,
                izin: k.izin,
                gelap: gelap,
                skalaHuruf: skala,
                kunciLatar: kunci,
              ),
            );
            await selesaikan(tester);
            if (k.sesudah != null) {
              await jalankanSesudahCrud(tester, k);
              await selesaikan(tester);
            }
            // Keadaan "memuat" dipotret SEBELUM jawaban datang.
            if (k.menahan) {
              await tester.pump(const Duration(milliseconds: 100));
            }

            if (folder != null) {
              final batas = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(kunci),
              );
              await tester.runAsync(() async {
                final gambar = await batas.toImage(pixelRatio: piksel);
                final data = await gambar.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                File(
                  '$folder/${k.nama}.$kode${gelap ? '-gelap' : ''}$akhiran.png',
                ).writeAsBytesSync(data!.buffer.asUint8List());
              });
            }

            if (k.menahan) {
              await tester.pump(const Duration(seconds: 6));
              await selesaikan(tester);
            }
            expect(tester.takeException(), isNull);
          } finally {
            debugDisableShadows = true;
          }
        });
      }
    }
  }
  }
}
