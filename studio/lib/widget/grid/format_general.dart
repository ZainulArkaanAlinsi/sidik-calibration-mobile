/// Tampilan format angka **General** Excel — logika murni, tanpa widget.
///
/// Excel tidak menyimpan teks General: teksnya dibangun dari NILAI sel dan
/// LEBAR kolomnya setiap kali digambar. Server mengirim `s` hasil
/// PhpSpreadsheet yang bentuknya lain (14+ digit, eksponen gaya PHP), jadi
/// grid membangun teksnya sendiri dari `n` — TAMPILAN saja, nilai tidak
/// berubah dan tidak dipakai menghitung apa pun.
///
/// Aturan di bawah DIBUKTIKAN terhadap Excel asli, bukan ditebak:
/// `test/fixtures/excel_general_text.json` (`Range.Text` & `Range.Formula`
/// Excel 365 lewat COM, dibuat `tool/excel_general_fixture.ps1`; versi Excel
/// tercatat di fixture), dicocokkan `test/format_general_test.dart`.
///
/// 1. Nilai dibulatkan dulu ke 15 digit signifikan (presisi tampil Excel);
///    pembulatan tampil = setengah menjauhi nol pada digit desimal itu
///    (`1.005` → `1.01`, `2.675` → `2.68` walau nilai binernya di bawah).
/// 2. Anggaran karakter = ruang teks (lebar sel − [paddingSelExcel] px)
///    dibagi lebar digit font sel. Tanda minus memakan lebar glifnya sendiri
///    (Calibri 11: digit 7 px, minus 5 px); titik, `E`, dan `+` dihitung
///    satu karakter penuh. Paling banyak [batasKarakterGeneral] karakter di
///    luar tanda minus.
/// 3. Bentuk desimal: desimal sebanyak yang muat, nol ekor dibuang.
/// 4. Bentuk ilmiah (`1.23E-05`, `1.23457E+11`; pangkat ≥ 2 digit, panjang
///    pangkat diukur dari nilai yang dibulatkan ke 1 digit — `9.9E+99` di
///    7 karakter jadi `1E+100`) hanya bila anggaran ≥ 5 karakter. Dipilih
///    bila bagian bulat tidak muat, atau bila menampilkan LEBIH banyak digit
///    signifikan nilai daripada bentuk desimal (seri → desimal).
/// 5. Anggaran < 5: bentuk desimal saja, boleh `0`/`-0` (`-0.000012345` di
///    kolom 5 = `-0`). Anggaran ≥ 5 tetapi tak ada digit signifikan yang
///    tampil & bentuk ilmiah tak muat → `#`.
/// 6. Tidak muat → `#` sebanyak yang muat.
library;

import 'dart:math' as math;

/// Padding teks sel Excel dalam px pada 96 dpi (2 px kiri-kanan + 1 px garis
/// kisi; ECMA-376 §18.3.1.13, MDW Calibri 11 = 7 px). Ruang teks General =
/// lebar sel − ini.
const double paddingSelExcel = 5;

/// Teks General Excel paling panjang (di luar tanda minus): `0.333333333`,
/// `12345678901`, `1.23457E+11` — terukur di fixture, kolom selebar apa pun.
const int batasKarakterGeneral = 11;

/// Lebar glif (px pada 96 dpi = dp Studio pada zoom 100 %) yang dipakai
/// anggaran karakter General.
class MetrikGeneral {
  const MetrikGeneral({
    required this.digit,
    required this.minus,
    required this.pagar,
  });

  /// Lebar digit `0`.
  final double digit;

  /// Lebar tanda minus `-`.
  final double minus;

  /// Lebar `#` (pengisi sel yang tak muat).
  final double pagar;

  /// Calibri 11 — font Normal workbook master.
  static const calibri11 = MetrikGeneral(digit: 7, minus: 5, pagar: 7);

  /// Metrik Calibri untuk font sel [ukuranPt] (`null` = 11 pt). Tabel
  /// [_calibriBiasa]/[_calibriTebal] = ukur GDI 96 dpi (fixture
  /// `calibri_gdi_96dpi`); di luar 6–24 pt diskalakan dari Calibri 11.
  /// Grid menggambar dengan Inter, tetapi PILIHAN teksnya mengikuti
  /// Calibri supaya sama dengan Excel.
  static MetrikGeneral calibri(double? ukuranPt, {bool tebal = false}) {
    final pt = ukuranPt ?? 11;
    final tabel = tebal ? _calibriTebal : _calibriBiasa;
    final i = pt.round() - _ptPertama;
    if (i >= 0 && i < tabel.length) return tabel[i];
    final s = pt / 11;
    return MetrikGeneral(digit: 7 * s, minus: 5 * s, pagar: 7 * s);
  }

  @override
  bool operator ==(Object other) =>
      other is MetrikGeneral &&
      other.digit == digit &&
      other.minus == minus &&
      other.pagar == pagar;

  @override
  int get hashCode => Object.hash(digit, minus, pagar);
}

const int _ptPertama = 6;

// Calibri, GDI TextRenderer, 96 dpi, 6..24 pt — PERSIS `calibri_gdi_96dpi`
// di fixture (dijaga test).
const List<MetrikGeneral> _calibriBiasa = [
  MetrikGeneral(digit: 4, minus: 2, pagar: 4), // 6 pt
  MetrikGeneral(digit: 5, minus: 3, pagar: 5), // 7 pt
  MetrikGeneral(digit: 6, minus: 3, pagar: 5), // 8 pt
  MetrikGeneral(digit: 6, minus: 4, pagar: 6), // 9 pt
  MetrikGeneral(digit: 7, minus: 4, pagar: 7), // 10 pt
  MetrikGeneral(digit: 7, minus: 5, pagar: 7), // 11 pt
  MetrikGeneral(digit: 8, minus: 5, pagar: 8), // 12 pt
  MetrikGeneral(digit: 9, minus: 6, pagar: 9), // 13 pt
  MetrikGeneral(digit: 10, minus: 6, pagar: 9), // 14 pt
  MetrikGeneral(digit: 10, minus: 6, pagar: 10), // 15 pt
  MetrikGeneral(digit: 11, minus: 7, pagar: 11), // 16 pt
  MetrikGeneral(digit: 12, minus: 7, pagar: 11), // 17 pt
  MetrikGeneral(digit: 12, minus: 7, pagar: 12), // 18 pt
  MetrikGeneral(digit: 13, minus: 8, pagar: 13), // 19 pt
  MetrikGeneral(digit: 14, minus: 8, pagar: 13), // 20 pt
  MetrikGeneral(digit: 14, minus: 9, pagar: 14), // 21 pt
  MetrikGeneral(digit: 15, minus: 9, pagar: 15), // 22 pt
  MetrikGeneral(digit: 16, minus: 9, pagar: 15), // 23 pt
  MetrikGeneral(digit: 16, minus: 10, pagar: 16), // 24 pt
];
const List<MetrikGeneral> _calibriTebal = [
  MetrikGeneral(digit: 4, minus: 2, pagar: 4), // 6 pt
  MetrikGeneral(digit: 5, minus: 3, pagar: 5), // 7 pt
  MetrikGeneral(digit: 6, minus: 3, pagar: 5), // 8 pt
  MetrikGeneral(digit: 6, minus: 4, pagar: 6), // 9 pt
  MetrikGeneral(digit: 7, minus: 4, pagar: 7), // 10 pt
  MetrikGeneral(digit: 7, minus: 5, pagar: 7), // 11 pt
  MetrikGeneral(digit: 8, minus: 5, pagar: 8), // 12 pt
  MetrikGeneral(digit: 9, minus: 6, pagar: 9), // 13 pt
  MetrikGeneral(digit: 10, minus: 6, pagar: 9), // 14 pt
  MetrikGeneral(digit: 10, minus: 6, pagar: 10), // 15 pt
  MetrikGeneral(digit: 11, minus: 7, pagar: 11), // 16 pt
  MetrikGeneral(digit: 12, minus: 7, pagar: 11), // 17 pt
  MetrikGeneral(digit: 12, minus: 7, pagar: 12), // 18 pt
  MetrikGeneral(digit: 13, minus: 8, pagar: 13), // 19 pt
  MetrikGeneral(digit: 14, minus: 8, pagar: 13), // 20 pt
  MetrikGeneral(digit: 14, minus: 9, pagar: 14), // 21 pt
  MetrikGeneral(digit: 15, minus: 9, pagar: 15), // 22 pt
  MetrikGeneral(digit: 16, minus: 9, pagar: 15), // 23 pt
  MetrikGeneral(digit: 16, minus: 10, pagar: 16), // 24 pt
];

const double _eps = 1e-9;

/// Ruang teks General (px/dp pada zoom 100 %) untuk sel/gabungan selebar
/// [lebarSel].
double ruangTeksGeneral(double lebarSel) => lebarSel - paddingSelExcel;

/// Teks yang Excel tampilkan untuk [nilai] berformat General di ruang teks
/// [ruang] (lihat [ruangTeksGeneral]). Bisa `#…` bila tidak muat, atau
/// kosong bila satu `#` pun tidak muat.
String teksGeneral(
  num nilai,
  double ruang, {
  MetrikGeneral metrik = MetrikGeneral.calibri11,
}) {
  final x = nilai.toDouble();
  String pagar() => metrik.pagar <= 0 || ruang + _eps < metrik.pagar
      ? ''
      : '#' * (ruang / metrik.pagar + _eps).floor();

  if (!x.isFinite) return pagar();
  if (x == 0) return ruang + _eps >= metrik.digit ? '0' : pagar();

  final negatif = x < 0;
  final tanda = negatif ? '-' : '';
  final l = math.min(
    batasKarakterGeneral,
    ((ruang - (negatif ? metrik.minus : 0)) / metrik.digit + _eps).floor(),
  );
  if (l <= 0) return pagar();
  final (:digit, :pangkat) = _desimal15(x.abs());

  // Bentuk desimal: desimal terbanyak yang muat (diukur SEBELUM nol ekor
  // dibuang; hasil pembulatan bisa menambah satu digit bulat).
  String? tetap;
  var sigTetap = 0;
  for (var d = math.max(0, l - 2); d >= 0; d--) {
    final t = _tetap(digit, pangkat, d);
    if (t.length <= l) {
      tetap = _buangNolEkor(t);
      sigTetap = math.min(pangkat + 1 + d, digit.length);
      break;
    }
  }
  if (l < 5) return tetap == null ? pagar() : '$tanda$tetap';

  // Bentuk ilmiah.
  final pangkat1 = pangkat + (_bulatkan(digit, 1).length > 1 ? 1 : 0);
  final digitPangkat = math.max(2, pangkat1.abs().toString().length);
  String? ilmiah;
  var sigIlmiah = 0;
  if (3 + digitPangkat <= l) {
    final k = math.max(0, l - 4 - digitPangkat);
    ilmiah = _ilmiah(digit, pangkat, k);
    sigIlmiah = math.min(k + 1, digit.length);
  }

  if (tetap != null && sigTetap >= 1 && sigTetap >= sigIlmiah) {
    return '$tanda$tetap';
  }
  if (ilmiah != null) return '$tanda$ilmiah';
  return pagar();
}

/// Isi bilah rumus Excel untuk sel berisi angka (bukan rumus): 15 digit
/// signifikan; bentuk desimal bila pangkat ≤ 20 dan desimalnya ≤ 19,
/// selain itu ilmiah (`1.23456789012345E-16`, `1E+21`). Terbukti terhadap
/// `Range.Formula` di fixture.
String teksBilahRumus(num nilai) {
  final x = nilai.toDouble();
  if (!x.isFinite) return nilai.toString();
  if (x == 0) return '0';
  final tanda = x < 0 ? '-' : '';
  final (:digit, :pangkat) = _desimal15(x.abs());
  final desimal = digit.length - pangkat - 1;
  if (pangkat <= 20 && desimal <= 19) {
    if (pangkat < 0) return '${tanda}0.${'0' * (-pangkat - 1)}$digit';
    final bulat = digit.length >= pangkat + 1
        ? digit.substring(0, pangkat + 1)
        : digit.padRight(pangkat + 1, '0');
    final pecahan = digit.length > pangkat + 1
        ? digit.substring(pangkat + 1)
        : '';
    return pecahan.isEmpty ? '$tanda$bulat' : '$tanda$bulat.$pecahan';
  }
  final m = digit.length > 1 ? '${digit[0]}.${digit.substring(1)}' : digit;
  return '$tanda$m${_pangkatExcel(pangkat)}';
}

// ─────────────────────────────────────────────────────────────── digit

/// |nilai| > 0 dibulatkan ke 15 digit signifikan: [digit] tanpa nol ekor,
/// nilai = d₀.d₁d₂… × 10^[pangkat].
({String digit, int pangkat}) _desimal15(double a) {
  final s = a.toStringAsExponential(14);
  final e = s.indexOf('e');
  final mantisa = s.substring(0, e).replaceFirst('.', '');
  var akhir = mantisa.length;
  while (akhir > 1 && mantisa.codeUnitAt(akhir - 1) == 0x30) {
    akhir--;
  }
  return (
    digit: mantisa.substring(0, akhir),
    pangkat: int.parse(s.substring(e + 1)),
  );
}

/// [simpan] digit pertama [digit] (dilengkapi nol), dibulatkan setengah ke
/// atas pada digit berikutnya. Bisa satu digit lebih panjang (`99` → `100`).
/// [simpan] = 0: `1` bila digit pertama ≥ 5, selain itu `0`.
String _bulatkan(String digit, int simpan) {
  if (simpan < 0) return '0';
  if (simpan == 0) return digit.codeUnitAt(0) >= 0x35 ? '1' : '0';
  if (simpan >= digit.length) return digit.padRight(simpan, '0');
  final dasar = digit.substring(0, simpan);
  if (digit.codeUnitAt(simpan) < 0x35) return dasar;
  final c = dasar.codeUnits.toList();
  var i = c.length - 1;
  while (i >= 0 && c[i] == 0x39) {
    c[i] = 0x30;
    i--;
  }
  if (i < 0) return '1${String.fromCharCodes(c)}';
  c[i]++;
  return String.fromCharCodes(c);
}

/// Bentuk desimal dengan tepat [d] desimal (nol ekor BELUM dibuang).
String _tetap(String digit, int pangkat, int d) {
  final r = _bulatkan(digit, pangkat + 1 + d);
  if (d == 0) return r;
  final p = r.padLeft(d + 1, '0');
  return '${p.substring(0, p.length - d)}.${p.substring(p.length - d)}';
}

/// Bentuk ilmiah dengan [k] desimal mantisa, nol ekor dibuang.
String _ilmiah(String digit, int pangkat, int k) {
  var r = _bulatkan(digit, k + 1);
  var p = pangkat;
  if (r.length > k + 1) {
    r = r.substring(0, k + 1);
    p++;
  }
  final m = k > 0 ? _buangNolEkor('${r[0]}.${r.substring(1)}') : r;
  return '$m${_pangkatExcel(p)}';
}

/// `E+05`, `E-10`, `E+100`.
String _pangkatExcel(int p) =>
    'E${p < 0 ? '-' : '+'}${p.abs().toString().padLeft(2, '0')}';

String _buangNolEkor(String t) {
  if (!t.contains('.')) return t;
  var akhir = t.length;
  while (t.codeUnitAt(akhir - 1) == 0x30) {
    akhir--;
  }
  if (t.codeUnitAt(akhir - 1) == 0x2E) akhir--;
  return t.substring(0, akhir);
}

final _polaPangkatExcel = RegExp(r'E[+-]\d{2,}$');

/// `true` bila [s] adalah ANGKA MENTAH tulisan skrip, bukan teks General
/// tulisan Excel — dipakai sel CSV (`s` = teks berkas apa adanya): CSV yang
/// diekspor skrip menulis `0.010015000000000001` atau
/// `1.5000000000001124e-05`, yang tidak pernah ditulis Excel.
///
/// Mentah bila [s] terbaca sebagai angka berhingga DAN salah satu:
/// - lebih dari 15 digit signifikan (Excel menampilkan paling banyak 15);
/// - memakai `e` kecil;
/// - memakai `E` tanpa bentuk pangkat Excel `E+NN`/`E-NN`.
///
/// Teks yang sudah berbentuk Excel (`0.127`, `1.5E-05`, `1234`) → `false`:
/// tetap ditampilkan apa adanya.
bool teksAngkaMentah(String s) {
  final t = s.trim();
  final n = double.tryParse(t);
  if (n == null || !n.isFinite) return false;
  if (t.contains('e')) return true;
  final pangkat = t.indexOf('E');
  if (pangkat >= 0 && !_polaPangkatExcel.hasMatch(t)) return true;
  final mantisa = pangkat >= 0 ? t.substring(0, pangkat) : t;
  final digit = mantisa
      .replaceAll(RegExp(r'[^0-9]'), '')
      .replaceFirst(RegExp(r'^0+'), '');
  return digit.length > 15;
}
