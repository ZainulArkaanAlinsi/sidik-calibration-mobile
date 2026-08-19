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

  /// Kepala kolom yang tercetak beda per formulir: lembar hasil
  /// `ocr:cetak-lembar` nyetak `X1`, formulir lain nyetak `Repeat 1`. Bawaannya
  /// nerima dua-duanya — kertas lama lab belum dipastikan bentuknya, dan
  /// nerima keduanya nggak bisa bikin salah taruh karena dua tulisan itu cuma
  /// ada di kepala kolom.
  test('kepala kolom `Repeat n` kebaca sama kayak `Xn`', () {
    final terbaca = [
      for (final t in tabel())
        if (RegExp(r'^X\d$').hasMatch(t.teks))
          (teks: 'Repeat ${t.teks.substring(1)}', kotak: t.kotak)
        else
          t,
    ];

    final hasil = petakan(terbaca);

    expect(hasil.sel, hasLength(30), reason: '10 titik × 3 Repeat');
    expect(hasil.angkaTakTerpetakan, 0);

    final peta = {
      for (final s in hasil.sel) '${s.titikUkur}|${s.repeatNo}': s.teks,
    };

    expect(peta['${titik[0]}|1'], bacaan[0][0]);
    expect(peta['${titik.last}|3'], bacaan.last[2]);
  });

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

  /// **Bug asli:** lembar Viscometer nyetak label larutan bulat di kolom
  /// Standard ("100"/"1000"/"60000" cP), tapi angka yang dipakai ngitung
  /// nilai sertifikat pada 25 °C (`ViscometerProfile::TITIK`):
  /// 99,65 / 1018 / 59003 cP. Titik ke-2 & ke-3 meleset 1,77% & 1,69% dari
  /// labelnya — jauh di luar toleransi jangkar angka (0,5%, `_toleransiTitik`),
  /// jadi dua dari tiga baris nggak akan PERNAH kejangkar lewat angka, sebagus
  /// apa pun fotonya. Yang benar: dicocokkan sebagai TEKS ke label yang
  /// beneran tercetak (`labelTercetak`), bukan dilonggarkan toleransinya.
  group('Viscometer: label tercetak beda dari nilai sertifikat', () {
    const titikUkur = [99.65, 1018.0, 59003.0];
    final labelTercetak = {99.65: '100', 1018.0: '1000', 59003.0: '60000'};
    // Meleset jelas dari titiknya (bukan cuma beberapa digit di belakang
    // koma) — supaya pembacaan nggak kebetulan ikut lolos toleransi jangkar
    // angka dan diam-diam jadi jangkar barisnya sendiri sebelum labelnya
    // sempat diuji. "Before Adjustment" itu maksudnya: alat MEMANG belum
    // sesuai standar.
    final pembacaan = {99.65: '97,20', 1018.0: '985,40', 59003.0: '61250,00'};

    const xStandar = 200.0;
    const xRepeat1 = 420.0;
    const yKepala = 100.0;
    const yBaris = [200.0, 260.0, 320.0];

    List<TeksTerbaca> lembar() => [
      kata('X1', xRepeat1, yKepala),
      for (var i = 0; i < titikUkur.length; i++) ...[
        kata(labelTercetak[titikUkur[i]]!, xStandar, yBaris[i]),
        kata(pembacaan[titikUkur[i]]!, xRepeat1, yBaris[i]),
      ],
    ];

    test('tanpa labelTercetak, dua dari tiga baris hilang', () {
      final hasil = const PetaTabelFoto().petakan(
        terbaca: lembar(),
        titikUkur: titikUkur,
        pengulangan: const [1],
        fieldPerRepeat: const ['pembacaan'],
      );

      expect(hasil.titikKetemu, contains(99.65));
      expect(hasil.titikKetemu, isNot(contains(1018.0)));
      expect(hasil.titikKetemu, isNot(contains(59003.0)));
      expect(hasil.sel, hasLength(1), reason: 'cuma baris 100 cP yang kejangkar');
    });

    test('dengan labelTercetak, ketiga baris kejangkar & angkanya benar', () {
      final hasil = const PetaTabelFoto().petakan(
        terbaca: lembar(),
        titikUkur: titikUkur,
        pengulangan: const [1],
        fieldPerRepeat: const ['pembacaan'],
        labelTercetak: labelTercetak,
      );

      expect(hasil.titikKetemu, containsAll(titikUkur));
      expect(hasil.sel, hasLength(3));

      final peta = {
        for (final s in hasil.sel) s.titikUkur: s.teks,
      };

      expect(peta[99.65], pembacaan[99.65]);
      expect(peta[1018.0], pembacaan[1018.0]);
      expect(peta[59003.0], pembacaan[59003.0]);
    });
  });

  /// Lembar Viscometer UTUH seperti kertasnya: 3 baris × 5 Repeat × 2
  /// sub-kolom (cP + °C), kepala kolomnya NOMOR POLOS `1`..`5` di bawah
  /// tulisan `UUT Reading`.
  ///
  /// **Bug asli:** formulir Rev.3 nggak nyetak `X1`/`Repeat 1` — cuma nomor
  /// polos — dan `prefiks_pengulangan` cuma dikirim profil Spectrophotometer.
  /// Jadi jangkar kolomnya nggak pernah ketemu, dan tiap jepretan balik nol
  /// sel dengan pesan "nggak ada angka yang bisa dipastikan tempatnya" —
  /// sebagus apa pun fotonya.
  group('Viscometer: lembar utuh, kepala kolom nomor polos', () {
    const titikUkur = [99.65, 1018.0, 59003.0];
    final label = {99.65: '100', 1018.0: '1000', 59003.0: '60000'};

    // Angka lembar kerja: pembacaan cP + suhu larutan °C, per Repeat.
    final bacaan = {
      99.65: ['97,20', '97,25', '97,18', '97,22', '97,19'],
      1018.0: ['985,40', '985,60', '985,30', '985,50', '985,45'],
      59003.0: ['61250,00', '61248,00', '61252,00', '61249,00', '61251,00'],
    };
    final suhu = {
      99.65: ['25,10', '25,12', '25,11', '25,13', '25,10'],
      1018.0: ['25,20', '25,21', '25,19', '25,22', '25,20'],
      59003.0: ['25,30', '25,31', '25,29', '25,32', '25,30'],
    };

    const xStandar = 150.0;
    const yJudul = 60.0;
    const yNomor = 110.0;
    const ySatuan = 150.0;
    const yBaris = [220.0, 300.0, 380.0];

    // Tiap Repeat dua sub-kolom: cP di kiri, °C di kanannya.
    double xBacaan(int r) => 320.0 + r * 300.0;
    double xSuhu(int r) => xBacaan(r) + 140.0;
    double xNomor(int r) => xBacaan(r) + 70.0;

    /// [satuanSuhu] dibikin bisa diganti buat nguji `°C` yang kebaca meleset.
    List<TeksTerbaca> lembar({
      String satuanSuhu = '°C',
      Set<String> rusak = const {},
    }) {
      final hasil = <TeksTerbaca>[kata('UUT Reading', xBacaan(0), yJudul)];

      for (var r = 0; r < 5; r++) {
        if (!rusak.contains('nomor${r + 1}')) {
          hasil.add(kata('${r + 1}', xNomor(r), yNomor));
        }
        if (!rusak.contains('cP')) hasil.add(kata('cP', xBacaan(r), ySatuan));
        if (!rusak.contains('suhu')) {
          hasil.add(kata(satuanSuhu, xSuhu(r), ySatuan));
        }
      }

      for (var i = 0; i < titikUkur.length; i++) {
        final t = titikUkur[i];
        hasil.add(kata(label[t]!, xStandar, yBaris[i]));

        for (var r = 0; r < 5; r++) {
          hasil.add(kata(bacaan[t]![r], xBacaan(r), yBaris[i]));
          hasil.add(kata(suhu[t]![r], xSuhu(r), yBaris[i]));
        }
      }

      return hasil;
    }

    HasilPetaTabel petakanVisco(List<TeksTerbaca> terbaca) =>
        const PetaTabelFoto().petakan(
          terbaca: terbaca,
          titikUkur: titikUkur,
          pengulangan: const [1, 2, 3, 4, 5],
          fieldPerRepeat: const ['pembacaan', 'suhu'],
          labelField: const {'pembacaan': 'cP', 'suhu': '°C'},
          labelTercetak: label,
        );

    test('30 sel mendarat di baris, Repeat, & sub-kolom yang benar', () {
      final hasil = petakanVisco(lembar());

      expect(hasil.repeatKetemu, containsAll([1, 2, 3, 4, 5]));
      expect(hasil.titikKetemu, containsAll(titikUkur));
      expect(hasil.sel, hasLength(30), reason: '3 titik × 5 Repeat × 2 kolom');
      expect(hasil.angkaTakTerpetakan, 0);

      final peta = {
        for (final s in hasil.sel)
          '${s.titikUkur}|${s.repeatNo}|${s.fieldId}': s.teks,
      };

      for (var i = 0; i < titikUkur.length; i++) {
        final t = titikUkur[i];

        for (var r = 0; r < 5; r++) {
          expect(
            peta['$t|${r + 1}|pembacaan'],
            bacaan[t]![r],
            reason: 'Titik $t Repeat ${r + 1} kolom cP salah.',
          );
          expect(
            peta['$t|${r + 1}|suhu'],
            suhu[t]![r],
            reason: 'Titik $t Repeat ${r + 1} kolom °C salah.',
          );
        }
      }
    });

    /// `°C` itu bentuk tersulit buat ML Kit di seluruh lembar. Kalau
    /// lingkarannya kebaca sebagai huruf, jepretan yang sehat nggak boleh
    /// ditolak gara-gara satu karakter yang bukan bagian angkanya.
    test('`°C` yang kebaca `oC` / `C` polos tetap kejangkar', () {
      for (final varian in ['oC', 'C', '0C', '˚C']) {
        final hasil = petakanVisco(lembar(satuanSuhu: varian));

        expect(
          hasil.sel,
          hasLength(30),
          reason: 'satuan suhu kebaca `$varian` mestinya masih kena.',
        );
      }
    });

    test('deret nomor kurang satu → BATAL, bukan dipakai sebagian', () {
      // Empat kolom kejangkar & satu nggak itu jauh lebih berbahaya daripada
      // nol: angka Repeat 3 bakal ketarik ke kolom tetangga terdekat.
      final hasil = petakanVisco(lembar(rusak: {'nomor3'}));

      expect(hasil.sel, isEmpty);
      expect(hasil.repeatKetemu, isEmpty);
    });

    test('label sub-kolom hilang → NOL sel + laporan kolom mana', () {
      // Kalau `cP` nggak kebaca sementara `°C` kebaca, tanpa penjaga ini
      // SELURUH pembacaan mendarat di kolom suhu — kotaknya terisi rapi,
      // jumlahnya pas, dan baru ketahuan aneh di sertifikat.
      final hasil = petakanVisco(lembar(rusak: {'cP'}));

      expect(hasil.sel, isEmpty);
      expect(hasil.labelKolomKurang, contains('cP'));
    });

    test('pembacaan nggak pernah nyamar jadi kepala kolom', () {
      // Titik 100 cP dibaca `1`..`5` (alat rusak parah / salah satuan). Angka
      // itu ada di BARIS ISI, jadi syarat "kepala selalu di atas isi" yang
      // harus nolak dia — bukan kebetulan nilainya beda.
      final terbaca = [
        ...lembar(rusak: {'nomor1', 'nomor2', 'nomor3', 'nomor4', 'nomor5'}),
        for (var r = 0; r < 5; r++) kata('${r + 1}', xBacaan(r), yBaris[0]),
      ];

      final hasil = petakanVisco(terbaca);

      expect(hasil.repeatKetemu, isEmpty, reason: 'isi tabel bukan kepala');
      expect(hasil.sel, isEmpty);
    });
  });
}
