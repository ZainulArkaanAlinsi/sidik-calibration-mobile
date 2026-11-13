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
import 'package:sidik_calibration/services/ocr_angka/pagar_tinta.dart';
import 'package:sidik_calibration/services/ocr_angka/pemotong_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/sesi_inferensi.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/pembaca_sel_onnx.dart';

/// Keadaan baru mesin angka v2: sel BERTINTA yang tidak menghasilkan bacaan
/// (model diam, pemotong tak yakin, ML Kit diam) adalah `perluCek`, BUKAN
/// kosong; sel tanpa tulisan tetap kosong. Sesi model dipalsukan.
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

  /// Model yang tidak melihat isi: semua frame = blank.
  KeluaranCtc keluaranKosong() {
    const t = 40;
    final k = Float32List(t * kelasModel);
    for (var f = 0; f < t; f++) {
      k[f * kelasModel + kolomModel[0]] = 1.0;
    }

    return KeluaranCtc(
      nilai: k,
      frame: t,
      kelas: kelasModel,
      sudahPeluang: true,
    );
  }

  final model = Uint8List.fromList(List.generate(64, (i) => i));
  final meta = MetaModelOcr.dari(
    jsonEncode({
      'versi': 'uji',
      'berkas': 'model_uji.onnx',
      'sha256': sha256Dari(model),
      'asal_data': 'publik',
      'bukti_akurasi': 'SINTETIS',
      'alfabet': '0123456789.,-',
      'kolom': kolomModel,
      'ambang_jalur': 0.990,
    }),
  )!;

  img.Image kertas(int w, int h) {
    final i = img.Image(width: w, height: h, numChannels: 3);
    img.fill(i, color: img.ColorRgb8(235, 235, 235));

    return i;
  }

  /// Crop bertulisan (gelap 0,038 > gelapMin).
  img.Image bertinta() {
    final i = kertas(160, 60);
    for (var y = 15; y < 45; y++) {
      for (var x = 60; x < 66; x++) {
        i.setPixelRgb(x, y, 30, 30, 30);
      }
    }

    return i;
  }

  final aturan3 = AturanFormatSel(desimal: 3, bolehNegatif: false);

  _Sesi sesiKosong() => _Sesi(keluaranKosong());
  MesinAngka mesin(_Sesi s) => MesinAngka(sesi: s, meta: meta);

  group('putuskanSelAngka: tinta tebal tak terbaca', () {
    final kosong = const HasilDekodeCtc(
      teks: '',
      peluangKarakter: [],
      jalur: 0,
    );

    test('tanpa tanda bertinta: model diam = kosong (perilaku lama)', () {
      final h = putuskanSelAngka(dekode: kosong, aturan: aturan3);

      expect(h.status, StatusSelAngka.kosong);
      expect(h.alasan, AlasanSelAngka.teksKosong);
      expect(h.perluCekTanpaBacaan, isFalse);
    });

    test('bertinta: model diam = perluCek, bukan kosong', () {
      final h = putuskanSelAngka(
        dekode: kosong,
        aturan: aturan3,
        bertinta: true,
      );

      expect(h.status, StatusSelAngka.perluCek);
      expect(h.alasan, AlasanSelAngka.tintaTebalTakTerbaca);
      expect(h.bacaanMentah, isEmpty);
      expect(h.usulan, isNull, reason: 'tidak pernah jadi usulan');
      expect(h.perluCekTanpaBacaan, isTrue);
    });

    test(
      'keluaran tak valid tetap perluCek keluaranTakValid (bukan tanpa bacaan)',
      () {
        final h = putuskanSelAngka(
          dekode: const HasilDekodeCtc.tidakValid(),
          aturan: aturan3,
          bertinta: true,
        );

        expect(h.alasan, AlasanSelAngka.keluaranTakValid);
        expect(h.perluCekTanpaBacaan, isFalse);
      },
    );
  });

  group('MesinAngka.bacaPotongan', () {
    test(
      'tanpa tulisan milik baris -> kosong, model TIDAK dijalankan',
      () async {
        final s = sesiKosong();
        final h = await mesin(
          s,
        ).bacaPotongan(const HasilPotongSel.kosong(), aturan3);

        expect(h.status, StatusSelAngka.kosong);
        expect(h.alasan, AlasanSelAngka.tintaKosong);
        expect(s.dipanggil, 0);
      },
    );

    test(
      'pemotong tidak yakin + ada tinta -> perluCek TANPA menjalankan model',
      () async {
        final s = sesiKosong();
        final h = await mesin(s).bacaPotongan(
          HasilPotongSel(
            crop: bertinta(),
            sebabTakYakin: SebabPemotongTakYakin.tintaMelewatiJendelaVertikal,
          ),
          aturan3,
        );

        expect(h.status, StatusSelAngka.perluCek);
        expect(h.alasan, AlasanSelAngka.pemotongTakYakin);
        expect(h.perluCekTanpaBacaan, isTrue);
        expect(
          s.dipanggil,
          0,
          reason: 'sel yang pemotongnya ragu tidak dibaca model',
        );
      },
    );

    test(
      'crop ADA tetapi pagar menolaknya (pemotong ragu atau yakin) -> perluCek '
      'tintaPudar, bukan kosong',
      () async {
        for (final sebab in [
          null,
          SebabPemotongTakYakin.tintaMenempelTepiSamping,
        ]) {
          final s = sesiKosong();
          final h = await mesin(s).bacaPotongan(
            HasilPotongSel(crop: kertas(30, 60), sebabTakYakin: sebab),
            aturan3,
          );

          expect(h.status, StatusSelAngka.perluCek, reason: '$sebab');
          expect(h.alasan, AlasanSelAngka.tintaPudar);
          expect(h.perluCekTanpaBacaan, isTrue);
          expect(s.dipanggil, 0);
        }
      },
    );

    test('kotak terlalu kecil -> perluCek (tak bisa dinilai kosong)', () async {
      final s = sesiKosong();
      final h = await mesin(s).bacaPotongan(
        const HasilPotongSel(
          sebabTakYakin: SebabPemotongTakYakin.kotakTerlaluKecil,
        ),
        aturan3,
      );

      expect(h.status, StatusSelAngka.perluCek);
      expect(h.perluCekTanpaBacaan, isTrue);
    });

    test('crop bertulisan + model membaca yakin -> usulan', () async {
      final s = _Sesi(keluaranDari('crop/002364.png')); // "97,646"
      final h = await mesin(
        s,
      ).bacaPotongan(HasilPotongSel(crop: bertinta()), aturan3);

      expect(h.usulan, '97,646');
      expect(s.dipanggil, 1);
    });

    test(
      'crop bertulisan + model DIAM (coretan/strip) -> perluCek, bukan kosong',
      () async {
        final s = sesiKosong();
        final h = await mesin(
          s,
        ).bacaPotongan(HasilPotongSel(crop: bertinta()), aturan3);

        expect(s.dipanggil, 1);
        expect(h.status, StatusSelAngka.perluCek);
        expect(h.alasan, AlasanSelAngka.tintaTebalTakTerbaca);
        expect(h.perluCekTanpaBacaan, isTrue);
        expect(h.usulan, isNull);
      },
    );

    test(
      'crop kosong biasa + model diam -> tetap kosong (tidak isi-palsu, tidak dibaca)',
      () async {
        final s = sesiKosong();
        final h = await mesin(s).baca(kertas(160, 60), aturan3);

        expect(h.status, StatusSelAngka.kosong);
        expect(h.alasan, AlasanSelAngka.tintaKosong);
        expect(s.dipanggil, 0);
      },
    );
  });

  group('tinta pudar: rantai PemotongSel -> pagar tinta -> keputusan', () {
    /// Halaman 400×200 kertas 232; empat goresan "angka" di sel (50..268,
    /// 60..104) berabu [rasio] × 232. Abu ternormalisasi = rasio × 255.
    img.Image halamanTinta(double rasio) {
      final abu = (232 * rasio).round();
      final i = img.Image(width: 400, height: 200, numChannels: 3);
      img.fill(i, color: img.ColorRgb8(232, 232, 232));
      for (final x0 in [110, 130, 150, 170]) {
        for (var y = 69; y < 95; y++) {
          for (var x = x0; x < x0 + 4; x++) {
            i.setPixelRgb(x, y, abu, abu, abu);
          }
        }
      }

      return i;
    }

    const kotak = (x: 50.0, y: 60.0, w: 218.0, h: 44.0);

    Future<({HasilPotongSel potong, HasilSelAngka hasil, _Sesi sesi})> jalankan(
      double rasio,
    ) async {
      final potong = PemotongSel.potongSemua(halamanTinta(rasio), [
        kotak,
      ]).single;
      final sesi = sesiKosong();
      final hasil = await mesin(sesi).bacaPotongan(potong, aturan3);

      return (potong: potong, hasil: hasil, sesi: sesi);
    }

    test('tinta pudar (rasio 0,72 / 0,74 / 0,77 / 0,78): pemotong yakin, pagar '
        'menolak -> perluCek, BUKAN kosong', () async {
      for (final rasio in [0.72, 0.74, 0.77, 0.78]) {
        final r = await jalankan(rasio);

        expect(
          r.potong.crop,
          isNotNull,
          reason: 'pemotong melihat tulisan $rasio',
        );
        expect(r.potong.takYakin, isFalse, reason: 'pemotong yakin $rasio');
        expect(
          PagarTinta.adaTinta(PagarTinta.ukur(r.potong.crop!)),
          isFalse,
          reason: 'pagar tidak melihat tinta pada rasio $rasio',
        );
        expect(r.hasil.status, StatusSelAngka.perluCek, reason: 'rasio $rasio');
        expect(
          r.hasil.alasan,
          AlasanSelAngka.tintaPudar,
          reason: 'rasio $rasio',
        );
        expect(r.hasil.perluCekTanpaBacaan, isTrue);
        expect(r.hasil.usulan, isNull);
        expect(r.sesi.dipanggil, 0, reason: 'model tidak dijalankan');
      }
    });

    test(
      'rasio 0,70 (di tepi ambang pagar): TIDAK kosong, jalur mana pun',
      () async {
        final r = await jalankan(0.70);

        expect(r.hasil.status, isNot(StatusSelAngka.kosong));
      },
    );

    test('tinta pekat (rasio 0,35): lolos pagar, model dijalankan', () async {
      final r = await jalankan(0.35);

      expect(r.potong.crop, isNotNull);
      expect(r.sesi.dipanggil, 1);
      // Model diam pada tinta yang jelas ada -> perluCek tinta tebal.
      expect(r.hasil.alasan, AlasanSelAngka.tintaTebalTakTerbaca);
    });

    test('sel benar-benar kosong (tidak ada komponen) tetap kosong', () async {
      final i = img.Image(width: 400, height: 200, numChannels: 3);
      img.fill(i, color: img.ColorRgb8(232, 232, 232));
      final potong = PemotongSel.potongSemua(i, [kotak]).single;
      final sesi = sesiKosong();
      final h = await mesin(sesi).bacaPotongan(potong, aturan3);

      expect(potong.crop, isNull);
      expect(h.status, StatusSelAngka.kosong);
      expect(h.alasan, AlasanSelAngka.tintaKosong);
      expect(h.perluCekTanpaBacaan, isFalse);
      expect(sesi.dipanggil, 0);
    });

    test(
      'BATAS DIKETAHUI: tinta lebih pudar dari 0,78 dianggap kertas oleh pemotong '
      '(sama dengan rig) -> kosong',
      () async {
        final r = await jalankan(0.85);

        expect(r.potong.crop, isNull);
        expect(r.hasil.status, StatusSelAngka.kosong);
      },
    );

    test('PembacaSelOnnx menandai tinta pudar sebagai perlu dicek', () async {
      final potong = PemotongSel.potongSemua(halamanTinta(0.75), [
        kotak,
      ]).single;
      final b = await PembacaSelOnnx(
        cadangan: _Cadangan(null),
        muatMesin: () async => mesin(sesiKosong()),
      ).bacaMesin(kertas(218, 44), potong, aturan3);

      expect(b.perluCekTanpaBacaan, isTrue);
      expect(b.bacaan.teks, isNull);
    });
  });

  group('PembacaSelOnnx.bacaMesin', () {
    PembacaSelOnnx pembaca(MesinAngka? m, PembacaSel cadangan) =>
        PembacaSelOnnx(cadangan: cadangan, muatMesin: () async => m);

    test(
      'tinta tebal tak terbaca: teks null TAPI ditandai perlu dicek',
      () async {
        final cad = _Cadangan(null);
        final b = await pembaca(
          mesin(sesiKosong()),
          cad,
        ).bacaMesin(bertinta(), HasilPotongSel(crop: bertinta()), aturan3);

        expect(b.perluCekTanpaBacaan, isTrue);
        expect(b.bacaan.teks, isNull);
        expect(b.bacaan.keyakinan, isNull);
        expect(
          cad.dibaca,
          0,
          reason: 'mesin tetap aktif; tidak jatuh ke ML Kit',
        );
      },
    );

    test('pemotong tidak yakin -> ditandai, model tidak dijalankan', () async {
      final s = sesiKosong();
      final b = await pembaca(mesin(s), _Cadangan(null)).bacaMesin(
        bertinta(),
        HasilPotongSel(
          crop: bertinta(),
          sebabTakYakin: SebabPemotongTakYakin.garisDatar,
        ),
        aturan3,
      );

      expect(b.perluCekTanpaBacaan, isTrue);
      expect(s.dipanggil, 0);
    });

    test('sel kosong -> teks null dan TIDAK ditandai', () async {
      final b = await pembaca(
        mesin(sesiKosong()),
        _Cadangan(null),
      ).bacaMesin(kertas(160, 60), const HasilPotongSel.kosong(), aturan3);

      expect(b.perluCekTanpaBacaan, isFalse);
      expect(b.bacaan.teks, isNull);
    });

    test('usulan -> teks + keyakinan = skor jalur, tidak ditandai', () async {
      final b = await pembaca(
        mesin(_Sesi(keluaranDari('crop/002364.png'))),
        _Cadangan(null),
      ).bacaMesin(bertinta(), HasilPotongSel(crop: bertinta()), aturan3);

      expect(b.bacaan.teks, '97,646');
      expect(b.bacaan.keyakinan, greaterThanOrEqualTo(0.99));
      expect(b.perluCekTanpaBacaan, isFalse);
    });

    test(
      'ditahan dengan bacaan (jalur rendah) -> keyakinan 0,0, tidak ditandai tanpa-bacaan',
      () async {
        final b =
            await pembaca(
              mesin(_Sesi(keluaranDari('crop/004956.png'))), // "0,29" ±0,984
              _Cadangan(null),
            ).bacaMesin(
              bertinta(),
              HasilPotongSel(crop: bertinta()),
              AturanFormatSel(desimal: 2, bolehNegatif: false),
            );

        expect(b.bacaan.teks, '0,29');
        expect(b.bacaan.keyakinan, 0.0);
        expect(
          b.perluCekTanpaBacaan,
          isFalse,
          reason: 'ada bacaan; alur lama menangani',
        );
      },
    );

    test(
      'tanpa aturan format: ML Kit, mesin tidak dimuat, tidak ditandai',
      () async {
        var dimuat = 0;
        final cad = _Cadangan('12.5');
        final p = PembacaSelOnnx(
          cadangan: cad,
          muatMesin: () async {
            dimuat++;
            return null;
          },
        );

        final b = await p.bacaMesin(bertinta(), null, null);

        expect(b.bacaan.teks, '12.5');
        expect(b.perluCekTanpaBacaan, isFalse);
        expect(dimuat, 0);
      },
    );

    group('jaring terakhir: sel terlalu lebar untuk kanvas 320 px', () {
      img.Image lebar() {
        final i = kertas(900, 100);
        for (var y = 25; y < 75; y++) {
          for (var x = 380; x < 440; x++) {
            i.setPixelRgb(x, y, 30, 30, 30);
          }
        }

        return i;
      }

      MesinAngka mesinLebarTetap() =>
          MesinAngka(sesi: _SesiLebar(keluaranKosong()), meta: meta);

      test(
        'ML Kit membaca; bila membaca teks, hasilnya dipakai apa adanya',
        () async {
          final b = await pembaca(
            mesinLebarTetap(),
            _Cadangan('19.2000'),
          ).bacaMesin(lebar(), HasilPotongSel(crop: lebar()), aturan3);

          expect(b.bacaan.teks, '19.2000');
          expect(b.perluCekTanpaBacaan, isFalse);
        },
      );

      test(
        'ML Kit juga diam padahal bertinta -> perlu dicek (bukan kosong)',
        () async {
          final b = await pembaca(
            mesinLebarTetap(),
            _Cadangan(null),
          ).bacaMesin(lebar(), HasilPotongSel(crop: lebar()), aturan3);

          expect(b.bacaan.teks, isNull);
          expect(b.perluCekTanpaBacaan, isTrue);
        },
      );

      test('sel lebar TANPA tinta tetap kosong (tidak ditandai)', () async {
        // Pemotong tidak menemukan tulisan (crop null), dan jalur lama tanpa
        // pemotong membaca crop kosong: keduanya kosong. (Crop yang ADA tetapi
        // ditolak pagar = tinta pudar -> perluCek; lihat grup tinta pudar.)
        for (final potong in <HasilPotongSel?>[
          const HasilPotongSel.kosong(),
          null,
        ]) {
          final b = await pembaca(
            mesinLebarTetap(),
            _Cadangan(null),
          ).bacaMesin(kertas(900, 100), potong, aturan3);

          expect(b.bacaan.teks, isNull);
          expect(b.perluCekTanpaBacaan, isFalse);
        }
      });
    });

    test('bacaBerformat (jalur lama tanpa pemotong) tetap bekerja', () async {
      final b = await pembaca(
        mesin(_Sesi(keluaranDari('crop/002364.png'))),
        _Cadangan(null),
      ).bacaBerformat(bertinta(), aturan3);

      expect(b.teks, '97,646');
    });
  });

  group('AturanFormatSel: "0" bulat HANYA dengan penanda eksplisit boleh_bulat', () {
    AturanFormatSel? dari({
      double? nominal,
      bool? bolehBulat,
      int? desimal = 4,
    }) => AturanFormatSel.dari(
      AturanSelAsli(
        nominal: nominal,
        desimal: desimal,
        min: 0,
        maks: 5,
        bolehBulat: bolehBulat,
      ),
    );

    test(
      'tanpa penanda: "0" DITOLAK walau nominal tepat 0 (grid suhu Enclosure/Autoklaf)',
      () {
        // Server mengirim nominal = 0 untuk SEMUA baris grid Enclosure/Autoklaf
        // (`titik_ukur` 0,0): turunan `nominal == 0` meloloskan "0" di sel suhu.
        final a = dari(nominal: 0)!;

        expect(a.nolBulat, isFalse);
        expect(a.lolos('0'), isFalse);
        expect(a.lolos('0.0000'), isTrue, reason: 'aturan desimal biasa tetap');
        expect(dari(nominal: 0, bolehBulat: false)!.lolos('0'), isFalse);
        expect(dari(nominal: 1.5)!.lolos('0'), isFalse);
        expect(dari()!.lolos('0'), isFalse);
      },
    );

    test('dengan penanda true: "0" lolos; selain "0" tetap aturan desimal', () {
      final a = dari(nominal: 0, bolehBulat: true)!;

      expect(a.nolBulat, isTrue);
      expect(a.lolos('0'), isTrue);
      expect(a.lolos('0.0000'), isTrue);
      expect(a.lolos('00'), isFalse);
      expect(a.lolos('5'), isFalse, reason: 'hanya persis "0"');
      expect(a.lolos('0.0'), isFalse, reason: 'desimal harus 4');
      expect(a.lolos('0,'), isFalse);
      // Penanda tidak bergantung pada nominal.
      expect(dari(nominal: 3, bolehBulat: true)!.lolos('0'), isTrue);
    });

    test('penanda dibaca dari JSON hanya bila bool sungguhan', () {
      AturanSelAsli? json(Object? v, {bool ada = true}) => AturanSelAsli.dari({
        'tipe': 'desimal',
        'desimal': 4,
        if (ada) 'boleh_bulat': v,
      });

      expect(json(true)!.bolehBulat, isTrue);
      expect(json(false)!.bolehBulat, isFalse);
      expect(json(1)!.bolehBulat, isNull);
      expect(json('true')!.bolehBulat, isNull);
      expect(
        json(null, ada: false)!.bolehBulat,
        isNull,
        reason: 'server belum mengirim',
      );
      expect(AturanFormatSel.dari(json(true))!.lolos('0'), isTrue);
      expect(AturanFormatSel.dari(json(null, ada: false))!.lolos('0'), isFalse);
    });

    test('templat tanpa desimal: tetap null (mesin tidak dipakai)', () {
      expect(dari(nominal: 0, bolehBulat: true, desimal: null), isNull);
    });
  });
}

/// Sesi tiruan: keluaran tetap, mencatat jumlah panggilan.
class _Sesi implements SesiInferensiCtc {
  _Sesi(this._keluaran);

  final KeluaranCtc _keluaran;
  int dipanggil = 0;

  @override
  Future<KeluaranCtc> jalankan(Float32List masukan, int lebar) async {
    dipanggil++;

    return _keluaran;
  }

  @override
  Future<void> tutup() async {}
}

/// Sesi berlebar tetap 320 (seperti TFLite).
class _SesiLebar extends _Sesi implements SesiLebarTetap {
  _SesiLebar(super.keluaran);

  @override
  int get lebarTetap => 320;
}

/// ML Kit tiruan: balikan tetap (null = tidak menemukan teks).
class _Cadangan implements PembacaSel {
  _Cadangan(this.teks);

  final String? teks;
  int dibaca = 0;

  @override
  Future<BacaanSel> baca(img.Image potongan) async {
    dibaca++;

    return (teks: teks, keyakinan: null, didalamKotak: true);
  }

  @override
  Future<void> tutup() async {}
}
