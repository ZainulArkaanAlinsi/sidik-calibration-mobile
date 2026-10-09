import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/models/worksheet_template.dart';
import 'package:sidik_calibration/services/jalankan_pindai_asli.dart'
    show cariKodeDokumen;
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/registrasi_jangkar_teks.dart';

/// Penyelarasan foto formulir ASLI ke halaman PDF lewat tulisan cetaknya —
/// PANDUAN-OCR-LEMBAR-KERJA.md §3 langkah 2 (RATAKAN).
///
/// Jangkar yang dipakai jangkar NYATA formulir pH: 93 kata
/// `geometri.jangkar_teks` di `test/assets/template-asli-ph_meter-0509.json`,
/// disalin dari `database/ocr-templates/asli/ph_meter-0509.draf.json` (repo
/// API, origin/main 3222d1b) lewat logika `FormulirAsli::untukKode()`. Yang
/// sintetis cuma FOTONYA: posisi kata di foto = homography yang diketahui
/// + derau, supaya hasilnya bisa diadu ke jawaban yang pasti.
void main() {
  final template = WorksheetTemplate.fromJson(
    jsonDecode(
          File(
            'test/assets/template-asli-ph_meter-0509.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>,
  );
  final halaman = template.halamanPt!;

  group('normalisasi — sama persis dengan server', () {
    test('huruf & angka saja, huruf besar (teksJangkar)', () {
      expect(normalisasiJangkar('(oC)'), 'OC');
      expect(normalisasiJangkar(':Insitu:'), 'INSITU');
      expect(normalisasiJangkar('14+/992613877'), '14992613877');
      expect(normalisasiJangkar('Sensor/SH1/20'), 'SENSORSH120');
      // `°` simbol, bukan huruf — dibuang, sama dengan `\p{L}\p{N}` PHP.
      expect(normalisasiJangkar('(°C)'), 'C');
      expect(normalisasiJangkar('…'), '');
    });

    test('kode formulir: cuma spasi & huruf besar, tanpa tebak karakter', () {
      expect(
        normalisasiKodeDokumen(' sidik-fm-cal- 0509 '),
        'SIDIK-FM-CAL-0509',
      );
      expect(
        normalisasiKodeDokumen('SIDIK-FM-CAL-O509'),
        isNot('SIDIK-FM-CAL-0509'),
      );
    });

    test('kuadran dari pusat kotak, batas 0,5 (kuadran() server)', () {
      expect(kuadranKotak(const KotakSel(x: 0.1, y: 0.1, w: 0.1, h: 0.1)), 0);
      expect(kuadranKotak(const KotakSel(x: 0.6, y: 0.1, w: 0.1, h: 0.1)), 1);
      expect(kuadranKotak(const KotakSel(x: 0.1, y: 0.6, w: 0.1, h: 0.1)), 2);
      expect(kuadranKotak(const KotakSel(x: 0.45, y: 0.45, w: 0.1, h: 0.1)), 3);
    });
  });

  group('kode formulir di teks halaman', () {
    TeksTerbaca t(String s) =>
        (teks: s, kotak: const Rect.fromLTWH(0, 0, 10, 10), keyakinan: null);

    test('terbaca utuh → teks mentahnya', () {
      final c = cariKodeDokumen([
        t('Revise'),
        t('SIDIK-FM-CAL-0509'),
      ], 'SIDIK-FM-CAL-0509');
      expect(c.cocok, 'SIDIK-FM-CAL-0509');
    });

    test('dipecah ML Kit jadi dua kata → tetap dikenali', () {
      final c = cariKodeDokumen([
        t('SIDIK-FM-CAL-'),
        t('0509'),
      ], 'SIDIK-FM-CAL-0509');
      expect(c.cocok, 'SIDIK-FM-CAL- 0509');
    });

    test('kode formulir LAIN yang sah → dilaporkan sebagai formulir lain', () {
      final c = cariKodeDokumen([t('SIDIK-FM-CAL-0510')], 'SIDIK-FM-CAL-0509');
      expect(c.cocok, isNull);
      expect(c.lain, 'SIDIK-FM-CAL-0510');
    });

    test('salah baca O/0 → BUKAN formulir lain, dan tidak dibetulkan', () {
      final c = cariKodeDokumen([t('SIDIK-FM-CAL-O5O9')], 'SIDIK-FM-CAL-0509');
      expect(c.cocok, isNull);
      expect(c.lain, isNull);
    });
  });

  group('Homografi kuadrat-terkecil', () {
    final benar = _homografiUji();

    test('empat titik → homography yang sama persis', () {
      final sumber = <Titik>[
        (x: 10, y: 20),
        (x: 700, y: 30),
        (x: 690, y: 580),
        (x: 20, y: 600),
      ];
      final tujuan = [for (final p in sumber) benar.terapkan(p)!];
      final h = Homografi.kuadratTerkecil(sumber, tujuan)!;

      for (final p in [...sumber, (x: 400.0, y: 300.0)]) {
        final a = h.terapkan(p)!;
        final b = benar.terapkan(p)!;
        expect((a.x - b.x).abs(), lessThan(1e-6));
        expect((a.y - b.y).abs(), lessThan(1e-6));
      }
    });

    test('banyak titik tanpa derau → tepat, dan inversnya pulang-pergi', () {
      final sumber = <Titik>[
        for (var i = 0; i < 30; i++) (x: 25.0 * i, y: 600 - 19.0 * i),
        for (var i = 0; i < 10; i++) (x: 750 - 60.0 * i, y: 40.0 + 55 * i),
      ];
      final tujuan = [for (final p in sumber) benar.terapkan(p)!];
      final h = Homografi.kuadratTerkecil(sumber, tujuan)!;
      final balik = h.invers()!;

      for (final p in sumber) {
        final q = balik.terapkan(h.terapkan(p)!)!;
        expect((q.x - p.x).abs(), lessThan(1e-6));
        expect((q.y - p.y).abs(), lessThan(1e-6));
      }
    });

    test('titik segaris → null, bukan homography karangan', () {
      final sumber = <Titik>[
        for (var i = 0; i < 6; i++) (x: 10.0 * i, y: 5.0 * i),
      ];
      expect(Homografi.kuadratTerkecil(sumber, sumber), isNull);
    });
  });

  group('pencocok jangkar teks', () {
    test('hanya jangkar yang teksnya UNIK di template yang dipakai', () {
      // Name ×5, 4.00 ×2, Calibration ×3 di formulir pH. Satu kata "Name" di
      // foto tidak boleh dipasangkan ke salah satunya — itu menebak.
      final terbaca = [
        _kata('Name', (x: 100, y: 100)),
        _kata('4.00', (x: 200, y: 200)),
        _kata('Thermohygro', (x: 300, y: 300)),
      ];
      final calon = const RegistrasiJangkarTeks().calon(
        jangkar: template.jangkarTeks,
        halamanPt: halaman,
        terbaca: terbaca,
      );

      expect(calon, hasLength(1));
      expect(template.jangkarTeks[calon.single.indeks].teks, 'Thermohygro');
    });

    test('tanda baca beda tetap cocok (":Insitu:" ↔ "Insitu")', () {
      final calon = const RegistrasiJangkarTeks().calon(
        jangkar: template.jangkarTeks,
        halamanPt: halaman,
        terbaca: [_kata('Insitu', (x: 1, y: 1))],
      );

      expect(calon, hasLength(1));
      expect(template.jangkarTeks[calon.single.indeks].teks, ':Insitu:');
      // Yang dikirim teks MENTAH foto, bukan teks template.
      expect(calon.single.teksMentah, 'Insitu');
    });

    test('teks yang muncul terlalu sering di foto dilewati', () {
      final calon = const RegistrasiJangkarTeks().calon(
        jangkar: template.jangkarTeks,
        halamanPt: halaman,
        terbaca: [
          for (var i = 0; i < 4; i++) _kata('Thermohygro', (x: 10.0 * i, y: 1)),
        ],
      );

      expect(calon, isEmpty);
    });
  });

  group('RANSAC pada foto sintetis formulir pH', () {
    final benar = _homografiUji();

    test('outlier & kata nyasar dibuang, homography pulih, residual kecil', () {
      final acak = math.Random(7);
      final terbaca = <TeksTerbaca>[];
      final digeser = <String>{};
      var ke = 0;

      for (final j in template.jangkarTeks) {
        ke++;
        // Sebagian kata tidak terbaca ML Kit sama sekali.
        if (ke % 9 == 0) continue;

        final pusat = (
          x: (j.kotak.x + j.kotak.w / 2) * halaman.w,
          y: (j.kotak.y + j.kotak.h / 2) * halaman.h,
        );
        var p = benar.terapkan(pusat)!;

        // Derau kotak ML Kit: ±1 px (≈ ±0,23 pt di 4,3 px/pt).
        p = (
          x: p.x + (acak.nextDouble() * 2 - 1),
          y: p.y + (acak.nextDouble() * 2 - 1),
        );

        // Seperempat kata digeser jauh — pasangan yang salah.
        if (ke % 4 == 0) {
          p = (x: p.x + 60 + acak.nextDouble() * 140, y: p.y - 90);
          digeser.add(j.teks);
        }

        terbaca.add(_kata(j.teks, p));
      }

      // Tulisan tangan yang kebetulan sama dengan kata cetak unik.
      terbaca
        ..add(_kata('Thermohygro', (x: 2100, y: 1500)))
        ..add(_kata('TH-2', (x: 900, y: 2200)));

      final reg = const RegistrasiJangkarTeks();
      final hasil = reg.cocokkan(
        reg.calon(
          jangkar: template.jangkarTeks,
          halamanPt: halaman,
          terbaca: terbaca,
        ),
      )!;

      expect(hasil.inlier.length, greaterThanOrEqualTo(8));
      expect(hasil.menyebar, isTrue, reason: 'kuadran: ${hasil.kuadran}');
      expect(hasil.residualPt, lessThan(0.6));

      // Satu indeks paling banyak sekali (server menolak indeks kembar).
      final indeks = hasil.inlier.map((i) => i.indeks).toList();
      expect(indeks.toSet().length, indeks.length);

      // Tidak satu pun pasangan yang digeser jauh ikut jadi inlier.
      for (final i in hasil.inlier) {
        final p = benar.invers()!.terapkan(i.foto)!;
        final galat = math.sqrt(
          math.pow(p.x - i.template.x, 2) + math.pow(p.y - i.template.y, 2),
        );
        expect(galat, lessThan(1.5), reason: 'inlier #${i.indeks} meleset');
      }

      // Peta halaman → foto yang ditemukan menunjuk tempat yang sama dengan
      // yang benar, di seluruh halaman (bukan cuma dekat jangkar).
      for (final p in <Titik>[
        (x: 20, y: 20),
        (x: 772, y: 20),
        (x: 772, y: 592),
        (x: 20, y: 592),
        (x: 430, y: 230),
      ]) {
        final a = hasil.templateKeFoto.terapkan(p)!;
        final b = benar.terapkan(p)!;
        expect(
          math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2)),
          lessThan(3),
          reason: 'titik $p',
        );
      }
    });

    test('jangkar cuma di separuh atas → tidak menyebar ke 4 kuadran', () {
      final terbaca = [
        for (final j in template.jangkarTeks)
          if (j.kotak.y + j.kotak.h / 2 < 0.5)
            _kata(
              j.teks,
              benar.terapkan((
                x: (j.kotak.x + j.kotak.w / 2) * halaman.w,
                y: (j.kotak.y + j.kotak.h / 2) * halaman.h,
              ))!,
            ),
      ];

      final reg = const RegistrasiJangkarTeks();
      final hasil = reg.cocokkan(
        reg.calon(
          jangkar: template.jangkarTeks,
          halamanPt: halaman,
          terbaca: terbaca,
        ),
      )!;

      expect(hasil.inlier.length, greaterThanOrEqualTo(8));
      expect(hasil.menyebar, isFalse);
      expect(hasil.kuadran[2] + hasil.kuadran[3], 0);
    });

    test('kurang dari 4 jangkar → null', () {
      final reg = const RegistrasiJangkarTeks();
      expect(
        reg.cocokkan(
          reg.calon(
            jangkar: template.jangkarTeks,
            halamanPt: halaman,
            terbaca: [_kata('Thermohygro', (x: 1, y: 1))],
          ),
        ),
        isNull,
      );
    });

    test('foto yang sama → jawaban yang sama (benih tetap, buat audit)', () {
      final terbaca = [
        for (final j in template.jangkarTeks)
          _kata(
            j.teks,
            benar.terapkan((
              x: (j.kotak.x + j.kotak.w / 2) * halaman.w,
              y: (j.kotak.y + j.kotak.h / 2) * halaman.h,
            ))!,
          ),
      ];
      final reg = const RegistrasiJangkarTeks();
      final calon = reg.calon(
        jangkar: template.jangkarTeks,
        halamanPt: halaman,
        terbaca: terbaca,
      );

      final a = reg.cocokkan(calon)!;
      final b = reg.cocokkan(calon)!;
      expect(a.fotoKeTemplate.m, b.fotoKeTemplate.m);
      expect(a.residualPt, b.residualPt);
    });
  });
}

/// Homography uji: halaman (pt) → foto (px). 4,3 px/pt, diputar 3°, digeser,
/// plus sedikit perspektif — bentuk foto HP yang wajar.
Homografi _homografiUji() {
  const s = 4.3;
  final c = math.cos(3 * math.pi / 180) * s;
  final n = math.sin(3 * math.pi / 180) * s;

  return Homografi([c, -n, 180, n, c, 140, 2e-5, -1.5e-5, 1]);
}

TeksTerbaca _kata(String teks, Titik pusat) => (
  teks: teks,
  kotak: Rect.fromCenter(
    center: Offset(pusat.x, pusat.y),
    width: 40,
    height: 18,
  ),
  keyakinan: null,
);
