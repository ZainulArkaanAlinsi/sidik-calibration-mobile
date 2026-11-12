import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/ocr_angka/aturan_format_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/dekoder_ctc.dart';
import 'package:sidik_calibration/services/ocr_angka/keputusan_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/mesin_angka.dart';
import 'package:sidik_calibration/services/ocr_angka/meta_model.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin_bawaan.dart';
import 'package:sidik_calibration/services/ocr_angka/praproses_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/sesi_inferensi.dart';
import 'package:sidik_calibration/services/ocr_angka/sumber_model_ocr.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/pembaca_sel_onnx.dart';

/// Ketahanan mesin angka terhadap masukan buruk: keluaran model NaN/tak hingga,
/// crop yang tak wajar, meta yang diubah, model yang bukan yang dipatok, dan
/// JSON templat yang aneh. Tidak satu pun boleh menjadi USULAN atau melempar ke
/// pemanggil.
void main() {
  const lebar = 14; // blank + 13 karakter

  // Frame "satu-panas": kelas [k] bernilai [p], sisanya dibagi rata.
  Float64List frame(List<int> kelas, {double p = 0.95}) {
    final m = Float64List(kelas.length * lebar);
    for (var t = 0; t < kelas.length; t++) {
      for (var k = 0; k < lebar; k++) {
        m[t * lebar + k] = k == kelas[t] ? p : (1 - p) / 13;
      }
    }
    return m;
  }

  group('keluaran tak finit -> tidak valid, bukan usulan', () {
    test('kontrol: masukan bersih tetap terbaca', () {
      final h = DekoderCtc.dekode(frame([6, 0, 7]), 3);

      expect(h.valid, isTrue);
      expect(h.teks, '56');
    });

    test('satu frame NaN', () {
      final m = frame([6, 0, 7]);
      for (var k = 0; k < lebar; k++) {
        m[lebar + k] = double.nan;
      }
      final h = DekoderCtc.dekode(m, 3);

      expect(h.valid, isFalse);
      expect(h.teks, isEmpty);
      expect(h.jalur, 0.0);
    });

    test('satu frame Infinity', () {
      final m = frame([6, 0, 7]);
      for (var k = 0; k < lebar; k++) {
        m[k] = double.infinity;
      }

      expect(DekoderCtc.dekode(m, 3).valid, isFalse);
    });

    test('satu kolom NaN di satu frame', () {
      final m = frame([6, 0, 7]);
      m[lebar + 3] = double.nan;

      expect(DekoderCtc.dekode(m, 3).valid, isFalse);
    });

    test('nilai negatif ditolak', () {
      final m = frame([6, 0, 7]);
      m[lebar + 1] = -0.1;

      expect(DekoderCtc.dekode(m, 3).valid, isFalse);
    });

    test('semua NaN', () {
      final h = DekoderCtc.dekode(
        Float64List.fromList(List.filled(3 * lebar, double.nan)),
        3,
      );

      expect(h.valid, isFalse);
      expect(h.teks, isEmpty);
    });

    test(
      'logit +Infinity lewat ambilKolom (jalur softmax) -> NaN -> tidak valid',
      () {
        // 2 frame × 4 kelas; frame pertama berjumlah tak hingga: dianggap logit
        // lalu di-softmax, exp(inf - inf) = NaN.
        final keluaran = Float32List.fromList([
          0,
          double.infinity,
          0,
          0,
          1,
          0,
          0,
          0,
        ]);
        final kolom = DekoderCtc.ambilKolom(keluaran, 2, 4, [0, 1, 2]);

        expect(kolom.any((v) => v.isNaN), isTrue);
        expect(DekoderCtc.dekode(kolom, 2, alfabet: '01').valid, isFalse);
      },
    );

    test('baris pertama NaN lewat ambilKolom tetap tidak valid', () {
      final keluaran = Float32List.fromList(List.filled(8, double.nan));
      final kolom = DekoderCtc.ambilKolom(keluaran, 2, 4, [0, 1, 2]);

      expect(DekoderCtc.dekode(kolom, 2, alfabet: '01').valid, isFalse);
    });

    test('putuskanSelAngka: tidak valid -> ditahan, tidak pernah usulan', () {
      final a = AturanFormatSel(desimal: 0, bolehNegatif: false);
      final h = putuskanSelAngka(
        dekode: const HasilDekodeCtc.tidakValid(),
        aturan: a,
      );

      expect(h.status, StatusSelAngka.perluCek);
      expect(h.alasan, AlasanSelAngka.keluaranTakValid);
      expect(h.usulan, isNull);
    });

    test('skor NaN / Infinity yang lolos sampai keputusan juga ditahan', () {
      final a = AturanFormatSel(desimal: 0, bolehNegatif: false);

      for (final skor in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final h = putuskanSelAngka(
          dekode: HasilDekodeCtc(
            teks: '12',
            peluangKarakter: const [0.9],
            jalur: skor,
          ),
          aturan: a,
        );

        expect(h.usulan, isNull, reason: 'skor $skor');
        expect(h.status, isNot(StatusSelAngka.usulanKeyakinanTinggi));
      }
    });

    test('ambang NaN menahan semuanya (NaN < ambang salah, jadi !(>=))', () {
      final h = putuskanSelAngka(
        dekode: const HasilDekodeCtc(
          teks: '12',
          peluangKarakter: [0.99],
          jalur: 0.999,
        ),
        aturan: AturanFormatSel(desimal: 0, bolehNegatif: false),
        ambang: double.nan,
      );

      expect(h.status, StatusSelAngka.perluCek);
      expect(h.alasan, AlasanSelAngka.jalurRendah);
    });
  });

  group('MesinAngka dan PembacaSelOnnx menghadapi keluaran NaN', () {
    final kolomModel = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 76, 74, 75];
    final model = Uint8List.fromList(List.generate(16, (i) => i));
    final meta = MetaModelOcr.dari(
      jsonEncode({
        'berkas': 'm.onnx',
        'sha256': sha256Dari(model),
        'kolom': kolomModel,
      }),
    )!;

    // 40 frame × 438 kelas; frame 0 = digit '5' yakin, sisanya blank yakin.
    KeluaranCtc keluaran({bool nan = false}) {
      const t = 40;
      const k = 438;
      final n = Float32List(t * k);
      for (var f = 0; f < t; f++) {
        n[f * k + (f == 0 ? 6 : 0)] = 0.999;
      }
      if (nan) n[5 * k + 10] = double.nan;
      return KeluaranCtc(nilai: n, frame: t, kelas: k);
    }

    img.Image bertinta() {
      final i = img.Image(width: 160, height: 60, numChannels: 3);
      img.fill(i, color: img.ColorRgb8(235, 235, 235));
      for (var y = 15; y < 45; y++) {
        for (var x = 60; x < 66; x++) {
          i.setPixelRgb(x, y, 30, 30, 30);
        }
      }
      return i;
    }

    final aturan = AturanFormatSel(desimal: 0, bolehNegatif: false);

    test('kontrol: keluaran bersih menjadi usulan "5"', () async {
      final mesin = MesinAngka(sesi: _Sesi([keluaran()]), meta: meta);
      final h = await mesin.baca(bertinta(), aturan);

      expect(h.usulan, '5');
    });

    test(
      'keluaran NaN: ditahan dengan alasan, bukan usulan, tidak melempar',
      () async {
        final mesin = MesinAngka(
          sesi: _Sesi([keluaran(nan: true)]),
          meta: meta,
        );
        final h = await mesin.baca(bertinta(), aturan);

        expect(h.usulan, isNull);
        expect(h.status, StatusSelAngka.perluCek);
        expect(h.alasan, AlasanSelAngka.keluaranTakValid);
      },
    );

    test(
      'sel dengan keluaran NaN dibaca ML Kit; mesin tetap aktif untuk sel lain',
      () async {
        final cad = _Cadangan();
        final log = <String>[];
        final p = PembacaSelOnnx(
          cadangan: cad,
          muatMesin: () async => MesinAngka(
            sesi: _Sesi([keluaran(nan: true), keluaran()]),
            meta: meta,
          ),
          catat: log.add,
        );

        final a = await p.bacaBerformat(bertinta(), aturan);
        final b = await p.bacaBerformat(bertinta(), aturan);

        expect(a.teks, 'cadangan', reason: 'sel tidak hilang diam-diam');
        expect(b.teks, '5', reason: 'mesin tidak dimatikan oleh satu sel');
        expect(cad.dibaca, 1);
        expect(log.single, contains('tak valid'));
      },
    );

    test(
      'keBacaanSel selalu menghasilkan nilai finit yang aman di-JSON-kan',
      () {
        for (final h in [
          const HasilSelAngka.kosong(AlasanSelAngka.tintaKosong),
          const HasilSelAngka(
            status: StatusSelAngka.perluCek,
            bacaanMentah: '',
            jalur: 0,
            alasan: AlasanSelAngka.keluaranTakValid,
          ),
          const HasilSelAngka(
            status: StatusSelAngka.usulanKeyakinanTinggi,
            bacaanMentah: '7',
            jalur: double.nan, // tidak seharusnya terjadi; dijaga sekali lagi
          ),
        ]) {
          final b = PembacaSelOnnx.keBacaanSel(h);

          expect(b.keyakinan == null || b.keyakinan!.isFinite, isTrue);
          expect(
            () => jsonEncode({
              'teks_mentah': b.teks,
              'confidence_ocr': b.keyakinan,
            }),
            returnsNormally,
          );
        }
      },
    );
  });

  group('crop tak wajar', () {
    test('ukuranWajar: batas sisi dan lebar kanvas', () {
      expect(PraprosesSel.ukuranWajar(200, 60), isTrue);
      expect(PraprosesSel.ukuranWajar(2048, 48), isTrue);
      expect(
        PraprosesSel.ukuranWajar(2049, 48),
        isFalse,
        reason: 'sisi > 2048',
      );
      expect(PraprosesSel.ukuranWajar(100, 3000), isFalse);
      expect(
        PraprosesSel.ukuranWajar(2000, 40),
        isFalse,
        reason: 'rw 2400 > 2048',
      );
      expect(PraprosesSel.ukuranWajar(300, 1), isFalse, reason: 'rw 14400');
      expect(PraprosesSel.ukuranWajar(0, 10), isFalse);
      expect(PraprosesSel.ukuranWajar(10, 0), isFalse);
    });

    test('proses melempar ArgumentError untuk crop tak wajar', () {
      expect(
        () => PraprosesSel.proses(img.Image(width: 2000, height: 40)),
        throwsArgumentError,
      );
    });

    test(
      'MesinAngka: kosong + ukuranTakWajar, model tidak dijalankan',
      () async {
        final model = Uint8List.fromList([1, 2, 3]);
        final sesi = _Sesi(const []);
        final mesin = MesinAngka(
          sesi: sesi,
          meta: MetaModelOcr.dari(
            jsonEncode({
              'berkas': 'm.onnx',
              'sha256': sha256Dari(model),
              'kolom': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 76, 74, 75],
            }),
          )!,
        );

        final h = await mesin.baca(
          img.Image(width: 2000, height: 40),
          AturanFormatSel(desimal: 0, bolehNegatif: false),
        );

        expect(h.status, StatusSelAngka.kosong);
        expect(h.alasan, AlasanSelAngka.ukuranTakWajar);
        expect(sesi.dipanggil, 0);
      },
    );
  });

  group('meta.json yang diubah atau tidak dipercaya', () {
    Map<String, dynamic> dasar() => {
      'berkas': 'm.onnx',
      'sha256': 'a' * 64,
      'kolom': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 76, 74, 75],
    };

    test('ambang_jalur dijepit ke 0,5..1', () {
      double ambang(Object? nilai) => MetaModelOcr.dari(
        jsonEncode({...dasar(), 'ambang_jalur': nilai}),
      )!.ambangJalur;

      expect(ambang(0), 0.5, reason: 'ambang 0 meloloskan semuanya');
      expect(ambang(-3), 0.5);
      expect(ambang(0.2), 0.5);
      expect(ambang(0.995), 0.995);
      expect(ambang(7), 1.0);
      expect(ambang(null), ambangJalurAwal);
    });

    test('ambang_jalur bukan angka -> meta tidak sah', () {
      expect(
        MetaModelOcr.dari(jsonEncode({...dasar(), 'ambang_jalur': 'rendah'})),
        isNull,
      );
    });

    test('sha256 yang dipatok app = sha256 di meta.json repo', () {
      final meta = MetaModelOcr.dari(
        File('assets/models/ocr_angka_en.meta.json').readAsStringSync(),
      )!;

      expect(sha256ModelDipercaya, contains(meta.sha256));
    });

    group('muatMesinAngka dengan sha256 dipatok', () {
      final model = Uint8List.fromList(List.generate(32, (i) => i * 3));
      final metaJson = jsonEncode({
        ...dasar(),
        'sha256': sha256Dari(model),
        'bukti_akurasi': 'FOTO_NYATA',
      });
      final sumber = _Sumber(metaJson, model);
      Future<SesiInferensiCtc> buat(Uint8List _) async => _Sesi(const []);

      test('model yang bukan yang dipatok ditolak', () async {
        final h = await muatMesinAngka(
          sumber: sumber,
          buatSesi: buat,
          izinkanSintetis: true,
          sha256Dipercaya: {'0' * 64},
        );

        expect(h.mesin, isNull);
        expect(h.ditolak, PenolakanMesin.sha256TakDikenal);
      });

      test('yang dipatok diterima; tanpa patokan (debug) diterima', () async {
        final patok = await muatMesinAngka(
          sumber: sumber,
          buatSesi: buat,
          izinkanSintetis: false,
          sha256Dipercaya: {sha256Dari(model)},
        );
        final bebas = await muatMesinAngka(
          sumber: sumber,
          buatSesi: buat,
          izinkanSintetis: false,
        );

        expect(patok.mesin, isNotNull);
        expect(bebas.mesin, isNotNull);
      });
    });

    test(
      'muatMesinAngkaBawaan: tanpa runtime -> null tanpa menyentuh penyimpanan',
      () async {
        expect(await muatMesinAngkaBawaan(null, izinkanSintetis: true), isNull);
      },
    );
  });

  group('JSON templat yang aneh', () {
    test('izinkan_minus bukan bool -> tidak diketahui, tidak melempar', () {
      for (final v in [
        0,
        1,
        'true',
        'false',
        1.5,
        <String, dynamic>{},
        <int>[],
      ]) {
        final a = AturanSelAsli.dari({
          'tipe': 'desimal',
          'desimal': 2,
          'izinkan_minus': v,
        });

        expect(a, isNotNull, reason: 'nilai $v');
        expect(a!.izinkanMinus, isNull, reason: 'nilai $v');
        expect(a.desimal, 2);
      }
    });

    test('izinkan_minus bool tetap terbaca', () {
      expect(
        AturanSelAsli.dari({
          'tipe': 'desimal',
          'izinkan_minus': true,
        })!.izinkanMinus,
        isTrue,
      );
      expect(
        AturanSelAsli.dari({
          'tipe': 'desimal',
          'izinkan_minus': false,
        })!.izinkanMinus,
        isFalse,
      );
    });
  });
}

/// Sesi tiruan: mengembalikan keluaran berurutan (yang terakhir diulang).
class _Sesi implements SesiInferensiCtc {
  _Sesi(this._daftar);

  final List<KeluaranCtc> _daftar;
  int dipanggil = 0;

  @override
  Future<KeluaranCtc> jalankan(Float32List masukan, int lebar) async {
    final i = dipanggil < _daftar.length ? dipanggil : _daftar.length - 1;
    dipanggil++;

    return _daftar[i];
  }

  @override
  Future<void> tutup() async {}
}

class _Cadangan implements PembacaSel {
  int dibaca = 0;

  @override
  Future<BacaanSel> baca(img.Image potongan) async {
    dibaca++;

    return (teks: 'cadangan', keyakinan: null, didalamKotak: true);
  }

  @override
  Future<void> tutup() async {}
}

class _Sumber implements SumberModelOcr {
  _Sumber(this._meta, this._model);

  final String _meta;
  final Uint8List _model;

  @override
  Future<String?> metaJson() async => _meta;

  @override
  Future<Uint8List?> model(String berkas) async => _model;
}
