import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/foto_kompres.dart';
import 'package:sidik_calibration/services/foto_untuk_ocr.dart';
import 'package:sidik_calibration/services/jalankan_pindai.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_qr.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/pindai_lembar.dart';

/// KUNCI: OCR hanya menerima foto kamera asli atau hasil warp. Citra/byte
/// keluaran kompresi (salinan arsip) harus DITOLAK — uji sintetis 11 Nov 2026:
/// kompresi sebelum OCR menghilangkan kode formulir pada 5 dari 6 foto.
///
/// Test di berkas ini GAGAL bila ada yang melonggarkan penjaga (mis. menghapus
/// `pastikanBukanSalinanArsip` dari pintu OCR, atau meng-impor kompresi dari
/// berkas OCR).

class _PembacaHalamanPenghitung implements PembacaHalaman {
  int dipanggil = 0;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra, {FotoAsli? asli}) async {
    dipanggil++;

    return const [];
  }

  @override
  Future<void> tutup() async {}
}

Uint8List _fotoDerau(int w, int h, {int seed = 7}) {
  final acak = math.Random(seed);
  final gambar = img.Image(width: w, height: h);
  for (final p in gambar) {
    final dasar = (p.x * 255 ~/ w + p.y * 255 ~/ h) ~/ 2;
    p
      ..r = (dasar + acak.nextInt(90)).clamp(0, 255)
      ..g = (dasar + acak.nextInt(90)).clamp(0, 255)
      ..b = (dasar + acak.nextInt(90)).clamp(0, 255);
  }

  return Uint8List.fromList(img.encodeJpg(gambar, quality: 95));
}

void main() {
  late WorksheetTemplate template;
  late Uint8List fotoBesar; // jauh di atas 500 KB
  late SalinanArsip salinan;

  setUpAll(() async {
    template = WorksheetTemplate.fromJson(
      jsonDecode(
            File(
              'test/assets/template-asli-ph_meter-0509.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    fotoBesar = _fotoDerau(1500, 800);
    final hasil = await FotoKompres(
      mesin: const [PemampatDartMurni()],
    ).kompres(fotoBesar);
    salinan = hasil.salinan;
  });

  group('salinan arsip: tipe & tanda', () {
    test(
      'kompresi menghasilkan SalinanArsip <= 500 KB, bukan FotoUntukOcr',
      () {
        expect(fotoBesar.length, greaterThan(500 * 1024));
        expect(salinan.byte.length, lessThanOrEqualTo(500 * 1024));

        // Bukan subtipe FotoUntukOcr -> `bacaFoto(salinan)` tidak lolos
        // kompilasi; di sini dipastikan juga saat runtime.
        final Object apa = salinan;
        expect(apa is FotoUntukOcr, isFalse);
      },
    );

    test('FotoUntukOcr tertutup: hanya foto asli kamera atau hasil warp', () {
      final citra = img.Image(width: 4, height: 4);
      final FotoUntukOcr a = FotoAsliKamera(citra, jpegAsli: fotoBesar);
      final FotoUntukOcr b = FotoHasilWarp(citra);

      // Switch ekshaustif: menambah subtipe baru memaksa test ini diubah.
      String nama(FotoUntukOcr f) => switch (f) {
        FotoAsliKamera() => 'asli',
        FotoHasilWarp() => 'warp',
      };

      expect(nama(a), 'asli');
      expect(nama(b), 'warp');
      expect(a.jpegAsli, same(fotoBesar));
      expect(b.jpegAsli, isNull);
    });

    test('citra dari salinan ditandai; foto kamera asli TIDAK', () {
      final dariSalinan = salinan.dekode()!;

      expect(apakahDariSalinanArsip(dariSalinan), isTrue);
      expect(apakahDariSalinanArsip(salinan.byte), isTrue);
      expect(apakahDariSalinanArsip(fotoBesar), isFalse);
      expect(apakahDariSalinanArsip(img.decodeJpg(fotoBesar)), isFalse);
    });

    test(
      'foto kecil dilewati kompresi: byte kamera asli tidak ikut tertandai',
      () async {
        final kecil = Uint8List.fromList(
          img.encodeJpg(img.Image(width: 64, height: 64), quality: 90),
        );
        final h = await FotoKompres(
          mesin: const [PemampatDartMurni()],
        ).kompres(kecil);

        expect(h.metrik.dilewati, isTrue);
        expect(apakahDariSalinanArsip(kecil), isFalse); // aslinya bersih
        expect(apakahDariSalinanArsip(h.salinan.byte), isTrue); // salinan: ya
        expect(identical(h.salinan.byte, kecil), isFalse);
      },
    );
  });

  group('OCR MENOLAK gambar terkompresi', () {
    test('JalankanPindaiAsli.baca(citra dari salinan) -> ditolak, ML Kit '
        'tidak disentuh', () async {
      final halaman = _PembacaHalamanPenghitung();
      final pembaca = MockPembacaSel();

      await expectLater(
        JalankanPindaiAsli(
          halaman: halaman,
          pembaca: pembaca,
        ).baca(salinan.dekode()!, template: template),
        throwsA(isA<FotoTerkompresiDitolak>()),
      );

      expect(halaman.dipanggil, 0);
      expect(pembaca.jumlahDibaca, 0);
    });

    test('byte JPEG salinan sebagai jpegAsli -> ditolak', () async {
      final halaman = _PembacaHalamanPenghitung();

      await expectLater(
        JalankanPindaiAsli(halaman: halaman, pembaca: MockPembacaSel()).baca(
          img.decodeJpg(fotoBesar)!,
          template: template,
          jpegAsli: salinan.byte,
        ),
        throwsA(isA<FotoTerkompresiDitolak>()),
      );
      expect(halaman.dipanggil, 0);
    });

    test('citra turunan yang DITANDAI manual juga ditolak', () async {
      final citra = img.Image(width: 8, height: 8);
      tandaiSebagaiSalinanArsip(citra);

      await expectLater(
        JalankanPindaiAsli(
          halaman: _PembacaHalamanPenghitung(),
          pembaca: MockPembacaSel(),
        ).baca(citra, template: template),
        throwsA(isA<FotoTerkompresiDitolak>()),
      );
    });

    test(
      'MlKitPembacaHalaman.baca menolak citra salinan sebelum ML Kit',
      () async {
        var mlKitDipanggil = 0;
        final pembaca = MlKitPembacaHalaman(
          proses: (_) async {
            mlKitDipanggil++;
            throw StateError('tidak boleh sampai sini');
          },
        );

        await expectLater(
          pembaca.baca(salinan.dekode()!),
          throwsA(isA<FotoTerkompresiDitolak>()),
        );
        expect(mlKitDipanggil, 0);
      },
    );

    test('jalur cetak JalankanPindai.susun juga menolak', () async {
      final mesin = JalankanPindai(
        mesin: const PindaiLembar(),
        pembaca: MockPembacaSel(),
        pembacaQr: MockPembacaQr(),
      );

      await expectLater(
        mesin.susun(salinan.dekode()!, template: template),
        throwsA(isA<FotoTerkompresiDitolak>()),
      );
    });
  });

  group(
    'bypass: salinan di-copy / dipotong / didekode ulang tetap ditolak',
    () {
      // Tiap "wajah" salinan yang bisa dibuat orang lewat jalan pintas.
      final wajah =
          <String, ({img.Image Function() citra, Uint8List? Function() jpeg})>{
            'Uint8List.fromList(byte) sebagai jpegAsli': (
              citra: () => img.decodeJpg(fotoBesar)!,
              jpeg: () => Uint8List.fromList(salinan.byte),
            ),
            'sublist(0, n) sebagai jpegAsli': (
              citra: () => img.decodeJpg(fotoBesar)!,
              jpeg: () => salinan.byte.sublist(0, 4096),
            ),
            'sublist(2) (tanpa SOI) sebagai jpegAsli': (
              citra: () => img.decodeJpg(fotoBesar)!,
              jpeg: () => salinan.byte.sublist(2),
            ),
            'img.decodeJpg(byte salinan) TANPA jpegAsli': (
              citra: () => img.decodeJpg(salinan.byte)!,
              jpeg: () => null,
            ),
            'Image.from(decodeJpg(byte salinan))': (
              citra: () => img.Image.from(img.decodeJpg(salinan.byte)!),
              jpeg: () => null,
            ),
            'salinan.dekode()': (
              citra: () => salinan.dekode()!,
              jpeg: () => null,
            ),
          };

      for (final e in wajah.entries) {
        test('JalankanPindaiAsli.baca: ${e.key}', () async {
          final halaman = _PembacaHalamanPenghitung();

          await expectLater(
            JalankanPindaiAsli(
              halaman: halaman,
              pembaca: MockPembacaSel(),
            ).baca(
              e.value.citra(),
              template: template,
              jpegAsli: e.value.jpeg(),
            ),
            throwsA(isA<FotoTerkompresiDitolak>()),
          );
          expect(halaman.dipanggil, 0);
        });

        test('bacaFoto(FotoAsliKamera): ${e.key}', () async {
          final halaman = _PembacaHalamanPenghitung();

          await expectLater(
            JalankanPindaiAsli(
              halaman: halaman,
              pembaca: MockPembacaSel(),
            ).bacaFoto(
              FotoAsliKamera(e.value.citra(), jpegAsli: e.value.jpeg()),
              template: template,
            ),
            throwsA(isA<FotoTerkompresiDitolak>()),
          );
          expect(halaman.dipanggil, 0);
        });

        test(
          'MlKitPembacaHalaman.baca (citra & asli.jpeg): ${e.key}',
          () async {
            var mlKitDipanggil = 0;
            final pembaca = MlKitPembacaHalaman(
              jpegLangsung: true,
              proses: (_) async {
                mlKitDipanggil++;
                throw StateError('tidak boleh sampai ML Kit');
              },
            );

            await expectLater(
              pembaca.baca(
                e.value.citra(),
                asli: e.value.jpeg() == null
                    ? null
                    : (jpeg: e.value.jpeg()!, orientasi: 1),
              ),
              throwsA(isA<FotoTerkompresiDitolak>()),
            );
            expect(mlKitDipanggil, 0);
          },
        );

        // Jalur cetak hanya menerima citra (tanpa jpegAsli): vektor yang murni
        // jpegAsli tidak berlaku di sini.
        if (!e.key.contains('sebagai jpegAsli')) {
          test('JalankanPindai.susun (cetak): ${e.key}', () async {
            await expectLater(
              JalankanPindai(
                mesin: const PindaiLembar(),
                pembaca: MockPembacaSel(),
                pembacaQr: MockPembacaQr(),
              ).susun(e.value.citra(), template: template),
              throwsA(isA<FotoTerkompresiDitolak>()),
            );
          });
        }
      }

      test('MlKitPembacaHalaman: citra bersih + asli.jpeg = byte salinan '
          '-> ditolak sebelum ML Kit', () async {
        var mlKitDipanggil = 0;
        final pembaca = MlKitPembacaHalaman(
          jpegLangsung: true,
          proses: (_) async {
            mlKitDipanggil++;
            throw StateError('tidak boleh sampai ML Kit');
          },
        );

        await expectLater(
          pembaca.baca(
            img.decodeJpg(fotoBesar)!,
            asli: (jpeg: salinan.byte, orientasi: 1),
          ),
          throwsA(isA<FotoTerkompresiDitolak>()),
        );
        expect(mlKitDipanggil, 0);
      });

      test(
        'penanda ada di DALAM byte salinan dan tidak muncul di foto kamera',
        () {
          expect(apakahDariSalinanArsip(salinan.byte), isTrue);
          expect(apakahDariSalinanArsip(fotoBesar), isFalse);
          expect(apakahDariSalinanArsip(img.decodeJpg(fotoBesar)!), isFalse);

          // JPEG kamera yang punya EXIF sendiri (deskripsi lain) tetap bersih.
          final exif = img.ExifData()
            ..imageIfd.imageDescription = 'Foto kamera lab'
            ..imageIfd.make = 'Samsung'
            ..imageIfd.orientation = 6;
          final kamera = img.injectJpgExif(fotoBesar, exif)!;
          expect(apakahDariSalinanArsip(kamera), isFalse);
          expect(apakahDariSalinanArsip(img.decodeJpg(kamera)!), isFalse);
        },
      );
    },
  );

  group('OCR TETAP menerima foto kamera asli / hasil warp', () {
    test('bacaFoto(FotoAsliKamera) lolos penjaga dan sampai ke ML Kit '
        'sehalaman', () async {
      final halaman = _PembacaHalamanPenghitung();

      // Teks kosong -> berhenti di "kode tidak terbaca": artinya penjaga
      // kompresi dilewati dan pembaca benar-benar dipanggil.
      await expectLater(
        JalankanPindaiAsli(
          halaman: halaman,
          pembaca: MockPembacaSel(),
        ).bacaFoto(
          FotoAsliKamera(img.decodeJpg(fotoBesar)!, jpegAsli: fotoBesar),
          template: template,
        ),
        throwsA(
          isA<PindaiAsliGagal>().having(
            (e) => e.sebab,
            'sebab',
            GagalPindaiAsli.kodeTidakTerbaca,
          ),
        ),
      );
      expect(halaman.dipanggil, greaterThan(0));
    });

    test('foto kamera ber-EXIF (orientasi, merk) lolos penjaga', () async {
      final halaman = _PembacaHalamanPenghitung();
      final exif = img.ExifData()
        ..imageIfd.make = 'Samsung'
        ..imageIfd.orientation = 1;
      final kamera = img.injectJpgExif(fotoBesar, exif)!;

      await expectLater(
        JalankanPindaiAsli(
          halaman: halaman,
          pembaca: MockPembacaSel(),
        ).bacaFoto(
          FotoAsliKamera(img.decodeJpg(kamera)!, jpegAsli: kamera),
          template: template,
        ),
        throwsA(isA<PindaiAsliGagal>()),
      );
      expect(halaman.dipanggil, greaterThan(0));
    });

    test('bacaFoto(FotoHasilWarp) juga lolos penjaga', () async {
      final halaman = _PembacaHalamanPenghitung();

      await expectLater(
        JalankanPindaiAsli(
          halaman: halaman,
          pembaca: MockPembacaSel(),
        ).bacaFoto(
          FotoHasilWarp(img.Image(width: 200, height: 300)),
          template: template,
        ),
        throwsA(isA<PindaiAsliGagal>()),
      );
      expect(halaman.dipanggil, greaterThan(0));
    });
  });

  group('arsitektur: kompresi terisolasi dari OCR', () {
    final semuaLib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    String nama(File f) => f.path.replaceAll(r'\', '/');

    test('belum ada pemanggil aktif modul kompresi (alur sekarang tidak '
        'berubah)', () {
      final pengimpor = [
        for (final f in semuaLib)
          if (RegExp(
                r'''import\s+['"][^'"]*foto_kompres\.dart['"]''',
              ).hasMatch(f.readAsStringSync()) &&
              !nama(f).endsWith('services/foto_kompres.dart'))
            nama(f),
      ];

      expect(
        pengimpor,
        isEmpty,
        reason:
            'foto_kompres.dart baru boleh diimpor pemanggil UNGGAHAN/ARSIP; '
            'jika menambahkannya, perbarui test ini dengan alasan.',
      );
    });

    test('berkas OCR tidak boleh meng-impor foto_kompres.dart', () {
      const ocr = [
        'jalankan_pindai',
        'jalankan_pindai_asli',
        'pembaca_halaman',
        'pembaca_sel',
        'pembaca_qr',
        'pindai_lembar',
        'registrasi_jangkar_teks',
        'peta_tabel_foto',
        'potong_sel_foto',
        'ambil_foto_tabel',
        'baca_paralel',
        'jenis_lembar',
        'pindai_formulir_asli_flow',
      ];
      final salah = <String>[];

      for (final f in semuaLib) {
        final nm = nama(f).split('/').last.replaceAll('.dart', '');
        if (!ocr.contains(nm)) continue;
        if (f.readAsStringSync().contains('foto_kompres.dart')) {
          salah.add(nama(f));
        }
      }

      expect(salah, isEmpty);
    });

    test(
      'alur foto lembar asli memberi OCR foto kamera lewat pintu bertipe',
      () {
        final isi = File(
          'lib/screens/calibration/pindai_formulir_asli_flow.dart',
        ).readAsStringSync();

        expect(isi, contains('bacaFoto('));
        expect(isi, contains('FotoAsliKamera('));
      },
    );
  });
}
