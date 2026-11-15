// MasukBerurutan dan TekanSkala (`lib/core/motion/gerak_bersama.dart`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/motion/app_motion.dart';
import 'package:sidik_calibration/core/motion/gerak_bersama.dart';

import '../support/uji_biru_awan.dart';

double _opasitas(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(MasukBerurutan),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

double _geser(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byType(MasukBerurutan),
        matching: find.byType(Transform),
      ),
    )
    .transform
    .getTranslation()
    .y;

/// Anak yang bisa dikenai ketukan (SizedBox kosong tidak menerima peristiwa).
class _Kotak extends StatelessWidget {
  const _Kotak();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey('isi'),
    width: 100,
    height: 60,
    child: ColoredBox(color: Colors.transparent),
  );
}

Widget _butir(int indeks) => MasukBerurutan(
  indeks: indeks,
  child: const SizedBox(key: ValueKey('isi'), width: 100, height: 40),
);

void main() {
  setUpAll(muatFontUji);

  group('MasukBerurutan', () {
    testWidgets('mulai tak terlihat dan 12 dp di bawah; selesai 240 ms', (
      tester,
    ) async {
      await tester.pumpWidget(aplikasiUji(_butir(0)));
      expect(_opasitas(tester), 0);
      expect(_geser(tester), GerakBersama.geserMasuk);
      expect(GerakBersama.geserMasuk, 12);

      await tester.pump(AppMotion.sedang ~/ 2);
      expect(_opasitas(tester), inExclusiveRange(0, 1));
      expect(_geser(tester), inExclusiveRange(0, 12));

      await tester.pump(AppMotion.sedang);
      expect(_opasitas(tester), 1);
      expect(_geser(tester), 0);
    });

    testWidgets('berurutan: butir ke-3 menunggu 3 x 35 ms', (tester) async {
      await tester.pumpWidget(aplikasiUji(_butir(3)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opasitas(tester), 0, reason: 'masih menunggu (< 105 ms)');
      await tester.pump(const Duration(milliseconds: 5) + AppMotion.sedang);
      expect(_opasitas(tester), 1);
    });

    testWidgets('tundaan dibatasi 210 ms berapa pun panjang daftar', (
      tester,
    ) async {
      await tester.pumpWidget(aplikasiUji(_butir(40)));
      await tester.pump(AppMotion.maksTunda - const Duration(milliseconds: 5));
      expect(_opasitas(tester), 0);
      await tester.pump(const Duration(milliseconds: 5) + AppMotion.sedang);
      expect(_opasitas(tester), 1);
    });

    testWidgets('tidak mengubah ukuran anak dan tidak menyisakan timer', (
      tester,
    ) async {
      await tester.pumpWidget(aplikasiUji(Center(child: _butir(2))));
      expect(
        tester.getSize(find.byKey(const ValueKey('isi'))),
        const Size(100, 40),
      );
      // Tes berakhir saat animasi belum selesai: tidak boleh ada Timer menggantung.
    });

    testWidgets('kurangi gerak: langsung utuh, tanpa tundaan, tanpa animasi', (
      tester,
    ) async {
      await tester.pumpWidget(aplikasiUji(kurangiGerak(_butir(5))));
      expect(_opasitas(tester), 1);
      expect(_geser(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('anak tetap bisa diketuk dan dibaca setelah masuk', (
      tester,
    ) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          MasukBerurutan(
            indeks: 1,
            child: ElevatedButton(
              onPressed: () => n++,
              child: const Text('Buka'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka'));
      expect(n, 1);
    });
  });

  group('TekanSkala', () {
    AnimatedScale skala(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale));

    testWidgets('ditekan: 0,97 dalam 120 ms; dilepas: kembali 1', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(Center(child: TekanSkala(child: const _Kotak()))),
      );
      expect(skala(tester).scale, 1);
      expect(skala(tester).duration, AppMotion.kilat);
      expect(GerakBersama.skalaTekan, 0.97);
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('isi'))),
      );
      await tester.pump();
      expect(skala(tester).scale, 0.97);
      await tester.pump(AppMotion.kilat);
      expect(
        tester.getSize(find.byKey(const ValueKey('isi'))),
        const Size(100, 60),
        reason: 'ukuran tata letak tetap; hanya gambar yang berskala',
      );
      await g.up();
      await tester.pump();
      expect(skala(tester).scale, 1);
    });

    testWidgets('dibatalkan (geser keluar): kembali 1', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(Center(child: TekanSkala(child: const _Kotak()))),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('isi'))),
      );
      await tester.pump();
      await g.cancel();
      await tester.pump();
      expect(skala(tester).scale, 1);
    });

    testWidgets('tidak aktif: tidak berskala', (tester) async {
      await tester.pumpWidget(
        aplikasiUji(
          Center(child: TekanSkala(aktif: false, child: const _Kotak())),
        ),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('isi'))),
      );
      await tester.pump();
      expect(skala(tester).scale, 1);
      await g.up();
    });

    testWidgets('kurangi gerak: durasi nol (perpindahan seketika)', (
      tester,
    ) async {
      await tester.pumpWidget(
        aplikasiUji(
          kurangiGerak(Center(child: TekanSkala(child: const _Kotak()))),
        ),
      );
      expect(skala(tester).duration, Duration.zero);
    });

    testWidgets('di luar InkWell: ketukan tetap sampai ke tombol', (
      tester,
    ) async {
      var n = 0;
      await tester.pumpWidget(
        aplikasiUji(
          Center(
            child: TekanSkala(
              child: ElevatedButton(
                onPressed: () => n++,
                child: const Text('Ketuk'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ketuk'));
      expect(n, 1);
    });
  });
}
