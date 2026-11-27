import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart';
import 'package:sidik_calibration/services/jenis_lembar.dart';
import 'package:sidik_calibration/services/kenali_formulir_teks.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/pembaca_sel.dart';
import 'package:sidik_calibration/services/registrasi_jangkar_teks.dart';

/// Kenali formulir dari JUDUL / nama alat tercetak, bukan dari angka kode.
///
/// SEMUA teks di sini TIRUAN, bukan foto asli dan bukan keluaran ML Kit:
/// baris-barisnya dibangun dari tulisan cetak peta formulir (judul, kata
/// jangkar) dan dari pola galat yang teramati pada satu foto contoh lewat
/// pembaca teks lokal Windows (kode di kaki terpotong, `SIDIK-IK-CAL-0508`
/// blok Metode terbaca mirip kode formulir, judul pecah dua baris). Akurasi
/// pada foto nyata: BELUM TERUKUR.
void main() {
  // ---------------------------------------------------------------------------
  // Bahan dasar: peta pH 0509 Rev.4 (geometri nyata) + homography yang diketahui.
  // ---------------------------------------------------------------------------
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

  TeksTerbaca kataDi(String teks, double xPt, double yPt) {
    final p = proyeksi(xPt, yPt);

    return (
      teks: teks,
      kotak: Rect.fromCenter(center: Offset(p.x, p.y), width: 14, height: 18),
      keyakinan: null,
    );
  }

  /// Kata jangkar peta pH di posisi fotonya. Kode formulir ([denganKode]) dan
  /// judul lengkap ([denganJudul]: "- pH" yang tidak jadi jangkar karena tidak
  /// unik) bisa dihilangkan; revisi tercetak di kanan "Revise".
  List<TeksTerbaca> kataCetak({
    bool denganKode = true,
    bool denganJudul = true,
    String? revisi = '4',
  }) {
    final hasil = <TeksTerbaca>[
      for (final j in template.jangkarTeks)
        if (denganKode || !j.teks.startsWith('SIDIK-FM-CAL'))
          (teks: j.teks, kotak: kotakFoto(j.kotak), keyakinan: null),
    ];

    if (denganJudul) {
      final ws = template.jangkarTeks.firstWhere((j) => j.teks == 'Worksheet');
      final meter = template.jangkarTeks.firstWhere((j) => j.teks == 'Meter');
      final y = (ws.kotak.y + ws.kotak.h / 2) * halaman.h;
      hasil
        ..add(kataDi('-', (ws.kotak.x + ws.kotak.w) * halaman.w + 3, y))
        ..add(kataDi('pH', meter.kotak.x * halaman.w - 14, y));
    }

    if (revisi != null) {
      final rev = template.jangkarTeks
          .firstWhere((j) => j.teks == 'Revise')
          .kotak;
      final y = (rev.y + rev.h / 2) * halaman.h;
      final x = (rev.x + rev.w) * halaman.w;
      for (final (dx, t) in [(4.0, ':'), (12.0, revisi)]) {
        hasil.add(kataDi(t, x + dx, y));
      }
    }

    return hasil;
  }

  img.Image foto() {
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
    }

    return c;
  }

  const sebabKenaliGagal = {
    GagalPindaiAsli.kodeTidakTerbaca,
    GagalPindaiAsli.formulirLain,
    GagalPindaiAsli.revisiBeda,
    GagalPindaiAsli.revisiTidakTerbaca,
  };

  // ---------------------------------------------------------------------------
  // BUKTI: gerbang mana yang menghentikan lembar yang judulnya jelas.
  // ---------------------------------------------------------------------------
  group(
    'BUKTI (tiruan, bukan foto asli): lembar berjudul jelas dihentikan',
    () {
      test(
        'kode kaki tidak terbaca, judul + jangkar utuh -> harus lolos kenali',
        () async {
          await expectLater(
            JalankanPindaiAsli(
              halaman: MockPembacaHalaman(kataCetak(denganKode: false)),
              pembaca: MockPembacaSel(),
            ).baca(foto(), template: template),
            completion(isA<HasilBacaAsli>()),
          );
        },
      );

      test(
        'revisi tercetak beda tetapi judul sama -> harus lolos kenali',
        () async {
          await expectLater(
            JalankanPindaiAsli(
              halaman: MockPembacaHalaman(
                kataCetak(denganKode: false, revisi: '5'),
              ),
              pembaca: MockPembacaSel(),
            ).baca(foto(), template: template),
            completion(isA<HasilBacaAsli>()),
          );
        },
      );
    },
  );

  // ---------------------------------------------------------------------------
  // Keputusan murni dari teks (tanpa foto).
  // ---------------------------------------------------------------------------
  FormulirDikenal dikenal(String id, String kode, String judul) =>
      (templateId: id, kodeDokumen: kode, judul: judul);

  final ph = dikenal(
    'ph_meter',
    'SIDIK-FM-CAL-0509',
    'Calibration Worksheet - pH Meter',
  );
  final konduktivitas = dikenal(
    'conductivity_meter',
    'SIDIK-FM-CAL-0510',
    'Calibration Worksheet - Conductivity Meter',
  );
  final spektro = dikenal(
    'spectrophotometer',
    'SIDIK-FM-CAL-0511',
    'Calibration Worksheet - UV/VIS Spectrophotometer',
  );
  final tekanan = dikenal(
    'pressure_gauge',
    'SIDIK-FM-CAL-0507',
    'Calibration Worksheet - Pressure & Vacuum Gauge',
  );
  final mikrometer = [
    for (final v in ['A', 'B', 'C', 'D'])
      dikenal(
        'micrometer_$v',
        'SIDIK-FM-CAL-0522.$v',
        'Calibration Work Sheet - Micrometer',
      ),
  ];

  /// Template pengganti: hanya identitasnya yang dipakai keputusan teks.
  WorksheetTemplate templatDari(FormulirDikenal f, {int revisi = 5}) =>
      templateDengan({
        'template_id': f.templateId,
        'kode_dokumen': f.kodeDokumen,
        'judul': f.judul,
        'revisi': revisi,
        'geometri': {
          ...(dataTemplate['geometri'] as Map<String, dynamic>),
          'jangkar_teks': const <Map<String, dynamic>>[],
        },
      });

  /// Satu baris cetak jadi elemen PER KATA (seperti ML Kit): kode formulir
  /// utuh ada di satu kata, "Revise : 5" tiga kata.
  List<TeksTerbaca> baris(String teks, int n) => [
    for (final (k, kata) in teks.split(' ').indexed)
      (
        teks: kata,
        kotak: Rect.fromLTWH(10.0 + 90 * k, 20.0 * n, 80, 12),
        keyakinan: null,
      ),
  ];

  List<TeksTerbaca> halamanDari(List<String> teks) => [
    for (final (i, t) in teks.indexed) ...baris(t, i),
  ];

  ({String? cocok, String? lain}) kodeDari(
    List<TeksTerbaca> t,
    WorksheetTemplate w,
  ) => cariKodeDokumen(t, w.kodeDokumen);

  HasilKenaliTeks kenali(
    List<String> teks,
    FormulirDikenal untuk, {
    List<FormulirDikenal> semua = const [],
  }) {
    final t = templatDari(untuk);
    final terbaca = halamanDari(teks);

    return kenaliFormulirDariTeks(
      terbaca: terbaca,
      template: t,
      kode: kodeDari(terbaca, t),
      dikenal: semua,
    );
  }

  // Pola galat dari satu foto contoh (pembaca teks lokal Windows, BUKAN ML Kit):
  // judul pecah di tengah kata, "Method" memuat kode instruksi kerja yang mirip
  // kode formulir, kode formulir di kaki terpotong tepi foto.
  const lembarSpektroKodeHilang = [
    'PT. SIDIK',
    'Calibration Worksh',
    'et - UV/VIS Spectrophotometer',
    '2. Calibration Method:',
    'SIDIK-1K-CAL-0508',
    'Revise : 5',
    'SIDIK.FM-CAL.05',
  ];

  group('keputusan teks', () {
    test('(a) kode tidak terbaca, judul jelas -> dikenali dari judul', () {
      final h = kenali(
        lembarSpektroKodeHilang,
        spektro,
        semua: [ph, konduktivitas, spektro, tekanan],
      );

      expect(h.keputusan, KeputusanKenali.cocok);
      expect(h.dasar, DasarKenali.judul);
      expect(h.kodeTerbaca, isNull);
    });

    test('(a) judul jelas tanpa daftar formulir lain juga dikenali', () {
      final h = kenali(lembarSpektroKodeHilang, spektro);

      expect(h.keputusan, KeputusanKenali.cocok);
      expect(h.dasar, DasarKenali.judul);
    });

    test('(a) kode terbaca bersih dan judul sepakat: dasar kode + judul', () {
      final h = kenali(
        [
          'Calibration Worksheet - UV/VIS Spectrophotometer LK-285-IDN',
          'Revise : 5 SIDIK-FM-CAL-0511',
        ],
        spektro,
        semua: [ph, spektro],
      );

      expect(h.keputusan, KeputusanKenali.cocok);
      expect(h.dasar, DasarKenali.kodeDanJudul);
      expect(h.kodeTerbaca, 'SIDIK-FM-CAL-0511');
    });

    test('(b) kode template terbaca tetapi judul milik formulir lain', () {
      final h = kenali(
        [
          'Calibration Worksheet - Pressure & Vacuum Gauge LK-285-IDN',
          'Revise : 5 SIDIK-FM-CAL-0511',
        ],
        spektro,
        semua: [ph, spektro, tekanan],
      );

      expect(h.keputusan, KeputusanKenali.formulirLain);
      expect(h.terbaca, isNotEmpty);
    });

    test('(b) kode formulir lain terbaca walau judulnya cocok', () {
      final h = kenali(
        [
          'Calibration Worksheet - UV/VIS Spectrophotometer LK-285-IDN',
          'Revise : 5 SIDIK-FM-CAL-0510',
        ],
        spektro,
        semua: [spektro, konduktivitas],
      );

      expect(h.keputusan, KeputusanKenali.formulirLain);
      expect(h.terbaca, 'SIDIK-FM-CAL-0510');
    });

    test(
      '(c) varian bernama sama, kode tak terbaca -> ambigu, bukan tebakan',
      () {
        final h = kenali(
          ['Calibration Work Sheet - Micrometer LK-285-IDN', 'Revise : 1'],
          mikrometer.first,
          semua: mikrometer,
        );

        expect(h.keputusan, KeputusanKenali.ambigu);
        expect(h.kandidat, [
          'SIDIK-FM-CAL-0522.A',
          'SIDIK-FM-CAL-0522.B',
          'SIDIK-FM-CAL-0522.C',
          'SIDIK-FM-CAL-0522.D',
        ]);
      },
    );

    test('(c) kode terpotong tanpa huruf varian tetap ambigu', () {
      final h = kenali(
        [
          'Calibration Work Sheet - Micrometer LK-285-IDN',
          'Revise : 1 SIDIK-FM-CAL-0522',
        ],
        mikrometer.first,
        semua: mikrometer,
      );

      expect(h.keputusan, KeputusanKenali.ambigu);
    });

    test(
      '(c) kode varian terbaca memutus: varian ini cocok, varian lain ditolak',
      () {
        const teks = [
          'Calibration Work Sheet - Micrometer LK-285-IDN',
          'Revise : 1 SIDIK-FM-CAL-0522.B',
        ];

        expect(
          kenali(teks, mikrometer[1], semua: mikrometer).keputusan,
          KeputusanKenali.cocok,
        );

        final salah = kenali(teks, mikrometer.first, semua: mikrometer);
        expect(salah.keputusan, KeputusanKenali.formulirLain);
        expect(salah.terbaca, 'SIDIK-FM-CAL-0522.B');
      },
    );

    test('(d) kertas jenis lain ditolak, bukan dilolosi', () {
      const konduktivitasTeks = [
        'PT. SIDIK',
        'Calibration Worksheet - Conductivity Meter LK-285-IDN',
        'Revise : 5 SIDIK-FM-CAL-0510',
      ];
      final h = kenali(
        konduktivitasTeks,
        ph,
        semua: [ph, konduktivitas, spektro],
      );
      expect(h.keputusan, KeputusanKenali.formulirLain);

      // Kode di kaki rusak: tetap kertas lain karena judulnya.
      final tanpaKode = kenali(
        [
          'PT. SIDIK',
          'Calibration Worksheet - Conductivity Meter LK-285-IDN',
          'Revise : 5',
        ],
        ph,
        semua: [ph, konduktivitas, spektro],
      );
      expect(tanpaKode.keputusan, KeputusanKenali.formulirLain);

      // Daftar formulir lain tak tersedia: tidak dilolosi, hanya tak terbaca.
      final tanpaDaftar = kenali([
        'Calibration Worksheet - Conductivity Meter LK-285-IDN',
        'Revise : 5',
      ], ph);
      expect(tanpaDaftar.keputusan, KeputusanKenali.tidakTerbaca);
    });

    test('tidak ada bukti sama sekali: tidak terbaca', () {
      final h = kenali(['Lorem ipsum', '1 2 3 4 5'], ph, semua: [ph, spektro]);

      expect(h.keputusan, KeputusanKenali.tidakTerbaca);
    });

    test('0504: formulir sekode (satu kertas) tidak dianggap bersaing', () {
      final oven = dikenal(
        'oven',
        'SIDIK-FM-CAL-0504',
        'Calibration Worksheet - Enclosure (Oven)',
      );
      final furnace = dikenal(
        'furnace',
        'SIDIK-FM-CAL-0504',
        'Calibration Worksheet - Furnace',
      );

      final h = kenali(
        ['Calibration Worksheet - Furnace LK-285-IDN', 'Revise : 3'],
        oven,
        semua: [oven, furnace, ph],
      );

      expect(h.keputusan, KeputusanKenali.cocok);
    });
  });

  // ---------------------------------------------------------------------------
  // Lewat JalankanPindaiAsli.baca: pintu kenali + revisi sebagai satu alur.
  // ---------------------------------------------------------------------------
  group('JalankanPindaiAsli: kenali dari judul', () {
    final kecil = img.Image(width: 40, height: 30);

    Future<void> gagal(
      GagalPindaiAsli sebab,
      List<TeksTerbaca> kata, {
      List<FormulirDikenal> semua = const [],
      WorksheetTemplate? t,
    }) => expectLater(
      JalankanPindaiAsli(
        halaman: MockPembacaHalaman(kata),
        pembaca: MockPembacaSel(),
        dikenal: semua,
      ).baca(kecil, template: t ?? template),
      throwsA(isA<PindaiAsliGagal>().having((e) => e.sebab, 'sebab', sebab)),
    );

    test(
      '(a) kode tidak terbaca, judul jelas: lolos, kodeTerbaca kosong',
      () async {
        final hasil = await JalankanPindaiAsli(
          halaman: MockPembacaHalaman(kataCetak(denganKode: false)),
          pembaca: MockPembacaSel(),
        ).baca(foto(), template: template);

        expect(hasil.kodeTerbaca, isNull);
        expect(hasil.dasarKenali, DasarKenali.judul);
        expect(hasil.statusRevisi, StatusRevisiAsli.sesuai);
        expect(hasil.sel, isNotEmpty);
      },
    );

    test('(e) revisi beda, judul sama: lolos dengan catatan revisi', () async {
      final hasil = await JalankanPindaiAsli(
        halaman: MockPembacaHalaman(kataCetak(denganKode: false, revisi: '5')),
        pembaca: MockPembacaSel(),
      ).baca(foto(), template: template);

      expect(hasil.statusRevisi, StatusRevisiAsli.beda);
      expect(hasil.revisiTerbaca, contains('5'));
      expect(hasil.sel, isNotEmpty);
    });

    test('revisi tak terbaca, judul sama: lolos dengan catatan', () async {
      final hasil = await JalankanPindaiAsli(
        halaman: MockPembacaHalaman(kataCetak(denganKode: false, revisi: null)),
        pembaca: MockPembacaSel(),
      ).baca(foto(), template: template);

      expect(hasil.statusRevisi, StatusRevisiAsli.tidakTerbaca);
      expect(hasil.revisiTerbaca, isNull);
    });

    test('kode cocok dan revisi beda: lolos, revisi dicatat', () async {
      final hasil = await JalankanPindaiAsli(
        halaman: MockPembacaHalaman(kataCetak(revisi: '5')),
        pembaca: MockPembacaSel(),
      ).baca(foto(), template: template);

      expect(hasil.kodeTerbaca, 'SIDIK-FM-CAL-0509');
      expect(hasil.statusRevisi, StatusRevisiAsli.beda);
    });

    test('(b) kode template terbaca, judul formulir lain: ditolak', () async {
      final kata = kataCetak(denganJudul: false);
      // Judul tercetak diganti "Conductivity Meter" (yang bukan "pH Meter").
      final ws = template.jangkarTeks.firstWhere((j) => j.teks == 'Worksheet');
      final y = (ws.kotak.y + ws.kotak.h / 2) * halaman.h;
      final x = (ws.kotak.x + ws.kotak.w) * halaman.w;
      kata.addAll([kataDi('-', x + 3, y), kataDi('Conductivity', x + 8, y)]);

      await gagal(
        GagalPindaiAsli.formulirLain,
        kata,
        semua: [
          dikenal('ph_meter', template.kodeDokumen, template.judul),
          konduktivitas,
        ],
      );
    });

    test(
      '(c) varian bernama sama, kode tak terbaca: gagal dengan kandidat',
      () async {
        final a = mikrometer.first;
        final t = templateDengan({
          'template_id': a.templateId,
          'kode_dokumen': a.kodeDokumen,
          'judul': a.judul,
        });
        final kata = <TeksTerbaca>[
          for (final j in t.jangkarTeks)
            if (!j.teks.startsWith('SIDIK-FM-CAL') && j.teks != 'Meter')
              (teks: j.teks, kotak: kotakFoto(j.kotak), keyakinan: null),
        ];
        final ws = t.jangkarTeks.firstWhere((j) => j.teks == 'Worksheet');
        final y = (ws.kotak.y + ws.kotak.h / 2) * halaman.h;
        kata.add(
          kataDi('Micrometer', (ws.kotak.x + ws.kotak.w) * halaman.w + 8, y),
        );

        await expectLater(
          JalankanPindaiAsli(
            halaman: MockPembacaHalaman(kata),
            pembaca: MockPembacaSel(),
            dikenal: mikrometer,
          ).baca(kecil, template: t),
          throwsA(
            isA<PindaiAsliGagal>()
                .having(
                  (e) => e.sebab,
                  'sebab',
                  GagalPindaiAsli.kodeTidakTerbaca,
                )
                .having((e) => e.kandidat, 'kandidat', hasLength(4)),
          ),
        );
      },
    );

    test('(d) kertas jenis lain tidak lolos', () async {
      // Teks yang terbaca milik formulir konduktivitas; template yang dipilih pH.
      final kata = halamanDari([
        'PT. SIDIK',
        'Calibration Worksheet - Conductivity Meter LK-285-IDN',
        'Revise : 5',
      ]);

      await gagal(
        GagalPindaiAsli.formulirLain,
        kata,
        semua: [
          dikenal('ph_meter', template.kodeDokumen, template.judul),
          konduktivitas,
        ],
      );
    });

    test('tanpa bukti judul atau kode: tetap berhenti (bukan lolos)', () async {
      await gagal(GagalPindaiAsli.kodeTidakTerbaca, [
        for (final j in template.jangkarTeks)
          if (!j.teks.startsWith('SIDIK-FM-CAL') &&
              !const {'Worksheet', 'Meter'}.contains(j.teks))
            (teks: j.teks, kotak: kotakFoto(j.kotak), keyakinan: null),
      ]);
    });

    test(
      'kode cocok tetap lolos tanpa daftar formulir lain (perilaku lama)',
      () async {
        final hasil = await JalankanPindaiAsli(
          halaman: MockPembacaHalaman(kataCetak(denganJudul: false)),
          pembaca: MockPembacaSel(),
        ).baca(foto(), template: template);

        expect(hasil.kodeTerbaca, 'SIDIK-FM-CAL-0509');
        expect(hasil.dasarKenali, DasarKenali.kode);
      },
    );

    test('sebab kenali tidak bocor ke tahap sesudahnya', () async {
      // Lolos kenali + revisi -> berhenti di mutu foto kecil, bukan sebab kenali.
      await expectLater(
        JalankanPindaiAsli(
          halaman: MockPembacaHalaman(kataCetak(denganKode: false)),
          pembaca: MockPembacaSel(),
        ).baca(kecil, template: template),
        throwsA(
          isA<PindaiAsliGagal>().having(
            (e) => e.sebab,
            'sebab',
            isNot(isIn(sebabKenaliGagal)),
          ),
        ),
      );
    });
  });
}
