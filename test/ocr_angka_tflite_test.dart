import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sidik_calibration/providers/sakelar_ocr_provider.dart';
import 'package:sidik_calibration/providers/worksheet_scan_provider.dart';
import 'package:sidik_calibration/services/ocr_angka/aturan_format_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/dekoder_ctc.dart';
import 'package:sidik_calibration/services/ocr_angka/keputusan_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/mesin_angka.dart';
import 'package:sidik_calibration/services/ocr_angka/meta_model.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin.dart';
import 'package:sidik_calibration/services/ocr_angka/muat_mesin_bawaan.dart';
import 'package:sidik_calibration/services/ocr_angka/pelari_tflite.dart';
import 'package:sidik_calibration/services/ocr_angka/praproses_sel.dart';
import 'package:sidik_calibration/services/ocr_angka/sesi_inferensi.dart';
import 'package:sidik_calibration/services/ocr_angka/sesi_inferensi_tflite.dart';
import 'package:sidik_calibration/services/ocr_angka/sumber_model_ocr.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/pembaca_sel_onnx.dart';

/// Adaptor `SesiInferensiTflite` TANPA runtime native: pelari tiruan menggantikan
/// LiteRT. Yang diuji: penataan masukan NHWC, pembacaan keluaran PELUANG,
/// pagar lebar 320, pemuatan malas satu kali, penutupan, dan jatuh ke ML Kit.
/// Inferensi nyata hanya terbukti di perangkat (`integration_test/
/// ocr_tflite_hp_test.dart`).
void main() {
  const kontrakSah = KontrakTensor(
    bentukMasukan: [1, 48, 320, 3],
    tipeMasukan: 'float32',
    bentukKeluaran: [1, 40, 438],
    tipeKeluaran: 'float32',
  );

  final fx =
      jsonDecode(
            File(
              'test/fixtures/ocr_angka/paritas_dekode.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final contoh = (fx['contoh'] as List).cast<Map<String, dynamic>>();
  final kolomModel = (fx['kolom_model'] as List).cast<int>();

  /// Keluaran model `[40,438]` PELUANG dari fixture rig (14 kolom whitelist).
  Float32List peluangDari(String file) {
    final c = contoh.firstWhere((c) => c['file'] == file);
    final ppm = (c['mentah_ppm'] as List).cast<int>();
    final k = Float32List(40 * 438);
    for (var f = 0; f < 40; f++) {
      for (var j = 0; j < 14; j++) {
        k[f * 438 + kolomModel[j]] = ppm[f * 14 + j] / 1e6;
      }
    }

    return k;
  }

  final meta = MetaModelOcr.dari(
    jsonEncode({
      'versi': 'uji',
      'berkas': 'ocr_angka_en.tflite',
      'sha256': sha256Dari(Uint8List.fromList([1, 2, 3])),
      'asal_data': 'publik',
      'bukti_akurasi': 'SINTETIS',
      'alfabet': '0123456789.,-',
      'kolom': kolomModel,
      'ambang_jalur': 0.990,
    }),
  )!;

  /// Crop [w]×[h] kertas abu-abu; [tinta] menaruh batang gelap di tengah.
  img.Image crop(int w, int h, {bool tinta = true}) {
    final i = img.Image(width: w, height: h, numChannels: 3);
    img.fill(i, color: img.ColorRgb8(235, 235, 235));
    if (tinta) {
      for (var y = h ~/ 4; y < h - h ~/ 4; y++) {
        for (var x = w ~/ 2 - 3; x < w ~/ 2 + 3; x++) {
          i.setPixelRgb(x, y, 30, 30, 30);
        }
      }
    }

    return i;
  }

  final aturan3 = AturanFormatSel(desimal: 3, bolehNegatif: false);

  group('chwKeNhwc', () {
    test('piksel (kanal, y, x) pindah ke (y, x, kanal), tanpa ubah nilai', () {
      final chw = Float32List(3 * 48 * 320);
      for (var c = 0; c < 3; c++) {
        for (var y = 0; y < 48; y++) {
          for (var x = 0; x < 320; x++) {
            chw[(c * 48 + y) * 320 + x] = c * 1e6 + y * 1e3 + x;
          }
        }
      }

      final nhwc = SesiInferensiTflite.chwKeNhwc(chw);

      expect(nhwc.length, chw.length);
      for (var y = 0; y < 48; y++) {
        for (var x = 0; x < 320; x++) {
          for (var c = 0; c < 3; c++) {
            expect(
              nhwc[(y * 320 + x) * 3 + c],
              chw[(c * 48 + y) * 320 + x],
              reason: 'c=$c y=$y x=$x',
            );
          }
        }
      }
    });

    test('dari PraprosesSel: kanal BGR, normalisasi, pad kanan tetap nol', () {
      // Piksel merah murni (RGB 255,0,0) -> BGR (0,0,255) -> (-1,-1,+1).
      final merah = img.Image(width: 150, height: 48, numChannels: 3);
      img.fill(merah, color: img.ColorRgb8(255, 0, 0));

      final t = PraprosesSel.proses(merah);
      expect(t.lebar, 320);
      expect(t.lebarIsi, 150);

      final nhwc = SesiInferensiTflite.chwKeNhwc(t.data);
      double px(int y, int x, int c) => nhwc[(y * 320 + x) * 3 + c];

      expect([px(10, 20, 0), px(10, 20, 1), px(10, 20, 2)], [-1.0, -1.0, 1.0]);
      for (var y = 0; y < 48; y++) {
        for (var x = 150; x < 320; x++) {
          for (var c = 0; c < 3; c++) {
            expect(px(y, x, c), 0.0, reason: 'pad harus 0 ($y,$x,$c)');
          }
        }
      }
    });

    test('panjang salah ditolak', () {
      expect(
        () => SesiInferensiTflite.chwKeNhwc(Float32List(10)),
        throwsArgumentError,
      );
    });
  });

  group('periksaKontrak', () {
    KontrakTensor ubah({
      List<int>? masuk,
      String? tipeMasuk,
      List<int>? keluar,
      String? tipeKeluar,
    }) => KontrakTensor(
      bentukMasukan: masuk ?? kontrakSah.bentukMasukan,
      tipeMasukan: tipeMasuk ?? kontrakSah.tipeMasukan,
      bentukKeluaran: keluar ?? kontrakSah.bentukKeluaran,
      tipeKeluaran: tipeKeluar ?? kontrakSah.tipeKeluaran,
    );

    test('kontrak sah lolos', () {
      SesiInferensiTflite.periksaKontrak(kontrakSah);
    });

    for (final kasus in {
      'masukan NCHW [1,3,48,320]': ubah(masuk: [1, 3, 48, 320]),
      'masukan berlebar dinamis [1,48,-1,3]': ubah(masuk: [1, 48, -1, 3]),
      'masukan lain lebar [1,48,480,3]': ubah(masuk: [1, 48, 480, 3]),
      'masukan int8 (model kuantisasi)': ubah(tipeMasuk: 'int8'),
      'keluaran 20 frame': ubah(keluar: [1, 20, 438]),
      'keluaran lain jumlah kelas': ubah(keluar: [1, 40, 6625]),
      'keluaran uint8': ubah(tipeKeluar: 'uint8'),
    }.entries) {
      test('${kasus.key} -> ditolak', () {
        expect(
          () => SesiInferensiTflite.periksaKontrak(kasus.value),
          throwsStateError,
        );
      });
    }
  });

  group('SesiInferensiTflite (pelari tiruan)', () {
    late PelariPalsu pelari;
    late int dimuat;

    SesiInferensiTflite sesi({PelariPalsu? p, Duration? lambatMuat}) {
      pelari = p ?? PelariPalsu(keluaran: peluangDari('crop/002364.png'));
      dimuat = 0;

      return SesiInferensiTflite(
        muatPelari: () async {
          dimuat++;
          if (lambatMuat != null) await Future<void>.delayed(lambatMuat);

          return pelari;
        },
      );
    }

    Float32List tensorChw() => PraprosesSel.proses(crop(160, 60)).data;

    test('masukan ke model = tensor CHW yang ditata NHWC', () async {
      final s = sesi();
      final chw = tensorChw();

      await s.jalankan(chw, 320);

      expect(pelari.masukanTerakhir, SesiInferensiTflite.chwKeNhwc(chw));
      expect(pelari.masukanTerakhir!.length, 1 * 48 * 320 * 3);
    });

    test(
      'keluaran: 40 frame x 438 kelas, nilai PELUANG diteruskan apa adanya',
      () async {
        final s = sesi();
        final k = await s.jalankan(tensorChw(), 320);

        expect(k.frame, 40);
        expect(k.kelas, 438);
        expect(k.nilai, pelari.keluaran);
        expect(
          k.sudahPeluang,
          isTrue,
          reason: 'bukan logit: jangan di-softmax',
        );
        // Peluang, bukan logit: tiap frame berjumlah ~1.
        var jumlah = 0.0;
        for (var c = 0; c < 438; c++) {
          jumlah += k.nilai[c];
        }
        expect(jumlah, closeTo(1.0, 1e-2));
      },
    );

    test('lebar selain 320 ditolak sebelum menyentuh model', () async {
      final s = sesi();

      await expectLater(
        s.jalankan(Float32List(3 * 48 * 480), 480),
        throwsArgumentError,
      );
      expect(dimuat, 0, reason: 'model tidak perlu dimuat untuk masukan salah');
      expect(pelari.dipanggil, 0);
    });

    test('panjang tensor salah ditolak', () async {
      final s = sesi();

      await expectLater(s.jalankan(Float32List(100), 320), throwsArgumentError);
      expect(pelari.dipanggil, 0);
    });

    test('keluaran model dengan ukuran lain -> galat, bukan tebakan', () async {
      final s = sesi(p: PelariPalsu(keluaran: Float32List(40 * 437)));

      await expectLater(s.jalankan(tensorChw(), 320), throwsStateError);
    });

    test(
      'kontrak model salah -> galat, pelari ditutup, tidak dicoba ulang',
      () async {
        final salah = PelariPalsu(
          keluaran: Float32List(40 * 438),
          kontrak: const KontrakTensor(
            bentukMasukan: [1, 3, 48, 320],
            tipeMasukan: 'float32',
            bentukKeluaran: [1, 40, 438],
            tipeKeluaran: 'float32',
          ),
        );
        final s = sesi(p: salah);

        await expectLater(s.siapkan(), throwsStateError);
        await expectLater(s.jalankan(tensorChw(), 320), throwsStateError);
        expect(dimuat, 1, reason: 'kegagalan diingat, tidak memuat ulang');
        expect(salah.ditutup, 1);
        expect(salah.dipanggil, 0);
      },
    );

    test('pemuatan MALAS: tidak ada pemuatan sebelum dipakai', () async {
      final s = sesi();
      expect(dimuat, 0);

      await s.tutup();
      expect(dimuat, 0, reason: 'tutup tanpa pernah dipakai tidak memuat');
    });

    test('pemuatan SATU kali walau dipanggil bersamaan', () async {
      final s = sesi(lambatMuat: const Duration(milliseconds: 30));
      final chw = tensorChw();

      final hasil = await Future.wait([
        for (var i = 0; i < 5; i++) s.jalankan(chw, 320),
      ]);

      expect(hasil, hasLength(5));
      expect(dimuat, 1);
      expect(pelari.dipanggil, 5);
    });

    test(
      'tutup melepas pelari sekali, aman diulang, lalu menolak pakai',
      () async {
        final s = sesi();
        await s.jalankan(tensorChw(), 320);

        await s.tutup();
        await s.tutup();

        expect(pelari.ditutup, 1);
        await expectLater(s.jalankan(tensorChw(), 320), throwsStateError);
        await expectLater(s.siapkan(), throwsStateError);
      },
    );

    test('tutup menunggu pemuatan yang sedang berjalan', () async {
      final s = sesi(lambatMuat: const Duration(milliseconds: 40));
      final siap = s.siapkan();

      await s.tutup();
      await siap;

      expect(pelari.ditutup, 1);
    });

    test(
      'mati hanya bila pelarinya mati (belum dimuat = belum mati)',
      () async {
        final s = sesi();
        expect(s.mati, isFalse);

        await s.siapkan();
        expect(s.mati, isFalse);

        pelari.mati = true;
        expect(s.mati, isTrue);
      },
    );

    test('lebarTetap = kanvas PraprosesSel (320)', () {
      final s = sesi();

      expect(s, isA<SesiLebarTetap>());
      expect(s.lebarTetap, 320);
      expect(s.lebarTetap, PraprosesSel.lebarMin);
    });
  });

  group('MesinAngka di atas SesiInferensiTflite', () {
    MesinAngka mesin(PelariPalsu p) => MesinAngka(
      sesi: SesiInferensiTflite(muatPelari: () async => p),
      meta: meta,
    );

    test(
      'keluaran peluang rig -> teks dan skor sama dengan dekode rig',
      () async {
        // Fixture: crop/002364.png = "97,646", jalur 0,996936 (rig, ONNX).
        final p = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
        final h = await mesin(p).baca(crop(160, 60), aturan3);

        expect(p.dipanggil, 1);
        expect(h.status, StatusSelAngka.usulanKeyakinanTinggi);
        expect(h.usulan, '97,646');
        expect(h.jalur, closeTo(0.996936, 2e-4));
      },
    );

    test('semua contoh rig: teks identik dan skor dalam 2e-4', () async {
      for (final c in contoh) {
        final p = PelariPalsu(keluaran: peluangDari(c['file'] as String));
        final h = await mesin(p).baca(
          crop(160, 60),
          AturanFormatSel(
            desimal: ((c['desimal'] as int) < 0 ? 4 : c['desimal'] as int),
            bolehNegatif: true,
          ),
          // Ambang 0: ukur bacaan mentah, bukan keputusan.
          ambang: 0.5,
        );

        expect(h.bacaanMentah, c['teks'], reason: c['file'] as String);
        expect(
          h.jalur,
          closeTo((c['jalur'] as num).toDouble(), 2e-4),
          reason: c['file'] as String,
        );
      }
    });

    test('peluang TIDAK di-softmax ulang (akan meratakan skor)', () async {
      // Satu frame yakin 0,999 untuk "5": bila dianggap logit, softmax atas
      // 438 kelas memberi skor jauh di bawah 0,99.
      final k = Float32List(40 * 438);
      for (var f = 0; f < 40; f++) {
        k[f * 438 + 0] = 0.999;
        k[f * 438 + 437] = 0.001;
      }
      for (var f = 10; f < 13; f++) {
        k[f * 438 + 0] = 0.001;
        k[f * 438 + 6] = 0.999; // '5' = indeks kelas 6
      }
      final h = await mesin(
        PelariPalsu(keluaran: k),
      ).baca(crop(160, 60), AturanFormatSel(desimal: 0, bolehNegatif: false));

      expect(h.bacaanMentah, '5');
      expect(h.jalur, greaterThan(0.999));
      expect(h.usulan, '5');
    });

    group('pagar lebar tetap 320', () {
      test('hasil resize 320 piksel masih dibaca', () async {
        final p = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
        // 320x48 -> ceil(48*320/48) = 320.
        final h = await mesin(p).baca(crop(320, 48), aturan3);

        expect(p.dipanggil, 1);
        expect(h.status, isNot(StatusSelAngka.kosong));
      });

      test(
        'MesinAngka: hasil resize 321 piksel DITAHAN (ukuranTakWajar), model tidak jalan',
        () async {
          final p = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
          // 321x48 -> 321 > 320.
          final h = await mesin(p).baca(crop(321, 48), aturan3);

          expect(p.dipanggil, 0);
          expect(h.status, StatusSelAngka.kosong);
          expect(h.alasan, AlasanSelAngka.ukuranTakWajar);
          expect(h.usulan, isNull);
        },
      );

      test(
        'MesinAngka: sel sangat lebar dan berisi: ditahan, tanpa usulan',
        () async {
          final p = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
          final h = await mesin(p).baca(crop(900, 100), aturan3);

          expect(p.dipanggil, 0);
          expect(h.alasan, AlasanSelAngka.ukuranTakWajar);
        },
      );

      test(
        'MesinAngka: sel lebar TANPA tinta tetap dilaporkan tintaKosong',
        () async {
          final p = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
          final h = await mesin(p).baca(crop(900, 100, tinta: false), aturan3);

          expect(p.dipanggil, 0);
          expect(h.alasan, AlasanSelAngka.tintaKosong);
        },
      );

      test('sesi berlebar dinamis (ONNX) tidak kena pagar ini', () async {
        final sesi = SesiDinamis(
          KeluaranCtc(
            nilai: peluangDari('crop/002364.png'),
            frame: 40,
            kelas: 438,
          ),
        );
        final m = MesinAngka(sesi: sesi, meta: meta);

        // 500x48 -> lebar 500 > 320, tetapi sesi ini menerima lebar apa pun.
        await m.baca(crop(500, 48), aturan3);

        expect(sesi.dipanggil, 1);
        expect(sesi.lebarTerakhir, 500);
      });
    });
  });

  group(
    'PembacaSelOnnx: sel bertinta yang tak muat di kanvas dibaca ML Kit',
    () {
      PembacaSelOnnx pembaca(
        PelariPalsu p,
        PembacaCadangan cad, {
        List<String>? log,
      }) => PembacaSelOnnx(
        cadangan: cad,
        muatMesin: () async => MesinAngka(
          sesi: SesiInferensiTflite(muatPelari: () async => p),
          meta: meta,
        ),
        catat: log?.add,
      );

      test(
        'lebar 321 px: ML Kit yang membaca, bukan kosong dan bukan teks model',
        () async {
          // Bila model dijalankan ia akan menjawab "97,646" (usulan).
          final p = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
          final cad = PembacaCadangan();
          final log = <String>[];

          final b = await pembaca(
            p,
            cad,
            log: log,
          ).bacaBerformat(crop(321, 48), aturan3);

          expect(b.teks, 'cadangan');
          expect(cad.dibaca, 1);
          expect(
            p.dipanggil,
            0,
            reason: 'model tidak dijalankan untuk sel ini',
          );
          expect(log.single, contains('ML Kit'));
        },
      );

      test('sel sangat lebar dan berisi juga ke ML Kit', () async {
        final p = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
        final cad = PembacaCadangan();

        final b = await pembaca(p, cad).bacaBerformat(crop(900, 100), aturan3);

        expect(b.teks, 'cadangan');
        expect(cad.dibaca, 1);
      });

      test('mesin TETAP aktif: sel normal berikutnya dibaca model', () async {
        final p = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
        final cad = PembacaCadangan();
        final pb = pembaca(p, cad);

        await pb.bacaBerformat(crop(321, 48), aturan3);
        final b = await pb.bacaBerformat(crop(160, 60), aturan3);

        expect(b.teks, '97,646', reason: 'dibaca model, bukan cadangan');
        expect(cad.dibaca, 1, reason: 'hanya sel lebar yang ke ML Kit');
        expect(p.dipanggil, 1);
      });

      test(
        'sel lebar yang memang KOSONG (di bawah pagar tinta) tetap kosong',
        () async {
          final p = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
          final cad = PembacaCadangan();

          final b = await pembaca(
            p,
            cad,
          ).bacaBerformat(crop(900, 100, tinta: false), aturan3);

          expect(b.teks, isNull);
          expect(cad.dibaca, 0, reason: 'sel kosong tidak boleh diisi ML Kit');
          expect(p.dipanggil, 0);
        },
      );
    },
  );

  group('DekoderCtc.ambilKolom: peluang vs logit', () {
    // Dua frame, baris pertama berjumlah 0,2 (BUKAN 1): tebakan lama
    // menganggapnya logit dan men-softmax; bendera eksplisit tidak.
    Float32List baris() {
      final k = Float32List(2 * 438);
      k[0] = 0.2;
      k[1 * 438 + 0] = 0.2;

      return k;
    }

    test('sudahPeluang: true memakai nilai apa adanya', () {
      final m = DekoderCtc.ambilKolom(
        baris(),
        2,
        438,
        kolomModel,
        sudahPeluang: true,
      );

      expect(m[0], closeTo(0.2, 1e-7));
      expect(m[1], 0.0);
    });

    test('sudahPeluang: false men-softmax', () {
      final m = DekoderCtc.ambilKolom(
        baris(),
        2,
        438,
        kolomModel,
        sudahPeluang: false,
      );

      // exp(0) / (exp(0) + 436 x exp(-0,2)... ) bukan 0,2: cukup dipastikan
      // berubah dan berada di (0, 1).
      expect(m[0], isNot(closeTo(0.2, 1e-3)));
      expect(m[0], inExclusiveRange(0.0, 1.0));
    });

    test(
      'tanpa bendera: tebakan lama (jumlah != 1 -> softmax) tidak berubah',
      () {
        final tebak = DekoderCtc.ambilKolom(baris(), 2, 438, kolomModel);
        final logit = DekoderCtc.ambilKolom(
          baris(),
          2,
          438,
          kolomModel,
          sudahPeluang: false,
        );

        expect(tebak, logit);
      },
    );
  });

  group('sakelar mati tidak menyentuh model', () {
    test('bawaan: tidak ada pabrik sesi, pembaca pindai = ML Kit', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(sakelarOcrProvider).pakaiMesinAngkaOnnx, isFalse);
      expect(c.read(buatSesiOcrAngkaProvider), isNull);
      expect(c.read(pabrikPembacaPindaiProvider).sel(), isA<MlKitPembacaSel>());
    });

    test(
      'tanpa pabrik sesi, gerbang muat berhenti SEBELUM membuka sumber model',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final sumber = SumberPencatat();

        final h = await muatMesinAngka(
          sumber: sumber,
          buatSesi: c.read(buatSesiOcrAngkaProvider),
          izinkanSintetis: true,
        );

        expect(h.ditolak, PenolakanMesin.runtimeTidakAda);
        expect(h.mesin, isNull);
        expect(sumber.dibuka, 0, reason: 'model tidak boleh dibaca saat mati');
        expect(await muatMesinAngkaBawaan(null, izinkanSintetis: true), isNull);
      },
    );

    test(
      'sakelar menyala: pabrik sesi TFLite tersedia, pembaca pindai = PembacaSelOnnx',
      () {
        final c = ProviderContainer(
          overrides: [
            sakelarOcrProvider.overrideWithValue(
              const SakelarOcr(pakaiMesinAngkaOnnx: true),
            ),
          ],
        );
        addTearDown(c.dispose);

        expect(c.read(buatSesiOcrAngkaProvider), isNotNull);
        expect(
          c.read(pabrikPembacaPindaiProvider).sel(),
          isA<PembacaSelOnnx>(),
        );
      },
    );

    test('sakelar lain menyala tidak ikut menyalakan mesin angka', () {
      final c = ProviderContainer(
        overrides: [
          sakelarOcrProvider.overrideWithValue(
            const SakelarOcr(kumpulkanContohSel: true, pakaiModelDigit: true),
          ),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(buatSesiOcrAngkaProvider), isNull);
    });
  });

  group('PabrikSesiTfliteBersama: model dimuat sekali per proses', () {
    late PelariPalsu pelari;
    late List<PelariPalsu> pelaris;
    late int pabrikDipanggil;

    /// [gagalDulu]: berapa pemuatan pertama yang gagal (pustaka native hilang).
    PabrikSesiTfliteBersama pabrik({int gagalDulu = 0}) {
      pelaris = [];
      pabrikDipanggil = 0;

      return PabrikSesiTfliteBersama((model) async {
        pabrikDipanggil++;
        if (pabrikDipanggil <= gagalDulu) {
          throw StateError('pustaka native tidak ada');
        }

        final baru = PelariPalsu(keluaran: peluangDari('crop/002364.png'));
        pelari = baru;
        pelaris.add(baru);

        // Seperti `SesiInferensiTflite.dariByte`: pelari dimuat SEKARANG.
        final sesi = SesiInferensiTflite(muatPelari: () async => baru);
        await sesi.siapkan();

        return sesi;
      });
    }

    final model = Uint8List.fromList([1, 2, 3]);

    test(
      'dua foto berturut-turut memakai satu model; tutup() tidak menutupnya',
      () async {
        final p = pabrik();

        final foto1 = await p.buat(model);
        await foto1.jalankan(PraprosesSel.proses(crop(160, 60)).data, 320);
        await foto1.tutup();

        final foto2 = await p.buat(model);
        await foto2.jalankan(PraprosesSel.proses(crop(160, 60)).data, 320);
        await foto2.tutup();

        expect(pabrikDipanggil, 1, reason: 'tidak memuat ulang per foto');
        expect(pelari.dipanggil, 2);
        expect(
          pelari.ditutup,
          0,
          reason: 'model dipegang pabrik, bukan sesi foto',
        );
      },
    );

    test('sesi bersama tetap membawa pagar lebar 320', () async {
      final p = pabrik();
      final sesi = await p.buat(model);

      expect(sesi, isA<SesiLebarTetap>());
      expect((sesi as SesiLebarTetap).lebarTetap, 320);
    });

    test('pemanggilan bersamaan berbagi satu pemuatan', () async {
      final p = pabrik();

      await Future.wait([for (var i = 0; i < 4; i++) p.buat(model)]);

      expect(pabrikDipanggil, 1);
    });

    test(
      'gagal memuat SEKALI: foto berikutnya boleh mencoba sekali lagi',
      () async {
        final p = pabrik(gagalDulu: 1);

        await expectLater(p.buat(model), throwsStateError);
        expect(p.menyerah, isFalse);
        final sesi = await p.buat(model);
        await sesi.jalankan(PraprosesSel.proses(crop(160, 60)).data, 320);

        expect(pabrikDipanggil, 2);
        expect(pelari.dipanggil, 1);
      },
    );

    test(
      'gagal memuat DUA kali: menyerah, percobaan ketiga tidak membuka pabrik',
      () async {
        final p = pabrik(gagalDulu: 99);

        await expectLater(p.buat(model), throwsStateError);
        await expectLater(p.buat(model), throwsStateError);
        expect(p.menyerah, isTrue);

        // Foto ke-3, ke-4, ...: langsung gagal. Tanpa ingatan ini tiap foto
        // membuka isolate dan membocorkan >= 7,8 MB memori native lagi.
        await expectLater(p.buat(model), throwsStateError);
        await expectLater(p.buat(model), throwsStateError);
        expect(pabrikDipanggil, PabrikSesiTfliteBersama.batasGagal);
      },
    );

    test(
      'gagal serentak dihitung sekali per pemuatan, bukan per pemanggil',
      () async {
        final p = pabrik(gagalDulu: 99);

        final hasil = await Future.wait([
          p.buat(model).then<Object?>((_) => null, onError: (Object e) => e),
          p.buat(model).then<Object?>((_) => null, onError: (Object e) => e),
          p.buat(model).then<Object?>((_) => null, onError: (Object e) => e),
        ]);

        expect(hasil.whereType<StateError>(), hasLength(3));
        expect(pabrikDipanggil, 1);
        expect(p.menyerah, isFalse, reason: 'baru satu pemuatan yang gagal');
      },
    );

    test(
      'gerbang muat berhenti SEBELUM membuka sumber model sesudah menyerah',
      () async {
        final p = pabrik(gagalDulu: 99);
        final sumber = SumberPencatat();
        Future<HasilMuatMesin> gerbang() => muatMesinAngka(
          sumber: sumber,
          buatSesi: p.buat,
          izinkanSintetis: true,
          menyerah: () => p.menyerah,
        );

        // Sebelum menyerah gerbang membuka sumber model.
        await gerbang();
        expect(sumber.dibuka, greaterThan(0));
        // Dua pemuatan runtime gagal (di aplikasi: dua foto berturut-turut).
        await expectLater(p.buat(model), throwsStateError);
        await expectLater(p.buat(model), throwsStateError);
        expect(p.menyerah, isTrue);

        final dibukaSebelum = sumber.dibuka;
        final h = await gerbang();

        expect(h.mesin, isNull);
        expect(h.ditolak, PenolakanMesin.runtimeGagalDimuat);
        expect(sumber.dibuka, dibukaSebelum, reason: 'aset tidak dibaca lagi');
        expect(pabrikDipanggil, PabrikSesiTfliteBersama.batasGagal);
      },
    );

    test(
      'muatMesinAngkaBawaan: menyerah -> null tanpa menyentuh pabrik',
      () async {
        final p = pabrik();
        var ditanya = 0;

        final mesin = await muatMesinAngkaBawaan(
          p.buat,
          izinkanSintetis: true,
          menyerah: () {
            ditanya++;
            return true;
          },
        );

        expect(mesin, isNull);
        expect(pabrikDipanggil, 0);
        // Ditanya SEBELUM sumber model dibuka: di mesin test membuka sumber
        // bawaan (path_provider) gagal dan hasilnya tetap null, jadi hanya
        // hitungan ini yang membedakan "berhenti lebih awal".
        expect(ditanya, 1);
      },
    );

    test('pekerja MATI: sesi dibuang dan model dimuat ulang SEKALI', () async {
      final p = pabrik();
      final foto1 = await p.buat(model);
      await foto1.jalankan(PraprosesSel.proses(crop(160, 60)).data, 320);
      final pertama = pelari;

      pertama.mati = true;
      final foto2 = await p.buat(model);
      await foto2.jalankan(PraprosesSel.proses(crop(160, 60)).data, 320);

      expect(pabrikDipanggil, 2);
      expect(pertama.ditutup, 1, reason: 'sesi mati dibuang');
      expect(pelaris, hasLength(2));
      expect(pelaris[1].dipanggil, 1, reason: 'foto 2 dibaca pelari baru');
      expect(pertama.dipanggil, 1);
      expect(p.menyerah, isFalse);
    });

    test(
      'pekerja mati LAGI sesudah dimuat ulang: menyerah, tidak ada muat ketiga',
      () async {
        final p = pabrik();
        await p.buat(model);
        pelaris[0].mati = true;
        await p.buat(model); // muat ulang (jatah satu-satunya)
        pelaris[1].mati = true;

        await expectLater(p.buat(model), throwsStateError);
        expect(p.menyerah, isTrue);
        await expectLater(p.buat(model), throwsStateError);

        expect(pabrikDipanggil, 2, reason: 'tidak ada loop muat ulang');
        expect(pelaris[1].ditutup, 1);
      },
    );

    test(
      'dua pemanggil melihat pekerja mati bersamaan: satu muat ulang saja',
      () async {
        final p = pabrik();
        await p.buat(model);
        pelaris[0].mati = true;

        final sesi = await Future.wait([p.buat(model), p.buat(model)]);
        await sesi[0].jalankan(PraprosesSel.proses(crop(160, 60)).data, 320);
        await sesi[1].jalankan(PraprosesSel.proses(crop(160, 60)).data, 320);

        expect(pabrikDipanggil, 2);
        expect(pelaris[1].dipanggil, 2, reason: 'keduanya memakai pelari baru');
      },
    );

    test(
      'lepas() menutup model sekali, aman diulang, lalu menolak buat()',
      () async {
        final p = pabrik();
        final sesi = await p.buat(model);
        await sesi.jalankan(PraprosesSel.proses(crop(160, 60)).data, 320);

        await p.lepas();
        await p.lepas();

        expect(pelari.ditutup, 1);
        await expectLater(p.buat(model), throwsStateError);
      },
    );

    test('lepas() tanpa pernah dipakai tidak memuat apa pun', () async {
      final p = pabrik();

      await p.lepas();

      expect(pabrikDipanggil, 0);
    });

    test('provider: sakelar menyala memberi pabrik yang sama tiap dibaca', () {
      final c = ProviderContainer(
        overrides: [
          sakelarOcrProvider.overrideWithValue(
            const SakelarOcr(pakaiMesinAngkaOnnx: true),
          ),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(buatSesiOcrAngkaProvider), isNotNull);
      expect(c.read(pabrikSesiOcrAngkaProvider), isNotNull);
      expect(c.read(pabrikSesiOcrAngkaProvider)!.menyerah, isFalse);
      expect(
        c.read(buatSesiOcrAngkaProvider),
        same(c.read(buatSesiOcrAngkaProvider)),
      );
    });

    test('provider: sakelar mati tidak membuat pabrik sama sekali', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(pabrikSesiOcrAngkaProvider), isNull);
      expect(c.read(buatSesiOcrAngkaProvider), isNull);
    });
  });

  group('gagal muat runtime -> ML Kit, tanpa crash', () {
    test(
      'pabrik sesi gagal (pustaka native tidak ada di mesin test)',
      () async {
        // Pabrik ASLI (`dariByte`) pada byte apa pun: di mesin test tidak ada
        // libtensorflowlite, jadi pekerja gagal memuat dan sesi tidak lahir.
        final garbage = Uint8List.fromList(List.generate(64, (i) => i));
        final sumber = SumberPalsu(
          meta: jsonEncode({
            'berkas': 'm.tflite',
            'sha256': sha256Dari(garbage),
            'bukti_akurasi': 'SINTETIS',
            'kolom': kolomModel,
          }),
          model: garbage,
        );

        final h = await muatMesinAngka(
          sumber: sumber,
          buatSesi: SesiInferensiTflite.dariByte,
          izinkanSintetis: true,
        );

        expect(h.mesin, isNull);
        expect(h.ditolak, PenolakanMesin.runtimeGagalDimuat);

        final cadangan = PembacaCadangan();
        final p = PembacaSelOnnx(
          cadangan: cadangan,
          muatMesin: () async => h.mesin,
        );
        final b = await p.bacaBerformat(crop(160, 60), aturan3);

        expect(b.teks, 'cadangan');
        expect(cadangan.dibaca, 1);
      },
    );

    test(
      'sel yang gagal dijalankan model -> sisa lembar dibaca ML Kit',
      () async {
        final p = PelariPalsu(
          keluaran: peluangDari('crop/002364.png'),
          lemparPadaPanggilanKe: 1,
        );
        final cadangan = PembacaCadangan();
        final pembaca = PembacaSelOnnx(
          cadangan: cadangan,
          muatMesin: () async => MesinAngka(
            sesi: SesiInferensiTflite(muatPelari: () async => p),
            meta: meta,
          ),
        );

        final b = await pembaca.bacaBerformat(crop(160, 60), aturan3);
        final b2 = await pembaca.bacaBerformat(crop(160, 60), aturan3);

        expect(b.teks, 'cadangan');
        expect(b2.teks, 'cadangan');
        expect(p.dipanggil, 1, reason: 'mesin dimatikan sesudah galat pertama');
      },
    );
  });
}

/// Pelari tiruan: mengembalikan keluaran tetap dan mencatat apa yang masuk.
class PelariPalsu implements PelariTflite {
  PelariPalsu({
    required this.keluaran,
    this.kontrak = const KontrakTensor(
      bentukMasukan: [1, 48, 320, 3],
      tipeMasukan: 'float32',
      bentukKeluaran: [1, 40, 438],
      tipeKeluaran: 'float32',
    ),
    this.lemparPadaPanggilanKe,
  });

  final Float32List keluaran;
  final int? lemparPadaPanggilanKe;

  @override
  final KontrakTensor kontrak;

  int dipanggil = 0;
  int ditutup = 0;
  Float32List? masukanTerakhir;

  @override
  bool mati = false;

  @override
  Future<Float32List> jalankan(Float32List masukan) async {
    dipanggil++;
    masukanTerakhir = masukan;
    if (dipanggil == lemparPadaPanggilanKe) throw StateError('model mati');

    return keluaran;
  }

  @override
  Future<void> tutup() async => ditutup++;
}

/// Sesi berlebar dinamis (seperti ONNX): TIDAK mengimplementasikan
/// `SesiLebarTetap`.
class SesiDinamis implements SesiInferensiCtc {
  SesiDinamis(this._keluaran);

  final KeluaranCtc _keluaran;
  int dipanggil = 0;
  int? lebarTerakhir;

  @override
  Future<KeluaranCtc> jalankan(Float32List masukan, int lebar) async {
    dipanggil++;
    lebarTerakhir = lebar;

    return _keluaran;
  }

  @override
  Future<void> tutup() async {}
}

class SumberPencatat implements SumberModelOcr {
  int dibuka = 0;

  @override
  Future<String?> metaJson() async {
    dibuka++;
    return null;
  }

  @override
  Future<Uint8List?> model(String berkas) async {
    dibuka++;
    return null;
  }
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

/// ML Kit tiruan: menandai bacaannya "cadangan".
class PembacaCadangan implements PembacaSel {
  int dibaca = 0;

  @override
  Future<BacaanSel> baca(img.Image potongan) async {
    dibaca++;
    return (teks: 'cadangan', keyakinan: null, didalamKotak: true);
  }

  @override
  Future<void> tutup() async {}
}
