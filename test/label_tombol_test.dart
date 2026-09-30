import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/widgets/app_button.dart';

/// Label tombol = sentence case, apa adanya dari ARB (keputusan desain 26 Sep
/// 2026, diterapkan 30 Sep).
///
/// ## Kenapa test ini ada
///
/// Sebelumnya label dikapitalkan di DUA tempat yang beda: `AppButton` (string
/// diubah sebelum jadi `Text`) dan `ThemeData.foregroundBuilder` (buat
/// `FilledButton`/`OutlinedButton` yang dipanggil langsung, mis. tombol
/// dialog). Waktu huruf besar dicabut, gampang cuma satu yang ikut dicabut —
/// dan yang muncul bukan error, cuma casing belang antar tombol: "SIMPAN" di
/// satu layar, "Batal" di dialognya. Test ini mematok keduanya sekaligus.
///
/// Huruf besar tetap ada di tempat yang memang benar secara fisik — label
/// terukir di logam (`SidikMaterial.gayaEtsa`) dan eyebrow seksi — dan itu
/// bukan tombol.
void main() {
  Widget bungkus(Widget anak) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: anak)),
  );

  testWidgets('AppButton merender labelnya apa adanya', (tester) async {
    await tester.pumpWidget(
      bungkus(AppButton(label: 'Simpan draft', onPressed: () {})),
    );

    expect(find.text('Simpan draft'), findsOneWidget);
    expect(find.text('SIMPAN DRAFT'), findsNothing);
  });

  testWidgets('AppButton berikon juga apa adanya', (tester) async {
    await tester.pumpWidget(
      bungkus(
        AppButton(label: 'Kirim sekarang', icon: Icons.send, onPressed: () {}),
      ),
    );

    expect(find.text('Kirim sekarang'), findsOneWidget);
  });

  testWidgets('FilledButton yang dipanggil langsung tidak dikapitalkan tema', (
    tester,
  ) async {
    await tester.pumpWidget(
      bungkus(
        FilledButton(onPressed: () {}, child: const Text('Kirim sertifikat')),
      ),
    );

    expect(find.text('Kirim sertifikat'), findsOneWidget);
    expect(find.text('KIRIM SERTIFIKAT'), findsNothing);
  });

  testWidgets(
    'OutlinedButton yang dipanggil langsung tidak dikapitalkan tema',
    (tester) async {
      await tester.pumpWidget(
        bungkus(
          OutlinedButton(onPressed: () {}, child: const Text('Tutup dialog')),
        ),
      );

      expect(find.text('Tutup dialog'), findsOneWidget);
    },
  );

  testWidgets('anak yang bukan Text dibiarkan utuh', (tester) async {
    await tester.pumpWidget(
      bungkus(
        FilledButton(
          onPressed: () {},
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.download), Text('Unduh PDF')],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.text('Unduh PDF'), findsOneWidget);
  });
}
