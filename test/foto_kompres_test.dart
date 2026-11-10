import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/services/foto_kompres.dart';

/// Foto derau deterministik: JPEG-nya sulit dikompres, jadi target 500 KB
/// benar-benar harus dikejar penurunan kualitas (bukan lolos begitu saja).
Uint8List fotoDerau(int w, int h, {int seed = 7, int kualitas = 95}) {
  final acak = math.Random(seed);
  final gambar = img.Image(width: w, height: h);
  for (final p in gambar) {
    // Gradasi halus + derau kuat.
    final dasar = (p.x * 255 ~/ w + p.y * 255 ~/ h) ~/ 2;
    p
      ..r = (dasar + acak.nextInt(90)).clamp(0, 255)
      ..g = (dasar + acak.nextInt(90)).clamp(0, 255)
      ..b = (dasar + acak.nextInt(90)).clamp(0, 255);
  }

  return Uint8List.fromList(img.encodeJpg(gambar, quality: kualitas));
}

/// Mesin palsu: ukuran keluaran = fungsi kualitas, supaya penggelung
/// [FotoKompres] bisa diuji tanpa platform channel.
class _MesinPalsu implements PemampatGambar {
  _MesinPalsu(this.nama, {this.ukuran, this.gagal = false});

  @override
  final String nama;
  final int Function(int kualitas, int lebar)? ukuran;
  final bool gagal;
  final panggilan = <({FormatFoto format, int kualitas, int lebar})>[];

  @override
  bool dukung(FormatFoto format) => true;

  @override
  Future<Uint8List> kodekan(
    CitraSiap citra,
    FormatFoto format,
    int kualitas,
  ) async {
    panggilan.add((format: format, kualitas: kualitas, lebar: citra.lebar));
    if (gagal) throw StateError('mesin $nama rusak');

    return Uint8List(
      (ukuran ?? (q, _) => q * 10 * 1024)(kualitas, citra.lebar),
    );
  }
}

void main() {
  late Uint8List foto; // 2200x1100 derau: jauh di atas 500 KB dan di atas 1920
  late Uint8List fotoFake; // ukuran piksel sama, isi polos (cepat didekode)
  setUpAll(() {
    foto = fotoDerau(2200, 1100);
    fotoFake = Uint8List.fromList(
      img.encodeJpg(
        img.Image(width: 2200, height: 1100)..clear(img.ColorRgb8(90, 90, 90)),
      ),
    );
  });

  group('OpsiKompres.ukuranAkhir', () {
    const opsi = OpsiKompres();

    test('landscape besar dimuat ke 1920x1080, rasio terjaga', () {
      final u = opsi.ukuranAkhir(4000, 3000);
      expect(u.lebar, lessThanOrEqualTo(1920));
      expect(u.tinggi, lessThanOrEqualTo(1080));
      // 4:3 ditentukan sisi pendek 1080 -> 1440x1080.
      expect((u.lebar, u.tinggi), (1440, 1080));
    });

    test('potret dimuat ke 1080x1920 (orientasi tidak dipaksa)', () {
      final u = opsi.ukuranAkhir(3000, 4000);
      expect((u.lebar, u.tinggi), (1080, 1440));
      final p = opsi.ukuranAkhir(1654, 2339);
      expect(p.lebar, lessThanOrEqualTo(1080));
      expect(p.tinggi, lessThanOrEqualTo(1920));
    });

    test('tidak pernah memperbesar', () {
      final u = opsi.ukuranAkhir(800, 600);
      expect((u.lebar, u.tinggi), (800, 600));
    });

    test('tanpa batas piksel -> ukuran dipertahankan', () {
      const tanpa = OpsiKompres(sisiPanjangMaks: null, sisiPendekMaks: null);
      final u = tanpa.ukuranAkhir(4000, 3000);
      expect((u.lebar, u.tinggi), (4000, 3000));
    });
  });

  group('mesin Dart murni (nyata)', () {
    final kompres = FotoKompres(mesin: const [PemampatDartMurni()]);

    test('foto derau besar -> <= 500 KB, <= 1920x1080, JPEG', () async {
      expect(foto.length, greaterThan(500 * 1024));

      final h = await kompres.kompres(foto);
      final dekode = img.decodeJpg(h.byte)!;

      expect(h.byte.length, lessThanOrEqualTo(500 * 1024));
      expect(h.metrik.capaiTarget, isTrue);
      expect(dekode.width, lessThanOrEqualTo(1920));
      expect(dekode.height, lessThanOrEqualTo(1080));
      // Rasio terjaga (toleransi pembulatan satu piksel).
      expect(dekode.width / dekode.height, closeTo(2200 / 1100, 0.01));
      expect(h.mime, 'image/jpeg');
      expect(h.ekstensi, 'jpg');
      expect(h.metrik.mesin, 'dart-murni');
      expect(h.metrik.asliByte, foto.length);
      expect(h.metrik.akhirByte, h.byte.length);
      expect(h.metrik.dilewati, isFalse);
      expect(h.metrik.rasioHemat, greaterThan(0.3));
      expect(h.metrik.toJson()['asli_byte'], foto.length);
    });

    test('foto potret tetap potret & muat 1080x1920', () async {
      final potret = fotoDerau(1100, 2200, seed: 3);
      final h = await kompres.kompres(potret);
      final dekode = img.decodeJpg(h.byte)!;

      expect(dekode.height, greaterThan(dekode.width));
      expect(dekode.width, lessThanOrEqualTo(1080));
      expect(dekode.height, lessThanOrEqualTo(1920));
      expect(h.byte.length, lessThanOrEqualTo(500 * 1024));
    });

    test('foto yang sudah memenuhi batas dikembalikan APA ADANYA', () async {
      final kecil = fotoDerau(320, 240, kualitas: 60);
      expect(kecil.length, lessThan(500 * 1024));

      final h = await kompres.kompres(kecil);

      expect(identical(h.byte, kecil) || h.byte.length == kecil.length, isTrue);
      expect(h.byte, kecil);
      expect(h.metrik.dilewati, isTrue);
      expect(h.metrik.format, isNull);
      expect(h.mime, 'image/jpeg');
    });

    test('berkas bukan gambar -> galat, bukan "berhasil" palsu', () async {
      await expectLater(
        kompres.kompres(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(anything),
      );
    });

    test(
      'tanpa batas piksel: ukuran dipertahankan, hanya mutu turun',
      () async {
        final sedang = fotoDerau(1000, 700, seed: 5);
        final h = await kompres.kompres(
          sedang,
          opsi: const OpsiKompres(sisiPanjangMaks: null, sisiPendekMaks: null),
        );

        expect(h.metrik.lebarAkhir, h.metrik.lebarAsli);
        expect(h.metrik.tinggiAkhir, h.metrik.tinggiAsli);
      },
    );
  });

  group('penggelung kualitas (mesin palsu)', () {
    test('menurunkan kualitas 10 per langkah sampai muat target', () async {
      // q * 10 KB: 85->850, 75->750, 65->650, 55->550, 45->450 (muat).
      final mesin = _MesinPalsu('a');
      final h = await FotoKompres(mesin: [mesin]).kompres(fotoFake);

      expect(
        [for (final p in mesin.panggilan) p.kualitas],
        [85, 75, 65, 55, 45],
      );
      expect(h.metrik.kualitas, 45);
      expect(h.metrik.iterasi, 5);
      expect(h.byte.length, 450 * 1024);
      expect(h.metrik.capaiTarget, isTrue);
    });

    test('target ikut opsi (bukan angka 500 KB yang dipatok)', () async {
      final mesin = _MesinPalsu('a');
      final h = await FotoKompres(
        mesin: [mesin],
      ).kompres(foto, opsi: const OpsiKompres(targetByte: 300 * 1024));

      // q * 10 KB <= 300 KB hanya di q = 30 (lantai).
      expect(h.metrik.kualitas, 30);
      expect(h.byte.length, 300 * 1024);
    });

    test(
      'mentok di lantai: piksel disusutkan, TIDAK loop tanpa akhir',
      () async {
        final mesin = _MesinPalsu('a', ukuran: (_, _) => 900 * 1024);
        final h = await FotoKompres(mesin: [mesin]).kompres(fotoFake);

        // 7 tingkat kualitas (85..30) x (1 + 3 penyusutan).
        expect(mesin.panggilan.length, 7 * 4);
        expect(h.metrik.capaiTarget, isFalse);
        // Susut 15% tiga kali dari 1920x960.
        final lebar = mesin.panggilan.map((p) => p.lebar).toSet().toList()
          ..sort();
        expect(lebar.length, 4);
        expect(lebar.first, lessThan(lebar.last));
      },
    );

    test('penyusutan menolong: muat sesudah piksel mengecil', () async {
      // Besar selama lebar > 1300, kecil sesudahnya (1920 -> 1632 -> 1387
      // -> 1179 lewat tiga penyusutan 15%).
      final mesin = _MesinPalsu(
        'a',
        ukuran: (_, lebar) => lebar > 1300 ? 900 * 1024 : 100 * 1024,
      );
      final h = await FotoKompres(mesin: [mesin]).kompres(fotoFake);

      expect(h.metrik.capaiTarget, isTrue);
      expect(h.metrik.lebarAkhir, lessThan(1300));
      expect(h.metrik.lebarAkhir, lessThan(h.metrik.lebarAsli));
    });

    test(
      'maksPenyusutan 0: gagal jujur, ukuran piksel tidak disentuh',
      () async {
        final mesin = _MesinPalsu('a', ukuran: (_, _) => 900 * 1024);
        final h = await FotoKompres(
          mesin: [mesin],
        ).kompres(foto, opsi: const OpsiKompres(maksPenyusutan: 0));

        expect(h.metrik.capaiTarget, isFalse);
        expect(mesin.panggilan.map((p) => p.lebar).toSet().length, 1);
      },
    );
  });

  group('pemilihan mesin & format', () {
    test('WebP didahulukan bila ada mesin yang mampu', () async {
      final mesin = _MesinPalsu('native');
      final h = await FotoKompres(
        mesin: [mesin, const PemampatDartMurni()],
      ).kompres(fotoFake);

      expect(mesin.panggilan.first.format, FormatFoto.webp);
      expect(h.mime, 'image/webp');
      expect(h.ekstensi, 'webp');
      expect(h.metrik.format, FormatFoto.webp);
    });

    test('platform tanpa WebP (Windows): JPEG dari mesin Dart murni', () async {
      final h = await FotoKompres(
        mesin: const [PemampatDartMurni()],
      ).kompres(foto);

      expect(h.metrik.format, FormatFoto.jpeg);
      expect(img.decodeJpg(h.byte), isNotNull);
    });

    test('utamakanWebp=false -> JPEG walau mesin mampu WebP', () async {
      final mesin = _MesinPalsu('native');
      final h = await FotoKompres(
        mesin: [mesin],
      ).kompres(foto, opsi: const OpsiKompres(utamakanWebp: false));

      expect(h.metrik.format, FormatFoto.jpeg);
      expect(mesin.panggilan.every((p) => p.format == FormatFoto.jpeg), isTrue);
    });

    test('mesin utama gagal -> mesin cadangan mengambil alih', () async {
      final rusak = _MesinPalsu('native', gagal: true);
      final h = await FotoKompres(
        mesin: [rusak, const PemampatDartMurni()],
      ).kompres(foto);

      expect(rusak.panggilan, isNotEmpty); // sempat dicoba
      expect(h.metrik.mesin, 'dart-murni');
      expect(h.byte.length, lessThanOrEqualTo(500 * 1024));
    });

    test('WebP gagal di mesin yang sama -> JPEG di mesin itu', () async {
      var webp = 0;
      final mesin = _WebpRusak(() => webp++);
      final h = await FotoKompres(mesin: [mesin]).kompres(fotoFake);

      expect(webp, 1);
      expect(h.metrik.format, FormatFoto.jpeg);
    });

    test('semua mesin gagal -> StateError menyebut mesinnya', () async {
      await expectLater(
        FotoKompres(
          mesin: [_MesinPalsu('a', gagal: true), _MesinPalsu('b', gagal: true)],
        ).kompres(fotoFake),
        throwsA(
          isA<StateError>().having((e) => e.message, 'pesan', contains('a, b')),
        ),
      );
    });

    test('namaMesin menjaga urutan prioritas', () {
      expect(
        FotoKompres(
          mesin: [_MesinPalsu('x'), const PemampatDartMurni()],
        ).namaMesin,
        ['x', 'dart-murni'],
      );
    });
  });
}

class _WebpRusak implements PemampatGambar {
  _WebpRusak(this.padaWebp);

  final void Function() padaWebp;

  @override
  String get nama => 'webp-rusak';

  @override
  bool dukung(FormatFoto format) => true;

  @override
  Future<Uint8List> kodekan(
    CitraSiap citra,
    FormatFoto format,
    int kualitas,
  ) async {
    if (format == FormatFoto.webp) {
      padaWebp();
      throw UnsupportedError('webp tidak ada');
    }

    return Uint8List(100 * 1024);
  }
}
