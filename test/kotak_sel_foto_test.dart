import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Letak tiap sel di dalam citra — fondasi model pengenal angka sendiri.
///
/// ## Kenapa ini ada
///
/// `PetaTabelFoto.petakan` menjawab "angka yang KEBACA tempatnya di mana".
/// Yang dibutuhkan pelatihan model justru kebalikannya: **sel yang OCR-nya
/// gagal itu contoh paling berharga**, dan sel begitu nggak pernah muncul di
/// `sel` karena memang nggak ada teksnya.
///
/// `kotakSel` menurunkan kotak SELURUH sel dari jangkar yang sama — kebaca
/// maupun nggak. Dari situ tiap sel bisa dipotong jadi citra sendiri, dan
/// dipasangkan dengan angka yang akhirnya diketik teknisi sebagai labelnya.
///
/// Yang dijaga di sini geometrinya, bukan mutu potongannya: kotak yang meleset
/// setengah sel melatih model dengan potongan yang isinya angka tetangga, dan
/// model yang dilatih begitu salah dengan percaya diri.
void main() {
  const lebarKolom = 280.0;
  const xStandar = 200.0;
  const yKepala = 100.0;
  const yBarisPertama = 200.0;
  const tinggiBaris = 60.0;

  const titik = [100.0, 200.0, 300.0];

  double xKolom(int k) => 420.0 + k * lebarKolom;

  TeksTerbaca kata(String teks, double x, double y, {double? keyakinan}) => (
    teks: teks,
    kotak: Rect.fromLTWH(x, y, teks.length * 14, 24),
    keyakinan: keyakinan,
  );

  /// Foto tabel 3 baris × 3 kolom. [kosong] = sel yang angkanya NGGAK kebaca,
  /// dikunci `baris|kolom`.
  List<TeksTerbaca> foto({Set<String> kosong = const {}}) {
    final hasil = <TeksTerbaca>[
      for (var k = 0; k < 3; k++) kata('X${k + 1}', xKolom(k), yKepala),
    ];

    for (var b = 0; b < titik.length; b++) {
      final y = yBarisPertama + b * tinggiBaris;

      hasil.add(
        kata(titik[b].toStringAsFixed(1).replaceAll('.', ','), xStandar, y),
      );

      for (var k = 0; k < 3; k++) {
        if (kosong.contains('$b|$k')) continue;
        hasil.add(kata('9$b${k}0,5', xKolom(k), y));
      }
    }

    return hasil;
  }

  HasilPetaTabel petakan(
    List<TeksTerbaca> terbaca, {
    List<String> field = const ['pembacaan'],
  }) => const PetaTabelFoto().petakan(
    terbaca: terbaca,
    titikUkur: titik,
    pengulangan: const [1, 2, 3],
    fieldPerRepeat: field,
  );

  KotakSelFoto? cari(HasilPetaTabel h, double t, int r, [String f = 'pembacaan']) {
    for (final k in h.kotakSel) {
      if (k.titikUkur == t && k.repeatNo == r && k.fieldId == f) return k;
    }

    return null;
  }

  test('tiap sel dapat kotaknya — 3 baris × 3 kolom = 9', () {
    final hasil = petakan(foto());

    expect(hasil.kotakSel, hasLength(9));
  });

  test('kotaknya berpusat di perpotongan jangkar baris & kolom', () {
    final hasil = petakan(foto());

    // Baris ke-2 (`200,0`) × kolom `X2`. Pusat mendatarnya pusat kepala
    // kolomnya; pusat tegaknya pusat jangkar barisnya.
    final sel = cari(hasil, 200.0, 2)!;

    expect(sel.kotak.center.dx, closeTo(xKolom(1) + 14, 1));
    expect(sel.kotak.center.dy, closeTo(yBarisPertama + tinggiBaris + 12, 1));
  });

  test('kotaknya lebih kecil dari satu petak penuh', () {
    // Potongan yang pas-pasan ikut menyeret garis tabel dan ekor angka
    // tetangga — dua-duanya derau yang bikin model belajar hal yang salah.
    final sel = cari(petakan(foto()), 100.0, 1)!;

    expect(sel.kotak.width, lessThan(lebarKolom));
    expect(sel.kotak.height, lessThan(tinggiBaris));
    expect(
      sel.kotak.width,
      greaterThan(lebarKolom / 2),
      reason: 'Kekecilan juga salah — angkanya kepotong.',
    );
  });

  test('SEL YANG OCR-NYA GAGAL tetap dapat kotaknya', () {
    // Ini alasan seluruh berkas ini ada. Sel yang nggak kebaca itu justru
    // contoh latih paling berharga, dan dia nggak pernah muncul di `sel`.
    final hasil = petakan(foto(kosong: {'1|1'}));

    expect(
      hasil.sel.where((s) => s.titikUkur == 200.0 && s.repeatNo == 2),
      isEmpty,
      reason: 'Prasyarat: angkanya memang nggak kebaca.',
    );

    final sel = cari(hasil, 200.0, 2);

    expect(sel, isNotNull, reason: 'Kotaknya tetap harus ada.');
    expect(
      sel!.teks,
      isNull,
      reason: 'Dan ditandai kosong, bukan diisi tebakan.',
    );
  });

  test('sel yang kebaca membawa teksnya, biar bisa jadi label', () {
    final sel = cari(petakan(foto()), 100.0, 1)!;

    expect(sel.teks, '9000,5');
  });

  test('dua field per Repeat dibagi, nggak menempati kotak yang sama', () {
    // Lembar pH, Viscometer & Conductivity tiap Repeat-nya memuat SEPASANG
    // angka (pembacaan + °C), dan kertasnya mencetak label satuan di bawah
    // tiap kepala kolom. Label itu WAJIB ada — tanpa dia `petakan` menolak
    // seluruh tabel (`labelKolomKurang`), karena nggak ada dasar buat
    // membedakan kolom pembacaan dari kolom suhu.
    const xBaca = -60.0;
    const xSuhu = 60.0;

    final terbaca = <TeksTerbaca>[
      for (var k = 0; k < 3; k++) ...[
        kata('X${k + 1}', xKolom(k), yKepala),
        kata('cP', xKolom(k) + xBaca, yKepala + 40),
        kata('°C', xKolom(k) + xSuhu, yKepala + 40),
      ],
      for (var b = 0; b < titik.length; b++) ...[
        kata(
          titik[b].toStringAsFixed(1).replaceAll('.', ','),
          xStandar,
          yBarisPertama + b * tinggiBaris,
        ),
        for (var k = 0; k < 3; k++) ...[
          kata('9$b${k}0,5', xKolom(k) + xBaca, yBarisPertama + b * tinggiBaris),
          kata('2$b$k,5', xKolom(k) + xSuhu, yBarisPertama + b * tinggiBaris),
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

    expect(hasil.labelKolomKurang, isEmpty, reason: 'Prasyarat fixture.');
    expect(hasil.kotakSel, hasLength(18), reason: '9 sel × 2 field');

    final baca = cari(hasil, 100.0, 1)!;
    final suhu = cari(hasil, 100.0, 1, 'suhu')!;

    // Pusatnya ngikut label satuan yang tercetak, bukan dibagi rata — itu
    // yang paling dekat ke kebenaran waktu kertasnya menyediakannya.
    expect(baca.kotak.center.dx, lessThan(suhu.kotak.center.dx));
    expect(
      baca.kotak.overlaps(suhu.kotak),
      isFalse,
      reason:
          'Tumpang tindih bikin satu potongan memuat dua angka, dan dua label '
          'buat satu potongan melatih model dengan kontradiksi.',
    );
  });

  test('jangkar nggak cukup → kotaknya KOSONG, bukan dikarang', () {
    // Satu kolom doang: nggak ada jarak antar kolom yang bisa diukur, jadi
    // lebar selnya nggak bisa dipertanggungjawabkan. Kotak karangan diam-diam
    // melatih model dengan potongan yang salah; kotak yang nggak ada
    // kelihatan.
    final terbaca = <TeksTerbaca>[
      kata('X1', xKolom(0), yKepala),
      for (var b = 0; b < titik.length; b++) ...[
        kata(
          titik[b].toStringAsFixed(1).replaceAll('.', ','),
          xStandar,
          yBarisPertama + b * tinggiBaris,
        ),
        kata('9${b}00,5', xKolom(0), yBarisPertama + b * tinggiBaris),
      ],
    ];

    expect(petakan(terbaca).kotakSel, isEmpty);
  });
}
