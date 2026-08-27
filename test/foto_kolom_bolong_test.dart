import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Kepala kolom yang bolong di TENGAH — dan kenapa "jarak antar jangkar"
/// bukan "lebar satu kolom".
///
/// ## Bug yang ditutup berkas ini
///
/// `batasKolom` menjaga satu hal: angka yang duduk di bawah kolom yang
/// kepalanya nggak kebaca **dibuang**, bukan ditarik ke jangkar terdekat
/// sejauh apa pun. Batas itu diturunkan dari jarak terkecil antar jangkar
/// kolom yang selamat.
///
/// Turunan itu benar cuma waktu kolom yang hilang ada di UJUNG. Begitu yang
/// hilang di TENGAH, "jarak antar jangkar yang selamat" berhenti sama dengan
/// "lebar satu kolom": dengan `X1` dan `X4` kejangkar sementara `X2` & `X3`
/// hilang, jaraknya **tiga kali** lebar kolom — jadi batasnya ikut tiga kali
/// lipat, dan angka yang duduk persis di bawah `X2` lolos lalu disimpan
/// sebagai `X1`.
///
/// Yang bikin itu kelas kegagalan paling mahal di fitur ini, bukan sekadar
/// satu angka meleset:
///
///  1. Kolom tujuannya KOSONG di baris yang sama, jadi `_buangSelKembar`
///     nggak punya apa pun buat dibandingkan.
///  2. `angkaTakTerpetakan` tetap **nol**, jadi teknisi nggak diberi tahu
///     apa-apa.
///
/// Hasilnya tabel yang penuh, wajar, dan salah kolom — persis yang batas ini
/// dipasang buat dicegah.
///
/// Sekarang tiap selisih pusat dibagi **jarak posisi kolomnya**, jadi yang
/// dipakai selalu satu lebar kolom betulan.
void main() {
  // Lima kolom berjarak rata, seperti tabel tercetak.
  const lebarKolom = 280.0;
  const xStandar = 200.0;
  const yKepala = 100.0;
  const yBarisPertama = 200.0;
  const tinggiBaris = 60.0;

  const titik = [100.0, 200.0, 300.0];

  double xKolom(int k) => 420.0 + k * lebarKolom;

  TeksTerbaca kata(String teks, double x, double y) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 14, 24),
  );

  /// Angka pembacaan baris [b] kolom [k] — beda tiap sel, supaya sel yang
  /// mendarat di kolom yang salah ketahuan dari NILAINYA.
  ///
  /// Dijauhkan dari nilai standarnya (100/200/300) DENGAN SENGAJA: pembacaan
  /// yang kebetulan jatuh di dalam toleransi titik bisa ikut kepilih jadi
  /// jangkar BARIS, dan test yang begitu nggak lagi menguji sumbu kolomnya.
  /// Berkoma juga sengaja — biar nggak bisa disangka deret nomor polos kepala
  /// kolom.
  String bacaan(int b, int k) => '9$b${k}0,5';

  /// Foto tabel utuh, dengan kepala kolom [kepala] saja yang kebaca.
  List<TeksTerbaca> foto(List<int> kepala) {
    final hasil = <TeksTerbaca>[
      for (final k in kepala) kata('X${k + 1}', xKolom(k), yKepala),
    ];

    for (var b = 0; b < titik.length; b++) {
      final y = yBarisPertama + b * tinggiBaris;

      hasil.add(
        kata(titik[b].toStringAsFixed(1).replaceAll('.', ','), xStandar, y),
      );

      for (var k = 0; k < 5; k++) {
        hasil.add(kata(bacaan(b, k), xKolom(k), y));
      }
    }

    return hasil;
  }

  HasilPetaTabel petakan(List<TeksTerbaca> terbaca) =>
      const PetaTabelFoto().petakan(
        terbaca: terbaca,
        titikUkur: titik,
        pengulangan: const [1, 2, 3, 4, 5],
        fieldPerRepeat: const ['pembacaan'],
      );

  /// `{titik|repeat: teks}` — bentuk yang bikin salah kolom kelihatan.
  Map<String, String> peta(HasilPetaTabel h) => {
    for (final s in h.sel) '${s.titikUkur}|${s.repeatNo}': s.teks,
  };

  test('kelima kolom kejangkar: semuanya mendarat di kolomnya', () {
    // Jangkar kewarasan. Tanpa ini, dua test di bawah bisa hijau gara-gara
    // fixture-nya sendiri yang nggak pernah memetakan apa pun.
    final hasil = petakan(foto(const [0, 1, 2, 3, 4]));

    expect(hasil.sel, hasLength(15), reason: '3 titik × 5 kolom');
    expect(hasil.angkaTakTerpetakan, 0);
    expect(peta(hasil)['100.0|2'], bacaan(0, 1));
    expect(peta(hasil)['300.0|5'], bacaan(2, 4));
  });

  test('DUA kolom tengah hilang: angkanya dibuang, bukan pindah kolom', () {
    // Cuma `X1` & `X4` yang kejangkar, dan itu syarat yang menentukan: nggak
    // boleh ada DUA jangkar yang bertetangga.
    //
    // Kalau ada satu saja pasangan bertetangga (`X4` & `X5` misalnya), jarak
    // TERSEMPIT-nya sudah satu lebar kolom dengan sendirinya — batasnya benar
    // secara kebetulan, dan test-nya tetap hijau walau pembagian jarak
    // posisinya dicabut. Sudah kejadian waktu berkas ini ditulis.
    //
    // Sekarang satu-satunya jarak yang ada TIGA kali lebar kolom. Sebelum
    // diperbaiki, batasnya ikut tiga kali lipat: angka di bawah `X2` (satu
    // lebar kolom dari `X1`) lolos lalu tersimpan sebagai `X1`, dan angka di
    // bawah `X3` mendarat di `X4` — tanpa `angkaTakTerpetakan` naik sedikit
    // pun.
    final hasil = petakan(foto(const [0, 3]));

    final isi = peta(hasil);

    expect(
      isi['100.0|1'],
      bacaan(0, 0),
      reason: 'Kolom yang kepalanya kebaca tetap keisi angkanya sendiri.',
    );

    expect(
      isi.keys.where((k) => k.endsWith('|2')),
      isEmpty,
      reason: 'Kolom `X2` nggak punya jangkar — nggak boleh keisi sama sekali.',
    );

    expect(
      isi['100.0|4'],
      bacaan(0, 3),
      reason: 'Kolom `X4` juga — jangkarnya kebaca.',
    );

    expect(
      isi.values,
      isNot(contains(bacaan(0, 1))),
      reason:
          'Angka di bawah `X2` NGGAK BOLEH nyangkut di kolom mana pun. Ini '
          'kegagalan yang paling mahal: kolom tujuannya kosong, jadi '
          'pembuangan sel kembar nggak punya apa pun buat dibandingkan, dan '
          'teknisi dapat tabel penuh yang isinya geser satu kolom.',
    );

    expect(
      isi.values,
      isNot(contains(bacaan(0, 2))),
      reason:
          'Angka di bawah `X3` juga nggak boleh nyangkut — sebelum '
          'diperbaiki dia mendarat di `X4`.',
    );

    expect(
      hasil.angkaTakTerpetakan,
      greaterThan(0),
      reason:
          'Yang dibuang WAJIB dilaporkan. Diam-diam membuang angka kalibrasi '
          'persis kerusakan yang batas ini dipasang buat dicegah.',
    );
  });

  test('kolom UJUNG hilang: perilaku lama nggak bergeser', () {
    // Yang hilang di ujung, jarak antar jangkar yang selamat MEMANG satu lebar
    // kolom — jadi angka perbaikannya nggak boleh mengubah apa pun di sini.
    // Tanpa penjaga arah ini, "diperketat" gampang jadi "kolom sah ikut
    // kebuang", dan teknisi kehilangan angka yang fotonya baik-baik saja.
    final hasil = petakan(foto(const [0, 1, 2, 3]));

    final isi = peta(hasil);

    expect(isi['100.0|1'], bacaan(0, 0));
    expect(isi['100.0|4'], bacaan(0, 3));
    expect(
      isi.keys.where((k) => k.endsWith('|5')),
      isEmpty,
      reason: '`X5` nggak kejangkar, jadi nggak keisi.',
    );
  });
}
