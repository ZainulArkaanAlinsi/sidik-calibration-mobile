import 'dart:ui' show Rect;

import 'package:sidik_calibration/services/pembaca_halaman.dart'
    show TeksTerbaca;

/// Halaman lembar kerja SINTETIS untuk tes identitas kertas: elemen teks (satu
/// kata) berikut kotaknya, seperti keluaran ML Kit sehalaman. Tidak ada foto
/// asli lab di repo. Letak label meniru formulir kosong SIDIK-FM-CAL-0509
/// (point halaman A4 lanskap 792 x 612, dikali [skalaFotoUji] seperti foto);
/// nilainya karangan.

const skalaFotoUji = 4.0;

/// Satu elemen teks (satu kata) di (x0, y0)-(x1, y1) point.
TeksTerbaca el(
  double x0,
  double y0,
  double x1,
  double y1,
  String teks, {
  double? yakin,
}) => (
  teks: teks,
  kotak: Rect.fromLTRB(
    x0 * skalaFotoUji,
    y0 * skalaFotoUji,
    x1 * skalaFotoUji,
    y1 * skalaFotoUji,
  ),
  keyakinan: yakin,
);

/// Baris berlabel pH 0509: label di x=27..118, nilai mulai x=125.
List<TeksTerbaca> halamanLabelPh({
  String? nama,
  String? model,
  String? seri,
  String? merk,
  String? pemilik,
  List<String> alamat = const [],
  String? terima,
  String? kalibrasi,
  bool cetakanTh = true,
}) {
  final hasil = <TeksTerbaca>[
    el(44, 96, 63, 108, 'PT.'),
    el(66, 96, 98, 108, 'SIDIK'),
    el(300, 96, 363, 108, 'Calibration'),
    el(261, 125, 291, 132, 'Received'),
    el(293, 125, 308, 132, 'Date'),
    el(312, 123, 315, 132, ':'),
    el(255, 137, 291, 144, 'Calibration'),
    el(293, 137, 308, 144, 'Date'),
    el(312, 135, 315, 144, ':'),
    el(69, 157, 121, 165, 'EQUIPMENT'),
    el(123, 157, 163, 165, 'IDENTITY'),
    el(165, 157, 184, 165, 'AND'),
    el(186, 157, 235, 165, 'CUSTOMER'),
    el(238, 157, 262, 165, 'DATA'),
    // 1. Name
    el(27, 184, 32, 191, '1.'),
    el(38, 184, 57, 191, 'Name'),
    el(115, 184, 118, 191, ':'),
    // 2. Range/Resolution + satuan cetak
    el(27, 197, 32, 204, '2.'),
    el(38, 197, 96, 204, 'Range/Resolution'),
    el(115, 197, 118, 204, ':'),
    el(185, 197, 194, 204, 'pH'),
    el(185, 208, 194, 215, 'pH'),
    // 3. Type/Model
    el(27, 219, 32, 226, '3.'),
    el(38, 219, 76, 226, 'Type/Model'),
    el(115, 218, 118, 225, ':'),
    // 4. Serial Number/LPI
    el(27, 230, 32, 237, '4.'),
    el(38, 230, 57, 237, 'Serial'),
    el(58, 230, 97, 237, 'Number/LPI'),
    el(115, 229, 118, 236, ':'),
    // 5. Merk/Manufacture
    el(27, 241, 32, 248, '5.'),
    el(38, 241, 97, 248, 'Merk/Manufacture'),
    el(115, 240, 118, 247, ':'),
    // OWNER
    el(27, 268, 60, 275, 'OWNER'),
    el(27, 281, 32, 288, '1.'),
    el(38, 281, 57, 288, 'Name'),
    el(115, 281, 118, 288, ':'),
    el(27, 292, 32, 299, '2.'),
    el(38, 292, 75, 299, 'Address'),
    el(115, 292, 118, 299, ':'),
  ];

  if (cetakanTh) {
    hasil.addAll([
      el(38, 255, 100, 262, 'Thermohygro'),
      el(150, 255, 175, 262, 'Insitu:'),
      el(180, 255, 195, 262, 'TH-6'),
      el(150, 268, 175, 275, 'Inlab:'),
      el(240, 281, 255, 288, 'TH-2'),
      el(260, 281, 275, 288, 'TH-7'),
      el(150, 303, 165, 310, 'TH-4'),
    ]);
  }

  // Tulisan tangan.
  void tulis(double y, String? teks, {double x = 125}) {
    if (teks == null) return;
    var kiri = x;
    for (final kata in teks.split(' ')) {
      final lebar = 6.0 * kata.length + 2;
      hasil.add(el(kiri, y, kiri + lebar, y + 8, kata));
      kiri += lebar + 4;
    }
  }

  tulis(183, nama);
  tulis(218, model);
  tulis(229, seri);
  tulis(240, merk);
  tulis(280, pemilik);
  for (var i = 0; i < alamat.length; i++) {
    tulis(291 + i * 11, alamat[i]);
  }
  tulis(123, terima, x: 330);
  tulis(135, kalibrasi, x: 330);

  return hasil;
}

/// Kaki formulir yang dibaca sebagai SATU baris: "Page 1 of 1 Revise : 4
/// SIDIK-FM-CAL-0509". Bahan pengenalan jenis lembar.
List<TeksTerbaca> kakiFormulirUji({
  String kode = 'SIDIK-FM-CAL-0509',
  String revisi = '4',
}) {
  var x = 40.0;
  final hasil = <TeksTerbaca>[];
  for (final kata in ['Page', '1', 'of', '1', 'Revise', ':', revisi, kode]) {
    final lebar = 6.0 * kata.length + 2;
    hasil.add(el(x, 585, x + lebar, 593, kata));
    x += lebar + 5;
  }

  return hasil;
}

/// Halaman pH 0509 lengkap: label, tulisan teknisi, dan kaki formulir.
List<TeksTerbaca> halamanPhUji({
  String? nama,
  String? model,
  String? seri,
  String? merk,
  String? pemilik,
  List<String> alamat = const [],
  String? terima,
  String? kalibrasi,
}) => [
  ...halamanLabelPh(
    nama: nama,
    model: model,
    seri: seri,
    merk: merk,
    pemilik: pemilik,
    alamat: alamat,
    terima: terima,
    kalibrasi: kalibrasi,
  ),
  ...kakiFormulirUji(),
];
