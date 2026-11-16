import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/services/kenali_jenis_lembar.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';

/// Putaran 0/90/180/270 memakai pengenal BERLAPIS. Murni logika: pembaca
/// halaman dan pemutar foto disuntik, tanpa ML Kit. Teks di bawah buatan tangan
/// yang meniru galat OCR pada teks cetak formulir (tanpa data pelanggan).
class _Pembaca implements PembacaHalaman {
  _Pembaca(this.teks);

  /// Satu blok teks per putaran; '' = halaman terbaca kosong.
  final List<String> teks;
  var dibaca = 0;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async {
    final t = dibaca < teks.length ? teks[dibaca] : '';
    dibaca++;

    return [
      for (final baris in t.split('\n').indexed)
        if (baris.$2.isNotEmpty)
          (
            teks: baris.$2,
            kotak: Rect.fromLTWH(0, baris.$1 * 40.0, 400, 20),
            keyakinan: null,
          ),
    ];
  }

  @override
  Future<void> tutup() async {}
}

const _dikenal = <FormulirDikenal>[
  (
    templateId: 'spectrophotometer',
    kodeDokumen: 'SIDIK-FM-CAL-0511_Rev.5',
    judul: 'Calibration Worksheet - UV/VIS Spectrophotometer',
  ),
  (
    templateId: 'ph_meter',
    kodeDokumen: 'SIDIK-FM-CAL-0509_Rev.4',
    judul: 'Calibration Worksheet - pH Meter',
  ),
  (
    templateId: 'oven',
    kodeDokumen: 'SIDIK-FM-CAL-0504_Rev.3',
    judul: 'Calibration Worksheet - Oven',
  ),
  (
    templateId: 'furnace',
    kodeDokumen: 'SIDIK-FM-CAL-0504_Rev.3',
    judul: 'Calibration Worksheet - Furnace',
  ),
];

Future<img.Image> _putarTiruan(img.Image foto, int sudut) async =>
    img.copyRotate(foto, angle: sudut);

Future<HasilJenisLembar?> _kenali(_Pembaca pembaca) => kenaliJenisLembar(
  foto: img.Image(width: 40, height: 30),
  halaman: pembaca,
  dikenal: _dikenal,
  putar: _putarTiruan,
);

void main() {
  const judulRusak =
      'PT. SIDIK Calibration Worksh\n'
      'et - UVIVIS Spectrophotometer LK-285-IDN';
  const kakiRusak = 'Page 1 of 1 Revise : 5 SIDIK.FM-CAL.OMI';

  test('kode kaki rusak + judul tergores di putaran ke-2: berlapis sepakat -> '
      'berhenti di sana dan memilih-awal', () async {
    final pembaca = _Pembaca(['', '$judulRusak\n$kakiRusak', 'tidak dibaca']);

    final hasil = await _kenali(pembaca);

    expect(hasil?.praPilihTemplateId, 'spectrophotometer');
    expect(hasil?.alasan, AlasanPetunjuk.praPilihBerlapis);
    expect(pembaca.dibaca, 2, reason: 'putaran 0 kosong, 90 sudah cukup');
  });

  test('bukti samar yang belum cukup TIDAK menghentikan pencarian: keempat '
      'putaran dicoba, hasilnya usulan tanpa pilih-awal', () async {
    // 0511 dengan tiga huruf kembar: terbaca, tetapi lemah.
    final pembaca = _Pembaca(['Page 1 of 1 Revise : 5 SIDIK-FM-CAL-OSII']);

    final hasil = await _kenali(pembaca);

    expect(hasil?.alasan, AlasanPetunjuk.lemah);
    expect(hasil?.praPilihTemplateId, isNull);
    expect(hasil?.kandidat.single.templateId, 'spectrophotometer');
    expect(pembaca.dibaca, 4);
  });

  test(
    'bukti kode yang lemah mengalahkan judul saja, dari putaran mana pun',
    () async {
      final pembaca = _Pembaca([
        'PT. SIDIK Calibration Worksheet - pH Meter LK-285-IDN',
        'Page 1 of 1 Revise : 5 SIDIK-FM-CAL-OSII',
      ]);

      final hasil = await _kenali(pembaca);

      expect(hasil?.alasan, AlasanPetunjuk.lemah);
      expect(hasil?.kandidat.single.templateId, 'spectrophotometer');
      expect(pembaca.dibaca, 4);
    },
  );

  test('kode bersih yang bertentangan dengan judul tetap menghentikan '
      'pencarian (kodenya sudah jelas), tanpa pilih-awal', () async {
    final pembaca = _Pembaca([
      'PT. SIDIK Calibration Worksheet - pH Meter LK-285-IDN\n'
          'Page 1 of 1 Revise : 5 SIDIK-FM-CAL-0511',
    ]);

    final hasil = await _kenali(pembaca);

    expect(hasil?.alasan, AlasanPetunjuk.bertentangan);
    expect(hasil?.praPilihTemplateId, isNull);
    expect(hasil?.kandidat.map((k) => k.templateId).toSet(), {
      'spectrophotometer',
      'ph_meter',
    });
    expect(pembaca.dibaca, 1);
  });

  test('umpan kode IK di putaran 0 tidak menghentikan pencarian dan tidak '
      'menjadi hasil', () async {
    final pembaca = _Pembaca([
      'Calibration Methode : SIDIK-IK-CAL-0509',
      'Page 1 of 1 Revise : 4 SIDIK-FM-CAL-0509',
    ]);

    final hasil = await _kenali(pembaca);

    expect(hasil?.praPilihTemplateId, 'ph_meter');
    expect(pembaca.dibaca, 2);
  });

  test('kode bersama (0504) berhenti dan menampilkan semua jenisnya tanpa '
      'pilih-awal', () async {
    final pembaca = _Pembaca(['Page 1 of 1 Revise : 3 SIDIK-FM-CAL-0504']);

    final hasil = await _kenali(pembaca);

    expect(hasil?.alasan, AlasanPetunjuk.kodeBersama);
    expect(hasil?.praPilihTemplateId, isNull);
    expect(hasil?.kandidat.length, 2);
    expect(pembaca.dibaca, 1);
  });

  test('tanpa bukti di keempat putaran = null (menu manual)', () async {
    final pembaca = _Pembaca(['Nama Alat : Merk : Type :']);

    expect(await _kenali(pembaca), isNull);
    expect(pembaca.dibaca, 4);
  });
}
