import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Foto SATU tabel → angka mendarat di baris & kolom yang benar.
///
/// Tabel yang ditiru di sini tabel Holmium Spectrophotometer yang beneran
/// (10 titik × X1..X3), angkanya dari lembar kerja asli. Koordinatnya disusun
/// seperti tabel tercetak: kolom nilai standar di kiri, tiga kolom pembacaan
/// di kanannya, baris berjarak rata.
///
/// **Yang diuji bukan ketajaman OCR-nya** — itu urusan ML Kit dan cuma bisa
/// dibuktikan di HP. Yang diuji di sini satu-satunya hal yang bisa salah tanpa
/// ngasih gejala: angka mendarat di sel yang salah.
void main() {
  const titik = [
    279.6, 287.7, 334.0, 360.9, 418.6, 445.8, 453.6, 460.0, 536.3, 637.9,
  ];

  /// Pembacaan per baris, urut X1 X2 X3 — disalin dari lembar aslinya.
  const bacaan = [
    ['280,00', '280,00', '280,00'],
    ['288,00', '288,00', '288,00'],
    ['333,74', '333,74', '333,74'],
    ['360,35', '360,59', '360,60'],
    ['418,60', '418,34', '418,34'],
    ['445,44', '445,69', '445,69'],
    ['453,55', '453,29', '453,29'],
    ['459,13', '459,37', '459,37'],
    ['536,63', '536,37', '536,37'],
    ['637,45', '637,18', '637,18'],
  ];

  // Tata letak tabelnya, dalam piksel citra.
  const xNomor = 60.0;
  const xStandar = 200.0;
  const xKolom = [420.0, 700.0, 980.0];
  const yKepala = 100.0;
  const yBarisPertama = 200.0;
  const tinggiBaris = 60.0;

  TeksTerbaca kata(String teks, double x, double y) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 14, 24),
  );

  /// Susun hasil OCR tabel utuh. [rusak] menghapus teks tertentu — dipakai buat
  /// menguji apa yang terjadi waktu jangkarnya nggak kebaca.
  List<TeksTerbaca> tabel({
    Set<String> rusak = const {},
    bool pakaiNomorUrut = true,
  }) {
    final hasil = <TeksTerbaca>[
      for (var k = 0; k < 3; k++)
        if (!rusak.contains('X${k + 1}')) kata('X${k + 1}', xKolom[k], yKepala),
    ];

    for (var i = 0; i < titik.length; i++) {
      final y = yBarisPertama + i * tinggiBaris;

      // Kolom "No." — angka 1..10 yang gampang ketuker sama pembacaan.
      if (pakaiNomorUrut) hasil.add(kata('${i + 1}', xNomor, y));

      final standar = titik[i].toStringAsFixed(1).replaceAll('.', ',');
      if (!rusak.contains(standar)) hasil.add(kata(standar, xStandar, y));

      for (var k = 0; k < 3; k++) {
        final teks = bacaan[i][k];
        if (!rusak.contains(teks)) hasil.add(kata(teks, xKolom[k], y));
      }
    }

    return hasil;
  }

  HasilPetaTabel petakan(List<TeksTerbaca> terbaca) =>
      const PetaTabelFoto().petakan(
        terbaca: terbaca,
        titikUkur: titik,
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
      );

  test('30 sel mendarat di baris & kolom yang benar', () {
    final hasil = petakan(tabel());

    expect(hasil.sel, hasLength(30), reason: '10 titik × 3 Repeat');
    expect(hasil.angkaTakTerpetakan, 0);

    final peta = {
      for (final s in hasil.sel) '${s.titikUkur}|${s.repeatNo}': s.teks,
    };

    for (var i = 0; i < titik.length; i++) {
      for (var k = 0; k < 3; k++) {
        expect(
          peta['${titik[i]}|${k + 1}'],
          bacaan[i][k],
          reason: 'Titik ${titik[i]} Repeat ${k + 1} salah.',
        );
      }
    }
  });

  /// Ini bentuk kegagalan yang paling mahal, dan satu-satunya yang nggak
  /// ngasih gejala: angka baris ke-8 mendarat di baris ke-7.
  test('baris nggak pernah geser, walau dua titiknya berdekatan', () {
    final hasil = petakan(tabel());
    final peta = {
      for (final s in hasil.sel) '${s.titikUkur}|${s.repeatNo}': s.teks,
    };

    // 453,6 & 460,0 cuma beda 1,4% — dua baris paling gampang ketuker di
    // seluruh lembar spektro.
    expect(peta['453.6|1'], '453,55');
    expect(peta['460.0|1'], '459,13');
  });

  test('urutan hasil OCR diacak → angkanya identik', () {
    // ML Kit nggak menjamin urutan bacaannya. Kalau pemetaannya diam-diam
    // ngandelin urutan, ini yang nangkep.
    final urut = petakan(tabel());
    final balik = petakan(tabel().reversed.toList());

    String kunci(HasilPetaTabel h) => ([
      for (final s in h.sel) '${s.titikUkur}|${s.repeatNo}=${s.teks}',
    ]..sort()).join(',');

    expect(kunci(balik), kunci(urut));
  });

  test('nomor urut di kolom kiri nggak ikut jadi pembacaan', () {
    // Kolom "No." isinya 1..10 — angka yang sah, dan kalau ikut kepetakan dia
    // bakal ngisi kolom X1 semua baris.
    final dengan = petakan(tabel());
    final tanpa = petakan(tabel(pakaiNomorUrut: false));

    expect(dengan.sel.length, tanpa.sel.length);
  });

  group('yang nggak bisa dipastikan DIBUANG, bukan ditebak', () {
    test('baris yang nilai standarnya nggak kebaca nggak pernah keisi', () {
      // Jangkarnya hilang → tiga pembacaan di baris itu nggak punya dasar
      // buat ditaruh di mana pun. Yang benar: nggak keisi, dan teknisi
      // mengetiknya sendiri.
      final hasil = petakan(tabel(rusak: {'334,0'}));

      expect(hasil.titikKetemu, isNot(contains(334.0)));
      expect(hasil.sel.any((s) => s.titikUkur == 334.0), isFalse);
      expect(hasil.sel, hasLength(27), reason: '9 titik × 3 Repeat');

      // Dan yang kebuang dilaporkan — teknisi berhak tau ada yang nggak
      // keangkut, bukan mengira tabelnya memang segitu.
      expect(hasil.angkaTakTerpetakan, 3);
    });

    test('kepala kolom nggak kebaca → seluruh kolomnya nggak keisi', () {
      final hasil = const PetaTabelFoto().petakan(
        terbaca: tabel(rusak: {'X2'}),
        titikUkur: titik,
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
      );

      expect(hasil.repeatKetemu, isNot(contains(2)));
      expect(hasil.sel.any((s) => s.repeatNo == 2), isFalse);
    });

    test('nggak ada jangkar sama sekali → NOL sel, bukan tebakan urutan', () {
      // Yang difoto bukan tabelnya (mis. kefoto halaman lain, atau tabel alat
      // yang beda). Kalau di sini dia memetakan pakai urutan, angkanya masuk
      // semua ke tempat yang salah tanpa satu pun error.
      final hasil = const PetaTabelFoto().petakan(
        terbaca: [
          kata('12,5', 400, 200),
          kata('13,1', 700, 200),
          kata('14,9', 980, 200),
        ],
        titikUkur: titik,
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
      );

      expect(hasil.sel, isEmpty);
      expect(hasil.kosong, isTrue);
      expect(hasil.angkaTakTerpetakan, 3);
    });

    test('dua angka jatuh di sel yang sama → dua-duanya dibuang', () {
      // Nggak ada dasar buat milih salah satu, dan milih asal itu persis cara
      // angka mendarat di tempat yang salah.
      final hasil = petakan([
        ...tabel(),
        kata('999,99', xKolom[0], yBarisPertama),
      ]);

      expect(hasil.sel.any((s) => s.titikUkur == 279.6 && s.repeatNo == 1),
          isFalse);
      expect(hasil.sel, hasLength(29));
    });
  });

  test('dua kolom per Repeat dipisah lewat kepala kolomnya', () {
    // Lembar pH: tiap Repeat punya `pembacaan` & `suhu`, dan dua-duanya angka.
    // Tanpa jangkar kepala kolom, suhu bisa mendarat di kolom pembacaan.
    const xPh = [420.0, 700.0];
    const xSuhu = [560.0, 840.0];

    final terbaca = <TeksTerbaca>[
      kata('X1', 480, 60),
      kata('X2', 760, 60),
      kata('pH', xPh[0], yKepala),
      kata('°C', xSuhu[0], yKepala),
      kata('pH', xPh[1], yKepala),
      kata('°C', xSuhu[1], yKepala),
      kata('4,00', xStandar, yBarisPertama),
      kata('4,01', xPh[0], yBarisPertama),
      kata('25,1', xSuhu[0], yBarisPertama),
      kata('4,02', xPh[1], yBarisPertama),
      kata('25,2', xSuhu[1], yBarisPertama),
    ];

    final hasil = const PetaTabelFoto().petakan(
      terbaca: terbaca,
      titikUkur: const [4.0],
      pengulangan: const [1, 2],
      fieldPerRepeat: const ['pembacaan', 'suhu'],
      labelField: const {'pembacaan': 'pH', 'suhu': '°C'},
    );

    final peta = {
      for (final s in hasil.sel)
        '${s.titikUkur}|${s.repeatNo}|${s.fieldId}': s.teks,
    };

    expect(peta['4.0|1|pembacaan'], '4,01');
    expect(peta['4.0|1|suhu'], '25,1');
    expect(peta['4.0|2|pembacaan'], '4,02');
    expect(peta['4.0|2|suhu'], '25,2');
  });
}
