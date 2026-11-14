import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/services/kenali_jenis_lembar.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';

/// Mengenali jenis lembar dari satu foto seluruh halaman, putaran demi
/// putaran. Murni logika: pembaca halaman dan pemutar foto disuntik.
class _Pembaca implements PembacaHalaman {
  _Pembaca(this.teks);

  final List<String> teks;
  final orientasi = <int?>[];
  var dibaca = 0;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async {
    orientasi.add(asli?.orientasi);
    final t = dibaca < teks.length ? teks[dibaca] : '';
    dibaca++;

    return t.isEmpty
        ? const []
        : [
            (
              teks: t,
              kotak: const Rect.fromLTWH(0, 0, 100, 10),
              keyakinan: null,
            ),
          ];
  }

  @override
  Future<void> tutup() async {}
}

const _dikenal = <FormulirDikenal>[
  (
    templateId: 'ph_meter',
    kodeDokumen: 'SIDIK-FM-CAL-0509_Rev.4',
    judul: 'Calibration Worksheet - pH Meter',
  ),
];

/// Pemutar tiruan yang mencatat sudutnya (tanpa isolate).
({PutarFoto putar, List<int> sudut}) _pemutar() {
  final sudut = <int>[];

  return (
    sudut: sudut,
    putar: (foto, s) async {
      sudut.add(s);

      return img.copyRotate(foto, angle: s);
    },
  );
}

void main() {
  final foto = img.Image(width: 40, height: 30);
  const kodePh = 'Revise : 4 SIDIK-FM-CAL-0509';
  const judulPh = 'PT. SIDIK Calibration Work Sheet - pH Meter LK-285-IDN';

  test('berhenti di putaran PERTAMA yang menghasilkan kode formulir', () async {
    final pembaca = _Pembaca(['', '', kodePh, kodePh]);
    final p = _pemutar();

    final hasil = await kenaliJenisLembar(
      foto: foto,
      halaman: pembaca,
      dikenal: _dikenal,
      putar: p.putar,
    );

    expect(hasil?.sumber, SumberJenisLembar.kodeFormulir);
    expect(hasil?.templateId, 'ph_meter');
    expect(pembaca.dibaca, 3, reason: '0, 90, lalu 180: sisanya tidak dibaca');
    // Putaran 0 memakai foto apa adanya (tanpa salinan puluhan MB).
    expect(p.sudut, [90, 180]);
  });

  test(
    'kode terbaca tapi tak dikenal server TETAP menghentikan pencarian',
    () async {
      final pembaca = _Pembaca(['SIDIK-FM-CAL-0599']);

      final hasil = await kenaliJenisLembar(
        foto: foto,
        halaman: pembaca,
        dikenal: _dikenal,
        putar: _pemutar().putar,
      );

      expect(hasil?.kodeFormulir, 'SIDIK-FM-CAL-0599');
      expect(hasil?.kandidat, isEmpty);
      expect(hasil?.templateId, isNull);
      expect(pembaca.dibaca, 1);
    },
  );

  test(
    'judul tercetak hanya jadi petunjuk bila tak ada putaran dengan '
    'kode; kode di putaran lebih akhir menang atas judul di putaran awal',
    () async {
      // Judul di putaran 0, kode baru terbaca di putaran 90.
      final denganKode = _Pembaca([judulPh, kodePh]);
      final a = await kenaliJenisLembar(
        foto: foto,
        halaman: denganKode,
        dikenal: _dikenal,
        putar: _pemutar().putar,
      );
      expect(a?.sumber, SumberJenisLembar.kodeFormulir);
      expect(denganKode.dibaca, 2);

      // Judul saja, di semua putaran tak ada kode: petunjuk judul, keempat
      // putaran dicoba, dan tidak ada pilihan-awal (bukan kode).
      final hanyaJudul = _Pembaca([judulPh]);
      final b = await kenaliJenisLembar(
        foto: foto,
        halaman: hanyaJudul,
        dikenal: _dikenal,
        putar: _pemutar().putar,
      );
      expect(b?.sumber, SumberJenisLembar.judul);
      expect(b?.satuKandidat, isFalse);
      expect(hanyaJudul.dibaca, 4);
    },
  );

  test('tidak ada petunjuk sama sekali = null (pemanggil menampilkan daftar '
      'manual)', () async {
    final pembaca = _Pembaca(const []);
    final p = _pemutar();

    final hasil = await kenaliJenisLembar(
      foto: foto,
      halaman: pembaca,
      dikenal: _dikenal,
      putar: p.putar,
    );

    expect(hasil, isNull);
    expect(pembaca.dibaca, 4);
    expect(p.sudut, [90, 180, 270]);
  });

  test('orientasi EXIF yang diberikan ke ML Kit = EXIF asal diputar sudutnya, '
      'dan JPEG asli ikut diteruskan', () async {
    final tegak = _Pembaca(const []);
    await kenaliJenisLembar(
      foto: foto,
      halaman: tegak,
      dikenal: _dikenal,
      jpegAsli: Uint8List.fromList([0xff, 0xd8]),
      putar: _pemutar().putar,
    );
    expect(tegak.orientasi, [1, 6, 3, 8]);

    // Tanpa JPEG asli: pembaca membaca piksel citra, tak ada orientasi.
    final tanpaJpeg = _Pembaca(const []);
    await kenaliJenisLembar(
      foto: foto,
      halaman: tanpaJpeg,
      dikenal: _dikenal,
      putar: _pemutar().putar,
    );
    expect(tanpaJpeg.orientasi, [null, null, null, null]);

    // Kamera HP tegak menulis EXIF 6: putaran 0 pun harus memanggang EXIF-nya,
    // jadi tidak boleh memakai foto mentah.
    final miring = img.Image(width: 40, height: 30)
      ..exif.imageIfd.orientation = 6;
    final p = _pemutar();
    final exif6 = _Pembaca(const []);
    await kenaliJenisLembar(
      foto: miring,
      halaman: exif6,
      dikenal: _dikenal,
      jpegAsli: Uint8List.fromList([0xff, 0xd8]),
      putar: p.putar,
    );
    expect(p.sudut, [0, 90, 180, 270]);
    expect(exif6.orientasi, [6, 3, 8, 1]);
  });

  test('pemutar bawaan (isolate) menukar lebar-tinggi dan tidak mengubah foto '
      'asli', () async {
    final asal = img.Image(width: 40, height: 30);
    final putar = await putarFotoDiIsolate(asal, 90);

    expect((putar.width, putar.height), (30, 40));
    expect((asal.width, asal.height), (40, 30));
  });
}
