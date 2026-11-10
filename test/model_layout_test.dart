import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sidik_calibration/services/layout/detektor_layout.dart';
import 'package:sidik_calibration/services/layout/model_layout.dart';

SpesifikasiModelLayout spesifikasiUntuk(List<int> isi) =>
    SpesifikasiModelLayout(
      namaBerkas: 'model-uji.onnx',
      url: 'https://contoh.test/model-uji.onnx',
      ukuranByte: isi.length,
      sha256Hex: sha256.convert(isi).toString(),
    );

void main() {
  late Directory dir;
  final isi = List<int>.generate(100000, (i) => (i * 31 + 7) % 256);
  late SpesifikasiModelLayout spek;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('model-layout-test');
    spek = spesifikasiUntuk(isi);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  PengelolaModelLayout bikin(
    http.Client klien, {
    SpesifikasiModelLayout? spesifikasi,
    int maksCoba = 3,
  }) => PengelolaModelLayout(
    direktori: () async => dir,
    klien: klien,
    spesifikasi: spesifikasi ?? spek,
    maksCoba: maksCoba,
    jeda: (_) => Duration.zero,
  );

  /// Klien yang mengirim [badan] dalam potongan 10 KB.
  MockClient klienSukses(
    List<int> badan, {
    void Function(http.BaseRequest)? lihat,
  }) => MockClient.streaming((req, _) async {
    lihat?.call(req);
    final mulai = req.headers['Range'] == null
        ? 0
        : int.parse(
            RegExp(
              r'bytes=(\d+)-',
            ).firstMatch(req.headers['Range']!)!.group(1)!,
          );
    final potong = badan.sublist(mulai);
    Stream<List<int>> aliran() async* {
      for (var i = 0; i < potong.length; i += 10000) {
        yield potong.sublist(i, (i + 10000).clamp(0, potong.length));
      }
    }

    return http.StreamedResponse(aliran(), mulai > 0 ? 206 : 200);
  });

  group('kunci sha256 di kode', () {
    test('spesifikasi pp_doclayout_l.onnx = rilis v1.0.0 yang dikunci', () {
      const s = SpesifikasiModelLayout.ppDocLayoutL;

      expect(s.namaBerkas, 'pp_doclayout_l.onnx');
      expect(s.ukuranByte, 129271998);
      expect(
        s.sha256Hex,
        '1d1ed16b17e79ae08d1a18ea92a3ad134edfdb4455d869907e47b42699f4edb5',
      );
      // Dipin ke TAG rilis (bukan "latest"), https.
      expect(
        s.url,
        'https://github.com/robert008/flutter_ocr_kit/releases/download/v1.0.0/pp_doclayout_l.onnx',
      );
      expect(Uri.parse(s.url).scheme, 'https');
    });
  });

  group('unduh', () {
    test(
      'unduh, progres naik sampai 1.0, sha256 cocok, berkas final ada',
      () async {
        final progres = <double>[];
        final tahap = <TahapLayout>[];
        final path = await bikin(klienSukses(isi)).pastikan(
          kemajuan: (t, b) {
            tahap.add(t);
            if (t == TahapLayout.mengunduhModel && b != null) progres.add(b);
          },
        );

        expect(File(path).readAsBytesSync(), isi);
        expect(File('$path.part').existsSync(), isFalse);
        expect(progres.last, 1.0);
        expect(progres.first, 0.0);
        for (var i = 1; i < progres.length; i++) {
          expect(progres[i], greaterThanOrEqualTo(progres[i - 1]));
        }
        expect(
          tahap,
          containsAllInOrder([
            TahapLayout.mengunduhModel,
            TahapLayout.memeriksaModel,
          ]),
        );
      },
    );

    test(
      'sha256 TIDAK cocok -> modelRusak, tidak pernah dimuat, berkas dibuang',
      () async {
        final rusak = List<int>.of(isi)..[500] ^= 0xFF; // ukuran sama, isi beda
        var permintaan = 0;
        final pengelola = bikin(
          klienSukses(rusak, lihat: (_) => permintaan++),
          maksCoba: 2,
        );

        await expectLater(
          pengelola.pastikan(),
          throwsA(
            isA<LayoutGagal>().having(
              (e) => e.sebab,
              'sebab',
              SebabLayoutGagal.modelRusak,
            ),
          ),
        );
        expect(permintaan, 2); // dicoba ulang dari nol, bukan dilanjutkan
        expect(File('${dir.path}/model-uji.onnx').existsSync(), isFalse);
        expect(File('${dir.path}/model-uji.onnx.part').existsSync(), isFalse);
      },
    );

    test(
      'hash yang dikunci diganti -> berkas yang benar pun ditolak',
      () async {
        // Mutan: kalau verifikasi dilewati, berkas ini lolos.
        final salah = SpesifikasiModelLayout(
          namaBerkas: spek.namaBerkas,
          url: spek.url,
          ukuranByte: spek.ukuranByte,
          sha256Hex: '0' * 64,
        );

        await expectLater(
          bikin(klienSukses(isi), spesifikasi: salah, maksCoba: 1).pastikan(),
          throwsA(isA<LayoutGagal>()),
        );
      },
    );

    test('gagal sesaat (HTTP 500) lalu pulih -> berhasil', () async {
      var n = 0;
      final klien = MockClient.streaming((req, _) async {
        n++;
        if (n == 1) {
          return http.StreamedResponse(Stream.value(utf8.encode('x')), 500);
        }

        return http.StreamedResponse(Stream.value(isi), 200);
      });

      final path = await bikin(klien).pastikan();

      expect(n, 2);
      expect(File(path).readAsBytesSync(), isi);
    });

    test('selalu gagal -> unduhGagal setelah maksCoba kali', () async {
      var n = 0;
      final klien = MockClient.streaming((req, _) async {
        n++;
        return http.StreamedResponse(const Stream.empty(), 503);
      });

      await expectLater(
        bikin(klien).pastikan(),
        throwsA(
          isA<LayoutGagal>().having(
            (e) => e.sebab,
            'sebab',
            SebabLayoutGagal.unduhGagal,
          ),
        ),
      );
      expect(n, 3);
    });

    test(
      'terputus di tengah -> percobaan berikut MELANJUTKAN (Range)',
      () async {
        final rentang = <String?>[];
        var n = 0;
        final klien = MockClient.streaming((req, _) async {
          rentang.add(req.headers['Range']);
          n++;
          if (n == 1) {
            // Hanya 40.000 byte lalu aliran putus (ukuran akhir kurang).
            return http.StreamedResponse(
              Stream.value(isi.sublist(0, 40000)),
              200,
            );
          }
          final mulai = int.parse(
            RegExp(
              r'bytes=(\d+)-',
            ).firstMatch(req.headers['Range']!)!.group(1)!,
          );

          return http.StreamedResponse(Stream.value(isi.sublist(mulai)), 206);
        });

        final path = await bikin(klien).pastikan();

        expect(rentang, [null, 'bytes=40000-']);
        expect(File(path).readAsBytesSync(), isi);
      },
    );

    test('server mengabaikan Range (200) -> ditulis ulang dari awal', () async {
      File(
        '${dir.path}/model-uji.onnx.part',
      ).writeAsBytesSync(isi.sublist(0, 30000));
      final klien = MockClient.streaming(
        (req, _) async => http.StreamedResponse(Stream.value(isi), 200),
      );

      final path = await bikin(klien).pastikan();

      expect(File(path).readAsBytesSync(), isi);
    });

    test(
      'izin unduh ditolak (data seluler) -> unduhDitolak, nol permintaan',
      () async {
        var n = 0;
        final klien = klienSukses(isi, lihat: (_) => n++);

        await expectLater(
          bikin(klien).pastikan(izinUnduh: () async => false),
          throwsA(
            isA<LayoutGagal>().having(
              (e) => e.sebab,
              'sebab',
              SebabLayoutGagal.unduhDitolak,
            ),
          ),
        );
        expect(n, 0);
      },
    );
  });

  group('berkas yang sudah ada', () {
    test('sudah ada & hash cocok -> tanpa jaringan, tanpa bertanya', () async {
      File('${dir.path}/model-uji.onnx').writeAsBytesSync(isi);
      var n = 0;
      var tanya = 0;

      final path = await bikin(klienSukses(isi, lihat: (_) => n++)).pastikan(
        izinUnduh: () async {
          tanya++;
          return true;
        },
      );

      expect(n, 0);
      expect(tanya, 0);
      expect(File(path).readAsBytesSync(), isi);
    });

    test(
      'ukuran benar tapi isi diubah -> dibuang lalu diunduh ulang',
      () async {
        final diubah = List<int>.of(isi)..[1] ^= 0x01;
        File('${dir.path}/model-uji.onnx').writeAsBytesSync(diubah);
        var n = 0;

        final path = await bikin(
          klienSukses(isi, lihat: (_) => n++),
        ).pastikan();

        expect(n, 1);
        expect(File(path).readAsBytesSync(), isi);
      },
    );

    test(
      'hash dihitung sekali per proses (panggilan kedua tak membaca ulang)',
      () async {
        File('${dir.path}/model-uji.onnx').writeAsBytesSync(isi);
        final pengelola = bikin(klienSukses(isi));
        final p1 = await pengelola.pastikan();
        // Rusak SESUDAH terverifikasi: tidak diperiksa lagi di proses yang sama.
        File(p1).writeAsBytesSync(Uint8List(isi.length));
        final p2 = await pengelola.pastikan();

        expect(p2, p1);
      },
    );

    test('buang() menghapus model & sisa unduhan', () async {
      File('${dir.path}/model-uji.onnx').writeAsBytesSync(isi);
      File('${dir.path}/model-uji.onnx.part').writeAsBytesSync([1]);
      final pengelola = bikin(klienSukses(isi));

      await pengelola.buang();

      expect(File('${dir.path}/model-uji.onnx').existsSync(), isFalse);
      expect(File('${dir.path}/model-uji.onnx.part').existsSync(), isFalse);
      expect(await pengelola.sudahAda(), isFalse);
    });
  });
}
