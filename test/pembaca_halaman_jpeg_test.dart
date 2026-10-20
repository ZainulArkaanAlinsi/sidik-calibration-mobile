import 'dart:io';
import 'dart:math' show Point;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import 'package:sidik_calibration/services/pembaca_halaman.dart';

/// M01: ML Kit sehalaman membaca JPEG kamera APA ADANYA — tanpa encode ulang
/// PNG, tanpa menurunkan resolusi — dan bingkai kotaknya tetap bingkai citra
/// yang dipegang Dart. ML Kit sendiri ditiru (tidak bisa jalan di test host);
/// yang diuji: berkas apa yang diserahkan kepadanya.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('halaman-jpeg'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Citra asimetris kecil: tiap piksel unik, jadi putar/cermin yang salah
  /// pasti ketahuan.
  img.Image citraUji({int w = 6, int h = 4}) {
    final c = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        c.setPixelRgb(x, y, x * 40, y * 60, (x + y) * 10);
      }
    }
    return c;
  }

  Uint8List jpegDenganOrientasi(img.Image c, int? orientasi) {
    final salin = img.Image.from(c);
    if (orientasi != null) salin.exif.imageIfd.orientation = orientasi;
    return img.encodeJpg(salin, quality: 95);
  }

  RecognizedText teksDi(Rect kotak) => RecognizedText(
    text: '4,00',
    blocks: [
      TextBlock(
        text: '4,00',
        boundingBox: kotak,
        recognizedLanguages: const [],
        cornerPoints: const <Point<int>>[],
        lines: [
          TextLine(
            text: '4,00',
            boundingBox: kotak,
            recognizedLanguages: const [],
            cornerPoints: const <Point<int>>[],
            confidence: null,
            angle: null,
            elements: [
              TextElement(
                text: '4,00',
                boundingBox: kotak,
                recognizedLanguages: const [],
                cornerPoints: const <Point<int>>[],
                symbols: const [],
                confidence: null,
                angle: null,
              ),
            ],
          ),
        ],
      ),
    ],
  );

  /// Pembaca dengan ML Kit tiruan yang mencatat berkas yang diserahkan.
  ({
    MlKitPembacaHalaman pembaca,
    List<({String ekstensi, Uint8List bita})> diserahkan,
  })
  buat({
    bool jpegLangsung = true,
    List<Rect> kotakPerPanggilan = const [Rect.fromLTWH(1, 1, 2, 2)],
  }) {
    final diserahkan = <({String ekstensi, Uint8List bita})>[];
    final pembaca = MlKitPembacaHalaman(
      jpegLangsung: jpegLangsung,
      folderSementara: () async => tmp,
      proses: (input) async {
        final path = input.filePath!;
        diserahkan.add((
          ekstensi: path.split('.').last,
          bita: File(path).readAsBytesSync(),
        ));
        final i = diserahkan.length - 1;
        return teksDi(
          kotakPerPanggilan[i < kotakPerPanggilan.length
              ? i
              : kotakPerPanggilan.length - 1],
        );
      },
    );
    return (pembaca: pembaca, diserahkan: diserahkan);
  }

  group('jalur JPEG asli (tanpa encode PNG)', () {
    test('orientasi sudah cocok → bita JPEG diserahkan identik', () async {
      final c = citraUji();
      final jpeg = jpegDenganOrientasi(c, null);
      final (:pembaca, :diserahkan) = buat();

      final hasil = await pembaca.baca(
        img.decodeJpg(jpeg)!,
        asli: (jpeg: jpeg, orientasi: 1),
      );

      expect(diserahkan, hasLength(1), reason: 'satu kali baca, tanpa PNG');
      expect(diserahkan.single.ekstensi, 'jpg');
      expect(diserahkan.single.bita, jpeg);
      expect(hasil.single.teks, '4,00');
      // Berkas sementara dibersihkan.
      expect(tmp.listSync(), isEmpty);
    });

    test(
      'orientasi beda → hanya EXIF yang ditulis ulang, data gambar identik',
      () async {
        final c = citraUji();
        final jpeg = jpegDenganOrientasi(c, 6);
        final (:pembaca, :diserahkan) = buat();

        // Citra Dart = decode mentah, EXIF tidak dipanggang → orientasi 1.
        await pembaca.baca(
          img.decodeJpg(jpeg)!,
          asli: (jpeg: jpeg, orientasi: 1),
        );

        expect(diserahkan, hasLength(1));
        final b = diserahkan.single.bita;
        expect(diserahkan.single.ekstensi, 'jpg');
        expect(img.decodeJpgExif(b)!.imageIfd.orientation, 1);
        // Mulai dari SOS (FFDA) sampai akhir = data terkompresi: sama persis.
        expect(_sejakSos(b), _sejakSos(jpeg));
      },
    );

    test(
      'kotak di luar bingkai citra → tidak dipakai, baca ulang lewat PNG',
      () async {
        final c = citraUji(w: 60, h: 40);
        final jpeg = jpegDenganOrientasi(c, null);
        final (:pembaca, :diserahkan) = buat(
          kotakPerPanggilan: const [
            Rect.fromLTWH(50, 45, 8, 8), // y 45..53 > tinggi 40 + toleransi
            Rect.fromLTWH(10, 10, 8, 8),
          ],
        );

        final hasil = await pembaca.baca(
          img.decodeJpg(jpeg)!,
          asli: (jpeg: jpeg, orientasi: 1),
        );

        expect(diserahkan.map((d) => d.ekstensi), ['jpg', 'png']);
        expect(hasil.single.kotak, const Rect.fromLTWH(10, 10, 8, 8));
      },
    );

    test(
      'tanpa JPEG asli / bukan JPEG / platform belum diperiksa → PNG',
      () async {
        final c = citraUji();
        final png = img.encodePng(c);

        for (final (asli, langsung) in <(FotoAsli?, bool)>[
          (null, true),
          ((jpeg: png, orientasi: 1), true),
          ((jpeg: jpegDenganOrientasi(c, null), orientasi: 1), false),
        ]) {
          final (:pembaca, :diserahkan) = buat(jpegLangsung: langsung);
          await pembaca.baca(c, asli: asli);
          expect(diserahkan.single.ekstensi, 'png');
          // PNG lossless: isinya citra Dart persis.
          final balik = img.decodePng(diserahkan.single.bita)!;
          expect(balik.getPixel(5, 3), c.getPixel(5, 3));
        }
      },
    );
  });

  test('jpegUntukMlKit: bukan JPEG → null', () {
    expect(
      jpegUntukMlKit((jpeg: Uint8List.fromList([1, 2, 3, 4]), orientasi: 1)),
      isNull,
    );
  });

  test('orientasiSetelahPutar sama dengan bakeOrientation lalu copyRotate '
      '(8 orientasi × 4 putaran)', () {
    final mentah = citraUji();

    for (var asal = 1; asal <= 8; asal++) {
      for (final putar in const [0, 90, 180, 270]) {
        final berExif = img.Image.from(mentah)
          ..exif.imageIfd.orientation = asal;
        final diharapkan = img.copyRotate(
          img.bakeOrientation(berExif),
          angle: putar,
        );

        final gabungan = img.Image.from(mentah)
          ..exif.imageIfd.orientation = orientasiSetelahPutar(asal, putar);
        final hasil = img.bakeOrientation(gabungan);

        expect(
          (hasil.width, hasil.height),
          (diharapkan.width, diharapkan.height),
          reason: 'asal $asal putar $putar',
        );
        for (var y = 0; y < hasil.height; y++) {
          for (var x = 0; x < hasil.width; x++) {
            expect(
              hasil.getPixel(x, y),
              diharapkan.getPixel(x, y),
              reason: 'asal $asal putar $putar ($x,$y)',
            );
          }
        }
      }
    }
  });

  test('dalamBingkai: toleransi 1% sisi terpanjang (min 4 px)', () {
    TeksTerbaca t(Rect r) => (teks: 'x', kotak: r, keyakinan: null);

    expect(
      dalamBingkai([t(const Rect.fromLTRB(0, 0, 1000, 800))], 1000, 800),
      isTrue,
    );
    expect(
      dalamBingkai([t(const Rect.fromLTRB(-9, 0, 1009, 809))], 1000, 800),
      isTrue,
    );
    expect(
      dalamBingkai([t(const Rect.fromLTRB(0, 0, 900, 820))], 1000, 800),
      isFalse,
    );
    expect(
      dalamBingkai([t(const Rect.fromLTRB(0, 0, 13, 13))], 10, 10),
      isTrue,
    );
    expect(
      dalamBingkai([t(const Rect.fromLTRB(0, 0, 15, 10))], 10, 10),
      isFalse,
    );
  });

  test('sapuBerkasPindaiLama: hanya tabel-*/sel-* yang sudah tua', () async {
    final sekarang = DateTime(2026, 10, 20, 12);
    final tua = sekarang.subtract(const Duration(minutes: 30));
    File berkas(String nama, DateTime waktu) => File('${tmp.path}/$nama')
      ..writeAsBytesSync([1])
      ..setLastModifiedSync(waktu);

    berkas('tabel-1-0.jpg', tua);
    berkas('sel-2-1.png', tua);
    berkas('sel-3-2.png', sekarang); // mungkin sedang dibaca
    berkas('lain.jpg', tua); // bukan milik pindai

    final n = await sapuBerkasPindaiLama(tmp, sekarang: sekarang);

    expect(n, 2);
    expect(tmp.listSync().map((f) => f.uri.pathSegments.last).toSet(), {
      'sel-3-2.png',
      'lain.jpg',
    });
  });
}

/// Bita sejak penanda Start Of Scan (FF DA) sampai akhir berkas.
List<int> _sejakSos(Uint8List b) {
  for (var i = 2; i < b.length - 1; i++) {
    if (b[i] == 0xff && b[i + 1] == 0xda) return b.sublist(i);
  }
  fail('SOS tidak ditemukan');
}
