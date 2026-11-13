import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_colors.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/sidik_theme.dart';
import 'package:sidik_calibration/widgets/sidik/sidik_tombol.dart';

/// Gerbang desain Lab, bagian 2: KONTRAS pasangan token (WCAG 2.x).
///
/// Dua lapis. Lapis pertama menguji token mentah `SidikMaterial` (tinta di atas
/// kertas, status di atas dasar tipisnya, dan seterusnya). Lapis kedua menguji
/// apa yang BENAR-BENAR dipakai widget: `ThemeData` yang dibangun `SidikTheme`
/// (skema warna, tombol, isian, navigasi, chip, snack) dan tombol utama yang
/// digambar `SidikTombol`. Lapis kedua ada karena tes lama hanya melihat token
/// dan kelewatan dua hal: `colorScheme.primary` yang dipakai layar sebagai
/// warna TEKS judul (1,91:1 di tema gelap) dan placeholder isian (3,68:1).
///
/// Ambang: teks biasa 4,5:1; komponen UI (tepi isian, ikon penting, isi tombol
/// terhadap latarnya) 3:1. Garis halus `kertasTepi`/`garis` sengaja TIDAK diuji:
/// itu hiasan pemisah, tidak boleh membawa makna sendiri.
///
/// Kalau ada warna digeser dan tes ini berteriak: betulkan warnanya. Jangan
/// menurunkan ambang.
void main() {
  const ambangTeks = 4.5;
  const ambangKomponen = 3.0;

  for (final (nama, tema, m) in <(String, ThemeData, SidikMaterial)>[
    ('terang', SidikTheme.terang, SidikMaterial.terangDefault),
    ('gelap', SidikTheme.gelap, SidikMaterial.gelapDefault),
  ]) {
    final s = tema.colorScheme;

    void cek(String apa, Color depan, Color belakang, {double? ambang}) {
      final batas = ambang ?? ambangTeks;
      final r = _rasio(depan, belakang);
      expect(
        r,
        greaterThanOrEqualTo(batas),
        reason:
            '$apa di tema $nama cuma ${r.toStringAsFixed(2)}:1 '
            '(minimal $batas:1)',
      );
    }

    void cekUi(String apa, Color depan, Color belakang) =>
        cek(apa, depan, belakang, ambang: ambangKomponen);

    group('kontras token mentah, tema $nama', () {
      test('tinta di atas kertas, baki, dan meja', () {
        cek('tinta/kertas', m.tinta, m.kertas);
        cek('tinta/baki', m.tinta, m.kertas2);
        cek('tinta/meja', m.tinta, m.meja);
        cek('tinta sekunder/kertas', m.tinta2, m.kertas);
        cek('tinta sekunder/baki', m.tinta2, m.kertas2);
      });

      test('keterangan yang jatuh langsung di atas MEJA juga harus lolos', () {
        // Sebagian layar menaruh keterangan di luar kartu (catatan di bawah
        // daftar), jadi dia mendarat di meja, bukan di kertas.
        cek('tinta sekunder/meja', m.tinta2, m.meja);
        cek('tinta sekunder/meja-2', m.tinta2, m.meja2);
        cek('tinta/meja-2', m.tinta, m.meja2);
      });

      test('label di app bar dan panel kebaca di semua nada panel', () {
        cek('etsa/logam', m.etsa, m.logam);
        cek('etsa/logam atas', m.etsa, m.logamAtas);
        cek('etsa/logam bawah', m.etsa, m.logamBawah);
      });

      test('pensil OCR tetap kebaca: ini angka ukur, bukan hiasan', () {
        cek('pensil/kertas', m.pensil, m.kertas);
        cek('pensil/baki', m.pensil, m.kertas2);
        // Sel OCR digambar di atas dasar amber, bukan kertas polos.
        cek('pensil/dasar amber', m.pensil, m.awasTipis);
      });

      test('warna interaktif', () {
        cek('biru tinta/kertas', m.biruTinta, m.kertas);
        cek('biru tinta/baki', m.biruTinta, m.kertas2);
        cek('biru tinta/meja', m.biruTinta, m.meja);
        cek('biru tinta/biru tipis', m.biruTinta, m.biruTipis);
        cek('tinta/biru tipis', m.tinta, m.biruTipis);
      });

      test('empat nada status di atas dasar tipisnya masing-masing', () {
        cek('lulus', m.lulus, m.lulusTipis);
        cek('gagal', m.gagal, m.gagalTipis);
        cek('awas', m.awas, m.awasTipis);
        cek('tunggu', m.tunggu, m.tungguTipis);
      });

      test(
        'nada status juga kebaca langsung di atas kertas, baki, dan meja',
        () {
          for (final (apa, latar) in [
            ('kertas', m.kertas),
            ('baki', m.kertas2),
            ('meja', m.meja),
          ]) {
            cek('lulus/$apa', m.lulus, latar);
            cek('gagal/$apa', m.gagal, latar);
            cek('awas/$apa', m.awas, latar);
            cek('tunggu/$apa', m.tunggu, latar);
          }
        },
      );

      test('angka LCD di layar kaca', () {
        cek('lcd hijau', m.lcdHijau, m.kaca);
        cek('lcd amber', m.lcdAmber, m.kaca);
        cek('teks kaca', m.lcdTeks, m.kaca);
      });

      test('lulus, gagal, dan awas beda terangnya, bukan cuma ronanya', () {
        // Hijau, merah, dan amber semuanya duduk di sumbu merah-hijau, sumbu
        // yang hilang buat mata deuteranopia dan buat fotokopi hitam-putih.
        // Jadi ketiganya wajib beda TERANGNYA (luminans relatif >= 0,02),
        // bukan cuma beda warnanya. `tunggu` dikecualikan: dia abu tanpa rona,
        // kebeda lewat kejenuhan, dan memaksanya ikut aturan ini mendorongnya
        // jadi nyaris putih ("menunggu" yang paling menyala itu salah arti).
        //
        // Pengaman utamanya tetap bukan warna: tiap lencana SELALU membawa
        // ikon + kata (diuji di `token_tema_lab_test.dart`). Aturan ini lapis
        // kedua. Amber sengaja berbeda dari milik Pelanggan (terang `#8C5C0A`,
        // gelap `#DB9A2B`) karena nilai Pelanggan gagal aturan ini.
        final berona = <String, double>{
          'lulus': _luminansi(m.lulus),
          'gagal': _luminansi(m.gagal),
          'awas': _luminansi(m.awas),
        };
        final kunci = berona.keys.toList();
        for (var a = 0; a < kunci.length; a++) {
          for (var b = a + 1; b < kunci.length; b++) {
            final beda = (berona[kunci[a]]! - berona[kunci[b]]!).abs();
            expect(
              beda,
              greaterThan(0.02),
              reason:
                  '${kunci[a]} dan ${kunci[b]} di tema $nama terangnya nyaris '
                  'sama (beda ${beda.toStringAsFixed(4)})',
            );
          }
        }
      });

      test('komponen: garis tegas dan biru terhadap latar yang dipakai', () {
        for (final (apa, latar) in [
          ('kertas', m.kertas),
          ('baki', m.kertas2),
          ('meja', m.meja),
        ]) {
          cekUi('garis tegas (logamTepi)/$apa', m.logamTepi, latar);
          cekUi('biru/$apa', m.biru, latar);
        }
      });
    });

    group('kontras dari ThemeData, tema $nama', () {
      final latar = tema.scaffoldBackgroundColor;
      final permukaan = <(String, Color)>[
        ('surface', s.surface),
        ('scaffold', latar),
        ('surfaceContainer', s.surfaceContainer),
        ('surfaceContainerHigh', s.surfaceContainerHigh),
        ('surfaceContainerHighest', s.surfaceContainerHighest),
      ];

      test('teks utama dan kedua di semua permukaan', () {
        for (final (apa, p) in permukaan) {
          cek('onSurface/$apa', s.onSurface, p);
          cek('onSurfaceVariant/$apa', s.onSurfaceVariant, p);
        }
      });

      test('primary sebagai TEKS/ikon (judul bagian, tautan, ikon aksen)', () {
        // 47 tempat memakai `colorScheme.primary` sebagai warna teks atau ikon.
        // Di tema gelap lama nilainya biru tombol (1,91:1 di kertas gelap).
        for (final (apa, p) in permukaan) {
          cek('primary/$apa', s.primary, p);
        }
        cek('primary/primaryContainer', s.primary, s.primaryContainer);
      });

      test('outline sebagai teks redup di kertas dan baki', () {
        // `outline` dipakai 22 tempat sebagai warna keterangan dan ikon redup.
        for (final (apa, p) in [
          ('surface', s.surface),
          ('surfaceContainer', s.surfaceContainer),
        ]) {
          cek('outline/$apa', s.outline, p);
        }
      });

      test('pasangan on* terhadap wadahnya', () {
        cek('onPrimary/primary', s.onPrimary, s.primary);
        cek(
          'onPrimaryContainer/primaryContainer',
          s.onPrimaryContainer,
          s.primaryContainer,
        );
        cek('onSecondary/secondary', s.onSecondary, s.secondary);
        cek(
          'onSecondaryContainer/secondaryContainer',
          s.onSecondaryContainer,
          s.secondaryContainer,
        );
        cek('onError/error', s.onError, s.error);
        cek(
          'onErrorContainer/errorContainer',
          s.onErrorContainer,
          s.errorContainer,
        );
        cek('error/surface', s.error, s.surface);
        cek('error/scaffold', s.error, latar);
        cek(
          'onInverseSurface/inverseSurface',
          s.onInverseSurface,
          s.inverseSurface,
        );
        cek(
          'inversePrimary/inverseSurface',
          s.inversePrimary,
          s.inverseSurface,
        );
      });

      test('tombol: label terhadap isinya', () {
        final isi = tema.filledButtonTheme.style!;
        cek(
          'label FilledButton',
          _w(isi.foregroundColor, 'foreground FilledButton'),
          _w(isi.backgroundColor, 'background FilledButton'),
        );

        final garis = tema.outlinedButtonTheme.style!;
        final isiGaris = garis.backgroundColor == null
            ? s.surface
            : _w(garis.backgroundColor, 'background OutlinedButton');
        cek(
          'label OutlinedButton',
          _w(garis.foregroundColor, 'foreground OutlinedButton'),
          isiGaris,
        );
        cekUi(
          'tepi OutlinedButton/latar',
          _tepi(garis.side, 'side OutlinedButton'),
          latar,
        );
        cekUi(
          'tepi OutlinedButton/permukaan',
          _tepi(garis.side, 'side OutlinedButton'),
          s.surface,
        );

        final teks = tema.textButtonTheme.style!;
        for (final (apa, p) in [('surface', s.surface), ('scaffold', latar)]) {
          cek(
            'label TextButton/$apa',
            _w(teks.foregroundColor, 'foreground TextButton'),
            p,
          );
        }
      });

      test('tombol isi terhadap latar (komponen UI 3:1)', () {
        final isi = _w(
          tema.filledButtonTheme.style!.backgroundColor,
          'background FilledButton',
        );
        cekUi('isi FilledButton/surface', isi, s.surface);
        cekUi('isi FilledButton/scaffold', isi, latar);
      });

      test('isian: placeholder, label, bantuan, galat terhadap isiannya', () {
        final d = tema.inputDecorationTheme;
        final isi = d.fillColor!;
        cek('hint', _gaya(d.hintStyle, 'hintStyle'), isi);
        cek('label', _gaya(d.labelStyle, 'labelStyle'), isi);
        cek('helper', _gaya(d.helperStyle, 'helperStyle'), isi);
        cek('error', _gaya(d.errorStyle, 'errorStyle'), isi);
        // Placeholder juga bisa mendarat di atas permukaan lain.
        cek('hint/surface', _gaya(d.hintStyle, 'hintStyle'), s.surface);
      });

      test('isian: tepi dan fokus terhadap isian dan permukaan (3:1)', () {
        final d = tema.inputDecorationTheme;
        final isi = d.fillColor!;
        for (final (apa, b) in [
          ('enabled', d.enabledBorder),
          ('focused', d.focusedBorder),
          ('error', d.errorBorder),
        ]) {
          final warna = b!.borderSide.color;
          cekUi('tepi $apa/isian', warna, isi);
          cekUi('tepi $apa/surface', warna, s.surface);
        }
        cekUi(
          'tepi enabled/scaffold',
          d.enabledBorder!.borderSide.color,
          latar,
        );
      });

      test('app bar: judul dan ikon terhadap latarnya', () {
        final a = tema.appBarTheme;
        final bg = a.backgroundColor!;
        cek('foreground', a.foregroundColor!, bg);
        cek('judul', a.titleTextStyle!.color!, bg);
        cek('ikon', a.iconTheme!.color!, bg);
      });

      test('navigasi bawah dan rail: label serta ikon', () {
        final n = tema.navigationBarTheme;
        final bg = n.backgroundColor!;
        final indikator = n.indicatorColor!;
        for (final terpilih in [false, true]) {
          final k = terpilih
              ? <WidgetState>{WidgetState.selected}
              : <WidgetState>{};
          final apa = terpilih ? 'terpilih' : 'biasa';
          final labelGaya = n.labelTextStyle!.resolve(k)!;
          cek('label nav $apa', labelGaya.color!, terpilih ? indikator : bg);
          cekUi(
            'ikon nav $apa',
            n.iconTheme!.resolve(k)!.color!,
            terpilih ? indikator : bg,
          );
        }

        final r = tema.navigationRailTheme;
        final rbg = r.backgroundColor!;
        final rIndikator = r.indicatorColor ?? s.secondaryContainer;
        cek('label rail biasa', r.unselectedLabelTextStyle!.color!, rbg);
        cek('label rail terpilih', r.selectedLabelTextStyle!.color!, rbg);
        cekUi('ikon rail biasa', r.unselectedIconTheme!.color!, rbg);
        cekUi('ikon rail terpilih', r.selectedIconTheme!.color!, rIndikator);
      });

      test('chip: label terhadap isi, tepi terhadap latar', () {
        final c = tema.chipTheme;
        const terpilih = <WidgetState>{WidgetState.selected};
        cek(
          'label chip',
          _dariState(c.labelStyle!.color, {}),
          c.backgroundColor!,
        );
        cek(
          'label chip terpilih',
          _dariState(c.labelStyle!.color, terpilih),
          c.selectedColor!,
        );
        cek(
          'label chip terpilih (secondary)',
          c.secondaryLabelStyle!.color!,
          c.selectedColor!,
        );
        cek('tanda centang chip terpilih', c.checkmarkColor!, c.selectedColor!);
        cekUi('tepi chip/surface', c.side!.color, s.surface);
        cekUi('tepi chip/scaffold', c.side!.color, latar);
      });

      test('snack bar dan tooltip', () {
        final sb = tema.snackBarTheme;
        cek('teks snack', sb.contentTextStyle!.color!, sb.backgroundColor!);
        cek('aksi snack', sb.actionTextColor!, sb.backgroundColor!);
        final tt = tema.tooltipTheme;
        final tipBg = (tt.decoration! as BoxDecoration).color!;
        cek('tooltip', tt.textStyle!.color!, tipBg);
      });

      test('sakelar, kotak centang, radio, progres (komponen UI 3:1)', () {
        final sw = tema.switchTheme;
        const hidup = <WidgetState>{WidgetState.selected};
        const mati = <WidgetState>{};
        cekUi(
          'sakelar hidup: ibu jari/jalur',
          sw.thumbColor!.resolve(hidup)!,
          sw.trackColor!.resolve(hidup)!,
        );
        cekUi(
          'sakelar hidup: jalur/surface',
          sw.trackColor!.resolve(hidup)!,
          s.surface,
        );
        cekUi(
          'sakelar mati: ibu jari/jalur',
          sw.thumbColor!.resolve(mati)!,
          sw.trackColor!.resolve(mati)!,
        );
        cekUi(
          'sakelar mati: tepi jalur/surface',
          sw.trackOutlineColor!.resolve(mati)!,
          s.surface,
        );

        final cb = tema.checkboxTheme;
        cekUi('kotak centang: tepi/surface', cb.side!.color, s.surface);
        cekUi(
          'kotak centang terpilih: isi/surface',
          cb.fillColor!.resolve(hidup)!,
          s.surface,
        );
        cekUi(
          'kotak centang terpilih: tanda/isi',
          cb.checkColor!.resolve(hidup)!,
          cb.fillColor!.resolve(hidup)!,
        );
        cekUi(
          'radio terpilih/surface',
          tema.radioTheme.fillColor!.resolve(hidup)!,
          s.surface,
        );
        cekUi(
          'radio biasa/surface',
          tema.radioTheme.fillColor!.resolve(mati)!,
          s.surface,
        );

        final p = tema.progressIndicatorTheme;
        cekUi('progres/jalur', p.color!, p.linearTrackColor!);
        cekUi('progres/surface', p.color!, s.surface);
      });
    });
  }

  group('AppColors tetap selaras dengan SidikMaterial', () {
    // Docblock `app_colors.dart`: "Kalau salah satu digeser, geser dua-duanya."
    // 137 pemanggilan `AppColors.xxx` memakai salinan ini.
    final t = SidikMaterial.terangDefault;
    final g = SidikMaterial.gelapDefault;

    test('terang', () {
      expect(AppColors.ink, t.tinta);
      expect(AppColors.textMuted, t.tinta2);
      expect(AppColors.ivory, t.meja);
      expect(AppColors.white, t.kertas);
      expect(AppColors.ivoryDim, t.kertas2);
      expect(AppColors.hairline, t.kertasTepi);
      expect(AppColors.cobalt, t.biru);
      expect(AppColors.cobaltSoft, t.biruTipis);
      expect(AppColors.success, t.lulus);
      expect(AppColors.mintSoft, t.lulusTipis);
      expect(AppColors.danger, t.gagal);
      expect(AppColors.crimsonSoft, t.gagalTipis);
      expect(AppColors.warning, t.awas);
      expect(AppColors.info, t.tunggu);
    });

    test('gelap', () {
      expect(AppColors.inkDeep, g.meja);
      expect(AppColors.inkSurface, g.kertas);
      expect(AppColors.inkOutline, g.kertasTepi);
      expect(AppColors.inkTextMuted, g.tinta2);
      expect(AppColors.cobaltLight, g.biruTinta);
      expect(AppColors.successDark, g.lulus);
      expect(AppColors.dangerDark, g.gagal);
      expect(AppColors.warningDark, g.awas);
      expect(AppColors.infoDark, g.tunggu);
    });

    test('teks AppColors terbaca di permukaannya sendiri', () {
      void cek(String apa, Color a, Color b) => expect(
        _rasio(a, b),
        greaterThanOrEqualTo(4.5),
        reason: '$apa cuma ${_rasio(a, b).toStringAsFixed(2)}:1',
      );
      for (final (apa, tinta) in [
        ('ink', AppColors.ink),
        ('textMuted', AppColors.textMuted),
        ('success', AppColors.success),
        ('danger', AppColors.danger),
        ('warning', AppColors.warning),
        ('info', AppColors.info),
        ('cobalt', AppColors.cobalt),
      ]) {
        cek('$apa/white', tinta, AppColors.white);
        cek('$apa/ivory', tinta, AppColors.ivory);
      }
      for (final (apa, tinta) in [
        ('inkTextMuted', AppColors.inkTextMuted),
        ('successDark', AppColors.successDark),
        ('dangerDark', AppColors.dangerDark),
        ('warningDark', AppColors.warningDark),
        ('infoDark', AppColors.infoDark),
        ('cobaltLight', AppColors.cobaltLight),
        ('mint', AppColors.mint),
      ]) {
        cek('$apa/inkSurface', tinta, AppColors.inkSurface);
        cek('$apa/inkDeep', tinta, AppColors.inkDeep);
      }
    });
  });

  group('tombol utama SidikTombol: label terhadap isinya', () {
    for (final (nama, tema) in <(String, ThemeData)>[
      ('terang', SidikTheme.terang),
      ('gelap', SidikTheme.gelap),
    ]) {
      for (final ragam in [RagamTombol.utama, RagamTombol.bahaya]) {
        testWidgets('${ragam.name}, tema $nama', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: tema,
              home: Scaffold(
                body: Center(
                  child: SidikTombol(
                    label: 'Kirim ke admin',
                    ragam: ragam,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          );
          final teks = tester.widget<Text>(find.text('Kirim ke admin'));
          final hiasan =
              tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: find.byType(SidikTombol),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration;
          // Isi bisa warna rata atau gradien: yang dinilai yang paling ketat.
          final isi = hiasan.gradient is LinearGradient
              ? (hiasan.gradient! as LinearGradient).colors
              : [hiasan.color!];
          final label = teks.style!.color!;
          for (final warna in isi) {
            expect(
              _rasio(label, warna),
              greaterThanOrEqualTo(4.5),
              reason:
                  'label tombol ${ragam.name} di tema $nama cuma '
                  '${_rasio(label, warna).toStringAsFixed(2)}:1',
            );
          }
        });
      }
    }
  });

  test('tidak ada token yang lupa diisi antar-tema', () {
    // lerp harus menghasilkan nilai di antara keduanya, bukan melempar.
    final tengah = SidikMaterial.terangDefault.lerp(
      SidikMaterial.gelapDefault,
      0.5,
    );
    expect(tengah, isA<SidikMaterial>());
    expect(tengah.kertas, isNot(equals(SidikMaterial.terangDefault.kertas)));
  });
}

/// Warna dari `WidgetStateProperty` pada keadaan biasa (tanpa state).
Color _w(WidgetStateProperty<Color?>? p, String apa) {
  final warna = p?.resolve(const <WidgetState>{});
  expect(warna, isNotNull, reason: '$apa tidak diatur di tema');
  return warna!;
}

Color _tepi(WidgetStateProperty<BorderSide?>? p, String apa) {
  final sisi = p?.resolve(const <WidgetState>{});
  expect(sisi, isNotNull, reason: '$apa tidak diatur di tema');
  return sisi!.color;
}

/// Warna yang bisa berupa `WidgetStateColor`, dibaca pada keadaan [state].
Color _dariState(Color? warna, Set<WidgetState> state) {
  expect(warna, isNotNull);
  return WidgetStateProperty.resolveAs<Color>(warna!, state);
}

Color _gaya(TextStyle? g, String apa) {
  expect(g?.color, isNotNull, reason: '$apa tidak punya warna');
  return g!.color!;
}

double _luminansi(Color c) {
  double k(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * k(c.r) + 0.7152 * k(c.g) + 0.0722 * k(c.b);
}

/// Rasio kontras. Warna depan yang tembus pandang dicampur dulu ke latarnya.
double _rasio(Color depan, Color belakang) {
  final a = depan.a < 1 ? Color.alphaBlend(depan, belakang) : depan;
  final la = _luminansi(a);
  final lb = _luminansi(belakang);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
