import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextAlign;

/// Aturan tampil sel Excel yang MURNI geometri — dipisah dari widget supaya
/// bisa diuji tanpa menggambar (`test/luber_teks_test.dart`).
///
/// Yang ditiru (perilaku Excel 365 pada sel tanpa "Wrap Text"):
///  - teks rata kiri/umum yang lebih lebar dari selnya digambar MENEMBUS sel
///    di kanannya selama sel itu kosong; berhenti di sel berisi berikutnya,
///    di sel gabungan, atau di tepi lembar;
///  - rata kanan meluber ke kiri, rata tengah ke dua arah (tetap di tengah
///    sel sumbernya, dipotong di sisi yang terhalang);
///  - angka TIDAK meluber: yang tidak muat diganti `####` ([teksPagar]).
///
/// Yang menentukan "kosong" (boleh dilintasi) adalah pemanggil: sel tanpa
/// nilai DAN tanpa rumus (rumus yang menghasilkan `""` tetap menghalangi,
/// seperti Excel), bukan bagian gabungan, dan sudah termuat. Sel kosong yang
/// cuma bergaya (isi/garis) tetap boleh dilintasi.

/// Letak teks sel sumber dan kolom yang dilintasinya.
@immutable
class LetakTeks {
  const LetakTeks({
    required this.kolomAwal,
    required this.kolomAkhir,
    required this.kiri,
    required this.kanan,
  });

  /// Kolom pertama & terakhir yang memuat sebagian teks (basis-1). Sama
  /// dengan kolom sumber bila teks tidak meluber.
  final int kolomAwal;
  final int kolomAkhir;

  /// Tepi kiri & kanan teks (dp), relatif tepi KIRI sel sumber. Boleh
  /// negatif (meluber ke kiri) atau melebihi lebar sel (meluber ke kanan).
  final double kiri;
  final double kanan;

  bool get luber => kolomAwal != kolomAkhir;

  @override
  bool operator ==(Object other) =>
      other is LetakTeks &&
      other.kolomAwal == kolomAwal &&
      other.kolomAkhir == kolomAkhir &&
      other.kiri == kiri &&
      other.kanan == kanan;

  @override
  int get hashCode => Object.hash(kolomAwal, kolomAkhir, kiri, kanan);

  @override
  String toString() =>
      'LetakTeks($kolomAwal..$kolomAkhir, ${kiri.toStringAsFixed(1)}..'
      '${kanan.toStringAsFixed(1)})';
}

/// Letak satu baris teks selebar [lebarTeks] di sel [kolom] selebar
/// [lebarSel], dengan jarak tepi [padding] kiri & kanan.
///
/// [bolehDilintasi] menjawab untuk kolom TETANGGA saja; ditanya berurutan
/// menjauh dari sumber, berhenti di jawaban `false` pertama. [lebarKolom]
/// boleh 0 (kolom tersembunyi: dilintasi tanpa menambah ruang).
///
/// [meluber] `false` (angka, logika, galat, teks dibungkus, sel gabungan):
/// letaknya dihitung, tapi kolomnya tidak pernah melebar.
LetakTeks letakTeks({
  required int kolom,
  required double lebarSel,
  required double lebarTeks,
  required TextAlign rata,
  required double padding,
  required double Function(int kolom) lebarKolom,
  required bool Function(int kolom) bolehDilintasi,
  required int kolomTerakhir,
  bool meluber = true,
}) {
  final double kiri;
  switch (rata) {
    case TextAlign.right || TextAlign.end:
      kiri = lebarSel - padding - lebarTeks;
    case TextAlign.center:
      kiri = (lebarSel - lebarTeks) / 2;
    default:
      kiri = padding;
  }
  final kanan = kiri + lebarTeks;

  var awal = kolom;
  var akhir = kolom;
  if (meluber && lebarTeks > lebarSel - 2 * padding) {
    final keKanan = switch (rata) {
      TextAlign.right || TextAlign.end => false,
      _ => true,
    };
    final keKiri = switch (rata) {
      TextAlign.right || TextAlign.end || TextAlign.center => true,
      _ => false,
    };
    if (keKanan) {
      var x = lebarSel;
      var k = kolom + 1;
      while (x < kanan && k <= kolomTerakhir && bolehDilintasi(k)) {
        x += lebarKolom(k);
        akhir = k;
        k++;
      }
    }
    if (keKiri) {
      var x = 0.0;
      var k = kolom - 1;
      while (x > kiri && k >= 1 && bolehDilintasi(k)) {
        x -= lebarKolom(k);
        awal = k;
        k--;
      }
    }
  }
  return LetakTeks(
    kolomAwal: awal,
    kolomAkhir: akhir,
    kiri: kiri,
    kanan: kanan,
  );
}

/// Keadaan satu sel bagi pencari sumber luberan.
enum KeadaanLuber {
  /// Kosong, boleh dilintasi teks tetangga.
  kosong,

  /// Berisi — kandidat sumber luberan (dan penghalang di baliknya).
  berisi,

  /// Gabungan / belum termuat / gagal: tidak dilintasi, bukan sumber.
  penghalang,
}

/// Kolom sel BERISI terdekat dari [kolom] ke arah [arah] (−1 kiri, +1
/// kanan) melewati sel kosong — calon sumber teks yang meluber ke [kolom].
/// `null` bila yang ditemui penghalang, tepi lembar, atau jaraknya melewati
/// [batas] dp (teks yang meluber lebih jauh dari itu tidak dicari; tanpa
/// batas, baris kosong di lembar lebar memindai sampai tepi).
int? cariSumberLuber({
  required int kolom,
  required int arah,
  required int kolomTerakhir,
  required KeadaanLuber Function(int kolom) keadaan,
  required double Function(int kolom) lebarKolom,
  required double batas,
}) {
  assert(arah == 1 || arah == -1);
  var jarak = 0.0;
  var k = kolom + arah;
  while (k >= 1 && k <= kolomTerakhir) {
    switch (keadaan(k)) {
      case KeadaanLuber.berisi:
        return k;
      case KeadaanLuber.penghalang:
        return null;
      case KeadaanLuber.kosong:
        jarak += lebarKolom(k);
        if (jarak > batas) return null;
    }
    k += arah;
  }
  return null;
}

/// `####` selebar [ruang]: angka yang tidak muat di selnya diganti tanda
/// pagar sebanyak yang muat — persis Excel. Ruang yang tak memuat satu pagar
/// pun = kosong.
String teksPagar(double ruang, double lebarPagar) {
  if (lebarPagar <= 0 || ruang < lebarPagar) return '';
  return '#' * math.max(0, (ruang / lebarPagar).floor());
}

/// Baris teks Excel yang TIDAK dibungkus digambar satu baris: pemisah baris
/// di dalam sel (Alt+Enter) tidak memecah baris tanpa "Wrap Text". Excel
/// tidak menggambar apa pun untuknya; di sini diganti spasi supaya dua kata
/// tidak menempel tak terbaca. Nilai aslinya tetap utuh di bilah rumus.
String teksSatuBaris(String teks) => teks.contains('\n') || teks.contains('\r')
    ? teks.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ')
    : teks;
