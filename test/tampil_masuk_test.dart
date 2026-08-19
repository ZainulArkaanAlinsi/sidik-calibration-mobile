import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sidik_calibration/widgets/tampil_masuk.dart';

/// Animasi masuk nggak boleh jadi beban buat daftar yang digulir.
///
/// Dua hal yang dijaga di sini, dua-duanya kelihatan sebagai "scroll berat"
/// padahal sebabnya beda:
///
///  1. Item yang digulir balik NGGAK animasi lagi. `ListView.builder` mbuang
///     item yang keluar layar dan mbangun ulang waktu balik — tanpa
///     [JejakMasuk], tiap gulir balik bikin kartunya berkedip.
///  2. Setelan "kurangi gerak" bikin gerakannya NOL, bukan diperlambat.
void main() {
  Widget bungkus(Widget child, {bool kurangiGerak = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: kurangiGerak),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  testWidgets('kurangi gerak → isinya langsung utuh, tanpa transisi', (
    tester,
  ) async {
    await tester.pumpWidget(
      bungkus(
        const TampilMasuk(child: Text('halo')),
        kurangiGerak: true,
      ),
    );

    // Frame PERTAMA, belum ada pump lanjutan: kalau masih dianimasiin,
    // opacity-nya bakal 0 dan `Opacity` ini kegambar di pohon.
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('halo'), findsOneWidget);
  });

  testWidgets('tanpa kurangi gerak → mulai transparan, lalu utuh', (
    tester,
  ) async {
    await tester.pumpWidget(bungkus(const TampilMasuk(child: Text('halo'))));

    final awal = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(awal, lessThan(1));

    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('jejak: indeks yang sama nggak animasi dua kali', (tester) async {
    final jejak = JejakMasuk();

    // Kelahiran pertama — animasi jalan.
    await tester.pumpWidget(
      bungkus(TampilMasuk(indeks: 3, jejak: jejak, child: const Text('kartu'))),
    );
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
    await tester.pumpAndSettle();

    // Item dibuang (digulir keluar layar), lalu dibangun ulang di indeks yang
    // sama. `State`-nya baru, tapi catatannya inget.
    await tester.pumpWidget(bungkus(const SizedBox.shrink()));
    await tester.pumpWidget(
      bungkus(TampilMasuk(indeks: 3, jejak: jejak, child: const Text('kartu'))),
    );

    expect(find.byType(Opacity), findsNothing);
    expect(find.text('kartu'), findsOneWidget);
  });

  testWidgets('jejak: indeks lain tetap dapat giliran animasinya', (
    tester,
  ) async {
    final jejak = JejakMasuk();

    await tester.pumpWidget(
      bungkus(TampilMasuk(indeks: 0, jejak: jejak, child: const Text('a'))),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(bungkus(const SizedBox.shrink()));
    await tester.pumpWidget(
      bungkus(TampilMasuk(indeks: 1, jejak: jejak, child: const Text('b'))),
    );

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
  });
}
