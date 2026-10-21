import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/foto_tertinggal.dart';
import 'package:sidik_calibration/services/photo_source.dart';

/// Foto yang hilang karena Android mematikan aplikasi saat kamera terbuka.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('foto-tertinggal'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File berkas(String nama) => File('${tmp.path}/$nama')..writeAsBytesSync([1]);

  test('tidak ada foto tertinggal: kamera dibuka, tanpa bertanya', () async {
    final sumber = MockSumberFoto(file: berkas('baru.jpg'));
    var ditanya = false;

    final f = await ambilFotoAtauPulihkan(
      sumber,
      pakaiTertinggal: (_) async => ditanya = true,
      maxWidth: 4200,
      maxHeight: 4200,
      imageQuality: 100,
    );

    expect(ditanya, isFalse);
    expect(f!.path, endsWith('baru.jpg'));
    expect(sumber.jumlahAmbil, 1);
    expect(sumber.maxWidthTerakhir, 4200);
    expect(sumber.maxHeightTerakhir, 4200);
  });

  test('foto tertinggal DIPAKAI hanya bila teknisi setuju', () async {
    final sisa = berkas('sisa.jpg');
    final sumber = MockSumberFoto(file: berkas('baru.jpg'), tertinggal: sisa);

    final f = await ambilFotoAtauPulihkan(
      sumber,
      pakaiTertinggal: (_) async => true,
    );

    expect(f!.path, sisa.path);
    expect(sumber.jumlahAmbil, 0, reason: 'kamera tidak perlu dibuka');
  });

  test('ditolak: berkas tertinggal dihapus, kamera dibuka', () async {
    final sisa = berkas('sisa.jpg');
    final sumber = MockSumberFoto(file: berkas('baru.jpg'), tertinggal: sisa);

    final f = await ambilFotoAtauPulihkan(
      sumber,
      pakaiTertinggal: (_) async => false,
    );

    expect(f!.path, endsWith('baru.jpg'));
    expect(sisa.existsSync(), isFalse, reason: 'isinya lembar pelanggan');
    expect(sumber.jumlahAmbil, 1);
  });

  test('foto tertinggal hanya ditawarkan SEKALI', () async {
    final sumber = MockSumberFoto(
      file: berkas('baru.jpg'),
      tertinggal: berkas('sisa.jpg'),
    );
    var tanya = 0;

    for (var i = 0; i < 2; i++) {
      await ambilFotoAtauPulihkan(
        sumber,
        pakaiTertinggal: (_) async {
          tanya++;
          return false;
        },
      );
    }

    expect(tanya, 1);
  });
}
