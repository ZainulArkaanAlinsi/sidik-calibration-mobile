import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/l10n/app_localizations.dart';
import 'package:sidik_calibration/providers/theme_mode_provider.dart';
import 'package:sidik_calibration/widgets/sakelar_tema.dart';

/// Sakelar tema sun & moon.
///
/// ## Kenapa test ini ada
///
/// Isinya animasi yang jalan terus — awan 6 detik dan bintang 2 detik,
/// dua-duanya `repeat()`. Controller yang muter selamanya bikin
/// `pumpAndSettle` **gantung sampai timeout**, dan itu bukan merah yang jelas:
/// yang kena justru test layar lain yang kebetulan mampir ke sakelar ini.
/// Makanya animasi latarnya mati waktu `MediaQuery.disableAnimations` nyala
/// (dan itu default di widget test) — pagar itu yang dijaga di sini.
void main() {
  Widget bungkus(Widget anak, {ThemeMode mode = ThemeMode.light}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: mode,
        home: Scaffold(body: Center(child: anak)),
      ),
    );
  }

  testWidgets('sakelar nggak bikin pumpAndSettle gantung', (tester) async {
    await tester.pumpWidget(bungkus(SakelarSunMoon(gelap: false, onTap: () {})));
    await tester.pumpAndSettle();

    expect(find.byType(SakelarSunMoon), findsOneWidget);
  });

  testWidgets('ketuk sakelar membalik mode tema', (tester) async {
    late WidgetRef ref;

    // `themeMode` ikut provider persis kayak `app.dart` — kalau nggak, sakelar
    // baca brightness yang nggak pernah berubah dan ketukan kedua cuma
    // nyetel ulang mode yang sama.
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: r.watch(themeModeProvider),
              home: const Scaffold(body: Center(child: SakelarTema())),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SakelarTema));
    await tester.pumpAndSettle();
    expect(ref.read(themeModeProvider), ThemeMode.dark);

    await tester.tap(find.byType(SakelarTema));
    await tester.pumpAndSettle();
    expect(ref.read(themeModeProvider), ThemeMode.light);
  });

  testWidgets('sakelar punya label buat pembaca layar', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      bungkus(
        SakelarSunMoon(gelap: true, onTap: () {}, label: 'Ganti tema'),
        mode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(SakelarSunMoon)).label,
      contains('Ganti tema'),
    );

    semantics.dispose();
  });
}
