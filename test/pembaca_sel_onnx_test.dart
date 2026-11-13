import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/providers/sakelar_ocr_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/services/ocr_angka/aturan_format_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/mesin_angka.dart';
import 'package:sidik_calibration/services/ocr_angka/meta_model.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin_bawaan.dart';
import 'package:sidik_calibration/services/ocr_angka/sesi_inferensi.dart';
import 'package:sidik_calibration/services/ocr_angka/sumber_model_ocr.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/pembaca_sel_onnx.dart';

/// Mesin angka di balik sakelar, dengan ML Kit sebagai cadangan. Inferensi
/// ONNX NYATA tidak diuji di sini (tidak ada runtime di mesin test): sesi
/// dipalsukan dari logits fixture rig.
void main() {
  final fx =
      jsonDecode(
            File(
              'test/fixtures/ocr_angka/paritas_dekode.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final contoh = (fx['contoh'] as List).cast<Map<String, dynamic>>();
  final kolomModel = (fx['kolom_model'] as List).cast<int>();
  const kelasModel = 438;

  KeluaranCtc keluaranDari(String file) {
    final c = contoh.firstWhere((c) => c['file'] == file);
    final t = c['frame'] as int;
    final ppm = (c['mentah_ppm'] as List).cast<int>();
    final k = Float32List(t * kelasModel);
    for (var f = 0; f < t; f++) {
      for (var j = 0; j < 14; j++) {
        k[f * kelasModel + kolomModel[j]] = ppm[f * 14 + j] / 1e6;
      }
    }
    return KeluaranCtc(nilai: k, frame: t, kelas: kelasModel);
  }

  final model = Uint8List.fromList(List.generate(64, (i) => i));
  final metaJson = jsonEncode({
    'versi': 'uji',
    'berkas': 'model_uji.onnx',
    'sha256': sha256Dari(model),
    'asal_data': 'publik',
    'bukti_akurasi': 'SINTETIS',
    'alfabet': '0123456789.,-',
    'kolom': kolomModel,
    'ambang_jalur': 0.990,
  });

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

  img.Image polos() {
    final i = img.Image(width: 160, height: 60, numChannels: 3);
    img.fill(i, color: img.ColorRgb8(235, 235, 235));
    return i;
  }

  MesinAngka mesinDengan(SesiPalsu sesi) =>
      MesinAngka(sesi: sesi, meta: MetaModelOcr.dari(metaJson)!);

  final aturan3 = AturanFormatSel(desimal: 3, bolehNegatif: false);

  group('MesinAngka (sesi palsu)', () {
    test('crop bertinta + bacaan yakin + format cocok -> usulan', () async {
      final sesi = SesiPalsu(keluaranDari('crop/002364.png')); // "97,646"
      final h = await mesinDengan(sesi).baca(bertinta(), aturan3);

      expect(sesi.dipanggil, 1);
      expect(h.usulan, '97,646');
      expect(h.jalur, greaterThan(0.99));
    });

    test('masukan model: tensor [1,3,48,lebar] dengan lebar >= 320', () async {
      final sesi = SesiPalsu(keluaranDari('crop/002364.png'));
      await mesinDengan(sesi).baca(bertinta(), aturan3);

      expect(sesi.lebarTerakhir, greaterThanOrEqualTo(320));
      expect(sesi.panjangTerakhir, 3 * 48 * sesi.lebarTerakhir!);
    });

    test('crop tanpa tinta -> kosong TANPA menjalankan model', () async {
      final sesi = SesiPalsu(keluaranDari('crop/002364.png'));
      final h = await mesinDengan(sesi).baca(polos(), aturan3);

      expect(sesi.dipanggil, 0, reason: 'hemat waktu: sel kosong tidak dibaca');
      expect(h.status.name, 'kosong');
      expect(h.alasan?.name, 'tintaKosong');
    });

    test('ambang dari argumen menimpa ambang meta', () async {
      final sesi = SesiPalsu(
        keluaranDari('crop/004512.png'),
      ); // "7723.7" ±0,993
      final m = mesinDengan(sesi);
      final a = AturanFormatSel(desimal: 1, bolehNegatif: true);

      expect((await m.baca(bertinta(), a)).usulan, '7723.7');
      expect((await m.baca(bertinta(), a, ambang: 0.999)).usulan, isNull);
    });
  });

  group('PembacaSelOnnx — pemetaan ke BacaanSel', () {
    PembacaSelOnnx pembaca({
      required Future<MesinAngka?> Function() muat,
      PembacaCadangan? cadangan,
      List<String>? log,
    }) => PembacaSelOnnx(
      cadangan: cadangan ?? PembacaCadangan(),
      muatMesin: muat,
      catat: log?.add,
    );

    test(
      'usulan -> teks + keyakinan = skor jalur (kuning di alur lama)',
      () async {
        final sesi = SesiPalsu(keluaranDari('crop/002364.png'));
        final b = await pembaca(
          muat: () async => mesinDengan(sesi),
        ).bacaBerformat(bertinta(), aturan3);

        expect(b.teks, '97,646');
        expect(b.keyakinan, greaterThanOrEqualTo(0.99));
        expect(b.didalamKotak, isTrue);
      },
    );

    test(
      'ditahan -> keyakinan 0,0 (MERAH, kotak kosong) dengan bacaan mentah',
      () async {
        final sesi = SesiPalsu(
          keluaranDari('crop/004956.png'),
        ); // "0,29" ±0,984
        final b = await pembaca(muat: () async => mesinDengan(sesi))
            .bacaBerformat(
              bertinta(),
              AturanFormatSel(desimal: 2, bolehNegatif: false),
            );

        expect(b.teks, '0,29');
        expect(b.keyakinan, 0.0);
      },
    );

    test(
      'kosong -> teks null (sel tetap kosong, tidak masuk review)',
      () async {
        final b = await pembaca(
          muat: () async =>
              mesinDengan(SesiPalsu(keluaranDari('crop/002364.png'))),
        ).bacaBerformat(polos(), aturan3);

        expect(b.teks, isNull);
        expect(b.keyakinan, isNull);
      },
    );
  });

  group('jatuh ke ML Kit tanpa crash', () {
    test('aturan format tidak ada -> cadangan, mesin TIDAK dimuat', () async {
      final cad = PembacaCadangan();
      var dimuat = 0;
      final p = PembacaSelOnnx(
        cadangan: cad,
        muatMesin: () async {
          dimuat++;
          return null;
        },
      );

      final b = await p.bacaBerformat(bertinta(), null);

      expect(b.teks, 'cadangan');
      expect(cad.dibaca, 1);
      expect(dimuat, 0);
    });

    test(
      'baca() tanpa format selalu cadangan (isian lingkungan, jam, suhu)',
      () async {
        final cad = PembacaCadangan();
        final p = PembacaSelOnnx(cadangan: cad, muatMesin: () async => null);

        expect((await p.baca(bertinta())).teks, 'cadangan');
      },
    );

    test(
      'mesin gagal dimuat (null) -> cadangan, dan muat tidak diulang tiap sel',
      () async {
        final cad = PembacaCadangan();
        var dimuat = 0;
        final p = PembacaSelOnnx(
          cadangan: cad,
          muatMesin: () async {
            dimuat++;
            return null;
          },
        );

        for (var i = 0; i < 3; i++) {
          expect((await p.bacaBerformat(bertinta(), aturan3)).teks, 'cadangan');
        }

        expect(cad.dibaca, 3);
        expect(dimuat, 1);
      },
    );

    test(
      'muatMesin MELEMPAR -> cadangan, tidak ada galat ke pemanggil',
      () async {
        final log = <String>[];
        final p = PembacaSelOnnx(
          cadangan: PembacaCadangan(),
          muatMesin: () async => throw StateError('pustaka native tak terbaca'),
          catat: log.add,
        );

        final b = await p.bacaBerformat(bertinta(), aturan3);

        expect(b.teks, 'cadangan');
        expect(log.single, contains('gagal dimuat'));
      },
    );

    test('sel dibaca paralel: mesin dimuat SEKALI', () async {
      var dimuat = 0;
      final sesi = SesiPalsu(keluaranDari('crop/002364.png'));
      final p = PembacaSelOnnx(
        cadangan: PembacaCadangan(),
        muatMesin: () async {
          dimuat++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return mesinDengan(sesi);
        },
      );

      final hasil = await Future.wait([
        for (var i = 0; i < 5; i++) p.bacaBerformat(bertinta(), aturan3),
      ]);

      expect(dimuat, 1);
      expect(hasil.map((b) => b.teks).toSet(), {'97,646'});
    });

    test(
      'sesi melempar di tengah lembar -> sel itu dan SISANYA lewat cadangan',
      () async {
        final cad = PembacaCadangan();
        final sesi = SesiPalsu(
          keluaranDari('crop/002364.png'),
          lemparPadaPanggilanKe: 2,
        );
        final log = <String>[];
        final p = PembacaSelOnnx(
          cadangan: cad,
          muatMesin: () async => mesinDengan(sesi),
          catat: log.add,
        );

        final a = await p.bacaBerformat(bertinta(), aturan3);
        final b = await p.bacaBerformat(bertinta(), aturan3);
        final c = await p.bacaBerformat(bertinta(), aturan3);

        expect(a.teks, '97,646');
        expect(b.teks, 'cadangan');
        expect(c.teks, 'cadangan');
        expect(
          sesi.dipanggil,
          2,
          reason: 'sesudah galat mesin tidak dicoba lagi',
        );
        expect(log.single, contains('pakai ML Kit'));
      },
    );

    test('tutup() menutup mesin dan cadangan', () async {
      final cad = PembacaCadangan();
      final sesi = SesiPalsu(keluaranDari('crop/002364.png'));
      final p = PembacaSelOnnx(
        cadangan: cad,
        muatMesin: () async => mesinDengan(sesi),
      );

      await p.bacaBerformat(bertinta(), aturan3);
      await p.tutup();

      expect(sesi.ditutup, isTrue);
      expect(cad.ditutup, isTrue);
    });
  });

  group('gerbang pemuatan model', () {
    SumberPalsu sumber({String? meta, Uint8List? berkas}) =>
        SumberPalsu(meta: meta ?? metaJson, model: berkas ?? model);

    Future<SesiInferensiCtc> buat(Uint8List _) async =>
        SesiPalsu(keluaranDari('crop/002364.png'));

    test(
      'meta.json di repo sah, kolomnya = indeks kelas yang dipakai fixture',
      () {
        final m = MetaModelOcr.dari(
          File('assets/models/ocr_angka_en.meta.json').readAsStringSync(),
        )!;

        expect(m.kolom, kolomModel);
        expect(m.berkas, 'ocr_angka_en.tflite');
        expect(m.sha256, hasLength(64));
        expect(m.ambangJalur, 0.990);
        expect(m.buktiSintetis, isTrue, reason: 'belum ada foto nyata');
        expect(m.asalData, 'publik');
      },
    );

    test('lolos semua -> mesin ada', () async {
      final h = await muatMesinAngka(
        sumber: sumber(),
        buatSesi: buat,
        izinkanSintetis: true,
      );

      expect(h.mesin, isNotNull);
      expect(h.ditolak, isNull);
    });

    test(
      'tanpa runtime (BuatSesiCtc null) -> runtimeTidakAda — kondisi build sekarang',
      () async {
        final h = await muatMesinAngka(
          sumber: sumber(),
          buatSesi: null,
          izinkanSintetis: true,
        );

        expect(h.mesin, isNull);
        expect(h.ditolak, PenolakanMesin.runtimeTidakAda);
      },
    );

    test('meta tidak ada -> modelTidakAda', () async {
      final h = await muatMesinAngka(
        sumber: SumberPalsu(),
        buatSesi: buat,
        izinkanSintetis: true,
      );
      expect(h.ditolak, PenolakanMesin.modelTidakAda);
    });

    test('berkas model tidak ada -> modelTidakAda', () async {
      final h = await muatMesinAngka(
        sumber: SumberPalsu(meta: metaJson),
        buatSesi: buat,
        izinkanSintetis: true,
      );
      expect(h.ditolak, PenolakanMesin.modelTidakAda);
    });

    test('meta rusak -> metaTidakSah', () async {
      for (final rusak in [
        'bukan json',
        '[]',
        '{}',
        jsonEncode({
          ...(jsonDecode(metaJson) as Map<String, dynamic>),
          'kolom': [0, 1, 2],
        }),
        jsonEncode({
          ...(jsonDecode(metaJson) as Map<String, dynamic>),
          'sha256': 'abc',
        }),
        jsonEncode({
          ...(jsonDecode(metaJson) as Map<String, dynamic>),
          'berkas': '../model.onnx',
        }),
        jsonEncode({
          ...(jsonDecode(metaJson) as Map<String, dynamic>),
          'alfabet': '0123456789',
        }),
      ]) {
        final h = await muatMesinAngka(
          sumber: sumber(meta: rusak),
          buatSesi: buat,
          izinkanSintetis: true,
        );
        expect(h.ditolak, PenolakanMesin.metaTidakSah, reason: rusak);
      }
    });

    test('berkas tertukar/rusak (sha256 beda) -> sha256TidakCocok', () async {
      final h = await muatMesinAngka(
        sumber: sumber(berkas: Uint8List.fromList([...model, 1])),
        buatSesi: buat,
        izinkanSintetis: true,
      );
      expect(h.ditolak, PenolakanMesin.sha256TidakCocok);
    });

    test('bukti SINTETIS ditolak tanpa sakelar developer', () async {
      final h = await muatMesinAngka(
        sumber: sumber(),
        buatSesi: buat,
        izinkanSintetis: false,
      );
      expect(h.ditolak, PenolakanMesin.buktiSintetisDitolak);
    });

    test('bukti bukan sintetis diterima tanpa sakelar', () async {
      final meta = jsonEncode({
        ...(jsonDecode(metaJson) as Map<String, dynamic>),
        'bukti_akurasi': 'FOTO_NYATA',
      });
      final h = await muatMesinAngka(
        sumber: sumber(meta: meta),
        buatSesi: buat,
        izinkanSintetis: false,
      );
      expect(h.mesin, isNotNull);
    });

    test(
      'runtime gagal membuat sesi -> runtimeGagalDimuat, tanpa melempar',
      () async {
        final h = await muatMesinAngka(
          sumber: sumber(),
          buatSesi: (_) async =>
              throw StateError('libonnxruntime.so tidak ditemukan'),
          izinkanSintetis: true,
        );
        expect(h.ditolak, PenolakanMesin.runtimeGagalDimuat);
      },
    );

    test(
      'SumberFolderOcr membaca meta + model dari folder; SumberBerlapis memilih yang punya meta',
      () async {
        final d = Directory.systemTemp.createTempSync('ocr_uji_');
        addTearDown(() => d.deleteSync(recursive: true));
        File('${d.path}/ocr_angka_en.meta.json').writeAsStringSync(metaJson);
        File('${d.path}/model_uji.onnx').writeAsBytesSync(model);

        final kosong = Directory('${d.path}/tidak_ada');
        final berlapis = SumberBerlapisOcr([
          SumberFolderOcr(kosong),
          SumberFolderOcr(d),
        ]);
        final h = await muatMesinAngka(
          sumber: berlapis,
          buatSesi: buat,
          izinkanSintetis: true,
        );

        expect(h.mesin, isNotNull);
      },
    );
  });

  group('sakelar mati bawaan', () {
    test('SakelarOcr() dan provider: mesin angka MATI', () {
      const s = SakelarOcr();
      expect(s.pakaiMesinAngkaOnnx, isFalse);

      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(sakelarOcrProvider).pakaiMesinAngkaOnnx, isFalse);
    });

    test('tanpa runtime terpasang, buatSesiOcrAngkaProvider null', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(buatSesiOcrAngkaProvider), isNull);
    });

    test(
      'pabrik bawaan memberi ML Kit; sakelar menyala memberi PembacaSelOnnx berlatar ML Kit',
      () {
        final mati = ProviderContainer();
        addTearDown(mati.dispose);
        expect(
          mati.read(pabrikPembacaPindaiProvider).sel(),
          isA<MlKitPembacaSel>(),
        );

        final nyala = ProviderContainer(
          overrides: [
            sakelarOcrProvider.overrideWithValue(
              const SakelarOcr(pakaiMesinAngkaOnnx: true),
            ),
          ],
        );
        addTearDown(nyala.dispose);
        expect(
          nyala.read(pabrikPembacaPindaiProvider).sel(),
          isA<PembacaSelOnnx>(),
        );
      },
    );

    test(
      'sakelar nyala tapi tanpa runtime/model: sel dibaca ML Kit (cadangan), tidak crash',
      () async {
        final nyala = ProviderContainer(
          overrides: [
            sakelarOcrProvider.overrideWithValue(
              const SakelarOcr(pakaiMesinAngkaOnnx: true),
            ),
          ],
        );
        addTearDown(nyala.dispose);

        // Cadangan diganti tiruan: yang diuji jalur muat -> null -> cadangan.
        final cad = PembacaCadangan();
        final p = PembacaSelOnnx(
          cadangan: cad,
          muatMesin: () => muatMesinAngkaBawaan(
            nyala.read(buatSesiOcrAngkaProvider),
            izinkanSintetis: true,
          ),
        );

        expect((await p.bacaBerformat(bertinta(), aturan3)).teks, 'cadangan');
      },
    );
  });
}

/// Sesi tiruan: mengembalikan keluaran tetap.
class SesiPalsu implements SesiInferensiCtc {
  SesiPalsu(this._keluaran, {this.lemparPadaPanggilanKe});

  final KeluaranCtc _keluaran;
  final int? lemparPadaPanggilanKe;

  int dipanggil = 0;
  int? lebarTerakhir;
  int? panjangTerakhir;
  bool ditutup = false;

  @override
  Future<KeluaranCtc> jalankan(Float32List masukan, int lebar) async {
    dipanggil++;
    lebarTerakhir = lebar;
    panjangTerakhir = masukan.length;
    if (dipanggil == lemparPadaPanggilanKe) throw StateError('sesi mati');
    return _keluaran;
  }

  @override
  Future<void> tutup() async => ditutup = true;
}

/// ML Kit tiruan: menandai bacaannya "cadangan".
class PembacaCadangan implements PembacaSel {
  int dibaca = 0;
  bool ditutup = false;

  @override
  Future<BacaanSel> baca(img.Image potongan) async {
    dibaca++;
    return (teks: 'cadangan', keyakinan: null, didalamKotak: true);
  }

  @override
  Future<void> tutup() async => ditutup = true;
}

class SumberPalsu implements SumberModelOcr {
  SumberPalsu({String? meta, Uint8List? model}) : _meta = meta, _berkas = model;

  final String? _meta;
  final Uint8List? _berkas;

  @override
  Future<String?> metaJson() async => _meta;

  @override
  Future<Uint8List?> model(String berkas) async => _berkas;
}
