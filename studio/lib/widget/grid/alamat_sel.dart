import 'package:flutter/foundation.dart';

/// Alamat & rentang sel gaya Excel (A1), basis-1 — dipakai [GridSel] dan
/// semua sumber selnya (workbook, kelola data, lembar hitung).
///
/// Batas Excel: 1.048.576 baris × 16.384 kolom (XFD). Dipakai juga untuk
/// kunci peta sel ([kunciSel]).
const int barisMaksExcel = 1048576;
const int kolomMaksExcel = 16384;

/// Huruf kolom Excel: 1 → `A`, 26 → `Z`, 27 → `AA`, 16384 → `XFD`.
String hurufKolom(int kolom) {
  assert(kolom >= 1, 'kolom basis-1');
  final huruf = StringBuffer();
  var n = kolom;
  final kebalik = <int>[];
  while (n > 0) {
    final sisa = (n - 1) % 26;
    kebalik.add(65 + sisa);
    n = (n - 1) ~/ 26;
  }
  for (final c in kebalik.reversed) {
    huruf.writeCharCode(c);
  }
  return huruf.toString();
}

/// Kebalikan [hurufKolom]; `null` bila bukan huruf kolom yang sah.
int? indeksKolom(String huruf) {
  final h = huruf.trim().toUpperCase();
  if (h.isEmpty || h.length > 3) return null;
  var n = 0;
  for (final c in h.codeUnits) {
    if (c < 65 || c > 90) return null;
    n = n * 26 + (c - 64);
  }
  return n > kolomMaksExcel ? null : n;
}

/// Kunci satu sel di peta (`baris`, `kolom` basis-1). Muat di int 53-bit.
int kunciSel(int baris, int kolom) => baris * (kolomMaksExcel + 1) + kolom;

final _polaA1 = RegExp(r'^\$?([A-Za-z]{1,3})\$?(\d{1,7})$');

/// Satu sel. Basis-1, sama dengan alamat A1 yang dibaca orang.
@immutable
class AlamatSel {
  const AlamatSel(this.baris, this.kolom);

  final int baris;
  final int kolom;

  /// `C5`.
  String get a1 => '${hurufKolom(kolom)}$baris';

  /// `C5`, `$C$5`, `c5` → alamat; selain itu `null`.
  static AlamatSel? urai(String teks) {
    final m = _polaA1.firstMatch(teks.trim());
    if (m == null) return null;
    final kolom = indeksKolom(m.group(1)!);
    final baris = int.tryParse(m.group(2)!);
    if (kolom == null || baris == null || baris < 1) return null;
    if (baris > barisMaksExcel) return null;
    return AlamatSel(baris, kolom);
  }

  @override
  bool operator ==(Object other) =>
      other is AlamatSel && other.baris == baris && other.kolom == kolom;

  @override
  int get hashCode => Object.hash(baris, kolom);

  @override
  String toString() => a1;
}

/// Rentang persegi sel, selalu ternormalisasi (awal ≤ akhir).
@immutable
class RentangSel {
  const RentangSel._(
    this.barisAwal,
    this.kolomAwal,
    this.barisAkhir,
    this.kolomAkhir,
  );

  factory RentangSel(int baris1, int kolom1, int baris2, int kolom2) =>
      RentangSel._(
        baris1 < baris2 ? baris1 : baris2,
        kolom1 < kolom2 ? kolom1 : kolom2,
        baris1 < baris2 ? baris2 : baris1,
        kolom1 < kolom2 ? kolom2 : kolom1,
      );

  factory RentangSel.dari(AlamatSel a, AlamatSel b) =>
      RentangSel(a.baris, a.kolom, b.baris, b.kolom);

  factory RentangSel.tunggal(AlamatSel a) =>
      RentangSel._(a.baris, a.kolom, a.baris, a.kolom);

  final int barisAwal;
  final int kolomAwal;
  final int barisAkhir;
  final int kolomAkhir;

  /// `A1:C1` (atau `A1` untuk satu sel) → rentang; selain itu `null`.
  static RentangSel? urai(String teks) {
    final bagian = teks.trim().split(':');
    if (bagian.isEmpty || bagian.length > 2) return null;
    final a = AlamatSel.urai(bagian.first);
    final b = bagian.length == 2 ? AlamatSel.urai(bagian.last) : a;
    if (a == null || b == null) return null;
    return RentangSel.dari(a, b);
  }

  AlamatSel get awal => AlamatSel(barisAwal, kolomAwal);
  AlamatSel get akhir => AlamatSel(barisAkhir, kolomAkhir);

  int get jumlahBaris => barisAkhir - barisAwal + 1;
  int get jumlahKolom => kolomAkhir - kolomAwal + 1;
  int get jumlahSel => jumlahBaris * jumlahKolom;
  bool get tunggal => jumlahSel == 1;

  bool memuat(int baris, int kolom) =>
      baris >= barisAwal &&
      baris <= barisAkhir &&
      kolom >= kolomAwal &&
      kolom <= kolomAkhir;

  bool beririsan(RentangSel lain) =>
      lain.barisAwal <= barisAkhir &&
      lain.barisAkhir >= barisAwal &&
      lain.kolomAwal <= kolomAkhir &&
      lain.kolomAkhir >= kolomAwal;

  /// Rentang terkecil yang memuat ini dan [lain].
  RentangSel gabung(RentangSel lain) => RentangSel._(
    barisAwal < lain.barisAwal ? barisAwal : lain.barisAwal,
    kolomAwal < lain.kolomAwal ? kolomAwal : lain.kolomAwal,
    barisAkhir > lain.barisAkhir ? barisAkhir : lain.barisAkhir,
    kolomAkhir > lain.kolomAkhir ? kolomAkhir : lain.kolomAkhir,
  );

  /// `A1:C3`; satu sel ditulis `A1`.
  String get a1 => tunggal ? awal.a1 : '${awal.a1}:${akhir.a1}';

  @override
  bool operator ==(Object other) =>
      other is RentangSel &&
      other.barisAwal == barisAwal &&
      other.kolomAwal == kolomAwal &&
      other.barisAkhir == barisAkhir &&
      other.kolomAkhir == kolomAkhir;

  @override
  int get hashCode => Object.hash(barisAwal, kolomAwal, barisAkhir, kolomAkhir);

  @override
  String toString() => a1;
}
