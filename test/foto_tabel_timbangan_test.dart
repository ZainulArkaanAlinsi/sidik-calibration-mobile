import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// **Foto blok REPEATABILITY lembar Timbangan — 40 angka, nol salah taruh.**
///
/// Yang ditiru di sini tata letak kertas MASTER LAB (`INPUT DATA`, sheet
/// `CALIBRATION RESULT`), bukan lembar cetak SIDIK. Itu kertas yang beneran
/// dipegang teknisi buat alat ini, dan susunannya:
///
/// ```
///        |  Middle Capacity   |  Maximum Capacity
///        |        50          |        100
///   No.  | Zero (kg) Reading (kg) | Zero (kg) Reading (kg)
///        |   (zi)      (mi)       |   (zi)      (mi)
///        |     1         2        |     1         2       <-- JEBAKAN
///    1   |     0       50.02      |     0       100.02
///    2   |     0       50.02      |     0       100.02
///   ...
///   10   |     0       50.02      |     0       100.02
/// ```
///
/// ## Jebakan yang bikin berkas ini ada
///
/// Baris `1 | 2 | 1 | 2` itu penomoran SUB-KOLOM, dan dia duduk **tepat di
/// atas** baris data. Jangkar baris yang cuma mencari tulisan `1` bakal
/// menemukannya duluan — [PetaTabelFoto] memilih kemunculan paling ATAS — dan
/// seluruh grid barisnya bergeser satu baris.
///
/// Yang bikin ini mahal: jangkarnya jadi **lengkap**. `1` dan `2` ketemu di
/// baris penomoran, `3`..`10` ketemu di kolom `No.`, jadi jumlahnya pas
/// sepuluh, tidak ada penjagaan yang berbunyi, kesepuluh pengulangan terisi
/// penuh — cuma isinya milik baris tetangganya. Persis kelas kegagalan yang
/// diminta pemilik proyek supaya tidak terjadi: *"jangan sampai ada salah
/// salah angka"*.
void main() {
  TeksTerbaca kata(String teks, double x, double y, {double lebarHuruf = 14}) =>
      (
        teks: teks,
        kotak: Rect.fromLTWH(x, y, teks.length * lebarHuruf, 24),
        keyakinan: null,
      );

  // --- tata letak kertas, dalam piksel citra ------------------------------
  const xNo = 60.0;
  const xMid = [300.0, 460.0]; // Zero (zi), Reading (mi)
  const xMaks = [700.0, 860.0];

  const yKepalaSlot = 60.0;
  const yNilaiSlot = 100.0;
  const yLabelKolom = 140.0;
  const yZiMi = 180.0;
  const yNomorSubKolom = 220.0; // <-- baris jebakan
  const yBarisPertama = 270.0;
  const tinggiBaris = 55.0;

  const slot = <SlotFoto>[
    (
      titikUkur: 50.0,
      kepala: ['Middle Capacity'],
      labelField: {'zero': 'Zero (kg)', 'pembacaan': 'Reading (kg)'},
    ),
    (
      titikUkur: 100.0,
      kepala: ['Maximum Capacity'],
      labelField: {'zero': 'Zero (kg)', 'pembacaan': 'Reading (kg)'},
    ),
  ];

  final pengulangan = List<int>.generate(10, (i) => i + 1);

  /// Sepuluh pembacaan tiap kolom. Sengaja BEDA-BEDA di beberapa baris —
  /// kertas asli sesi `011-CAL-525` memang begitu (baris 4 mid = 50,04;
  /// baris 8 maks = 100,04). Kalau semuanya kembar, grid yang bergeser satu
  /// baris tidak akan kelihatan sama sekali.
  const midMi = [
    '50.02', '50.02', '50.02', '50.04', '50.02',
    '50.02', '50.02', '50.02', '50.02', '50.02',
  ];
  const maksMi = [
    '100.02', '100.02', '100.02', '100.02', '100.02',
    '100.02', '100.02', '100.04', '100.02', '100.02',
  ];

  /// Kertas lengkap: kepala, baris jebakan, lalu sepuluh baris isi.
  List<TeksTerbaca> kertas({bool pakaiBarisJebakan = true}) => [
    // kepala slot
    kata('Middle Capacity', xMid[0], yKepalaSlot),
    kata('Maximum Capacity', xMaks[0], yKepalaSlot),
    kata('50', xMid[0], yNilaiSlot),
    kata('100', xMaks[0], yNilaiSlot),
    // label sub-kolom
    kata('No.', xNo, yLabelKolom),
    kata('Zero (kg)', xMid[0], yLabelKolom),
    kata('Reading (kg)', xMid[1], yLabelKolom),
    kata('Zero (kg)', xMaks[0], yLabelKolom),
    kata('Reading (kg)', xMaks[1], yLabelKolom),
    kata('(zi)', xMid[0], yZiMi),
    kata('(mi)', xMid[1], yZiMi),
    kata('(zi)', xMaks[0], yZiMi),
    kata('(mi)', xMaks[1], yZiMi),
    // JEBAKAN: penomoran sub-kolom, tepat di atas isi
    if (pakaiBarisJebakan) ...[
      kata('1', xMid[0], yNomorSubKolom),
      kata('2', xMid[1], yNomorSubKolom),
      kata('1', xMaks[0], yNomorSubKolom),
      kata('2', xMaks[1], yNomorSubKolom),
    ],
    // isi
    for (var i = 0; i < 10; i++) ...[
      kata('${i + 1}', xNo, yBarisPertama + i * tinggiBaris),
      kata('0', xMid[0], yBarisPertama + i * tinggiBaris),
      kata(midMi[i], xMid[1], yBarisPertama + i * tinggiBaris),
      kata('0', xMaks[0], yBarisPertama + i * tinggiBaris),
      kata(maksMi[i], xMaks[1], yBarisPertama + i * tinggiBaris),
    ],
  ];

  HasilPetaTabel petakan(List<TeksTerbaca> terbaca) =>
      const PetaTabelFoto().petakanKeBawah(
        terbaca: terbaca,
        slot: slot,
        pengulangan: pengulangan,
        // Persis yang dikirim `TimbanganProfile::bagianKeterulangan()`.
        kepalaPengulangan: {for (final r in pengulangan) r: ['$r']},
      );

  String? isi(HasilPetaTabel h, double titik, int repeat, String field) {
    for (final s in h.sel) {
      if (s.titikUkur == titik && s.repeatNo == repeat && s.fieldId == field) {
        return s.teks;
      }
    }

    return null;
  }

  test('empat puluh angka mendarat di sel yang benar — semuanya', () {
    final hasil = petakan(kertas());

    expect(hasil.kosong, isFalse, reason: 'Nol sel berarti nggak ada jangkar.');
    expect(hasil.sel, hasLength(40));
    expect(hasil.angkaTakTerpetakan, 0);

    for (var i = 0; i < 10; i++) {
      final r = i + 1;

      expect(isi(hasil, 50, r, 'zero'), '0', reason: 'Middle zi baris $r');
      expect(isi(hasil, 50, r, 'pembacaan'), midMi[i], reason: 'Middle mi baris $r');
      expect(isi(hasil, 100, r, 'zero'), '0', reason: 'Maximum zi baris $r');
      expect(isi(hasil, 100, r, 'pembacaan'), maksMi[i], reason: 'Maximum mi baris $r');
    }
  });

  test('baris penomoran sub-kolom TIDAK menggeser grid', () {
    // Dua jepretan yang isinya identik — satu dengan baris `1 | 2 | 1 | 2`,
    // satu tanpa. Kalau baris itu ikut kejangkar, yang berbeda bukan cuma
    // satu sel: SELURUH sepuluh baris bergeser.
    final dengan = petakan(kertas());
    final tanpa = petakan(kertas(pakaiBarisJebakan: false));

    for (var i = 0; i < 10; i++) {
      final r = i + 1;

      for (final (titik, field) in [
        (50.0, 'zero'),
        (50.0, 'pembacaan'),
        (100.0, 'zero'),
        (100.0, 'pembacaan'),
      ]) {
        expect(
          isi(dengan, titik, r, field),
          isi(tanpa, titik, r, field),
          reason:
              'Sel ($titik, $r, $field) berubah gara-gara baris penomoran '
              'sub-kolom ikut kejangkar.',
        );
      }
    }

    // Dan yang bikin geseran itu mahal: angkanya SAH semua, jadi tanpa
    // perbandingan di atas nggak ada yang kelihatan salah.
    expect(isi(dengan, 50, 4, 'pembacaan'), '50.04');
    expect(isi(dengan, 100, 8, 'pembacaan'), '100.04');
  });

  test('kertas GRAM nggak bisa mendarat di sesi kilogram', () {
    // Master gram menulis `Zero (g)` / `Reading (g)`. Slot sesi ini menyebut
    // `(kg)`, jadi label sub-kolomnya nggak ketemu satu pun.
    //
    // Yang dijaga: hasilnya NOL SEL, bukan 24,9999 g yang mendarat rapi di
    // kotak kilogram. Pemilik proyek menyebutnya sendiri — "ada yang gram ada
    // yang kg jangan ke tuker pas olah data nya".
    final gram = [
      for (final t in kertas())
        (
          teks: t.teks.replaceAll('(kg)', '(g)'),
          kotak: t.kotak,
          keyakinan: t.keyakinan,
        ),
    ];

    final hasil = petakan(gram);

    expect(
      hasil.sel,
      isEmpty,
      reason:
          'Label sub-kolom satuan lain nggak boleh dipetakan — kalau lolos, '
          'angka gram mendarat di kotak kilogram tanpa satu pun error.',
    );
  });

  test('deret nomor yang bolong membatalkan, bukan dipakai sebagian', () {
    // ML Kit rutin gagal membaca digit tunggal yang berdiri sendiri. Nomor
    // baris yang hilang satu bikin sembilan baris sisanya bergeser naik di
    // bawah titik yang hilang — jadi yang benar membatalkan seluruhnya.
    final bolong = [
      for (final t in kertas())
        if (!(t.teks == '7' && t.kotak.left == xNo)) t,
    ];

    final hasil = petakan(bolong);

    // NOL sel, bukan sembilan baris yang bergeser menutupi yang hilang.
    //
    // Lembar yang menyatakan penomoran polos nggak punya jalan mundur ke
    // pencarian teks biasa — di kertas ini jalan mundur itu justru yang
    // berbahaya: `1` & `2` bakal diambil dari baris jebakan.
    expect(
      hasil.sel,
      isEmpty,
      reason: 'Deret bolong harus membatalkan seluruhnya.',
    );
    expect(hasil.angkaTakTerpetakan, greaterThan(0));
  });
}
