import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/services/kenali_jenis_lembar.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';

/// `padaTeksHalaman`: teks halaman (elemen + kotak) dari putaran yang
/// menghasilkan hasil pengenalan, SEKALI, tanpa pembacaan kedua. Itu bahan
/// identitas kertas; tidak dipanggil bila tidak ada petunjuk sama sekali.
class _Pembaca implements PembacaHalaman {
  _Pembaca(this.teksPerPutaran);

  final List<String> teksPerPutaran;
  var dibaca = 0;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async {
    final t = dibaca < teksPerPutaran.length ? teksPerPutaran[dibaca] : '';
    dibaca++;

    return t.isEmpty
        ? const []
        : [
            (
              teks: t,
              kotak: Rect.fromLTWH(dibaca * 10, 0, 100, 10),
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

Future<img.Image> _tanpaPutar(img.Image foto, int sudut) async => foto;

void main() {
  final foto = img.Image(width: 40, height: 30);
  const kodePh = 'Revise : 4 SIDIK-FM-CAL-0509';

  test('teks putaran yang MENGHASILKAN kode diserahkan, sekali', () async {
    final pembaca = _Pembaca(['', kodePh, 'tidak dibaca']);
    final diserahkan = <List<TeksTerbaca>>[];

    final hasil = await kenaliJenisLembar(
      foto: foto,
      halaman: pembaca,
      dikenal: _dikenal,
      putar: _tanpaPutar,
      padaTeksHalaman: diserahkan.add,
    );

    expect(hasil?.templateId, 'ph_meter');
    expect(diserahkan, hasLength(1));
    expect(diserahkan.single.single.teks, kodePh);
    expect(
      diserahkan.single.single.kotak.left,
      20,
      reason: 'putaran ke-2, bukan putaran lain',
    );
    expect(pembaca.dibaca, 2, reason: 'tidak ada pembacaan tambahan');
  });

  test('hanya bukti samar (judul) di satu putaran: teks putaran TERBAIK itu '
      'diserahkan di akhir pencarian', () async {
    const samar = 'Calibration Work Sheet - pH Meter LK-285-IDN';
    final pembaca = _Pembaca(['', samar, '', '']);
    final diserahkan = <List<TeksTerbaca>>[];

    final hasil = await kenaliJenisLembar(
      foto: foto,
      halaman: pembaca,
      dikenal: _dikenal,
      putar: _tanpaPutar,
      padaTeksHalaman: diserahkan.add,
    );

    expect(hasil, isNotNull, reason: 'judul saja tetap petunjuk');
    expect(pembaca.dibaca, 4, reason: 'semua putaran dicoba');
    expect(diserahkan, hasLength(1));
    expect(diserahkan.single.single.teks, samar);
  });

  test('tidak ada petunjuk sama sekali: tidak dipanggil', () async {
    final pembaca = _Pembaca(['', '', '', '']);
    var dipanggil = 0;

    final hasil = await kenaliJenisLembar(
      foto: foto,
      halaman: pembaca,
      dikenal: _dikenal,
      putar: _tanpaPutar,
      padaTeksHalaman: (_) => dipanggil++,
    );

    expect(hasil, isNull);
    expect(dipanggil, 0);
  });

  test('tanpa callback: perilaku lama persis', () async {
    final hasil = await kenaliJenisLembar(
      foto: foto,
      halaman: _Pembaca([kodePh]),
      dikenal: _dikenal,
      putar: _tanpaPutar,
    );

    expect(hasil?.templateId, 'ph_meter');
  });
}
