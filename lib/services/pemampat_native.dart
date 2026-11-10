import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'foto_kompres.dart';

/// Mesin kompresi native Android (`flutter_image_compress`): WebP + JPEG.
///
/// Paket ini TIDAK punya implementasi Windows/Linux (pub.dev: android, ios,
/// macos, web), jadi cuma dipasang di daftar mesin Android — lihat
/// `fotoKompresProvider`. Di platform lain pemanggilan akan melempar
/// `MissingPluginException`, yang [FotoKompres] tangkap lalu berpindah ke
/// [PemampatDartMurni].
///
/// Ukuran piksel TIDAK diserahkan ke paket ini: `minWidth`/`minHeight`-nya
/// bermakna "jangan di bawah ini", bukan "muat di kotak ini", dan hasilnya
/// bergantung pada rotasi EXIF. [FotoKompres] sudah memberi citra berukuran
/// akhir (PNG, tanpa EXIF), jadi skala di sini selalu 1.
class PemampatFlutterImageCompress implements PemampatGambar {
  const PemampatFlutterImageCompress();

  @override
  String get nama => 'flutter_image_compress';

  @override
  bool dukung(FormatFoto format) => true;

  @override
  Future<Uint8List> kodekan(CitraSiap citra, FormatFoto format, int kualitas) =>
      FlutterImageCompress.compressWithList(
        citra.png,
        minWidth: citra.lebar,
        minHeight: citra.tinggi,
        quality: kualitas,
        format: switch (format) {
          FormatFoto.webp => CompressFormat.webp,
          FormatFoto.jpeg => CompressFormat.jpeg,
        },
        autoCorrectionAngle: false,
        keepExif: false,
      );
}
