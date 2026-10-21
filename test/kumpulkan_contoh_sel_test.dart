import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sidik_calibration/providers/sakelar_ocr_provider.dart';
import 'package:sidik_calibration/services/kumpulkan_contoh_sel.dart';
import 'package:sidik_calibration/services/simpanan_contoh_sel.dart';

/// Pengumpulan contoh sel TERKONFIRMASI — lokal saja, sakelar bawaan mati.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('contoh-sel'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Potongan sel sintetis berwarna, seukuran potongan kanvas 3 px/pt.
  Uint8List pngSel(String teks) {
    final c = img.Image(width: 240, height: 66);
    img.fill(c, color: img.ColorRgb8(226, 220, 205));
    img.drawRect(
      c,
      x1: 0,
      y1: 0,
      x2: 239,
      y2: 65,
      color: img.ColorRgb8(30, 30, 30),
    );
    img.drawString(
      c,
      teks,
      font: img.arial48,
      x: 30,
      y: 8,
      color: img.ColorRgb8(20, 30, 110),
    );
    // Derau kertas/kamera (deterministik) — potongan foto nyata tidak rata.
    var r = 7;
    for (var y = 0; y < c.height; y++) {
      for (var x = 0; x < c.width; x++) {
        r = (r * 1103515245 + 12345) & 0x7fffffff;
        final d = r % 31 - 15;
        final p = c.getPixel(x, y);
        c.setPixelRgb(
          x,
          y,
          (p.r + d).clamp(0, 255),
          (p.g + d).clamp(0, 255),
          (p.b + d).clamp(0, 255),
        );
      }
    }
    return img.encodePng(c);
  }

  test('sakelar: dua-duanya MATI bawaan, dan terpisah', () {
    const s = SakelarOcr();
    expect(s.kumpulkanContohSel, isFalse);
    expect(s.pakaiModelDigit, isFalse);

    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(sakelarOcrProvider).kumpulkanContohSel, isFalse);
    expect(c.read(sakelarOcrProvider).pakaiModelDigit, isFalse);
  });

  test(
    'hanya sel berlabel yang disimpan, sebagai JPEG abu-abu; tanpa foto penuh',
    () async {
      final simpanan = SimpananContohSel(tmp);
      final png = [pngSel('49,99'), pngSel('50,01'), pngSel('7')];

      final n = await simpanContohTerkonfirmasi(
        simpanan: simpanan,
        lembar: 'anak_timbangan',
        sel: [
          (label: '49,99992', png: png[0], fieldId: 'f1', bacaanOcr: '49,9992'),
          (label: '50,01', png: png[1], fieldId: 'f2', bacaanOcr: null),
          (label: '  ', png: png[2], fieldId: 'f3', bacaanOcr: '7'),
        ],
      );

      expect(n, 2);
      final isi = await simpanan.baca();
      expect(isi.contoh.map((c) => c.label), ['49,99992', '50,01']);
      expect(isi.contoh.first.bacaanOcr, '49,9992');
      expect(isi.contoh.first.lembar, 'anak_timbangan');

      // Isi folder: indeks + potongan sel .jpg saja.
      final nama = tmp.listSync().map((f) => f.uri.pathSegments.last).toList();
      expect(nama, contains('indeks.jsonl'));
      expect(
        nama
            .where((n) => n != 'indeks.jsonl')
            .every((n) => n.startsWith('sel_') && n.endsWith('.jpg')),
        isTrue,
      );

      // Abu-abu: R = G = B di tiap piksel hasil decode.
      final berkas = File('${tmp.path}/${isi.contoh.first.berkas}');
      final c = img.decodeJpg(berkas.readAsBytesSync())!;
      expect(c.numChannels == 1 || _abu(c), isTrue);

      // Ukuran rata-rata per sel (belum diukur di HP; ini potongan sintetis
      // 240×66): dicatat dan dijaga tetap kecil dibanding PNG berwarna.
      final ukuran = [
        for (final k in isi.contoh)
          File('${tmp.path}/${k.berkas}').lengthSync(),
      ];
      final rata = ukuran.reduce((a, b) => a + b) / ukuran.length;
      final rataPng = (png[0].length + png[1].length) / 2;
      // ignore: avoid_print
      print(
        'contoh sel: rata-rata ${rata.toStringAsFixed(0)} B/sel JPEG abu q70 '
        '(PNG warna ${rataPng.toStringAsFixed(0)} B)',
      );
      expect(rata, lessThan(12 * 1024));
    },
  );

  test('PNG rusak dilewati, bukan menggagalkan semuanya', () async {
    final simpanan = SimpananContohSel(tmp);
    final n = await simpanContohTerkonfirmasi(
      simpanan: simpanan,
      lembar: 'x',
      sel: [
        (
          label: '1',
          png: Uint8List.fromList([1, 2, 3]),
          fieldId: 'a',
          bacaanOcr: null,
        ),
        (label: '2', png: pngSel('2'), fieldId: 'b', bacaanOcr: null),
      ],
    );
    expect(n, 1);
  });
}

bool _abu(img.Image c) {
  for (var y = 0; y < c.height; y += 5) {
    for (var x = 0; x < c.width; x += 5) {
      final p = c.getPixel(x, y);
      if (p.r != p.g || p.g != p.b) return false;
    }
  }
  return true;
}
