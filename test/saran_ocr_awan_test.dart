import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/models/ocr_awan.dart';
import 'package:sidik_calibration/models/review_foto.dart';
import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/auth_service.dart';
import 'package:sidik_calibration/services/ocr_awan_sel_service.dart';
import 'package:sidik_calibration/services/saran_ocr_awan.dart';
import 'package:sidik_calibration/services/vonis_sel_foto.dart';

import 'support/potongan_sel_contoh.dart';

/// Penjalur usulan OCR awan di layar review: pemilihan sel angka, pemecahan
/// <= 20 per permintaan, jeda limiter 4/menit, dan JATUH KE JALUR LAMA pada
/// setiap kegagalan. Server palsu; tidak ada jaringan.
void main() {
  const konteks = KonteksOcrAwanSel(templateId: 'ph', kodeDokumen: 'F-1');

  String kunci(int i) => 'tabel_ph|$i|1|pembacaan';

  KandidatSelAwan kandidat(int i, {Uint8List? potongan}) =>
      KandidatSelAwan(kunci: kunci(i), potongan: potongan ?? potonganHeader());

  List<KandidatSelAwan> banyak(int n) => [
    for (var i = 1; i <= n; i++) kandidat(i),
  ];

  Map<String, dynamic> kuning(String k, String teks) => {
    'kunci': k,
    'status': 'kuning',
    'teks_awan': teks,
    'teks_normal': teks,
    'nilai_awan': double.tryParse(teks.replaceAll(',', '.')),
    'dinormalkan': false,
    'alasan': <String>[],
  };

  /// Server palsu: tiap potongan dijawab kuning "4,01".
  HasilOcrAwan jawabKuning(List<PotonganSelAwan> sel) => HasilOcrAwan(
    hasil: [for (final s in sel) ?SelOcrAwan.dariJson(kuning(s.kunci, '4,01'))],
    dilewati: const [],
    meta: MetaOcrAwan(
      jumlahDikirim: sel.length,
      jumlahPanggilan: 1,
      sisaSelLembar: 100,
    ),
  );

  PenjalurSaranAwan penjalur(
    OcrAwanSelService service, {
    bool Function()? nyala,
    Future<String?> Function()? token,
    DateTime Function()? sekarang,
    Tidur? tidur,
  }) => PenjalurSaranAwan(
    service: service,
    bacaToken: token ?? () async => 'token-uji',
    nyala: nyala,
    sekarang: sekarang,
    tidur: tidur ?? (_) async {},
  );

  group('pemecahan dan jeda', () {
    test('45 sel dipecah 20 + 20 + 5, berurutan', () async {
      final service = MockOcrAwanSelService(penjawab: jawabKuning);
      final kemajuan = <(int, int)>[];

      final h = await penjalur(service).minta(
        konteks: konteks,
        kandidat: banyak(45),
        onKemajuan: (s, t) => kemajuan.add((s, t)),
      );

      expect(service.permintaan.map((p) => p.length), [20, 20, 5]);
      expect(service.konteksDiterima, everyElement(same(konteks)));
      expect(h.papan!.usulan, hasLength(45));
      expect(h.sebabGagal, isNull);
      expect(h.jumlahDikirim, 45);
      expect(h.jumlahTidakTerkirim, 0);
      expect(kemajuan, [(0, 3), (1, 3), (2, 3), (3, 3)]);
    });

    test('tidak pernah lebih dari 20 sel dalam satu permintaan', () async {
      final service = MockOcrAwanSelService(penjawab: jawabKuning);

      await penjalur(service).minta(konteks: konteks, kandidat: banyak(61));

      expect(service.permintaan, hasLength(4));
      expect(
        service.permintaan.map((p) => p.length),
        everyElement(lessThanOrEqualTo(maksSelPerPermintaanUnggah)),
      );
    });

    test('permintaan kelima menunggu jendela limiter 4 per menit', () async {
      var jam = DateTime(2026, 11, 25, 10);
      final jeda = <Duration>[];
      final saatKirim = <DateTime>[];

      final service = MockOcrAwanSelService(
        penjawab: (sel) {
          saatKirim.add(jam);
          return jawabKuning(sel);
        },
      );

      final h = await penjalur(
        service,
        sekarang: () => jam,
        tidur: (d) async {
          jeda.add(d);
          jam = jam.add(d);
        },
      ).minta(konteks: konteks, kandidat: banyak(100));

      expect(service.permintaan, hasLength(5));
      expect(jeda, hasLength(1), reason: 'hanya permintaan ke-5 yang menunggu');
      expect(
        saatKirim[4].difference(saatKirim[0]),
        greaterThanOrEqualTo(const Duration(seconds: 60)),
        reason: 'lima permintaan tidak boleh jatuh dalam satu jendela 60 detik',
      );
      expect(h.papan!.usulan, hasLength(100));
    });

    test('jendela berlaku lintas panggilan pada penjalur yang sama', () async {
      var jam = DateTime(2026, 11, 25, 10);
      final jeda = <Duration>[];
      final service = MockOcrAwanSelService(penjawab: jawabKuning);
      final p = penjalur(
        service,
        sekarang: () => jam,
        tidur: (d) async {
          jeda.add(d);
          jam = jam.add(d);
        },
      );

      await p.minta(konteks: konteks, kandidat: banyak(80));
      expect(jeda, isEmpty);

      await p.minta(konteks: konteks, kandidat: banyak(20));
      expect(jeda, hasLength(1));
    });
  });

  group('jatuh ke jalur lama pada SETIAP kegagalan', () {
    GalatOcrAwan coded(int status, String kode) => GalatOcrAwan.dariRespons(
      ApiException(
        'x',
        status: status,
        body: {'kode': kode, 'fallback_manual': true},
      ),
    )!;

    final kasus = <(String, Object, SebabGagalSaranAwan)>[
      (
        '503 fitur_dimatikan',
        coded(503, 'fitur_dimatikan'),
        SebabGagalSaranAwan.fiturMati,
      ),
      (
        '503 ocr_cloud_belum_aktif',
        coded(503, 'ocr_cloud_belum_aktif'),
        SebabGagalSaranAwan.awanBelumSiap,
      ),
      (
        '503 ocr_cloud_belum_disetel',
        coded(503, 'ocr_cloud_belum_disetel'),
        SebabGagalSaranAwan.awanBelumSiap,
      ),
      ('401', const ApiException('x', status: 401), SebabGagalSaranAwan.akses),
      ('403', const ApiException('x', status: 403), SebabGagalSaranAwan.akses),
      (
        '404',
        const ApiException('x', status: 404),
        SebabGagalSaranAwan.ditolakServer,
      ),
      (
        '422 tanpa kode',
        const ApiException('x', status: 422),
        SebabGagalSaranAwan.ditolakServer,
      ),
      (
        '422 templat_tidak_dikenal',
        coded(422, 'templat_tidak_dikenal'),
        SebabGagalSaranAwan.ditolakServer,
      ),
      (
        '429 limiter',
        const ApiException('x', status: 429),
        SebabGagalSaranAwan.terlaluSering,
      ),
      (
        '429 batas_sel_per_lembar',
        coded(429, 'batas_sel_per_lembar'),
        SebabGagalSaranAwan.jatahHabis,
      ),
      (
        '502 ocr_cloud_gagal',
        coded(502, 'ocr_cloud_gagal'),
        SebabGagalSaranAwan.awanGagal,
      ),
      (
        '500',
        const ApiException('x', status: 500),
        SebabGagalSaranAwan.lainnya,
      ),
      ('waktu habis', TimeoutException('lama'), SebabGagalSaranAwan.jaringan),
      (
        'tanpa jaringan',
        const SocketException('putus'),
        SebabGagalSaranAwan.jaringan,
      ),
      (
        'koneksi terputus',
        const KoneksiException('putus'),
        SebabGagalSaranAwan.jaringan,
      ),
      ('galat tak dikenal', StateError('bug'), SebabGagalSaranAwan.lainnya),
    ];

    for (final k in kasus) {
      test(
        '${k.$1} -> ${k.$3.name}: tanpa crash, nol usulan, satu kali kirim',
        () async {
          final service = MockOcrAwanSelService(galat: k.$2);

          final h = await penjalur(
            service,
          ).minta(konteks: konteks, kandidat: banyak(3));

          expect(h.sebabGagal, k.$3);
          expect(h.gagalTotal, isTrue);
          expect(h.papan, isNull, reason: 'tidak ada sel yang terisi otomatis');
          expect(h.jumlahTidakTerkirim, 3);
          expect(
            service.permintaan,
            hasLength(1),
            reason: 'tanpa ulang otomatis',
          );
        },
      );
    }

    test(
      'galat di permintaan ke-2: usulan ke-1 tetap, sisanya berhenti',
      () async {
        var n = 0;
        final service = MockOcrAwanSelService(
          penjawab: (sel) {
            n++;
            if (n == 2) throw const ApiException('x', status: 429);
            return jawabKuning(sel);
          },
        );

        final h = await penjalur(
          service,
        ).minta(konteks: konteks, kandidat: banyak(45));

        expect(
          service.permintaan,
          hasLength(2),
          reason: 'berhenti pada galat pertama',
        );
        expect(h.papan!.usulan, hasLength(20));
        expect(h.sebabGagal, SebabGagalSaranAwan.terlaluSering);
        expect(h.jumlahDikirim, 20);
        expect(h.jumlahTidakTerkirim, 25);
        expect(h.sebagian, isTrue);
        expect(h.papan!.sebagian, isTrue);
      },
    );

    test(
      'sakelar klien mati: tanpa panggilan dan tanpa membaca token',
      () async {
        final service = MockOcrAwanSelService(penjawab: jawabKuning);
        var tokenDibaca = 0;

        final h = await penjalur(
          service,
          nyala: () => false,
          token: () async {
            tokenDibaca++;
            return 't';
          },
        ).minta(konteks: konteks, kandidat: banyak(5));

        expect(h.sebabGagal, SebabGagalSaranAwan.dimatikan);
        expect(h.papan, isNull);
        expect(service.permintaan, isEmpty);
        expect(tokenDibaca, 0);
      },
    );

    test('tanpa token: tidak ada panggilan', () async {
      final service = MockOcrAwanSelService(penjawab: jawabKuning);

      for (final token in <String?>[null, '']) {
        final h = await penjalur(
          service,
          token: () async => token,
        ).minta(konteks: konteks, kandidat: banyak(2));

        expect(h.sebabGagal, SebabGagalSaranAwan.akses);
        expect(h.papan, isNull);
      }
      expect(service.permintaan, isEmpty);
    });

    test('pembacaan token yang melempar tidak menjatuhkan layar', () async {
      final service = MockOcrAwanSelService(penjawab: jawabKuning);

      final h = await penjalur(
        service,
        token: () async => throw StateError('penyimpanan rusak'),
      ).minta(konteks: konteks, kandidat: banyak(2));

      expect(h.gagalTotal, isTrue);
      expect(service.permintaan, isEmpty);
    });

    test(
      'dibatalkan sebelum permintaan kedua: berhenti, tidak menghabiskan jatah',
      () async {
        var batal = false;
        final service = MockOcrAwanSelService(
          penjawab: (sel) {
            batal = true;
            return jawabKuning(sel);
          },
        );

        final h = await penjalur(service).minta(
          konteks: konteks,
          kandidat: banyak(45),
          dibatalkan: () => batal,
        );

        expect(service.permintaan, hasLength(1));
        expect(h.dibatalkan, isTrue);
        expect(h.jumlahTidakTerkirim, 25);
        expect(h.papan!.usulan, hasLength(20));
      },
    );
  });

  group('hanya potongan yang layak keluar dari HP', () {
    test('potongan melewati batas byte atau piksel tertahan di HP', () async {
      final service = MockOcrAwanSelService(penjawab: jawabKuning);

      final h = await penjalur(service).minta(
        konteks: konteks,
        kandidat: [
          kandidat(1),
          kandidat(
            2,
            potongan: potonganHeader(tambahanByte: maksByteSelUnggah),
          ),
          kandidat(3, potongan: potonganHeader(lebar: 1000, tinggi: 1000)),
          kandidat(4, potongan: Uint8List.fromList([1, 2, 3])),
        ],
      );

      expect(service.permintaan.single, [kunci(1)]);
      expect(h.jumlahDitahanDiHp, 3);
      expect(h.sebagian, isTrue);
      expect(
        h.papan!.dilewati.map((d) => d.alasan),
        containsAll([
          'potongan_kebesaran_byte',
          'potongan_kebesaran_piksel',
          'potongan_bukan_citra',
        ]),
      );
    });

    test(
      'semua potongan di luar batas: tidak ada panggilan, token tidak dibaca',
      () async {
        final service = MockOcrAwanSelService(penjawab: jawabKuning);
        var tokenDibaca = 0;

        final h =
            await penjalur(
              service,
              token: () async {
                tokenDibaca++;
                return 't';
              },
            ).minta(
              konteks: konteks,
              kandidat: [
                kandidat(
                  1,
                  potongan: potonganHeader(tambahanByte: maksByteSelUnggah),
                ),
              ],
            );

        expect(h.sebabGagal, SebabGagalSaranAwan.tidakAdaSel);
        expect(h.jumlahDitahanDiHp, 1);
        expect(service.permintaan, isEmpty);
        expect(tokenDibaca, 0);
      },
    );

    test('kunci identitas, kosong, dan kembar tidak dikirim', () async {
      final service = MockOcrAwanSelService(penjawab: jawabKuning);

      await penjalur(service).minta(
        konteks: konteks,
        kandidat: [
          kandidat(1),
          KandidatSelAwan(kunci: 'isian|suhu', potongan: potonganHeader()),
          KandidatSelAwan(kunci: 'centang|lulus', potongan: potonganHeader()),
          KandidatSelAwan(kunci: '  ', potongan: potonganHeader()),
          kandidat(1),
        ],
      );

      expect(service.permintaan.single, [kunci(1)]);
    });

    test('daftar kandidat kosong: tidak ada panggilan', () async {
      final service = MockOcrAwanSelService(penjawab: jawabKuning);

      final h = await penjalur(
        service,
      ).minta(konteks: konteks, kandidat: const []);

      expect(h.sebabGagal, SebabGagalSaranAwan.tidakAdaSel);
      expect(service.permintaan, isEmpty);
    });
  });

  group(
    'usulan: sel kosong tetap kosong, tidak ada nilai sebelum diputuskan',
    () {
      test(
        'sel yang dilihat awan kosong atau merah tidak menjadi usulan',
        () async {
          final service = MockOcrAwanSelService(
            hasil: HasilOcrAwan(
              hasil: [
                ?SelOcrAwan.dariJson(kuning(kunci(1), '4,01')),
                ?SelOcrAwan.dariJson({
                  'kunci': kunci(2),
                  'status': 'kosong',
                  'teks_awan': '',
                }),
                ?SelOcrAwan.dariJson({
                  'kunci': kunci(3),
                  'status': 'merah',
                  'teks_awan': 'l0,0',
                  'alasan': ['karakter_di_luar_whitelist'],
                }),
              ],
              dilewati: const [],
              meta: const MetaOcrAwan(),
            ),
          );

          final h = await penjalur(
            service,
          ).minta(konteks: konteks, kandidat: banyak(3));

          final papan = h.papan!;
          expect(papan.usulan.map((u) => u.kunci), [kunci(1)]);
          expect(papan.tanpaUsulan.map((s) => s.kunci), [kunci(2), kunci(3)]);
          // Semuanya menunggu keputusan: belum ada nilai untuk sel mana pun.
          expect(papan.usulan.single.perluDicek, isTrue);
          expect(papan.usulan.single.teksFinal, isNull);
          expect(papan.koreksiTerkonfirmasi, isEmpty);
        },
      );
    },
  );

  group('pilih sel angka', () {
    SelTemplateAsli selAsli(String tabel, int barisKe, int repeat) =>
        SelTemplateAsli(
          kunci: '$tabel|$barisKe|$repeat|pembacaan',
          tabelId: tabel,
          barisKe: barisKe,
          repeatNo: repeat,
          fieldId: 'pembacaan',
        );

    BarisTemplate barisT(int ke, String? tipe) => BarisTemplate(
      barisKe: ke,
      titikUkur: ke.toDouble(),
      label: 'B$ke',
      tipe: tipe,
    );

    final templat = WorksheetTemplate(
      templateId: 'ph',
      versi: 1,
      kodeDokumen: 'F-1',
      judul: 'pH',
      tabel: [
        TabelTemplate(
          tabelId: 'tabel_ph',
          judul: 'pH',
          baris: [barisT(1, 'angka'), barisT(2, 'jam'), barisT(3, null)],
          kolom: const [],
          pengulangan: const [1, 2],
        ),
      ],
      sel: const {},
      siapPindai: true,
      selAsli: [
        selAsli('tabel_ph', 1, 1),
        selAsli('tabel_ph', 1, 2),
        selAsli('tabel_ph', 2, 1),
        selAsli('tabel_ph', 3, 1),
        selAsli('tabel_lain', 1, 1),
        const SelTemplateAsli(
          kunci: 'isian|suhu',
          tabelId: 'tabel_ph',
          barisKe: 1,
          repeatNo: 1,
          fieldId: 'suhu',
        ),
      ],
    );

    test(
      'hanya baris bertipe angka; jam, tanpa tipe, tabel asing, isian tidak',
      () {
        expect(kunciSelAngka(templat), {
          'tabel_ph|1|1|pembacaan',
          'tabel_ph|1|2|pembacaan',
        });
      },
    );

    BarisReviewFoto baris(
      double titik,
      VonisFoto vonis, {
      int repeat = 1,
      Uint8List? potongan,
      String fieldId = 'tabel_ph@@1@@pembacaan',
    }) => (
      titikUkur: titik,
      repeatNo: repeat,
      fieldId: fieldId,
      judul: 'Sel $titik',
      teks: vonis == VonisFoto.merah ? '' : '4,00',
      keyakinan: 0.5,
      vonis: vonis,
      potongan: potongan ?? potonganHeader(),
    );

    test('hijau, tanpa potongan, tanpa kunci server, dan kembar disaring', () {
      final kuningA = baris(1, VonisFoto.kuning);
      final merahB = baris(2, VonisFoto.merah, repeat: 2);
      final hijau = baris(3, VonisFoto.hijau);
      final tanpaPotongan = (
        titikUkur: 4.0,
        repeatNo: 1,
        fieldId: 'tabel_ph@@1@@pembacaan',
        judul: 'x',
        teks: '4,00',
        keyakinan: 0.5,
        vonis: VonisFoto.kuning,
        potongan: null,
      );
      final isian = baris(
        -999,
        VonisFoto.kuning,
        fieldId: '@isian@@1@@suhu_awal',
      );
      final kembar = baris(5, VonisFoto.kuning);

      String k(BarisReviewFoto b) =>
          kunciSelFoto(b.titikUkur, b.repeatNo, b.fieldId);

      final hasil = pilihKandidatAwan(
        kunciAngka: kunciSelAngka(templat),
        baris: [kuningA, merahB, hijau, tanpaPotongan, isian, kembar],
        kunciServerPerBaris: {
          k(kuningA): 'tabel_ph|1|1|pembacaan',
          k(merahB): 'tabel_ph|1|2|pembacaan',
          k(hijau): 'tabel_ph|1|1|pembacaan',
          k(tanpaPotongan): 'tabel_ph|1|1|pembacaan',
          // `isian` sengaja tidak ada di peta.
          k(kembar): 'tabel_ph|1|1|pembacaan',
        },
      );

      expect(hasil.map((e) => e.kunci), [
        'tabel_ph|1|1|pembacaan',
        'tabel_ph|1|2|pembacaan',
      ]);
    });

    test('baris yang kuncinya bukan sel angka tidak pernah dipilih', () {
      final b = baris(1, VonisFoto.kuning);

      final hasil = pilihKandidatAwan(
        kunciAngka: {'tabel_ph|9|9|pembacaan'},
        baris: [b],
        kunciServerPerBaris: {
          kunciSelFoto(b.titikUkur, b.repeatNo, b.fieldId):
              'tabel_ph|2|1|pembacaan',
        },
      );

      expect(hasil, isEmpty);
    });
  });

  group('petakanGalatSaranAwan', () {
    test('tidak melempar untuk apa pun', () {
      for (final g in <Object>[
        'teks',
        42,
        StateError('x'),
        const FormatException('y'),
      ]) {
        expect(petakanGalatSaranAwan(g), SebabGagalSaranAwan.lainnya);
      }
    });
  });
}
