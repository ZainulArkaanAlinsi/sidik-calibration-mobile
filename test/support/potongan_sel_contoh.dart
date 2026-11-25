import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Potongan sel PALSU untuk tes OCR awan. Bukan foto pelanggan.

/// PNG yang bisa ditampilkan (kotak abu-abu bergaris), ukuran kecil.
Uint8List potonganNyata({int lebar = 120, int tinggi = 48}) {
  final citra = img.Image(width: lebar, height: tinggi)
    ..clear(img.ColorRgb8(244, 244, 244));
  img.drawLine(
    citra,
    x1: lebar ~/ 6,
    y1: tinggi ~/ 2,
    x2: lebar * 5 ~/ 6,
    y2: tinggi ~/ 2,
    color: img.ColorRgb8(60, 60, 60),
    thickness: 3,
  );

  return Uint8List.fromList(img.encodePng(citra));
}

/// PNG yang HANYA berisi tanda tangan berkas dan IHDR: cukup untuk pemeriksa
/// ukuran di klien (yang membaca header), murah dibuat dalam jumlah banyak, dan
/// tidak untuk ditampilkan. [tambahanByte] menggemukkan berkas tanpa mengubah
/// lebar dan tinggi.
Uint8List potonganHeader({
  int lebar = 120,
  int tinggi = 48,
  int tambahanByte = 0,
}) {
  final b = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(const [0, 0, 0, 13])
    ..add('IHDR'.codeUnits)
    ..add(_u32(lebar))
    ..add(_u32(tinggi))
    ..add(const [8, 2, 0, 0, 0, 0, 0, 0, 0])
    ..add(Uint8List(tambahanByte));

  return b.toBytes();
}

List<int> _u32(int n) => [
  (n >> 24) & 0xFF,
  (n >> 16) & 0xFF,
  (n >> 8) & 0xFF,
  n & 0xFF,
];
