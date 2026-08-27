import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Kepala kolom yang TERCETAK beda dari `Xn` — dan sebelum ini nggak satu pun
/// dari empat lembar yang begitu bisa difoto.
///
/// ## Apa yang bolong
///
/// [PetaTabelFoto] mengunci kolom ke tulisan kepala yang tercetak, dan
/// bawaannya cuma nerima `Xn` / `Repeat n` (plus deret nomor polos). Empat
/// lembar nyetak yang lain:
///
/// | Lembar | Kepala kolom yang kecetak |
/// |---|---|
/// | TITS | `UP X1` `UP X2` `UP X3` `DOWN X1` `DOWN X2` `DOWN X3` |
/// | Thermocouple / Termometer Gelas / Thermohygro (sisi standar) | `0″` `20″` `40″` `60″` `80″` |
/// | idem (sisi UUT) | `10″` `30″` `50″` `70″` `90″` |
///
/// Server SUDAH mengirim tulisan itu (`pengulangan_arah[].label`) dan layar
/// SUDAH menggambarnya sebagai kepala kolom — cuma pemetanya yang nggak pernah
/// dikasih tahu. Jadi tiap jepretan di keempat lembar itu pulang nol sel,
/// sebagus apa pun fotonya.
///
/// ## Dua hal yang diuji di sini, dan bedanya penting
///
///  1. **Ketemunya** — kepala dua kata (`UP X1`) kejangkar walau ML Kit
///     memulangkannya per KATA.
///  2. **Nggak ketukernya** — `X1` kecetak dua kali di lembar TITS (di bawah
///     `UP` dan di bawah `DOWN`). Yang kedua ini yang bahaya: dia nggak
///     menghasilkan error, cuma pembacaan arah DOWN yang mendarat di kolom UP.
void main() {
  // Tata letak tabelnya dalam piksel citra — tabel cetak: kolom set point di
  // kiri, kolom pengulangan berjajar rata di kanannya.
  const xSetPoint = 200.0;
  const lebarKolom = 280.0;
  const yKepala = 100.0;
  const yBarisPertama = 200.0;
  const tinggiBaris = 60.0;

  /// Satu ELEMENT hasil ML Kit — kira-kira satu kata, dengan kotaknya sendiri.
  ///
  /// Dipisah per kata, bukan per baris, karena begitu memang
  /// `MlKitPembacaHalaman` memulangkannya. Kepala `UP X1` karena itu datang
  /// sebagai DUA potong, dan itu justru yang bikin bug-nya lahir.
  TeksTerbaca kata(String teks, double x, double y) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 14, 24),
  );

  double xKolom(int k) => 420.0 + k * lebarKolom;

  /// Susun hasil OCR satu tabel: kepala kolom + kolom set point + pembacaan.
  ///
  /// [kepala] tulisan kepala tiap kolom seperti tercetak; dipecah per spasi
  /// jadi element-element yang bersebelahan, persis kelakuan ML Kit.
  List<TeksTerbaca> tabel({
    required List<String> kepala,
    required List<double> setPoint,
    required List<List<String>> bacaan,
    Set<String> kepalaHilang = const {},
  }) {
    final hasil = <TeksTerbaca>[];

    for (var k = 0; k < kepala.length; k++) {
      if (kepalaHilang.contains(kepala[k])) continue;

      var x = xKolom(k);

      for (final potong in kepala[k].split(' ')) {
        hasil.add(kata(potong, x, yKepala));
        // Spasi antar kata jauh lebih sempit dari jarak antar kolom — itu yang
        // membedakan "satu tulisan" dari "dua kepala kolom".
        x += potong.length * 14 + 6;
      }
    }

    for (var i = 0; i < setPoint.length; i++) {
      final y = yBarisPertama + i * tinggiBaris;

      hasil.add(kata(_angkaId(setPoint[i]), xSetPoint, y));

      for (var k = 0; k < bacaan[i].length; k++) {
        hasil.add(kata(bacaan[i][k], xKolom(k), y));
      }
    }

    return hasil;
  }

  Map<String, String> petaSel(HasilPetaTabel hasil) => {
    for (final s in hasil.sel) '${s.titikUkur}|${s.repeatNo}': s.teks,
  };

  group('TITS — kepala kolom dua kata, `X1` kecetak dua kali', () {
    const setPoint = [100.0, 200.0, 300.0, 400.0, 500.0];
    const kepala = ['UP X1', 'UP X2', 'UP X3', 'DOWN X1', 'DOWN X2', 'DOWN X3'];

    /// Sengaja beda-beda tiap sel: kalau satu angka mendarat di kolom
    /// sebelahnya, itu ketahuan dari NILAINYA — bukan cuma dari jumlah selnya,
    /// yang tetap pas waktu angkanya ketuker.
    const bacaan = [
      ['99,11', '99,12', '99,13', '99,21', '99,22', '99,23'],
      ['198,11', '198,12', '198,13', '198,21', '198,22', '198,23'],
      ['297,11', '297,12', '297,13', '297,21', '297,22', '297,23'],
      ['396,11', '396,12', '396,13', '396,21', '396,22', '396,23'],
      ['495,11', '495,12', '495,13', '495,21', '495,22', '495,23'],
    ];

    final terbaca = tabel(
      kepala: kepala,
      setPoint: setPoint,
      bacaan: bacaan,
    );

    HasilPetaTabel jalankan({Map<int, List<String>> kepalaPengulangan = const {}}) =>
        const PetaTabelFoto().petakan(
          terbaca: terbaca,
          titikUkur: setPoint,
          pengulangan: const [1, 2, 3, 4, 5, 6],
          fieldPerRepeat: const ['pembacaan'],
          kepalaPengulangan: kepalaPengulangan,
        );

    Map<int, List<String>> dariBentuk() => {
      for (var k = 0; k < kepala.length; k++) k + 1: [kepala[k]],
    };

    test('keenam kolomnya kejangkar dari tulisan yang tercetak', () {
      final hasil = jalankan(kepalaPengulangan: dariBentuk());

      expect(hasil.repeatKetemu..sort(), const [1, 2, 3, 4, 5, 6]);
      expect(hasil.sel, hasLength(30), reason: '5 set point × 6 pengulangan');
      expect(hasil.angkaTakTerpetakan, 0);
    });

    test('pembacaan DOWN nggak pernah mendarat di kolom UP', () {
      // Ini kegagalan yang paling mahal di lembar ini: `UP X1` dan `DOWN X1`
      // dua-duanya memuat potongan `X1`, jadi selama jangkarnya `Xn` yang
      // menang cuma soal beberapa piksel. Angkanya tetap wajar, jumlah selnya
      // tetap pas, dan yang terbit di sertifikat pembacaan arah sebaliknya.
      final peta = petaSel(jalankan(kepalaPengulangan: dariBentuk()));

      for (var i = 0; i < setPoint.length; i++) {
        for (var k = 0; k < kepala.length; k++) {
          expect(
            peta['${setPoint[i]}|${k + 1}'],
            bacaan[i][k],
            reason: 'Set point ${setPoint[i]} kolom ${kepala[k]} salah isi.',
          );
        }
      }
    });

    test('tanpa tulisan tercetak, `Xn` polos nggak dipercaya buat ngisi', () {
      // Bentuk kertas ini nggak bisa dijangkar `Xn`, dan jawaban yang benar
      // bukan "isi seadanya". Yang boleh terjadi cuma dua: nol sel, atau sel
      // yang isinya beneran punya kolom itu. Yang NGGAK boleh: sel terisi
      // angka milik kolom lain.
      final peta = petaSel(jalankan());

      for (var i = 0; i < setPoint.length; i++) {
        for (var k = 0; k < kepala.length; k++) {
          final isi = peta['${setPoint[i]}|${k + 1}'];

          expect(
            isi == null || isi == bacaan[i][k],
            isTrue,
            reason:
                'Kolom ${kepala[k]} set point ${setPoint[i]} keisi `$isi`, '
                'punyanya `${bacaan[i][k]}`.',
          );
        }
      }
    });
  });

  group('Suhu pasangan — kepala kolom detik (`0″`, `20″`, …)', () {
    const setPoint = [50.0, 100.0, 150.0, 200.0, 400.0];

    const bacaan = [
      ['49,11', '49,12', '49,13', '49,14', '49,15'],
      ['99,11', '99,12', '99,13', '99,14', '99,15'],
      ['149,11', '149,12', '149,13', '149,14', '149,15'],
      ['199,11', '199,12', '199,13', '199,14', '199,15'],
      ['399,11', '399,12', '399,13', '399,14', '399,15'],
    ];

    /// Yang dikirim server pakai DOUBLE PRIME (U+2033) — sama dengan yang
    /// dipajang layar sebagai kepala kolom.
    const kepalaServer = ['0″', '20″', '40″', '60″', '80″'];

    HasilPetaTabel jalankan(List<String> kepalaKertas) =>
        const PetaTabelFoto().petakan(
          terbaca: tabel(
            kepala: kepalaKertas,
            setPoint: setPoint,
            bacaan: bacaan,
          ),
          titikUkur: setPoint,
          pengulangan: const [1, 2, 3, 4, 5],
          fieldPerRepeat: const ['pembacaan'],
          kepalaPengulangan: {
            for (var k = 0; k < kepalaServer.length; k++)
              k + 1: [kepalaServer[k]],
          },
        );

    test('kelima kolomnya kejangkar & angkanya mendarat benar', () {
      final hasil = jalankan(kepalaServer);
      final peta = petaSel(hasil);

      expect(hasil.repeatKetemu..sort(), const [1, 2, 3, 4, 5]);
      expect(hasil.angkaTakTerpetakan, 0);

      for (var i = 0; i < setPoint.length; i++) {
        for (var k = 0; k < 5; k++) {
          expect(peta['${setPoint[i]}|${k + 1}'], bacaan[i][k]);
        }
      }
    });

    test('kertas nyetak kutip biasa (`0"`) — tetap kejangkar', () {
      // Lembar master lab dicetak dari Excel, dan yang kecetak di situ tanda
      // kutip biasa, bukan double prime. Font & ML Kit juga bisa memulangkan
      // `”` atau `′`. Satu karakter yang bahkan bukan bagian dari angkanya
      // nggak boleh bikin seluruh kolom nggak kejangkar.
      final hasil = jalankan(const ['0"', '20"', '40"', '60"', '80"']);

      expect(hasil.repeatKetemu..sort(), const [1, 2, 3, 4, 5]);
      expect(hasil.sel, hasLength(25));
    });
  });

  group('Kolom yang kepalanya nggak kebaca nggak boleh nyedot kolom sebelah', () {
    const setPoint = [50.0, 100.0, 150.0];
    const kepala = ['X1', 'X2', 'X3', 'X4', 'X5'];

    const bacaan = [
      ['49,11', '49,12', '49,13', '49,14', '49,15'],
      ['99,11', '99,12', '99,13', '99,14', '99,15'],
      ['149,11', '149,12', '149,13', '149,14', '149,15'],
    ];

    /// Dua kepala kolom paling kanan nggak kebaca — kejadian biasa waktu
    /// lembarnya kefoto agak kepotong di kanan.
    final hasil = const PetaTabelFoto().petakan(
      terbaca: tabel(
        kepala: kepala,
        setPoint: setPoint,
        bacaan: bacaan,
        kepalaHilang: const {'X4', 'X5'},
      ),
      titikUkur: setPoint,
      pengulangan: const [1, 2, 3, 4, 5],
      fieldPerRepeat: const ['pembacaan'],
    );

    test('kolom tanpa jangkar nggak keisi, dan yang kebuang dilaporkan', () {
      expect(hasil.repeatKetemu..sort(), const [1, 2, 3]);
      expect(hasil.sel.any((s) => s.repeatNo == 4 || s.repeatNo == 5), isFalse);
      expect(
        hasil.angkaTakTerpetakan,
        6,
        reason: '3 baris × 2 kolom tanpa jangkar — dibuang, bukan dipindahin',
      );
    });

    test('kolom yang kejangkar tetap bawa angkanya sendiri', () {
      // Ini bagian yang dulu jebol dan nggak ngasih gejala. Tanpa batas jarak,
      // angka kolom X4 ketarik ke jangkar terdekat (X3) — bentrok sama angka
      // X3 yang sah, dan `_buangSelKembar` membuang KEDUANYA. Jadi satu kepala
      // kolom yang kepotong menghapus kolom yang fotonya baik-baik saja.
      final peta = petaSel(hasil);

      expect(hasil.sel, hasLength(9), reason: '3 set point × 3 kolom kejangkar');

      for (var i = 0; i < setPoint.length; i++) {
        for (var k = 0; k < 3; k++) {
          expect(peta['${setPoint[i]}|${k + 1}'], bacaan[i][k]);
        }
      }
    });
  });
}

/// Set point ditulis seperti di kertas: `50`, bukan `50.0`.
String _angkaId(double nilai) => nilai == nilai.roundToDouble()
    ? nilai.toStringAsFixed(0)
    : nilai.toString().replaceAll('.', ',');
