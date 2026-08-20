import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/services/pembaca_halaman.dart';
import 'package:sidik_calibration/services/peta_tabel_foto.dart';

/// Tabel yang penanda barisnya kembar ditolak UTUH, bukan dipetakan sebagian.
///
/// Bentuk yang jadi sebabnya ada beneran: lembar Autoclave
/// (`SIDIK-FM-CAL-0539`) barisnya berlabel kata — `Time`, `Temp. Disk 1..3`,
/// `Indikator Suhu` — dan `titik_ukur`-nya nol semua sebagai pengisi.
///
/// Jangkar baris disimpan berkunci nilainya, jadi delapan baris bernilai `0`
/// runtuh jadi satu. Sebelum penjaga ini ada, jepretan tabel begitu ngasih
/// lima sel yang ngaku baris pertama dan tiga puluh lima angka kebuang — dan
/// lima sel itu MENDARAT, di baris yang belum tentu benar. Itu bukan "gagal",
/// itu salah taruh diam-diam.
void main() {
  TeksTerbaca kata(String teks, double x, double y) =>
      (teks: teks, kotak: Rect.fromLTWH(x, y, teks.length * 14, 24));

  /// Tabel dengan penanda baris kembar (`0` delapan kali), terisi penuh.
  List<TeksTerbaca> tabelAutoclave() {
    final hasil = <TeksTerbaca>[
      for (var r = 1; r <= 5; r++) kata('X$r', 420.0 + (r - 1) * 300, 100),
    ];

    for (var i = 0; i < 8; i++) {
      final y = 200.0 + i * 60;
      hasil.add(kata('0', 200, y));
      for (var r = 0; r < 5; r++) {
        hasil.add(kata('12$i$r,5', 420.0 + r * 300, y));
      }
    }

    return hasil;
  }

  test('penanda baris kembar → seluruh tabel ditolak, nol sel', () {
    final hasil = const PetaTabelFoto().petakan(
      terbaca: tabelAutoclave(),
      titikUkur: const [0, 0, 0, 0, 0, 0, 0, 0],
      pengulangan: const [1, 2, 3, 4, 5],
      fieldPerRepeat: const ['pembacaan'],
    );

    expect(hasil.kosong, isTrue);
    expect(hasil.sel, isEmpty);
    expect(hasil.barisKembar, [0.0]);
  });

  test('titik kembar dilaporkan semuanya, sekali per nilai', () {
    final hasil = const PetaTabelFoto().petakan(
      terbaca: const [],
      titikUkur: const [4, 4, 7, 7, 7, 10.01],
      pengulangan: const [1, 2],
      fieldPerRepeat: const ['pembacaan'],
    );

    expect(hasil.barisKembar, unorderedEquals(<double>[4, 7]));
  });

  test('titik yang semuanya beda tetap dipetakan seperti biasa', () {
    final terbaca = <TeksTerbaca>[
      for (var r = 1; r <= 3; r++) kata('X$r', 420.0 + (r - 1) * 300, 100),
    ];

    const titik = [279.6, 287.7, 334.0];

    for (var i = 0; i < titik.length; i++) {
      final y = 200.0 + i * 60;
      terbaca.add(
        kata(titik[i].toStringAsFixed(1).replaceAll('.', ','), 200, y),
      );
      for (var r = 0; r < 3; r++) {
        terbaca.add(kata('28$i$r,00', 420.0 + r * 300, y));
      }
    }

    final hasil = const PetaTabelFoto().petakan(
      terbaca: terbaca,
      titikUkur: titik,
      pengulangan: const [1, 2, 3],
      fieldPerRepeat: const ['pembacaan'],
    );

    expect(hasil.barisKembar, isEmpty);
    expect(hasil.sel, hasLength(9));
    expect(hasil.angkaTakTerpetakan, 0);
  });

  test('bentuk ke-bawah: dua slot bertitik sama ditolak utuh', () {
    final hasil = const PetaTabelFoto().petakanKeBawah(
      terbaca: const [],
      slot: const [
        (titikUkur: 25.0, kepala: ['84'], labelField: {}),
        (titikUkur: 25.0, kepala: ['1413 µS'], labelField: {}),
        // Slot mati (larutannya belum kedaftar di master) nggak ikut dihitung
        // kembar — `null` bukan nilai yang bisa bentrok.
        (titikUkur: null, kepala: ['80000 µS'], labelField: {}),
      ],
      pengulangan: const [1, 2],
    );

    expect(hasil.kosong, isTrue);
    expect(hasil.barisKembar, [25.0]);
  });
}
