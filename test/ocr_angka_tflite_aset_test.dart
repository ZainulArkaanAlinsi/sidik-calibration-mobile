import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/ocr_angka/meta_model.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin_bawaan.dart';
import 'package:sidik_calibration/services/ocr_angka/sesi_inferensi.dart';
import 'package:sidik_calibration/services/ocr_angka/sumber_model_ocr.dart';

/// Aset model yang DIBUNDEL di APK, meta-nya, dan sha256 yang dipatok app harus
/// satu cerita. Berkas model ikut APK walau sakelar mati (7,83 MB); yang
/// menahannya dimuat adalah sakelar dan pin ini.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List model;
  late String metaJson;
  late MetaModelOcr meta;

  setUpAll(() async {
    final data = await rootBundle.load('assets/models/ocr_angka_en.tflite');
    model = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    metaJson = await rootBundle.loadString(
      'assets/models/ocr_angka_en.meta.json',
    );
    meta = MetaModelOcr.dari(metaJson)!;
  });

  test('aset tflite terdaftar, ukuran 7.829.508 bita, flatbuffer TFL3', () {
    expect(model.length, 7829508);
    // Identifier berkas flatbuffer TFLite: bita 4..8 = "TFL3".
    expect(String.fromCharCodes(model.sublist(4, 8)), 'TFL3');
  });

  test('sha256 aset = sha256 di meta = satu-satunya yang dipatok app', () {
    expect(sha256Dari(model), meta.sha256);
    expect(
      meta.sha256,
      'e1121d540ae96a69f2891a6d8811ecb89cb5e55d8eafb69efce2ee1fae4043b7',
    );
    expect(sha256ModelDipercaya, {meta.sha256});
    expect(meta.cocokDengan(model), isTrue);
  });

  test('meta: berkas TFLite, whitelist, SINTETIS, ambang 0,990', () {
    expect(meta.berkas, 'ocr_angka_en.tflite');
    expect(meta.kolom, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 76, 74, 75]);
    expect(meta.buktiSintetis, isTrue);
    expect(meta.asalData, 'publik');
    expect(meta.ambangJalur, 0.990);
    expect(meta.versi, contains('tflite'));
  });

  test('pubspec mendaftarkan DUA berkas model, bukan folder assets/models', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('- assets/models/ocr_angka_en.tflite'));
    expect(pubspec, contains('- assets/models/ocr_angka_en.meta.json'));
    expect(
      RegExp(r'^\s*-\s*assets/models/?\s*$', multiLine: true).hasMatch(pubspec),
      isFalse,
      reason: 'mendaftarkan folder ikut memasukkan README dan berkas lain',
    );
    expect(pubspec, isNot(contains('rec_en_f16w')));
  });

  group('gerbang muat dengan aset asli (sesi tiruan)', () {
    Future<SesiInferensiCtc> buat(Uint8List m) async => _SesiKosong();

    test('rilis (pin) + sakelar menyala -> termuat', () async {
      final h = await muatMesinAngka(
        sumber: SumberAsetOcr(rootBundle),
        buatSesi: buat,
        izinkanSintetis: true,
        sha256Dipercaya: sha256ModelDipercaya,
      );

      expect(h.ditolak, isNull);
      expect(h.mesin, isNotNull);
    });

    test('tanpa izin sintetis (sakelar developer mati) -> ditolak', () async {
      final h = await muatMesinAngka(
        sumber: SumberAsetOcr(rootBundle),
        buatSesi: buat,
        izinkanSintetis: false,
        sha256Dipercaya: sha256ModelDipercaya,
      );

      expect(h.ditolak, PenolakanMesin.buktiSintetisDitolak);
    });

    test('pin lama (ONNX) tidak lagi dipercaya', () async {
      final h = await muatMesinAngka(
        sumber: SumberAsetOcr(rootBundle),
        buatSesi: buat,
        izinkanSintetis: true,
        sha256Dipercaya: const {
          'b5f833dfc5d0eb71da397b4efa06ebeee9b431b690a47d6af40d77d8eabc557f',
        },
      );

      expect(h.ditolak, PenolakanMesin.sha256TakDikenal);
    });

    test('byte model berubah satu bita -> sha256TidakCocok', () async {
      final rusak = Uint8List.fromList(model)..[1000] ^= 1;
      final h = await muatMesinAngka(
        sumber: _SumberTetap(metaJson, rusak),
        buatSesi: buat,
        izinkanSintetis: true,
        sha256Dipercaya: sha256ModelDipercaya,
      );

      expect(h.ditolak, PenolakanMesin.sha256TidakCocok);
    });

    test(
      'model lain dengan meta sendiri (folder perangkat) -> tak dikenal di rilis',
      () async {
        final lain = Uint8List.fromList([1, 2, 3, 4, 5]);
        final metaLain = metaJson.replaceFirst(meta.sha256, sha256Dari(lain));
        final h = await muatMesinAngka(
          sumber: _SumberTetap(metaLain, lain),
          buatSesi: buat,
          izinkanSintetis: true,
          sha256Dipercaya: sha256ModelDipercaya,
        );

        expect(h.ditolak, PenolakanMesin.sha256TakDikenal);
      },
    );
  });
}

class _SesiKosong implements SesiInferensiCtc {
  @override
  Future<KeluaranCtc> jalankan(Float32List masukan, int lebar) =>
      throw UnimplementedError();

  @override
  Future<void> tutup() async {}
}

class _SumberTetap implements SumberModelOcr {
  _SumberTetap(this._meta, this._model);

  final String _meta;
  final Uint8List _model;

  @override
  Future<String?> metaJson() async => _meta;

  @override
  Future<Uint8List?> model(String berkas) async => _model;
}
