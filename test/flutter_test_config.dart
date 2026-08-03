import 'dart:async';
import 'dart:io';

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

/// Platform tempat golden di `test/screenshots/` dibikin.
///
/// Golden itu artefak per-platform, bukan data yang berlaku universal: macOS
/// (CoreText) dan Windows (DirectWrite) merasterisasi font dengan hinting &
/// anti-aliasing yang beda, jadi lembar yang identik tetap keluar piksel yang
/// beda. Golden di repo ini dibikin di macOS (commit terakhir 27 Juli).
final bool _diPlatformAcuan = Platform.isMacOS;

/// Ambang di LUAR platform acuan.
///
/// Kenapa nggak dipakai ambang yang sama: beda Windows↔macOS terukur
/// **2,5%–4,3%** — 200x di atas derau mesin-sejenis yang [_ambangToleransi]
/// dikalibrasi buat itu. Jadi di Windows keenam golden selalu merah, dan suite
/// yang selalu merah ngajarin orang ngabaikan kegagalan. Itu lebih bahaya
/// daripada nggak ada golden.
///
/// Dan naikin [_ambangToleransi] ke 4,3% buat semua platform juga salah:
/// perubahan tampilan asli terkecil yang pernah tercatat 7,35%, jadi jaraknya
/// tinggal kurang dari 2x. Regresi beneran bakal lolos — di macOS juga, tempat
/// perbandingannya masih bermakna.
///
/// Jadi arahnya dipisah: di platform acuan tetap 0,1% (ketat, nangkep regresi
/// layout). Di luar itu yang masih dijaga cuma "layarnya rusak parah" — blank,
/// salah layar, font gagal dimuat; semuanya keluar puluhan persen. Regresi
/// layout halus BUKAN tanggung jawab platform non-acuan, dan itu memang celah
/// yang disengaja, bukan kelalaian.
const double _ambangLuarPlatform = 0.15;

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
        _diPlatformAcuan
            ? 'golden "$golden" beda $persen% — di bawah ambang '
                  '${(ambang * 100).toStringAsFixed(2)}%, dianggap derau '
                  'antar-mesin. Kalau ini ternyata perubahan tampilan yang '
                  'disengaja, jalanin --update-goldens.'
            // Di luar platform acuan angkanya JANGAN didiemin: ini satu-satunya
            // tempat orang bisa lihat bedanya berapa, dan yang mutusin apakah
            // itu wajar cuma manusia yang tau dia habis ngubah apa.
            : 'golden "$golden" beda $persen% — golden di repo ini dibikin di '
                  'macOS, dan rasterisasi font di sini beda, jadi angka ini '
                  'nggak dipakai buat mutusin lolos/gagal. Yang masih dijaga '
                  'cuma kerusakan parah (>'
                  '${(_ambangLuarPlatform * 100).toStringAsFixed(0)}%). '
                  'Regresi layout halus mesti dicek di macOS. JANGAN jalanin '
                  '--update-goldens di sini — itu cuma mindahin merahnya ke '
                  'mesin sebelah.',
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
    ambang: _diPlatformAcuan ? _ambangToleransi : _ambangLuarPlatform,
  );

  await testMain();
}
