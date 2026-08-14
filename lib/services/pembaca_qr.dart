import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Baca QR versi lembar dari fotonya sendiri — **ML Kit on-device**.
///
/// ## Kenapa ini nggak boleh dilewat
///
/// Server nolak seluruh pindai kalau `qr.terbaca` bukan `true`, dan itu
/// penjagaan yang bener: QR-nya satu-satunya cara sistem tau lembar mana &
/// revisi ke berapa yang lagi difoto. Formulir Rev.4 dan Rev.5 mirip di mata
/// orang; bedanya cuma kelihatan di koordinat sel, dan waktu koordinatnya
/// meleset nggak ada error yang muncul — angkanya cuma mendarat di baris
/// sebelah.
///
/// Jadi isinya WAJIB datang dari citra. Nyalin `qrIsi` dari respons template
/// ke `qr.isi` bikin penjagaan versi lembar mati total sambil kelihatan hidup:
/// nilainya selalu cocok, karena dua-duanya dari sumber yang sama.
abstract class PembacaQr {
  /// Isi QR yang kebaca, atau `null` kalau nggak ada yang kebaca.
  Future<String?> baca(img.Image citra);

  Future<void> tutup();
}

class MlKitPembacaQr implements PembacaQr {
  MlKitPembacaQr();

  final _pemindai = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  @override
  Future<String?> baca(img.Image citra) async {
    // ML Kit minta berkas atau byte ber-metadata. Ditulis ke folder sementara
    // app — BUKAN galeri atau folder bersama: isinya lembar kerja pelanggan.
    final dir = await getTemporaryDirectory();
    final berkas = File(
      '${dir.path}/qr-${DateTime.now().microsecondsSinceEpoch}.png',
    );

    try {
      await berkas.writeAsBytes(img.encodePng(citra));

      final hasil = await _pemindai.processImage(InputImage.fromFile(berkas));

      for (final b in hasil) {
        final isi = b.rawValue?.trim();
        if (isi != null && isi.isNotEmpty) return isi;
      }

      return null;
    } finally {
      if (berkas.existsSync()) berkas.deleteSync();
    }
  }

  @override
  Future<void> tutup() => _pemindai.close();
}

/// Tiruan buat test & mode mock.
class MockPembacaQr implements PembacaQr {
  MockPembacaQr({this.isi});

  /// `null` = QR-nya nggak kebaca di foto.
  final String? isi;

  @override
  Future<String?> baca(img.Image citra) async => isi;

  @override
  Future<void> tutup() async {}
}
