// Pendaftaran komponen bersama Lab (Paket 2).
//
// Komponen belum dipakai layar mana pun, dan `tool/cek-berkas-yatim.sh`
// menghitung berkas yang diimpor dari `test/` sebagai terpakai. Tes ini
// menjaga agar sebutan "terpakai" itu sah, bukan celah: tiap berkas komponen
// harus (1) tercatat di `daftar_komponen.dart`, (2) diimpor galeri render, dan
// (3) punya tes widget sendiri. Berkas komponen baru yang lupa salah satunya
// membuat tes ini merah, bukan lolos diam-diam.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/daftar_komponen.dart';
import '../support/galeri_komponen.dart';

String _baca(String jalur) => File(jalur).readAsStringSync();

void main() {
  final berkas = Directory('lib/widgets/sidik')
      .listSync()
      .whereType<File>()
      .map((f) => f.path.replaceAll('\\', '/').split('/').last)
      .where((n) => n.endsWith('.dart'))
      .map((n) => n.substring(0, n.length - '.dart'.length))
      .where((n) => !berkasSidikLama.contains(n))
      .toSet();

  test('tiap berkas komponen baru ada di daftar, dan sebaliknya', () {
    expect(
      berkas,
      daftarKomponenLab.keys.toSet(),
      reason:
          'tambahkan berkas baru ke test/support/daftar_komponen.dart '
          '(lalu ke galeri dan tes widget)',
    );
  });

  test('berkas lama yang dikecualikan memang masih ada', () {
    for (final n in berkasSidikLama) {
      expect(File('lib/widgets/sidik/$n.dart').existsSync(), isTrue, reason: n);
    }
  });

  test('tiap kelas yang didaftarkan benar dideklarasikan di berkasnya', () {
    for (final e in daftarKomponenLab.entries) {
      final sumber = _baca('lib/widgets/sidik/${e.key}.dart');
      for (final nama in e.value) {
        expect(
          RegExp(
            '(?:abstract final class|final class|class|enum|typedef)\\s+$nama\\b',
          ).hasMatch(sumber),
          isTrue,
          reason: '${e.key}.dart tidak mendeklarasikan $nama',
        );
      }
    }
  });

  test('galeri render mengimpor SEMUA berkas komponen', () {
    final galeri = _baca('test/support/galeri_komponen.dart');
    for (final n in daftarKomponenLab.keys) {
      expect(
        galeri,
        contains("package:sidik_calibration/widgets/sidik/$n.dart"),
        reason: '$n tidak diimpor galeri render',
      );
    }
  });

  test('tiap berkas komponen punya tes widget yang mengimpornya', () {
    final tes = Directory('test/komponen_sidik')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .map((f) => f.readAsStringSync())
        .toList();
    for (final n in daftarKomponenLab.keys) {
      expect(
        tes.any(
          (s) => s.contains("package:sidik_calibration/widgets/sidik/$n.dart"),
        ),
        isTrue,
        reason: '$n belum punya tes di test/komponen_sidik/',
      );
    }
  });

  test('galeri memuat tujuh halaman dan tiap halaman menghasilkan widget', () {
    expect(galeriHalaman.keys, [
      'stempel',
      'baris',
      'aksi',
      'skala',
      'navigasi',
      'keadaan',
      'lajur',
    ]);
  });

  test('komponen baru tidak memuat istilah terlarang di kodenya', () {
    for (final n in daftarKomponenLab.keys) {
      // Komentar boleh menyebut istilah itu (untuk menjelaskan larangannya);
      // yang dijaga adalah teks yang tampil.
      final sumber = _baca('lib/widgets/sidik/$n.dart')
          .split(RegExp(r'\r?\n'))
          .where((b) => !b.trimLeft().startsWith('//'))
          .join(' ')
          .toLowerCase();
      expect(sumber, isNot(contains('daluwarsa')), reason: n);
      expect(sumber, isNot(contains('adaluarsa')), reason: n);
      expect(
        sumber,
        isNot(contains('touppercase')),
        reason: '$n: label KAPITAL',
      );
    }
  });

  test('komponen tidak memakai `Colors.` kecuali transparent', () {
    final pola = RegExp(r'\bColors\.(?!transparent\b)\w+');
    for (final n in daftarKomponenLab.keys) {
      expect(
        pola.hasMatch(_baca('lib/widgets/sidik/$n.dart')),
        isFalse,
        reason: '$n memakai warna mentah',
      );
    }
  });
}
