import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_studio/tema/font_studio.dart';
import 'package:sidik_studio/tema/tema_studio.dart';
import 'package:sidik_studio/tema/warna_studio.dart';

/// Desain sistem Studio: kontras token (WCAG 2.1 AA), font dari paket
/// bersama, dan jembatan `SidikMaterial` untuk layar bersama.
///
/// Sumber ambang: WCAG 2.1 SC 1.4.3 (teks ≥ 4,5:1) dan SC 1.4.11 (komponen
/// non-teks ≥ 3:1). Rumus luminans = `Color.computeLuminance` (sRGB relatif,
/// definisi WCAG).
void main() {
  double kontras(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final terang = la > lb ? la : lb;
    final gelap = la > lb ? lb : la;
    return (terang + 0.05) / (gelap + 0.05);
  }

  for (final (nama, w) in [
    ('terang', WarnaStudio.terangBawaan),
    ('gelap', WarnaStudio.gelapBawaan),
  ]) {
    group('kontras $nama', () {
      final teks = {
        'teks': w.teks,
        'teks2': w.teks2,
        'teksRedup': w.teksRedup,
        'aksenTeks': w.aksenTeks,
        'lulus': w.lulus,
        'gagal': w.gagal,
        'awas': w.awas,
        'info': w.info,
      };
      final latar = {
        'permukaan': w.permukaan,
        'latar': w.latar,
        'permukaanRendah': w.permukaanRendah,
      };

      test('teks konten ≥ 4,5:1 di tiap permukaan', () {
        for (final t in teks.entries) {
          for (final l in latar.entries) {
            expect(
              kontras(t.value, l.value),
              greaterThanOrEqualTo(4.5),
              reason: '${t.key} di ${l.key}',
            );
          }
        }
      });

      test('teks sisi (sidebar/rail/drawer) ≥ 4,5:1', () {
        for (final l in [w.sisi, w.sisiAktif]) {
          expect(kontras(w.sisiTeks, l), greaterThanOrEqualTo(4.5));
          expect(kontras(w.sisiTeksRedup, l), greaterThanOrEqualTo(4.5));
        }
      });

      test('teks di atas warna isi ≥ 4,5:1', () {
        expect(kontras(w.diAtasPrimer, w.primer), greaterThanOrEqualTo(4.5));
        expect(kontras(w.diAtasAksen, w.aksen), greaterThanOrEqualTo(4.5));
        expect(kontras(w.teks, w.aksenTipis), greaterThanOrEqualTo(4.5));
        expect(kontras(w.gagal, w.gagalTipis), greaterThanOrEqualTo(4.5));
        expect(kontras(w.lulus, w.lulusTipis), greaterThanOrEqualTo(4.5));
        expect(kontras(w.awas, w.awasTipis), greaterThanOrEqualTo(4.5));
      });

      test('garis kontrol (isian, tombol garis) ≥ 3:1', () {
        expect(kontras(w.garisKuat, w.permukaan), greaterThanOrEqualTo(3));
      });
    });
  }

  group('tema', () {
    test('font teks & angka berasal dari paket sidik_calibration', () {
      final t = TemaStudio.bangun(WarnaStudio.terangBawaan);
      expect(t.textTheme.bodyMedium?.fontFamily, FontStudio.inter);
      expect(FontStudio.inter, 'packages/sidik_calibration/Inter');
      expect(
        TipografiStudio.angka().fontFamily,
        'packages/sidik_calibration/IBMPlexMono',
      );
    });

    test('layar bersama mendapat SidikMaterial versi Studio, rata', () {
      for (final w in [WarnaStudio.terangBawaan, WarnaStudio.gelapBawaan]) {
        final m = TemaStudio.bangun(w).extension<SidikMaterial>();
        expect(m, isNotNull);
        // Bukan kertas krem app lapangan.
        expect(m!.kertas, w.permukaan);
        expect(m.tinta, w.teks);
        expect(m.kertas, isNot(SidikMaterial.terangDefault.kertas));
        // Logam rata: tanpa gradien.
        expect(m.logamAtas, m.logamBawah);
      }
    });

    test('terang & gelap memakai token yang benar', () {
      expect(TemaStudio.terang.brightness, Brightness.light);
      expect(TemaStudio.gelap.brightness, Brightness.dark);
      expect(
        TemaStudio.terang.extension<WarnaStudio>(),
        WarnaStudio.terangBawaan,
      );
    });
  });

  group('font paket', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Bukti berkasnya benar-benar ada di bundel (bukan cuma namanya ditulis):
    // aset `packages/sidik_calibration/assets/fonts/*.ttf` dimuat dari
    // rootBundle yang sama dengan aplikasinya.
    test('8 berkas Inter & IBM Plex Mono termuat dari bundel paket', () async {
      expect(await daftarkanAliasFont(), 8);
    });
  });
}
