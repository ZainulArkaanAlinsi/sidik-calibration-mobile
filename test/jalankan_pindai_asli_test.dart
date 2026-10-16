import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/registrasi_jangkar_teks.dart';

/// Alur pindai formulir ASLI dari foto sampai bacaan per sel — seluruhnya
/// lokal (K-50-11): tanpa ML Kit, tanpa kamera, tanpa jaringan.
///
/// Geometri formulirnya NYATA (pH SIDIK-FM-CAL-0509 Rev.4, fixture
/// `test/assets/template-asli-ph_meter-0509.json` dari draf+peta repo API
/// 3222d1b). Fotonya sintetis: kertas berderau, kotak centang tercetak
/// digambar di posisi geometrinya lewat homography yang diketahui, sebagian
/// diberi tanda silang. ML Kit sehalaman ditiru dengan kata-kata cetak di
/// posisi yang sama. Jadi yang diuji sungguhan: pencocokan jangkar, RANSAC,
/// perataan halaman, pemotongan per kotak, rasio gelap centang, dan bentuk
/// kirimannya.
void main() {
  final dataTemplate =
      (jsonDecode(
                File(
                  'test/assets/template-asli-ph_meter-0509.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['data']
          as Map<String, dynamic>;

  WorksheetTemplate templateDengan([Map<String, dynamic> ubah = const {}]) =>
      WorksheetTemplate.fromJson({
        'data': {...dataTemplate, ...ubah},
      });

  final template = templateDengan();
  final halaman = template.halamanPt!;

  // Halaman (pt) → foto (px): 2,2 px/pt, miring 2°, sedikit perspektif.
  final benar = () {
    const s = 2.2;
    final c = math.cos(2 * math.pi / 180) * s;
    final n = math.sin(2 * math.pi / 180) * s;

    return Homografi([c, -n, 60, n, c, 80, 1e-5, -5e-6, 1]);
  }();

  Titik proyeksi(double xPt, double yPt) => benar.terapkan((x: xPt, y: yPt))!;

  Rect kotakFoto(KotakSel k) {
    final a = proyeksi(k.x * halaman.w, k.y * halaman.h);
    final b = proyeksi((k.x + k.w) * halaman.w, (k.y + k.h) * halaman.h);

    return Rect.fromPoints(Offset(a.x, a.y), Offset(b.x, b.y));
  }

  /// Kata-kata cetak formulir di posisi fotonya, plus `: 4` di kanan
  /// "Revise" (revisi tercetak).
  List<TeksTerbaca> kataCetak({
    String revisi = '4',
    bool denganKode = true,
    bool denganRevisi = true,
  }) {
    final hasil = <TeksTerbaca>[
      for (final j in template.jangkarTeks)
        if (denganKode || !j.teks.startsWith('SIDIK-FM-CAL'))
          (teks: j.teks, kotak: kotakFoto(j.kotak), keyakinan: null),
    ];

    final rev = template.jangkarTeks
        .firstWhere((j) => j.teks == 'Revise')
        .kotak;
    final y = (rev.y + rev.h / 2) * halaman.h;
    final x = (rev.x + rev.w) * halaman.w;
    for (final (dx, t) in [(4.0, ':'), (12.0, revisi)]) {
      if (!denganRevisi) break;
      final p = proyeksi(x + dx, y);
      hasil.add((
        teks: t,
        kotak: Rect.fromCenter(center: Offset(p.x, p.y), width: 10, height: 18),
        keyakinan: null,
      ));
    }

    return hasil;
  }

  /// Foto sintetis: kertas berderau (175..235 — tidak ada yang lolos ambang
  /// tinta, tidak ada yang silau), kotak centang tercetak, dan tanda silang di
  /// [dicentang].
  img.Image foto({required Set<String> dicentang}) {
    const w = 1900, h = 1500;
    final c = img.Image(width: w, height: h);
    final b = c.toUint8List();
    var s = 12345;
    for (var i = 0; i < w * h; i++) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final v = 175 + s % 61;
      b[i * 3] = v;
      b[i * 3 + 1] = v;
      b[i * 3 + 2] = v;
    }

    final tinta = img.ColorRgb8(25, 25, 30);

    for (final t in template.centang) {
      final k = t.kotak!;
      final x0 = k.x * halaman.w, y0 = k.y * halaman.h;
      final x1 = (k.x + k.w) * halaman.w, y1 = (k.y + k.h) * halaman.h;
      final sudut = [
        proyeksi(x0, y0),
        proyeksi(x1, y0),
        proyeksi(x1, y1),
        proyeksi(x0, y1),
      ];

      for (var i = 0; i < 4; i++) {
        final a = sudut[i], bb = sudut[(i + 1) % 4];
        img.drawLine(
          c,
          x1: a.x.round(),
          y1: a.y.round(),
          x2: bb.x.round(),
          y2: bb.y.round(),
          color: tinta,
          thickness: 2,
        );
      }

      if (dicentang.contains(t.id)) {
        const m = 1.8; // pt masuk dari bingkai
        final p = [
          proyeksi(x0 + m, y0 + m),
          proyeksi(x1 - m, y1 - m),
          proyeksi(x1 - m, y0 + m),
          proyeksi(x0 + m, y1 - m),
        ];
        for (final (a, bb) in [(p[0], p[1]), (p[2], p[3])]) {
          img.drawLine(
            c,
            x1: a.x.round(),
            y1: a.y.round(),
            x2: bb.x.round(),
            y2: bb.y.round(),
            color: img.ColorRgb8(20, 30, 100),
            thickness: 3,
          );
        }
      }
    }

    return c;
  }

  final bacaanSel = [
    for (var i = 0; i < 60; i++) '4,0${i % 10}',
    '25,0',
    '60',
    '25,4',
    '61',
  ];

  group('alur penuh foto → bacaan lokal', () {
    late HasilBacaAsli hasil;
    late MockPembacaSel pembaca;

    setUpAll(() async {
      pembaca = MockPembacaSel(bacaan: bacaanSel);
      hasil = await JalankanPindaiAsli(
        halaman: MockPembacaHalaman(kataCetak()),
        pembaca: pembaca,
      ).baca(foto(dicentang: {}), template: template);
    });

    test('dikenali: kode & revisi tercetak terbaca', () {
      expect(hasil.kodeTerbaca, 'SIDIK-FM-CAL-0509');
      expect(hasil.revisiTerbaca, ': 4');
    });

    test(
      'sel tabel + isian Env. dibaca per potongan; centang TIDAK dibaca',
      () {
        // 60 sel + 4 isian Env.; 9 kotak centang tidak disentuh pembaca.
        expect(template.centang, hasLength(9));
        expect(pembaca.jumlahDibaca, 64);
        expect(hasil.sel, hasLength(60));
        expect(hasil.sel.first.sel.kunci, template.selAsli.first.kunci);
        expect(hasil.sel.first.bacaan.teks, '4,00');
        expect(hasil.sel[9].bacaan.teks, '4,09');
        expect(hasil.isian.map((e) => e.isian.kode), [
          for (final i in template.isian) i.kode,
        ]);
        expect(hasil.isian.map((e) => e.bacaan.teks), [
          '25,0',
          '60',
          '25,4',
          '61',
        ]);
      },
    );

    test('potongan PNG ada di memori: satu per sel dan satu per isian', () {
      expect(hasil.potongan, hasLength(64));
      expect(hasil.potongan[template.selAsli.first.kunci], isNotEmpty);
      expect(
        hasil.potongan[kunciPotonganIsian(template.isian.first.kode)],
        isNotEmpty,
      );
    });
  });

  group('berhenti sebelum membaca sel', () {
    final kecil = img.Image(width: 40, height: 30);

    Future<void> gagal(
      GagalPindaiAsli sebab, {
      WorksheetTemplate? t,
      List<TeksTerbaca>? kata,
    }) async {
      await expectLater(
        JalankanPindaiAsli(
          halaman: MockPembacaHalaman(kata ?? kataCetak()),
          pembaca: MockPembacaSel(),
        ).baca(kecil, template: t ?? template),
        throwsA(isA<PindaiAsliGagal>().having((e) => e.sebab, 'sebab', sebab)),
      );
    }

    test('belum siap & mode uji mati', () async {
      await gagal(
        GagalPindaiAsli.belumSiap,
        t: templateDengan({'mode_uji': false, 'siap_pindai': false}),
      );
    });

    test('ada kotak tanpa koordinat → tidak dibaca sama sekali', () async {
      final isian = [...(dataTemplate['isian'] as List)];
      isian[2] = {...isian[2] as Map<String, dynamic>, 'kotak': null};

      await expectLater(
        JalankanPindaiAsli(
          halaman: MockPembacaHalaman(kataCetak()),
          pembaca: MockPembacaSel(),
        ).baca(kecil, template: templateDengan({'isian': isian})),
        throwsA(
          isA<PindaiAsliGagal>()
              .having(
                (e) => e.sebab,
                'sebab',
                GagalPindaiAsli.geometriBelumLengkap,
              )
              .having((e) => e.jumlah, 'jumlah', 1),
        ),
      );
    });

    test('kode formulir tidak terbaca', () async {
      await gagal(
        GagalPindaiAsli.kodeTidakTerbaca,
        kata: kataCetak(denganKode: false),
      );
    });

    test('formulir lain', () async {
      await expectLater(
        JalankanPindaiAsli(
          halaman: MockPembacaHalaman([
            ...kataCetak(denganKode: false),
            (
              teks: 'SIDIK-FM-CAL-0510',
              kotak: const Rect.fromLTWH(0, 0, 5, 5),
              keyakinan: null,
            ),
          ]),
          pembaca: MockPembacaSel(),
        ).baca(kecil, template: template),
        throwsA(
          isA<PindaiAsliGagal>()
              .having((e) => e.sebab, 'sebab', GagalPindaiAsli.formulirLain)
              .having((e) => e.terbaca, 'terbaca', 'SIDIK-FM-CAL-0510'),
        ),
      );
    });

    test('revisi tercetak beda dari yang dipegang sistem', () async {
      await gagal(GagalPindaiAsli.revisiBeda, kata: kataCetak(revisi: '5'));
    });

    test('revisi tidak terbaca → berhenti, tidak lanjut diam-diam', () async {
      await gagal(
        GagalPindaiAsli.revisiTidakTerbaca,
        kata: kataCetak(denganRevisi: false),
      );
    });

    test('jangkar terlalu sedikit', () async {
      final kode = template.jangkarTeks.firstWhere(
        (j) => j.teks == 'SIDIK-FM-CAL-0509',
      );
      await gagal(
        GagalPindaiAsli.jangkarKurang,
        kata: [
          for (final teks in const ['Thermohygro', 'OWNER', 'Address', 'Usage'])
            (
              teks: teks,
              kotak: kotakFoto(
                template.jangkarTeks.firstWhere((j) => j.teks == teks).kotak,
              ),
              keyakinan: null,
            ),
          (teks: kode.teks, kotak: kotakFoto(kode.kotak), keyakinan: null),
        ],
      );
    });

    test('jangkar cuma di separuh atas lembar', () async {
      await gagal(
        GagalPindaiAsli.jangkarTidakMenyebar,
        kata: [
          for (final k in kataCetak())
            if (benar.invers()!.terapkan((
                      x: k.kotak.center.dx,
                      y: k.kotak.center.dy,
                    ))!.y <
                    halaman.h / 2 ||
                k.teks == 'SIDIK-FM-CAL-0509')
              k,
        ],
      );
    });
  });

  test(
    'foto HP tegak (formulir terbaring) diputar dulu sebelum dibaca',
    () async {
      // Penanda di pojok foto lanskap asli. Diputar -90° jadi foto tegak; yang
      // benar memutarnya +90° — baru tulisan cetaknya terbaca di posisi aslinya.
      final lanskap = img.Image(width: 400, height: 300);
      img.fill(lanskap, color: img.ColorRgb8(200, 200, 200));
      lanskap.setPixelRgb(5, 5, 255, 0, 0);
      final tegak = img.copyRotate(lanskap, angle: -90);

      final pembacaHalaman = _PembacaOrientasi(
        kata: kataCetak(revisi: '5'),
        lebar: 400,
        tinggi: 300,
      );

      // Revisi sengaja beda supaya alurnya berhenti TEPAT sesudah kenali &
      // ratakan — cukup buat membuktikan orientasinya benar tanpa meratakan
      // kanvas penuh.
      await expectLater(
        JalankanPindaiAsli(
          halaman: pembacaHalaman,
          pembaca: MockPembacaSel(),
        ).baca(tegak, template: template),
        throwsA(
          isA<PindaiAsliGagal>().having(
            (e) => e.sebab,
            'sebab',
            GagalPindaiAsli.revisiBeda,
          ),
        ),
      );
      expect(pembacaHalaman.dibaca, 1);
    },
  );
}

/// ML Kit tiruan yang cuma "bisa membaca" foto di orientasi aslinya —
/// dikenali dari penanda merah di pojok kiri-atas.
class _PembacaOrientasi implements PembacaHalaman {
  _PembacaOrientasi({
    required this.kata,
    required this.lebar,
    required this.tinggi,
  });

  final List<TeksTerbaca> kata;
  final int lebar;
  final int tinggi;
  int dibaca = 0;

  @override
  Future<List<TeksTerbaca>> baca(img.Image citra) async {
    dibaca++;
    final tegak =
        citra.width == lebar &&
        citra.height == tinggi &&
        citra.getPixel(5, 5).r == 255;

    return tegak ? kata : const [];
  }

  @override
  Future<void> tutup() async {}
}
