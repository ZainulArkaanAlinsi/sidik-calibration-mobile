import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bikin perbandingan golden tahan beda antar-mesin.
///
/// Masalahnya: rendering teks beda tipis antar OS/versi Flutter. Bedanya cuma
/// belasan sampai puluhan piksel — mata nggak bisa lihat, tapi perbandingan
/// golden default menolak beda satu piksel pun. Efeknya golden merah bergantian
/// tiap ganti mesin, lalu di-regenerate bolak-balik tanpa ada yang benar-benar
/// berubah di tampilan.
///
/// Jadi beda di bawah [_ambangToleransi] dianggap lolos — tapi **selalu
/// dilaporkan**, nggak pernah diam-diam.
///
/// Ambangnya sengaja ketat. Sebagai acuan, golden di sini 360x760 = 273.600
/// piksel:
///
/// - derau antar-mesin yang pernah kelihatan: 17–33 piksel (0,006%–0,012%)
/// - perubahan tampilan asli yang paling kecil pernah tercatat: 20.097 piksel
///   (7,35%, waktu logo PT Sidik dipasang di Splash)
///
/// 0,1% = 274 piksel: 8x di atas derau, 73x di bawah perubahan asli terkecil.
/// Celah di antaranya lebar, jadi regresi beneran tetap ketangkep.
const double _ambangToleransi = 0.001;

class _ComparatorToleransi extends LocalFileComparator {
  _ComparatorToleransi(super.testFile, {required this.ambang});

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
      debugPrint(
        'golden "$golden" beda $persen% — di bawah ambang '
        '${(ambang * 100).toStringAsFixed(2)}%, dianggap derau antar-mesin. '
        'Kalau ini ternyata perubahan tampilan yang disengaja, '
        'jalanin --update-goldens.',
      );
      hasil.dispose();
      return true;
    }

    // Di atas ambang: perlakukan seperti biasa, lengkap dengan PNG
    // isolate/masked/diff di test/failures/ biar gampang dilihat bedanya.
    throw FlutterError(await generateFailureOutput(hasil, golden, basedir));
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Ambil basedir dari comparator bawaan — dia nunjuk ke folder file tes yang
  // lagi jalan, jadi path golden relatif ('screenshots/*.png') tetap ketemu.
  final bawaan = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _ComparatorToleransi(
    bawaan.basedir.resolve('flutter_test_config.dart'),
    ambang: _ambangToleransi,
  );

  await testMain();
}
