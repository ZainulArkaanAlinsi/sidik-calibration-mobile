// Perkakas uji komponen dasar Biru Awan (`lib/widgets/biru_awan/`, L3a).
//
// Melengkapi `komponen_uji.dart` (tema Lab, font asli, kontras dari pohon
// widget, pedoman sentuh) dengan tiga pemeriksaan yang diminta tiap komponen:
// mode kurangi gerak, skala huruf 1,3 pada lebar 320, dan tangkap-galat.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsData;
import 'package:flutter_test/flutter_test.dart';

import 'komponen_uji.dart';

export 'komponen_uji.dart';

/// Membungkus [anak] dengan `MediaQuery.disableAnimations` menyala, seperti
/// saat pengguna menyalakan "kurangi gerak" di sistem.
Widget kurangiGerak(Widget anak) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: anak,
  ),
);

/// Memasang [anak] pada lebar 320 dp dengan huruf 1,3x dan memastikan tidak ada
/// galat tata letak (RenderFlex overflow dan sejenisnya). Dua tema.
Future<void> periksaSkala13(
  WidgetTester tester,
  Widget anak, {
  double tinggi = 900,
}) async {
  for (final gelap in [false, true]) {
    layarUji(tester, lebar: 320, tinggi: tinggi);
    await tester.pumpWidget(
      aplikasiUji(
        Padding(padding: const EdgeInsets.all(16), child: anak),
        gelap: gelap,
        skala: 1.3,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.takeException(),
      isNull,
      reason:
          'galat tata letak di 320 dp x 1,3 (${gelap ? 'gelap' : 'terang'})',
    );
  }
}

/// Keadaan "aktif" pada node semantik: `true` (dapat dipakai), `false` (mati),
/// `null` bila node tidak membawa keadaan aktif sama sekali. Mutan "lupa
/// menandai mati" menghasilkan `true` atau `null`, bukan `false`.
bool? semantikAktif(SemanticsData data) =>
    switch (data.flagsCollection.isEnabled) {
      Tristate.isTrue => true,
      Tristate.isFalse => false,
      Tristate.none => null,
    };
