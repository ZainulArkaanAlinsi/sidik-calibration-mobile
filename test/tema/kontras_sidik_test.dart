import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_calibration/core/theme/app_colors.dart';
import 'package:sidik_calibration/core/theme/palet_lab.dart';
import 'package:sidik_calibration/core/theme/sidik_material.dart';
import 'package:sidik_calibration/core/theme/sidik_theme.dart';
import 'package:sidik_calibration/core/theme/tema_beku.dart';
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
/// Biru Awan (L1b): lapis ketiga menghitung SETIAP pasangan di `DESIGN.md`
/// (tabel Warna) dari nilai `PaletLab`, dan dua pasangan yang DILARANG di sana
/// dijaga sebagai tes negatif (teks putih di atas langit 2,26:1; teks primer di
/// atas kabut 4,47:1). Tepi kontrol memakai `garisKontrol` (#7C8FA8, >= 3:1),
/// bukan #C5D5E6 milik `DESIGN.md` yang cuma ±1,5:1 di putih.
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
        // bukan cuma beda warnanya. `tunggu` dikecualikan: dia abu/biru tanpa
        // kejenuhan merah-hijau, dan memaksanya ikut aturan ini mendorongnya
        // jadi nyaris putih ("menunggu" yang paling menyala itu salah arti).
        //
        // REVISI 16 Nov 2026: status = tinta GELAP berwarna di atas isi MUDA
        // (hijau gelap, merah gelap, amber gelap). Isi mudanya nyaris sama
        // terang BY DESIGN; yang dibandingkan di dua tema adalah TINTA-nya.
        //
        // Pengaman utamanya tetap bukan warna: tiap lencana SELALU membawa
        // ikon + kata (diuji di `token_tema_lab_test.dart`). Aturan ini lapis
        // kedua, dan BUKAN bukti aksesibilitas sendirian: selisih 0,02 di
        // luminans (rasio ~1,2:1) tidak terbedakan di hitam-putih.
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
        // Di tema terang primer di atas KABUT cuma 4,47:1 (DILARANG di
        // `DESIGN.md`; tes negatifnya di bawah), jadi permukaan kabut
        // (`primaryContainer`, `surfaceContainerHighest`) dikecualikan: teks
        // biru di sana memakai `onPrimaryContainer`/`secondary` (primerTua),
        // diuji di bawah dan di 'pasangan on*'.
        final kabut = m.terang ? <Color>{m.biruTipis, m.meja2} : <Color>{};
        for (final (apa, p) in permukaan) {
          if (kabut.contains(p)) continue;
          cek('primary/$apa', s.primary, p);
        }
        if (!m.terang) {
          cek('primary/primaryContainer', s.primary, s.primaryContainer);
        }
        // Teks biru di atas kabut: primerTua / onPrimaryContainer / secondary.
        for (final (apa, p) in [
          ('primaryContainer', s.primaryContainer),
          ('surfaceContainerHighest', s.surfaceContainerHighest),
        ]) {
          cek('onPrimaryContainer/$apa', s.onPrimaryContainer, p);
          cek('secondary/$apa', s.secondary, p);
        }
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

  group('pasangan DESIGN.md (tabel Warna), dihitung dari PaletLab', () {
    // Angka di kolom "Kontras" `DESIGN.md` / `tokens.json`. Dihitung ulang dari
    // nilai warna: kalau salah satunya digeser (atau dokumennya salah ketik),
    // tes ini yang berteriak.
    final pasangan = <(String, Color, Color, double)>[
      ('putih/primer', PaletLab.kertas, PaletLab.primer, 5.47),
      ('putih/primerTua', PaletLab.kertas, PaletLab.primerTua, 8.18),
      ('navy/langit', PaletLab.tinta, PaletLab.langit, 6.48),
      ('navy/awan', PaletLab.tinta, PaletLab.awan, 9.69),
      ('navy/kabut', PaletLab.tinta, PaletLab.kabut, 13.08),
      ('primerTua/kabut', PaletLab.primerTua, PaletLab.kabut, 7.31),
      (
        'primer/kabut (teks, lolos tipis)',
        PaletLab.primer,
        PaletLab.kabut,
        4.89,
      ),
      ('navy/latar', PaletLab.tinta, PaletLab.latar, 13.63),
      ('navy/putih', PaletLab.tinta, PaletLab.kertas, 14.64),
      ('tinta2/kertas', PaletLab.tinta2, PaletLab.kertas, 6.09),
      ('tinta2/kabut', PaletLab.tinta2, PaletLab.kabut, 5.44),
      ('hijauTinta/hijau', PaletLab.hijauTinta, PaletLab.hijau, 8.59),
      ('kuningTinta/kuning', PaletLab.kuningTinta, PaletLab.kuning, 5.63),
      ('gagalTerang/koral', PaletLab.gagalTerang, PaletLab.koral, 6.22),
      (
        'biruKelabuTinta/biruKelabu',
        PaletLab.biruKelabuTinta,
        PaletLab.biruKelabu,
        10.77,
      ),
      (
        'putih/gagalTerang (tombol bahaya, lencana)',
        PaletLab.kertas,
        PaletLab.gagalTerang,
        7.32,
      ),
      (
        'tema gelap: teks di atas primer',
        PaletLab.teksDiAtasPrimerGelap,
        PaletLab.primerGelap,
        9.58,
      ),
    ];

    for (final (apa, depan, belakang, dokumen) in pasangan) {
      test(apa, () {
        expect(
          _rasio(depan, belakang),
          closeTo(dokumen, 0.02),
          reason: '$apa: DESIGN.md menulis $dokumen:1',
        );
      });
    }

    test('semua pasangan teks lolos 4,5:1; primer di atas putih juga', () {
      for (final (apa, depan, belakang, dokumen) in pasangan) {
        expect(
          _rasio(depan, belakang),
          greaterThanOrEqualTo(4.5),
          reason: '$apa ($dokumen:1)',
        );
      }
    });

    test('tema memakai pasangan itu: tombol utama putih di atas primer', () {
      final s = SidikTheme.terang.colorScheme;
      expect(s.primary, PaletLab.primer);
      expect(s.onPrimary, PaletLab.kertas);
      expect(s.onPrimaryContainer, PaletLab.primerTua);
      expect(s.primaryContainer, PaletLab.kabut);
      expect(SidikMaterial.terangDefault.lulusTipis, PaletLab.hijau);
      expect(SidikMaterial.terangDefault.awasTipis, PaletLab.kuning);
      expect(SidikMaterial.terangDefault.tungguTipis, PaletLab.biruKelabu);
      expect(SidikMaterial.terangDefault.gagalTipis, PaletLab.kabutGagal);
      // REVISI 16 Nov 2026: tinta status GELAP berwarna, bukan navy.
      expect(SidikMaterial.terangDefault.lulus, PaletLab.hijauTinta);
      expect(SidikMaterial.terangDefault.awas, PaletLab.kuningTinta);
      expect(SidikMaterial.terangDefault.tunggu, PaletLab.biruKelabuTinta);
      expect(SidikMaterial.terangDefault.gagal, PaletLab.gagalTerang);
    });

    test('palet REVISI 16 Nov 2026 dikunci literal', () {
      expect(PaletLab.latar, const Color(0xFFF4F7FB));
      expect(PaletLab.kertas, const Color(0xFFFFFFFF));
      expect(PaletLab.tinta, const Color(0xFF102A43));
      expect(PaletLab.tinta2, const Color(0xFF526477));
      expect(PaletLab.primer, const Color(0xFF1769C2));
      expect(PaletLab.kabut, const Color(0xFFEAF3FF));
      expect(PaletLab.garisHalus, const Color(0xFFDCE5EE));
      expect(PaletLab.hijau, const Color(0xFFE3F3E8));
      expect(PaletLab.kuning, const Color(0xFFFFF3D6));
      expect(PaletLab.koral, const Color(0xFFFDE8E6));
      expect(PaletLab.biruKelabu, const Color(0xFFE6F0FA));
    });
  });

  group('pasangan DILARANG di DESIGN.md (tes negatif)', () {
    // Dua pasangan yang `DESIGN.md` larang. Tes ini TIDAK menguji bahwa tema
    // menghindarinya lewat tampilan; ia mengunci bahwa angkanya memang di
    // bawah ambang, jadi tidak ada yang "memperbaiki" larangan itu dengan
    // menggeser warna diam-diam, dan teks yang butuh pasangan itu pakai
    // pengganti yang sah.
    test(
      'teks PUTIH di atas langit: 2,26:1, jauh di bawah 4,5:1 (juga 3:1)',
      () {
        final r = _rasio(PaletLab.kertas, PaletLab.langit);
        expect(r, closeTo(2.26, 0.02));
        expect(r, lessThan(3.0));
        // Pengganti yang sah: navy di atas langit.
        expect(
          _rasio(PaletLab.tinta, PaletLab.langit),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    test('teks PRIMER di atas kabut: 4,89:1 (revisi), lolos tipis; tema '
        'tetap memakai primerTua', () {
      // Primer revisi #1769C2 dan kabut #EAF3FF (dulu 4,47:1 gagal tipis).
      // Lolos 4,5:1 hanya dengan selisih 0,39: tema TETAP memakai primerTua
      // (7,31:1) untuk teks biru di atas kabut.
      final r = _rasio(PaletLab.primer, PaletLab.kabut);
      expect(r, closeTo(4.89, 0.02));
      expect(r, greaterThanOrEqualTo(4.5));
      // Yang dipakai tema: primerTua.
      expect(
        _rasio(PaletLab.primerTua, PaletLab.kabut),
        greaterThanOrEqualTo(4.5),
      );
      final m = SidikMaterial.terangDefault;
      expect(m.biruTinta, PaletLab.primerTua);
      expect(
        SidikTheme.terang.colorScheme.onPrimaryContainer,
        PaletLab.primerTua,
      );
      expect(SidikTheme.terang.colorScheme.secondary, PaletLab.primerTua);
    });
  });

  group('batas yang DIKETAHUI: garisKontrol di atas kabut dan kabutGagal', () {
    // Dicatat peninjau L1b (standar §11). Ini MENDOKUMENTASIKAN rasio
    // sebenarnya; ambang 3:1 di grup lain TIDAK dilonggarkan. Tes 3:1 hanya
    // menjaga kertas, baki (latar), dan meja; di atas kabut/kabutGagal tepi
    // kontrol terang jatuh di bawah 3:1 dan itu utang desain yang terdaftar.
    test('rasio sebenarnya: 2,95:1 di kabut, 2,81:1 di kabutGagal', () {
      final kabut = _rasio(PaletLab.garisKontrol, PaletLab.kabut);
      final gagal = _rasio(PaletLab.garisKontrol, PaletLab.kabutGagal);
      expect(kabut, closeTo(2.95, 0.01));
      expect(gagal, closeTo(2.81, 0.01));
      expect(kabut, lessThan(3.0));
      expect(gagal, lessThan(3.0));
      // Di atas putih tetap lolos; ini yang dijaga tes 3:1.
      expect(
        _rasio(PaletLab.garisKontrol, PaletLab.kertas),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('pemakai nyata: tepi segmen SegmentedButton terpilih (isi kabut)', () {
      // `sidik_theme.dart`: segmen terpilih berisi `biruTipis` (kabut) dan
      // bertepi `garisTegas` (= garisKontrol). Terpilih TIDAK hanya dibawa
      // tepi: isinya berubah dan Material memberi tanda centang.
      final seg = SidikTheme.terang.segmentedButtonTheme.style!;
      const terpilih = <WidgetState>{WidgetState.selected};
      expect(seg.backgroundColor!.resolve(terpilih), PaletLab.kabut);
      expect(seg.backgroundColor!.resolve(const {}), PaletLab.kertas);
      expect(seg.side!.resolve(terpilih)!.color, PaletLab.garisKontrol);
      expect(
        _rasio(seg.side!.resolve(terpilih)!.color, PaletLab.kabut),
        lessThan(3.0),
      );
    });

    test('tema gelap tidak kena: tepi kontrol >= 3:1 di kabut gelap', () {
      expect(
        _rasio(PaletLab.garisTegasGelap, PaletLab.kabutGelap),
        greaterThanOrEqualTo(3.0),
      );
      final seg = SidikTheme.gelap.segmentedButtonTheme.style!;
      const terpilih = <WidgetState>{WidgetState.selected};
      expect(seg.backgroundColor!.resolve(terpilih), PaletLab.kabutGelap);
    });
  });

  group('tepi kontrol: garisKontrol (#7C8FA8), bukan garisTegas (#C5D5E6)', () {
    // Keputusan L1b: `DESIGN.md` menulis tepi tombol/isian #C5D5E6, tetapi di
    // atas putih itu cuma ±1,5:1 (WCAG 1.4.11 minta 3:1). #C5D5E6 tetap ada
    // sebagai garis DEKORATIF; kontrol memakai #7C8FA8.
    test('angkanya dihitung, bukan diasumsikan', () {
      expect(_rasio(PaletLab.garisTegas, PaletLab.kertas), lessThan(3.0));
      for (final (apa, latar) in [
        ('kertas', PaletLab.kertas),
        ('latar', PaletLab.latar),
      ]) {
        expect(
          _rasio(PaletLab.garisKontrol, latar),
          greaterThanOrEqualTo(3.0),
          reason: 'garisKontrol/$apa',
        );
      }
      for (final (apa, latar) in [
        ('kertas gelap', PaletLab.kertasGelap),
        ('latar gelap', PaletLab.latarGelap),
        ('kabut gelap', PaletLab.kabutGelap),
      ]) {
        expect(
          _rasio(PaletLab.garisTegasGelap, latar),
          greaterThanOrEqualTo(3.0),
          reason: 'garisTegasGelap/$apa',
        );
      }
    });

    test(
      'tema memakainya di tombol sekunder, isian, chip, sakelar, centang',
      () {
        for (final (tema, kontrol) in [
          (SidikTheme.terang, PaletLab.garisKontrol),
          (SidikTheme.gelap, PaletLab.garisTegasGelap),
        ]) {
          BorderSide sisi(WidgetStateProperty<BorderSide?>? p) =>
              p!.resolve(const <WidgetState>{})!;
          expect(sisi(tema.outlinedButtonTheme.style!.side).color, kontrol);
          expect(
            tema.inputDecorationTheme.enabledBorder!.borderSide.color,
            kontrol,
          );
          expect(tema.chipTheme.side!.color, kontrol);
          expect(tema.checkboxTheme.side!.color, kontrol);
          expect(
            tema.switchTheme.trackOutlineColor!.resolve(const <WidgetState>{}),
            kontrol,
          );
          expect(tema.extension<SidikMaterial>()!.garisTegas, kontrol);
        }
        // Dan #C5D5E6 tidak dipakai kontrol mana pun.
        final t = SidikTheme.terang;
        expect(
          t.outlinedButtonTheme.style!.side!
              .resolve(const <WidgetState>{})!
              .color,
          isNot(PaletLab.garisTegas),
        );
      },
    );
  });

  group('AppColors tetap selaras dengan SidikMaterial milik TemaBeku', () {
    // Sejak L1a `AppColors` membaca `PaletBeku` (salinan beku palet Lab), jadi
    // pasangannya adalah `SidikMaterial` di tema beku, BUKAN `terangDefault` /
    // `gelapDefault` (yang ikut palet Lab saat palet itu diganti).
    // Docblock `app_colors.dart`: 138 pemanggilan `AppColors.xxx` memakai salinan ini.
    final t = TemaBeku.terang.extension<SidikMaterial>()!;
    final g = TemaBeku.gelap.extension<SidikMaterial>()!;

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
