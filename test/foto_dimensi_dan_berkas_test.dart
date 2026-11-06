import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/foto_tertinggal.dart';
import 'package:sidik_calibration/services/pesan_galat_pindai.dart';
import 'package:sidik_calibration/services/photo_source.dart';
import 'package:sidik_calibration/services/potong_sel_foto.dart';

Uint8List foto(int w, int h) =>
    Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('foto-batas'));
  tearDown(() => tmp.deleteSync(recursive: true));

  for (final dimensi in [(4201, 1), (1, 4201)]) {
    test('header rejects either side over 4200: $dimensi', () async {
      final bita = foto(dimensi.$1, dimensi.$2);
      expect(() => decodeFotoTerbatas(bita), throwsA(isA<FotoMelebihiBatas>()));
      await expectLater(
        decodeFotoDiIsolate(bita),
        throwsA(isA<FotoMelebihiBatas>()),
      );
      expect(
        golongkanGalatPindai(const FotoMelebihiBatas()),
        GolonganGalatPindai.memoriHabis,
      );
    });
  }

  test('exact side boundary retains pixels', () {
    final bita = foto(1, 4200);
    final hasil = decodeFotoTerbatas(bita)!;
    expect(hasil.width, 1);
    expect(hasil.height, 4200);
  });

  test(
    'read clears camera cache after success; missing file remains an error',
    () async {
      final file = File('${tmp.path}/kamera.png')..writeAsBytesSync(foto(4, 3));
      final bita = await bacaDanHapusFoto(file);
      expect(decodeFotoTerbatas(bita)!.width, 4);
      expect(file.existsSync(), isFalse);
      await expectLater(
        bacaDanHapusFoto(file),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'recovered oversized portrait must pass the same header guard',
    () async {
      final file = File('${tmp.path}/pulihan.png')
        ..writeAsBytesSync(foto(1, 4201));
      final sumber = MockSumberFoto(tertinggal: file);
      final pulih = await ambilFotoAtauPulihkan(
        sumber,
        pakaiTertinggal: (_) async => true,
        maxWidth: 4200,
        maxHeight: 4200,
      );
      expect(sumber.jumlahAmbil, 0);
      final bita = await bacaDanHapusFoto(pulih!);
      expect(file.existsSync(), isFalse);
      expect(() => decodeFotoTerbatas(bita), throwsA(isA<FotoMelebihiBatas>()));
    },
  );
}
