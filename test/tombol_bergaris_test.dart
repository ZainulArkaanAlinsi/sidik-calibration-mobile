import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_theme.dart';
import 'package:sidik_calibration/widgets/app_button.dart';

/// Huruf besar di tombol, gaya btn-12.
///
/// ## Kenapa test ini ada
///
/// Aturannya dipasang di DUA tempat yang beda, dan gampang cuma satu yang
/// keinget waktu ada yang ngerapiin kode:
///
///  1. `AppButton` — label diubah sendiri sebelum jadi `Text`.
///  2. `ThemeData.foregroundBuilder` — buat `FilledButton`/`OutlinedButton`
///     yang dipanggil langsung (tombol dialog), yang nggak lewat `AppButton`
///     sama sekali.
///
/// Kalau salah satu copot, yang muncul bukan error — cuma casing belang antar
/// tombol, dan itu jenis kerusakan yang lolos review berkali-kali.
///
/// Test ini juga yang menahan efek sampingnya: begitu label jadi HURUF BESAR,
/// `find.text('Simpan')` di test lain berhenti ketemu. Itu sudah disesuaikan
/// di enam berkas test; yang di sini mematok alasannya.
void main() {
  Widget bungkus(Widget anak) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: anak)),
  );

  testWidgets('AppButton merender labelnya HURUF BESAR', (tester) async {
    await tester.pumpWidget(
      bungkus(AppButton(label: 'Simpan draft', onPressed: () {})),
    );

    expect(find.text('SIMPAN DRAFT'), findsOneWidget);
    expect(find.text('Simpan draft'), findsNothing);
  });

  testWidgets('AppButton berikon tetap HURUF BESAR', (tester) async {
    await tester.pumpWidget(
      bungkus(
        AppButton(
          label: 'Kirim sekarang',
          icon: Icons.send,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('KIRIM SEKARANG'), findsOneWidget);
  });

  testWidgets('FilledButton yang dipanggil langsung ikut HURUF BESAR', (
    tester,
  ) async {
    await tester.pumpWidget(
      bungkus(
        FilledButton(
          onPressed: () {},
          child: const Text('Kirim sertifikat'),
        ),
      ),
    );

    expect(find.text('KIRIM SERTIFIKAT'), findsOneWidget);
  });

  testWidgets('OutlinedButton yang dipanggil langsung ikut HURUF BESAR', (
    tester,
  ) async {
    await tester.pumpWidget(
      bungkus(
        OutlinedButton(onPressed: () {}, child: const Text('Tutup dialog')),
      ),
    );

    expect(find.text('TUTUP DIALOG'), findsOneWidget);
  });

  testWidgets('pembaca layar tetap dapat teks aslinya', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      bungkus(
        FilledButton(
          onPressed: () {},
          child: const Text('Kirim sertifikat'),
        ),
      ),
    );

    // Yang dibaca keras-keras tetap "Kirim sertifikat", bukan huruf besar
    // semua — sebagian pembaca layar mengeja teks kapital huruf per huruf.
    expect(
      tester.getSemantics(find.byType(FilledButton)).label,
      contains('Kirim sertifikat'),
    );

    semantics.dispose();
  });

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

    // Row bukan Text, jadi nggak disentuh sama sekali — termasuk ikonnya, yang
    // bakal ilang kalau anaknya asal diganti.
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.text('Unduh PDF'), findsOneWidget);
  });
}
