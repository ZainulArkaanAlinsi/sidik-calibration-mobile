import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Geometri kotak sel — empat cara kotak bisa SALAH tanpa kelihatan salah.
///
/// ## Kenapa berkas ini terpisah dari `kotak_sel_foto_test.dart`
///
/// Yang di sana menjaga kotaknya ADA dan tempatnya benar pada foto yang rapi.
/// Yang di sini menjaga kotaknya **nggak menipu** waktu fotonya nggak rapi —
/// dan itu keadaan yang jauh lebih sering di lapangan.
///
/// Semuanya satu akibat yang sama: potongan citra yang memuat angka TETANGGA,
/// lalu dilabeli angka yang diketik teknisi untuk sel INI. Model yang dilatih
/// dengan pasangan begitu belajar bahwa coretan "7" itu bernama "3" — dan dia
/// salah dengan percaya diri, karena datanya sendiri yang bohong.
///
/// Empat-empatnya ditemukan review CodeRabbit atas commit `791aa52`, lalu
/// dibuktikan ulang di sini sebelum diperbaiki.
void main() {
  const lebarKolom = 280.0;
  const xStandar = 200.0;
  const yKepala = 100.0;
  const titik = [100.0, 200.0, 300.0];

  double xKolom(int k) => 420.0 + k * lebarKolom;

  TeksTerbaca kata(String teks, double x, double y, {double? keyakinan}) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 14, 24),
    keyakinan: keyakinan,
  );

  /// Semua pasangan kotak yang tumpang tindih — bentuk yang bikin
  /// kegagalannya kelihatan waktu test-nya merah.
  List<String> tumpangTindih(List<KotakSelFoto> kotak) {
    final hasil = <String>[];

    for (var i = 0; i < kotak.length; i++) {
      for (var j = i + 1; j < kotak.length; j++) {
        if (!kotak[i].kotak.overlaps(kotak[j].kotak)) continue;

        hasil.add(
          '${kotak[i].titikUkur}|r${kotak[i].repeatNo}|${kotak[i].fieldId} '
          'x ${kotak[j].titikUkur}|r${kotak[j].repeatNo}|${kotak[j].fieldId}',
        );
      }
    }

    return hasil;
  }

  group('jangkar baris yang jaraknya nggak rata', () {
    // Dua jangkar baris berdempetan (200 & 210) dan satu jauh (310). Median
    // jaraknya 100 — dan tinggi SEMUA kotak diturunkan dari median itu, jadi
    // dua kotak yang pusatnya cuma 10 piksel terpisah dikasih tinggi 80.
    //
    // Kenapa keadaan ini nyata, bukan dikarang: satu angka nyasar yang
    // kebetulan masuk toleransi titik ukur ikut kepilih jadi jangkar baris.
    // Fotonya sendiri wajar; yang meleset penjangkarannya.
    List<TeksTerbaca> foto() {
      const ys = [200.0, 210.0, 310.0];

      return <TeksTerbaca>[
        for (var k = 0; k < 3; k++) kata('X${k + 1}', xKolom(k), yKepala),
        for (var b = 0; b < 3; b++) ...[
          kata(
            titik[b].toStringAsFixed(1).replaceAll('.', ','),
            xStandar,
            ys[b],
          ),
          for (var k = 0; k < 3; k++) kata('9$b${k}0,5', xKolom(k), ys[b]),
        ],
      ];
    }

    test('kotaknya NGGAK boleh tumpang tindih', () {
      final hasil = const PetaTabelFoto().petakan(
        terbaca: foto(),
        titikUkur: titik,
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
      );

      expect(hasil.kotakSel, isNotEmpty, reason: 'Prasyarat fixture.');
      expect(
        tumpangTindih(hasil.kotakSel),
        isEmpty,
        reason:
            'Tinggi kotak diturunkan dari MEDIAN jarak baris, jadi baris yang '
            'tetangganya dekat dikasih kotak yang jauh lebih tinggi dari '
            'jaraknya sendiri. Potongannya memuat angka baris sebelah.',
      );
    });
  });

  group('satu baris doang', () {
    test('jangkar baris cuma satu → kotaknya KOSONG, bukan dikarang', () {
      // Docblock `_kotakSel` sudah menjanjikan ini: "Balik KOSONG kalau
      // geometrinya nggak bisa dipertanggungjawabkan — satu baris doang, atau
      // satu kolom doang."
      //
      // Satu KOLOM memang ditolak, lewat `_jarakAntarKolom` yang balik
      // `infinity`. Satu BARIS nggak: `_jarakAntarBaris` balik `tinggi huruf
      // x 2` — angka terhingga — jadi penjaganya lolos, dan tinggi kotaknya
      // diturunkan dari tinggi HURUF, bukan dari jarak antar baris. Itu persis
      // definisi kotak karangan.
      final terbaca = <TeksTerbaca>[
        for (var k = 0; k < 3; k++) kata('X${k + 1}', xKolom(k), yKepala),
        kata('100,0', xStandar, 200),
        for (var k = 0; k < 3; k++) kata('9${k}0,5', xKolom(k), 200),
      ];

      final hasil = const PetaTabelFoto().petakan(
        terbaca: terbaca,
        titikUkur: const [100.0],
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
      );

      expect(
        hasil.kotakSel,
        isEmpty,
        reason:
            'Satu jangkar baris nggak memberi SATU PUN jarak antar baris yang '
            'bisa diukur, jadi tinggi selnya nggak punya dasar sama sekali.',
      );
    });
  });

  group('label field yang berdempetan', () {
    // `cP` kebaca persis di pusat kolomnya (kertas miring, atau kotak OCR-nya
    // meleset), sementara `°C` di sebelahnya cuma 60 piksel jauhnya.
    //
    // Yang bikin ini berbahaya: `_pusatField` mencampur DUA sistem koordinat —
    // field yang labelnya ketemu pakai posisi label ASLI, yang nggak ketemu
    // dibagi rata dari pusat kolom. Nggak ada apa pun yang menjamin dua sistem
    // itu nggak bertabrakan, dan waktu bertabrakan `angkaTakTerpetakan` tetap
    // nol.
    test('kotak antar field NGGAK boleh tumpang tindih', () {
      const xSuhu = 60.0;

      final terbaca = <TeksTerbaca>[
        for (var k = 0; k < 3; k++) ...[
          kata('X${k + 1}', xKolom(k), yKepala),
          kata('cP', xKolom(k), yKepala + 40),
          kata('°C', xKolom(k) + xSuhu, yKepala + 40),
        ],
        for (var b = 0; b < titik.length; b++) ...[
          kata(
            titik[b].toStringAsFixed(1).replaceAll('.', ','),
            xStandar,
            200.0 + b * 60,
          ),
          for (var k = 0; k < 3; k++) ...[
            kata('9$b${k}0,5', xKolom(k), 200.0 + b * 60),
            kata('2$b$k,5', xKolom(k) + xSuhu, 200.0 + b * 60),
          ],
        ],
      ];

      final hasil = const PetaTabelFoto().petakan(
        terbaca: terbaca,
        titikUkur: titik,
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan', 'suhu'],
        labelField: const {'pembacaan': 'cP', 'suhu': '°C'},
      );

      expect(hasil.kotakSel, isNotEmpty, reason: 'Prasyarat fixture.');
      expect(
        tumpangTindih(hasil.kotakSel),
        isEmpty,
        reason:
            'Dua field satu Repeat berbagi satu potongan: modelnya dilatih '
            'dengan satu citra yang punya DUA label berbeda. Itu kontradiksi, '
            'bukan sekadar derau.',
      );
    });
  });

  group('kotak di tepi citra', () {
    test('kotak yang keluar batas citra NGGAK ikut dipulangkan', () {
      // Kolom pertama duduk dekat tepi kiri. Kotaknya membentang ke kiri
      // sampai x negatif — koordinat yang nggak ada isinya di citra mana pun.
      //
      // Dibiarkan lewat, dia baru meledak (atau diam-diam digeser) di tahap
      // potong citra nanti, jauh dari sini. Ditolak di sini, sebabnya masih
      // kelihatan.
      final terbaca = <TeksTerbaca>[
        for (var k = 0; k < 3; k++)
          kata('X${k + 1}', 20.0 + k * lebarKolom, yKepala),
        for (var b = 0; b < titik.length; b++) ...[
          kata(
            titik[b].toStringAsFixed(1).replaceAll('.', ','),
            0,
            200.0 + b * 60,
          ),
          for (var k = 0; k < 3; k++)
            kata('9$b${k}0,5', 20.0 + k * lebarKolom, 200.0 + b * 60),
        ],
      ];

      final hasil = const PetaTabelFoto().petakan(
        terbaca: terbaca,
        titikUkur: titik,
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
        ukuranCitra: const Size(1200, 600),
      );

      for (final k in hasil.kotakSel) {
        expect(
          k.kotak.left >= 0 &&
              k.kotak.top >= 0 &&
              k.kotak.right <= 1200 &&
              k.kotak.bottom <= 600,
          isTrue,
          reason:
              'Kotak r${k.repeatNo} titik ${k.titikUkur} keluar citra: '
              '${k.kotak}. Potongan di luar citra itu bukan sel.',
        );
      }

      expect(
        hasil.kotakSel,
        isNotEmpty,
        reason: 'Yang di dalam citra tetap harus dipulangkan.',
      );
    });

    test('tanpa ukuran citra, perilakunya nggak berubah', () {
      // Penjagaan tepi cuma bisa jalan kalau ukurannya diberitahu. Yang nggak
      // memberitahu (test lama, pemanggil yang belum sempat diubah) harus
      // tetap dapat kotaknya — kalau nggak, "diperketat" diam-diam jadi
      // "semua kotak hilang".
      final terbaca = <TeksTerbaca>[
        for (var k = 0; k < 3; k++) kata('X${k + 1}', xKolom(k), yKepala),
        for (var b = 0; b < titik.length; b++) ...[
          kata(
            titik[b].toStringAsFixed(1).replaceAll('.', ','),
            xStandar,
            200.0 + b * 60,
          ),
          for (var k = 0; k < 3; k++)
            kata('9$b${k}0,5', xKolom(k), 200.0 + b * 60),
        ],
      ];

      final hasil = const PetaTabelFoto().petakan(
        terbaca: terbaca,
        titikUkur: titik,
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
      );

      expect(hasil.kotakSel, hasLength(9));
    });
  });

  group('yang dibuang dilaporkan', () {
    // Usulan review CodeRabbit atas PR ini, dan usulannya benar: aturan tepi
    // punya keadaan lapangan yang wajar di mana dia membuang sel yang
    // coretannya sebenarnya masih utuh — teknisi memotret dengan bingkai
    // terlalu rapat. Frekuensinya nggak bisa dihitung dari kode; repo ini
    // nggak punya satu pun korpus foto.
    //
    // Jadi yang bisa dilakukan bukan menebak frekuensinya, tapi membuatnya
    // BISA DIUKUR. Kalau angkanya nanti tinggi di lapangan, yang salah cara
    // memotretnya — dan itu dijawab dengan petunjuk bingkai, bukan dengan
    // melonggarkan penjagaan yang baru saja dipasang.
    //
    // Polanya sudah ada di kelas ini: `angkaTakTerpetakan` persis begini.
    test('kotak yang dibuang karena tepi citra ikut dihitung', () {
      final terbaca = <TeksTerbaca>[
        for (var k = 0; k < 3; k++)
          kata('X${k + 1}', 20.0 + k * lebarKolom, yKepala),
        for (var b = 0; b < titik.length; b++) ...[
          kata(
            titik[b].toStringAsFixed(1).replaceAll('.', ','),
            0,
            200.0 + b * 60,
          ),
          for (var k = 0; k < 3; k++)
            kata('9$b${k}0,5', 20.0 + k * lebarKolom, 200.0 + b * 60),
        ],
      ];

      final hasil = const PetaTabelFoto().petakan(
        terbaca: terbaca,
        titikUkur: titik,
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
        ukuranCitra: const Size(1200, 600),
      );

      expect(
        hasil.kotakSelDibuang,
        greaterThan(0),
        reason:
            'Kolom pertama duduk di tepi kiri, jadi ada yang dibuang. Dibuang '
            'diam-diam bikin tingkat penolakan mustahil diukur di lapangan.',
      );
    });

    test('foto yang rapi: nggak ada yang dibuang', () {
      // Penjaga arah. Tanpa ini, penghitung yang selalu naik pun kelihatan
      // benar, dan angkanya berhenti berarti apa-apa.
      final terbaca = <TeksTerbaca>[
        for (var k = 0; k < 3; k++) kata('X${k + 1}', xKolom(k), yKepala),
        for (var b = 0; b < titik.length; b++) ...[
          kata(
            titik[b].toStringAsFixed(1).replaceAll('.', ','),
            xStandar,
            200.0 + b * 60,
          ),
          for (var k = 0; k < 3; k++)
            kata('9$b${k}0,5', xKolom(k), 200.0 + b * 60),
        ],
      ];

      final hasil = const PetaTabelFoto().petakan(
        terbaca: terbaca,
        titikUkur: titik,
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
        ukuranCitra: const Size(2000, 900),
      );

      expect(hasil.kotakSel, hasLength(9));
      expect(hasil.kotakSelDibuang, 0);
    });

    test('jangkar kurang: NOL, bukan dihitung sebagai dibuang', () {
      // Bedanya menentukan obatnya. Jangkar yang nggak cukup itu geometri yang
      // NGGAK PERNAH ADA — jepretan ulang yang benar, bukan bingkai yang beda.
      // Dihitung sebagai "dibuang", dua keadaan yang obatnya beda jadi
      // kelihatan sama, dan angkanya berhenti bisa dipakai memutuskan apa pun.
      final terbaca = <TeksTerbaca>[
        for (var k = 0; k < 3; k++) kata('X${k + 1}', xKolom(k), yKepala),
        kata('100,0', xStandar, 200),
        for (var k = 0; k < 3; k++) kata('9${k}0,5', xKolom(k), 200),
      ];

      final hasil = const PetaTabelFoto().petakan(
        terbaca: terbaca,
        titikUkur: const [100.0],
        pengulangan: const [1, 2, 3],
        fieldPerRepeat: const ['pembacaan'],
        ukuranCitra: const Size(2000, 900),
      );

      expect(
        hasil.kotakSel,
        isEmpty,
        reason: 'Prasyarat: jangkar barisnya satu.',
      );
      expect(hasil.kotakSelDibuang, 0);
    });
  });
}
