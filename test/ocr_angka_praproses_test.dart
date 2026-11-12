import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/ocr_angka/praproses_sel.dart';

/// Paritas praproses crop sel dengan rig (`MesinPaddle._praproses`, OpenCV
/// `INTER_LINEAR`). Crop dan bita BGR 48-tinggi dari set uji SINTETIS.
void main() {
  final dir = 'test/fixtures/ocr_angka';
  final contoh =
      (jsonDecode(
                File('$dir/paritas_praproses.json').readAsStringSync(),
              )['contoh']
              as List)
          .cast<Map<String, dynamic>>();

  group('ubah ukuran bilinear ala OpenCV', () {
    for (final c in contoh) {
      test('${c['file']} (${c['lebar']}×${c['tinggi']} -> ${c['rw']}×48)', () {
        final crop = img.decodePng(
          File('$dir/${c['file']}').readAsBytesSync(),
        )!;
        final harapan = File('$dir/${c['bin']}').readAsBytesSync();

        final rgb = crop.getBytes(order: img.ChannelOrder.rgb);
        final hasil = PraprosesSel.ubahUkuranBgr(
          rgb,
          crop.width,
          crop.height,
          c['rw'] as int,
          48,
        );

        expect(hasil.length, harapan.length);

        var selisihMaks = 0;
        var jumlah = 0;
        var beda = 0;
        for (var i = 0; i < harapan.length; i++) {
          final d = (hasil[i] - harapan[i]).abs();
          if (d > selisihMaks) selisihMaks = d;
          jumlah += d;
          if (d != 0) beda++;
        }

        // OpenCV memakai jalur SIMD untuk lintasan vertikal yang membulatkan
        // lain dari rumus skalar: ±1 tingkat abu pada sebagian nilai (terukur
        // 11–13% pada tiga crop ini). Lebih dari itu berarti bobot
        // interpolasinya lain.
        expect(
          selisihMaks,
          lessThanOrEqualTo(1),
          reason: 'selisih maks per kanal',
        );
        expect(
          jumlah / harapan.length,
          lessThan(0.2),
          reason: 'rata-rata selisih',
        );
        expect(
          beda / harapan.length,
          lessThan(0.2),
          reason: 'porsi nilai yang berbeda',
        );
      });
    }
  });

  group('proses — bentuk dan normalisasi tensor', () {
    img.Image warna(int w, int h, int r, int g, int b) {
      final i = img.Image(width: w, height: h, numChannels: 3);
      img.fill(i, color: img.ColorRgb8(r, g, b));
      return i;
    }

    test('lebar kecil -> kanvas 320, isi di kiri, sisanya NOL', () {
      // 96×48 -> rw = 96; kanvas 320.
      final t = PraprosesSel.proses(warna(96, 48, 255, 255, 255));

      expect(t.lebar, 320);
      expect(t.lebarIsi, 96);
      expect(t.data.length, 3 * 48 * 320);

      // putih = 255 -> (255/255 - 0.5)/0.5 = 1.0 di bagian isi
      expect(t.data[0], closeTo(1.0, 1e-6));
      expect(t.data[95], closeTo(1.0, 1e-6));
      // padding setelah normalisasi = 0, BUKAN -1 (putih/hitam).
      expect(t.data[96], 0.0);
      expect(t.data[319], 0.0);
    });

    test('hitam -> -1, urutan kanal B, G, R', () {
      // R=255,G=0,B=128: kanal 0 = B, 1 = G, 2 = R
      final t = PraprosesSel.proses(warna(96, 48, 255, 0, 128));

      double di(int kanal) => t.data[(kanal * 48 + 10) * t.lebar + 10];
      expect(di(0), closeTo(128 / 127.5 - 1, 1e-6)); // B
      expect(di(1), closeTo(-1.0, 1e-6)); // G
      expect(di(2), closeTo(1.0, 1e-6)); // R
    });

    test(
      'crop lebih lebar dari 320 setelah skala tinggi -> kanvas melebar, tanpa padding',
      () {
        // 600×60 -> rw = ceil(48*600/60) = 480
        final t = PraprosesSel.proses(warna(600, 60, 255, 255, 255));

        expect(t.lebarIsi, 480);
        expect(t.lebar, 480);
      },
    );

    test('crop sempit -> lebar isi minimal 16', () {
      // 4×200 -> ceil(48*4/200)=1 -> 16
      final t = PraprosesSel.proses(warna(4, 200, 255, 255, 255));

      expect(t.lebarIsi, 16);
      expect(t.lebar, 320);
    });

    test('citra abu-abu 1 kanal dan RGBA diterima', () {
      final abu = img.Image(width: 100, height: 50, numChannels: 1);
      img.fill(abu, color: img.ColorUint8(0));
      final a = PraprosesSel.proses(abu);
      expect(a.data[0], closeTo(-1.0, 1e-6));

      final rgba = img.Image(width: 100, height: 50, numChannels: 4);
      img.fill(rgba, color: img.ColorRgba8(255, 255, 255, 255));
      final b = PraprosesSel.proses(rgba);
      expect(b.data[0], closeTo(1.0, 1e-6));
    });

    test('crop kosong -> ArgumentError', () {
      expect(
        () => PraprosesSel.proses(img.Image(width: 0, height: 0)),
        throwsArgumentError,
      );
    });

    test(
      'hasil tidak bergantung pada urutan pemanggilan (tanpa status bersama)',
      () {
        final a = PraprosesSel.proses(warna(120, 50, 10, 200, 90));
        PraprosesSel.proses(warna(333, 77, 1, 2, 3));
        final b = PraprosesSel.proses(warna(120, 50, 10, 200, 90));

        expect(Float32List.sublistView(a.data), orderedEquals(b.data));
      },
    );
  });
}
