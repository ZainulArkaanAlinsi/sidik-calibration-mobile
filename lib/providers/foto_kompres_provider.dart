import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/foto_kompres.dart';
import '../services/pemampat_native.dart';

/// Mesin native (`flutter_image_compress`) hanya ada di Android; platform lain
/// (Windows, test) memakai mesin Dart murni saja. Provider supaya test bisa
/// memaksa kedua susunan.
final kompresNativeTersediaProvider = Provider<bool>((ref) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return false;

  return Platform.isAndroid;
});

/// Layanan kompresi foto — tidak bergantung pada OCR atau layar mana pun,
/// jadi modul lain (mis. Studio) cukup membaca provider ini.
final fotoKompresProvider = Provider<FotoKompres>(
  (ref) => FotoKompres(
    mesin: [
      if (ref.watch(kompresNativeTersediaProvider))
        const PemampatFlutterImageCompress(),
      const PemampatDartMurni(),
    ],
  ),
);
