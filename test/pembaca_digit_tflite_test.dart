import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/providers/sakelar_ocr_provider.dart';
import 'package:sidik_calibration/services/pembaca_digit_tflite.dart';
import 'package:sidik_calibration/services/segmentasi_karakter.dart';

/// Gerbang `PembacaDigitTflite` dengan interpreter PALSU (runtime TFLite asli
/// tidak jalan di host test). Yang dijaga: model `asal_data` publik/sintetis
/// tidak pernah menjadi pembaca, sha256 wajib cocok, sakelar bawaan mati.
void main() {
  final model = Uint8List.fromList(List.generate(64, (i) => i));
  final hash = sha256.convert(model).toString();

  String meta({
    String asal = 'asli',
    String? sha,
    List<String> kelas = PembacaDigitTflite.kelasDiharapkan,
  }) => jsonEncode({
    'versi': 'v0',
    'berkas': 'pengenal_karakter_v0.tflite',
    'sha256': sha ?? hash,
    'asal_data': asal,
    'kelas': kelas,
  });

  const nyala = SakelarOcr(pakaiModelDigit: true);
  var dibuat = 0;
  InterpreterDigit pabrik(Uint8List _) {
    dibuat++;
    return _InterpreterPalsu();
  }

  setUp(() => dibuat = 0);

  HasilSiapkan siap({SakelarOcr s = nyala, String? m, Uint8List? mdl}) =>
      PembacaDigitTflite.siapkan(
        sakelar: s,
        model: mdl ?? model,
        metaJson: m ?? meta(),
        buatInterpreter: pabrik,
      );

  test('sakelar bawaan MATI → ditolak sebelum apa pun dibaca', () {
    final h = siap(s: const SakelarOcr());
    expect(h.pembaca, isNull);
    expect(h.ditolak, PenolakanModel.sakelarMati);
    expect(dibuat, 0);
  });

  test('asal_data publik / sintetis → DITOLAK mengisi sel', () {
    for (final asal in ['publik', 'sintetis']) {
      final h = siap(m: meta(asal: asal));
      expect(h.pembaca, isNull, reason: asal);
      expect(h.ditolak, PenolakanModel.asalDataBukanAsli);
    }
    expect(
      siap(m: meta(asal: 'campuran')).ditolak,
      PenolakanModel.asalDataTakDikenal,
    );
    expect(dibuat, 0, reason: 'interpreter tidak pernah dibuat');
  });

  test('sha256 tidak cocok → ditolak', () {
    final lain = Uint8List.fromList([...model, 1]);
    expect(siap(mdl: lain).ditolak, PenolakanModel.sha256TidakCocok);
  });

  test('meta rusak / kelas beda urutan → ditolak', () {
    expect(siap(m: '{').ditolak, PenolakanModel.metaTidakSah);
    expect(siap(m: meta(sha: 'abc')).ditolak, PenolakanModel.metaTidakSah);
    expect(
      siap(
        m: meta(kelas: [...PembacaDigitTflite.kelasDiharapkan.reversed]),
      ).ditolak,
      PenolakanModel.kelasTidakCocok,
    );
  });

  test('model asli + sha cocok: klasifikasi memakai interpreter', () {
    final h = siap();
    expect(h.ditolak, isNull);
    final p = h.pembaca!;

    final piksel = Uint8List(sisiMnist * sisiMnist)..[0] = 255;
    final k = p.klasifikasi([
      (
        jenis: JenisKarakter.tanda,
        kotak: (x: 0, y: 0, w: 1, h: 1),
        piksel: piksel,
      ),
    ]);
    expect(k.single.kelas, '7');
    expect(k.single.peluang, closeTo(0.9, 1e-9));
    p.tutup();
  });

  test('dariFolder membaca meta.json + berkas model', () async {
    final dir = Directory.systemTemp.createTempSync('model-digit');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/meta.json').writeAsStringSync(meta(asal: 'publik'));
    File('${dir.path}/pengenal_karakter_v0.tflite').writeAsBytesSync(model);

    final h = await PembacaDigitTflite.dariFolder(
      dir,
      sakelar: nyala,
      buatInterpreter: pabrik,
    );
    expect(h.ditolak, PenolakanModel.asalDataBukanAsli);
  });
}

class _InterpreterPalsu implements InterpreterDigit {
  @override
  List<double> jalankan(Float32List masukan) {
    expect(masukan, hasLength(784));
    expect(masukan[0], 1.0);
    return [for (var i = 0; i < 14; i++) i == 7 ? 0.9 : 0.1 / 13];
  }

  @override
  void tutup() {}
}
