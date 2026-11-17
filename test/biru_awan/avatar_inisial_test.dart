// AvatarInisial: bulatan inisial 36/48/52/84 (inisial 800).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/token_komponen_biru_awan_lanjut.dart';
import 'package:sidik_calibration/core/theme/warna_biru_awan.dart';
import 'package:sidik_calibration/widgets/biru_awan/avatar_inisial.dart';

import '../support/uji_lanjut_biru_awan.dart';

Widget _a({
  UkuranAvatarInisial ukuran = UkuranAvatarInisial.sedang,
  RagamAvatarInisial ragam = RagamAvatarInisial.kabut,
  String? label,
  VoidCallback? onTap,
  String inisial = 'SA',
}) => Center(
  child: AvatarInisial(
    inisial: inisial,
    ukuran: ukuran,
    ragam: ragam,
    label: label,
    onTap: onTap,
  ),
);

void main() {
  setUpAll(muatFontUji);

  group('inisialDari', () {
    test('huruf pertama dua kata pertama, apa adanya', () {
      expect(AvatarInisial.inisialDari('Siti Aminah'), 'SA');
      expect(AvatarInisial.inisialDari('  Andi   Budi Cahya '), 'AB');
      expect(AvatarInisial.inisialDari('Budi'), 'B');
      expect(AvatarInisial.inisialDari('budi'), 'b', reason: 'tak diubah');
      expect(AvatarInisial.inisialDari(''), '');
      expect(AvatarInisial.inisialDari('   '), '');
    });

    test('satu karakter pengguna utuh (gabungan/surrogate) tidak terbelah', () {
      expect(AvatarInisial.inisialDari('Éric Ünal'), 'ÉÜ');
      expect(AvatarInisial.inisialDari('😀 Budi'), '😀B');
    });
  });

  group('ukuran', () {
    final peta = {
      UkuranAvatarInisial.kecil: 36.0,
      UkuranAvatarInisial.sedang: 48.0,
      UkuranAvatarInisial.laci: 52.0,
      UkuranAvatarInisial.besar: 84.0,
    };
    for (final e in peta.entries) {
      testWidgets('${e.key.name}: ${e.value} dp, bulat, inisial 800', (
        tester,
      ) async {
        await pasang(tester, _a(ukuran: e.key));
        expect(
          tester.getSize(find.byType(AvatarInisial)),
          Size.square(e.value),
        );
        final dekor =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(AvatarInisial),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(dekor.shape, BoxShape.circle);
        expect(
          tester.widget<Text>(find.text('SA')).style!.fontWeight,
          FontWeight.w800,
        );
      });
    }
  });

  group('warna dan kontras', () {
    for (final gelap in [false, true]) {
      final nama = gelap ? 'gelap' : 'terang';
      testWidgets('isi dan inisial tiap ragam ($nama)', (tester) async {
        for (final r in RagamAvatarInisial.values) {
          await pasang(tester, _a(ragam: r), gelap: gelap);
          final m = bahan(tester);
          final w = warna(tester);
          final l = warnaLanjut(tester);
          final (Color isi, Color tinta) = switch (r) {
            RagamAvatarInisial.kabut => (w.isi(IsiBiruAwan.kabut), m.biruTinta),
            RagamAvatarInisial.putih => (m.kertas, m.biruTinta),
            RagamAvatarInisial.langit => (l.isiHero, l.tintaHero),
          };
          expect(
            isiKotak(tester, find.byType(AvatarInisial)),
            isi,
            reason: '$r',
          );
          expect(tester.widget<Text>(find.text('SA')).style!.color, tinta);
          expect(
            pelanggaranKontrasTeks(tester, find.byType(AvatarInisial)),
            isEmpty,
            reason: '$r ($nama)',
          );
        }
      });
    }
  });

  group('semantik dan ketuk', () {
    testWidgets('tanpa label: hiasan (tak ada node); dengan label: terpasang '
        'juga tanpa onTap', (tester) async {
      final s = tester.ensureSemantics();
      await pasang(tester, _a());
      expect(find.bySemanticsLabel('SA'), findsNothing);
      await pasang(tester, _a(label: 'Siti Aminah'));
      final d = semantik(tester, find.byType(AvatarInisial));
      expect(d.label, 'Siti Aminah');
      expect(d.hasAction(SemanticsAction.tap), isFalse);
      expect(d.flagsCollection.isButton, isFalse);
      s.dispose();
    });

    testWidgets('dariNama: label bawaan = nama; inisial dari nama', (
      tester,
    ) async {
      final s = tester.ensureSemantics();
      await pasang(
        tester,
        Center(child: AvatarInisial.dariNama('Siti Aminah')),
      );
      expect(find.text('SA'), findsOneWidget);
      expect(find.bySemanticsLabel('Siti Aminah'), findsOneWidget);
      s.dispose();
    });

    testWidgets('onTap: tombol berlabel, area sentuh >= 48 untuk avatar 36, '
        'ketuk di tepi area bekerja', (tester) async {
      final s = tester.ensureSemantics();
      var n = 0;
      await pasang(
        tester,
        _a(
          ukuran: UkuranAvatarInisial.kecil,
          label: 'Profil',
          onTap: () => n++,
        ),
      );
      expect(tester.getSize(find.byType(AvatarInisial)), const Size(48, 48));
      final d = semantik(tester, find.byType(AvatarInisial));
      expect(d.flagsCollection.isButton, isTrue);
      expect(d.hasAction(SemanticsAction.tap), isTrue);
      final r = tester.getRect(find.byType(AvatarInisial));
      await tester.tapAt(r.topLeft + const Offset(1, 1));
      await tester.tapAt(r.center);
      expect(n, 2);
      await periksaPedomanSentuh(tester);
      s.dispose();
    });

    test('onTap tanpa label ditolak', () {
      expect(
        () => AvatarInisial(inisial: 'A', onTap: () {}),
        throwsAssertionError,
      );
    });

    testWidgets('tanpa onTap: ketukan tidak menangkap, ukuran persis', (
      tester,
    ) async {
      await pasang(tester, _a(ukuran: UkuranAvatarInisial.kecil, label: 'x'));
      expect(tester.getSize(find.byType(AvatarInisial)), const Size(36, 36));
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('huruf', () {
    testWidgets('inisial panjang di 36 dp x 1,3 mengecil, tidak meluap', (
      tester,
    ) async {
      await pasang(
        tester,
        _a(ukuran: UkuranAvatarInisial.kecil, inisial: 'WWW'),
        skala: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(AvatarInisial)),
        Size.square(UkuranLanjutBiruAwan.avatarKecil),
      );
    });

    testWidgets('320 dp x huruf 1,3: tumpukan tanpa luapan', (tester) async {
      await periksaSkala13(
        tester,
        Row(
          children: [
            for (final u in UkuranAvatarInisial.values)
              AvatarInisial(inisial: 'MD', ukuran: u),
          ],
        ),
      );
    });
  });
}
