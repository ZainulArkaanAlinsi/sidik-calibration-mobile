import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Perbandingan golden Studio yang tahan derau antar-mesin — pola yang sama
/// dengan `test/flutter_test_config.dart` app lapangan, dengan satu beda:
/// **platform acuan Studio = Windows**.
///
/// Golden di `test/goldens/` dirasterisasi di Windows (DirectWrite), platform
/// utama Studio dan tempat golden ini dibuat. Rasterisasi font macOS/Linux
/// beda 2,5–4,3% (terukur di app lapangan), jadi di luar Windows yang masih
/// dijaga cuma kerusakan parah — sama seperti keputusan app lapangan untuk
/// platform non-acuannya.
const double _ambangAcuan = 0.001;
const double _ambangLuarPlatform = 0.15;

final bool _diPlatformAcuan = Platform.isWindows;

class _PembandingToleransi extends LocalFileComparator {
  _PembandingToleransi(super.testFile, {required this.ambang});

  final double ambang;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final hasil = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (hasil.passed) {
      hasil.dispose();
      return true;
    }

    if (hasil.diffPercent <= ambang) {
      final persen = (hasil.diffPercent * 100).toStringAsFixed(4);
      // Selalu dilaporkan, tidak pernah diam-diam.
      debugPrint(
        _diPlatformAcuan
            ? 'golden "$golden" beda $persen% — di bawah ambang, dianggap '
                  'derau antar-mesin. Bila perubahan tampilan disengaja, '
                  'jalankan --update-goldens.'
            : 'golden "$golden" beda $persen% — golden Studio dibuat di '
                  'Windows; di sini cuma kerusakan parah (>'
                  '${(_ambangLuarPlatform * 100).toStringAsFixed(0)}%) yang '
                  'dijaga. Regresi tata letak halus dicek di Windows. JANGAN '
                  '--update-goldens di sini.',
      );
      hasil.dispose();
      return true;
    }

    throw FlutterError(await generateFailureOutput(hasil, golden, basedir));
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final bawaan = goldenFileComparator;
  if (bawaan is LocalFileComparator) {
    goldenFileComparator = _PembandingToleransi(
      bawaan.basedir.resolve('flutter_test_config.dart'),
      ambang: _diPlatformAcuan ? _ambangAcuan : _ambangLuarPlatform,
    );
  }

  await testMain();
}
