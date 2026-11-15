// Perkakas tes komponen Biru Awan bagian 2 (L3b). Menambah `uji_biru_awan.dart`
// (L3a) dengan pemasangan satu baris dan akses token dari pohon widget.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan_lanjut.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';

import 'uji_biru_awan.dart';

export 'uji_biru_awan.dart';

/// Memasang [anak] pada layar [lebar] x [tinggi] dengan tema terang atau gelap
/// dan huruf [skala].
Future<void> pasang(
  WidgetTester tester,
  Widget anak, {
  bool gelap = false,
  double skala = 1.0,
  double lebar = 392,
  double tinggi = 852,
  bool bergulir = true,
}) async {
  layarUji(tester, lebar: lebar, tinggi: tinggi);
  await tester.pumpWidget(
    aplikasiUji(anak, gelap: gelap, skala: skala, bergulir: bergulir),
  );
}

/// Jalankan [isi] untuk tema terang lalu gelap (nama tema dikirim untuk pesan).
Future<void> duaTema(
  WidgetTester tester,
  Future<void> Function(bool gelap, String nama) isi,
) async {
  for (final gelap in [false, true]) {
    await isi(gelap, gelap ? 'gelap' : 'terang');
  }
}

BuildContext _konteks(WidgetTester tester) =>
    tester.element(find.byType(Scaffold));

SidikMaterial bahan(WidgetTester tester) => SidikMaterial.of(_konteks(tester));
WarnaBiruAwan warna(WidgetTester tester) => WarnaBiruAwan.of(_konteks(tester));
WarnaLanjutBiruAwan warnaLanjut(WidgetTester tester) =>
    WarnaLanjutBiruAwan.of(_konteks(tester));
ColorScheme skemaWarna(WidgetTester tester) =>
    Theme.of(_konteks(tester)).colorScheme;

/// Warna isi `DecoratedBox` pertama di bawah [dalam] yang punya warna.
Color? isiKotak(WidgetTester tester, Finder dalam) {
  for (final d in tester.widgetList<DecoratedBox>(
    find.descendant(of: dalam, matching: find.byType(DecoratedBox)),
  )) {
    final dekor = d.decoration;
    if (dekor is BoxDecoration && dekor.color != null) return dekor.color;
  }
  return null;
}

/// Semua teks di bawah [dalam] beserta gayanya (hasil gabungan `DefaultTextStyle`).
List<TextStyle> gayaTeks(WidgetTester tester, Finder dalam) => [
  for (final p in tester.renderObjectList<RenderParagraph>(
    find.descendant(of: dalam, matching: find.byType(RichText)),
  ))
    p.text.style ?? const TextStyle(),
];

/// Semantik node [Finder] (satu node).
SemanticsData semantik(WidgetTester tester, Finder f) =>
    tester.getSemantics(f).getSemanticsData();

/// Token lebar minimum sasaran sentuh.
const double sentuhMin = 48;

/// Nilai ambang kontras bukan-teks (WCAG 1.4.11).
const double ambangBukanTeks = 3;

/// Dipakai tes yang butuh angka motif.
const double kanvasMotifLebar = UkuranLanjutBiruAwan.motifLebar;
