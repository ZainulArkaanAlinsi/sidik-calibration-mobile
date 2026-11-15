import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/screens/auth/widgets/motif_skala.dart';

/// `MotifSkala` menggambar `docs/desain-ulang/aset/motif_skala.svg` (viewBox
/// 300 x 120) dengan kanvas. Tes ini membaca piksel hasil gambarnya: titik yang
/// HARUS tergambar (hub, jarum, busur, tik, penggaris), titik yang HARUS kosong,
/// warna dan opasitasnya, dan aturan `meet` saat kotaknya tidak sebangun.
void main() {
  const putih = Color(0xFFFFFFFF);

  /// Gambar [MotifSkala] ke piksel dan kembalikan alfa di (x, y).
  Future<int Function(int x, int y)> gambar(
    WidgetTester tester, {
    required double lebar,
    required double tinggi,
    double opasitas = 1,
    Color warna = putih,
  }) async {
    final kunci = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: kunci,
            child: MotifSkala(
              warna: warna,
              lebar: lebar,
              tinggi: tinggi,
              opasitas: opasitas,
            ),
          ),
        ),
      ),
    );
    late final ByteData data;
    late final int lebarPiksel;
    await tester.runAsync(() async {
      final batas = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(kunci),
      );
      final gambar = await batas.toImage();
      lebarPiksel = gambar.width;
      data = (await gambar.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    return (x, y) => data.getUint8((y * lebarPiksel + x) * 4 + 3);
  }

  testWidgets('piksel yang harus tergambar dan yang harus kosong', (
    tester,
  ) async {
    final alfa = await gambar(tester, lebar: 300, tinggi: 120);

    // Hub di (300, 120), jarum dari hub ke (245, 70,5).
    expect(alfa(299, 119), 255, reason: 'hub');
    expect(alfa(272, 95), 255, reason: 'jarum');
    // Busur luar (jari-jari 110) pada sudut 45 derajat, dan tik panjang di
    // puncak (300, 10) ke (300, 26).
    expect(alfa(222, 42), greaterThan(0), reason: 'busur luar');
    expect(alfa(299, 18), 255, reason: 'tik panjang di utara');
    // Penggaris: garis y = 118 dan tik panjang di x = 50 (tinggi 14).
    expect(alfa(30, 118), 255, reason: 'garis penggaris');
    expect(alfa(50, 110), 255, reason: 'tik panjang penggaris');
    expect(alfa(60, 115), greaterThan(150), reason: 'tik pendek penggaris');
    // Penggaris berakhir di x = 180 (+ ujung bulat), tidak sampai 185.
    expect(alfa(185, 118), 0, reason: 'penggaris tidak melewati 181');
    // Kosong: sudut kiri atas, bagian dalam busur, di atas penggaris.
    expect(alfa(2, 2), 0, reason: 'sudut kiri atas');
    expect(alfa(150, 30), 0, reason: 'di luar busur');
    expect(alfa(250, 110), 0, reason: 'di dalam busur, jauh dari jarum');
    expect(alfa(120, 60), 0, reason: 'tengah kosong');
  });

  testWidgets('warna dan opasitas dari pemanggil', (tester) async {
    final alfa = await gambar(
      tester,
      lebar: 300,
      tinggi: 120,
      opasitas: 0.5,
      warna: const Color(0xFF5BB4F5),
    );
    // Garis penggaris (tanpa tik di x = 35): alfa = opasitas x 255. Hub tidak
    // dipakai karena jarum dan tik menumpuk di sana.
    expect(alfa(35, 118), closeTo(128, 1));
    // Di luar gambar tetap kosong.
    expect(alfa(2, 2), 0);
  });

  testWidgets('kotak tidak sebangun: seluruh motif muat dan di tengah (meet)', (
    tester,
  ) async {
    // 600 x 300: skala = min(2, 2,5) = 2, motif 600 x 240 di tengah tegak
    // (30 dp kosong di atas); hub (300, 120) jatuh di (600, 270).
    final alfa = await gambar(tester, lebar: 600, tinggi: 300);
    expect(alfa(599, 269), 255, reason: 'hub di (600, 270) setelah digeser');
    expect(alfa(599, 10), 0, reason: 'pita kosong di atas');
    expect(alfa(599, 292), 0, reason: 'di bawah hub (jari-jari 18)');
    // Penggaris di y = 118 x 2 + 30 = 266.
    expect(alfa(60, 266), 255, reason: 'penggaris ikut diskalakan');
  });

  testWidgets('hiasan: tidak dibaca pembaca layar dan tidak menerima sentuhan', (
    tester,
  ) async {
    final semantik = tester.ensureSemantics();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MotifSkala(warna: putih, lebar: 100, tinggi: 40),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(MotifSkala),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(MotifSkala),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
    semantik.dispose();
  });
}
