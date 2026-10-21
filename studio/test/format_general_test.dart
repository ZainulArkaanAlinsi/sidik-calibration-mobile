import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_studio/data/workbook_model.dart';
import 'package:sidik_studio/l10n/studio_l10n.dart';
import 'package:sidik_studio/tema/tema_studio.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

import 'pembantu/studio_uji.dart';

/// Format angka "General" Excel di grid Studio — KEBENARAN = Excel asli.
///
/// `test/fixtures/excel_general_text.json` dibuat
/// `tool/excel_general_fixture.ps1` dari Excel 365 lewat COM: angka
/// SINTETIS di banyak lebar kolom, dibaca `Range.Text` (teks tampil, termasuk
/// `####`) dan `Range.Formula` (bilah rumus). Fixture TIDAK disunting tangan
/// dan tidak disesuaikan agar test hijau.
///
/// Excel 365 di layar 150 % kadang menghitung lebar kolom pada 144 dpi,
/// kadang 96 dpi (tercatat `meta.dpi_excel`). Algoritma diuji dengan metrik
/// Calibri pada dpi YANG DIPAKAI Excel itu; grid Studio (1 dp = 1 px Excel
/// 100 %) diuji terhadap Excel 96 dpi.
void main() {
  final fx = _Fixture.muat();

  group('teksGeneral = Range.Text Excel', () {
    test('Calibri 11: setiap angka × setiap lebar kolom SAMA PERSIS', () {
      final m = fx.metrikExcel(11, false);
      final beda = <String>[];
      var jumlah = 0;
      for (final k in fx.kolom) {
        final ruang = fx.ruangExcel(k);
        for (final c in fx.kasus) {
          jumlah++;
          final hasil = teksGeneral(c.n, ruang, metrik: m);
          final excel = c.teks[k.kunci];
          if (hasil != excel) {
            beda.add(
              '${c.ekspresi} @${k.kunci}: Excel "$excel", Studio "$hasil"',
            );
          }
        }
      }
      debugPrint(
        'General Calibri 11 (dpi Excel ${fx.dpiExcel}): '
        '${jumlah - beda.length}/$jumlah cocok',
      );
      expect(jumlah, greaterThan(7000));
      expect(beda, isEmpty, reason: beda.take(30).join('\n'));
    });

    test('font sel selain 11 pt: Calibri 11 tebal persis; ukuran lain '
        'dilaporkan (metrik huruf Excel di luar 11 pt belum persis)', () {
      final bedaLain = <String>[];
      var jumlahLain = 0;
      for (final k in fx.kolomFont) {
        final m = fx.metrikExcel(k.ukuran!.round(), k.tebal);
        final ruang = fx.ruangExcel(k);
        for (final c in fx.kasusFont) {
          final hasil = teksGeneral(c.n, ruang, metrik: m);
          final excel = c.teks[k.kunci];
          if (k.ukuran == 11) {
            expect(hasil, excel, reason: '${c.ekspresi} @${k.kunci}');
            continue;
          }
          jumlahLain++;
          if (hasil != excel) {
            bedaLain.add(
              '${c.ekspresi} @${k.kunci}: Excel "$excel", '
              'Studio "$hasil"',
            );
          }
        }
      }
      debugPrint(
        'General font lain (dpi Excel ${fx.dpiExcel}): '
        '${jumlahLain - bedaLain.length}/$jumlahLain cocok\n'
        '${bedaLain.join('\n')}',
      );
      expect(
        jumlahLain - bedaLain.length,
        greaterThanOrEqualTo((jumlahLain * 0.95).ceil()),
        reason: bedaLain.join('\n'),
      );
    });

    test('contoh peninjau di kolom bawaan 8,43 (64 dp): 1/3 → 0.333333, '
        '123456.789… → 123456.8, 1.234E-5 → 1.23E-05', () {
      const ruang = lebarKolomBawaanDp - paddingSelExcel;
      expect(teksGeneral(1 / 3, ruang), '0.333333');
      expect(teksGeneral(123456.789012345678, ruang), '123456.8');
      expect(teksGeneral(1.234e-5, ruang), '1.23E-05');
      expect(teksGeneral(123456789012, ruang), '1.23E+11');
      expect(teksGeneral(-1 / 3, ruang), '-0.33333');
      expect(teksGeneral(1e20, 3 * 7.0), '###');
    });
  });

  test('bilah rumus = Range.Formula Excel (15 digit signifikan); nilai yang '
      'disimpan Excel = n persis', () {
    final beda = <String>[];
    for (final c in [...fx.kasus, ...fx.kasusFont]) {
      expect(c.tersimpan, c.n, reason: c.ekspresi);
      final hasil = teksBilahRumus(c.n);
      if (hasil != c.bilahRumus) {
        beda.add('${c.ekspresi}: Excel "${c.bilahRumus}", Studio "$hasil"');
      }
    }
    debugPrint(
      'Bilah rumus: ${fx.kasus.length + fx.kasusFont.length - beda.length}'
      '/${fx.kasus.length + fx.kasusFont.length} cocok',
    );
    expect(beda, isEmpty, reason: beda.join('\n'));
  });

  test('tabel metrik Calibri 96 dpi = hasil ukur GDI di fixture', () {
    expect(fx.calibri96, hasLength(38));
    for (final r in fx.calibri96) {
      expect(
        MetrikGeneral.calibri(r.pt.toDouble(), tebal: r.tebal),
        r.metrik,
        reason: '${r.pt} pt tebal=${r.tebal}',
      );
    }
    // Di luar tabel: diskalakan dari Calibri 11.
    expect(
      MetrikGeneral.calibri(33),
      const MetrikGeneral(digit: 21, minus: 15, pagar: 21),
    );
  });

  group('grid', () {
    setUpAll(muatFontStudio);

    testWidgets('sel General digambar dari n untuk lebar kolomnya = Excel '
        '96 dpi; teks Inter tidak keluar sel', (tester) async {
      final kolom = fx.kolom;
      final lebar = <int, double>{
        for (var i = 0; i < kolom.length; i++)
          i + 1: lebarKolomExcelKeDp(_lebarTersimpan96(kolom[i].diminta)),
      };
      final bedaExcel = <String>[];
      final bedaSnap = <String>[];
      var dibanding = 0;
      var lewatPadding = 0;
      var keluarSel = 0;

      // Per potongan baris: grid berukuran layar biasa, dibaca SEKALI per
      // potongan (bukan satu finder per sel).
      const potongan = 48;
      for (var awal = 0; awal < fx.kasus.length; awal += potongan) {
        final kasus = fx.kasus.skip(awal).take(potongan).toList();
        final isi = <AlamatSel, SelGrid>{
          for (var r = 0; r < kasus.length; r++)
            for (var c = 0; c < kolom.length; c++)
              AlamatSel(r + 1, c + 1): SelGrid(
                // `s` server: TIDAK boleh tampil untuk sel General.
                teks: 'S${kasus[r].n}',
                jenis: JenisSelGrid.angka,
                nilai: kasus[r].n,
                general: true,
              ),
        };
        await _pompaGrid(tester, kasus.length, kolom.length, lebar, isi);
        final tampil = _bacaGrid(tester);

        for (var c = 0; c < kolom.length; c++) {
          final dp = lebar[c + 1]!;
          // ColumnWidth yang Excel 96 dpi laporkan untuk kolom selebar dp.
          final cw96 = ((dp - paddingSelExcel) / 7 * 100).round() / 100;
          final sama = fx.dpiExcel == 96 || cw96 == kolom[c].columnWidth;
          for (var r = 0; r < kasus.length; r++) {
            final k = kasus[r];
            final t = tampil[AlamatSel(r + 1, c + 1)];
            final teks = t?.teks ?? '';
            // Grid = fungsi murni pada ruang sel ini (satu jalur).
            expect(
              teks,
              teksGeneral(k.n, dp - paddingSelExcel),
              reason: '${k.ekspresi} @${kolom[c].kunci}',
            );
            final excel = k.teks[kolom[c].kunci];
            dibanding++;
            if (teks != excel) {
              (sama ? bedaExcel : bedaSnap).add(
                '${k.ekspresi} @${kolom[c].kunci}: Excel "$excel", '
                'grid "$teks"',
              );
            }
            if (t != null && teks.isNotEmpty && !teks.startsWith('#')) {
              // Kotak Text = lebar teks + 1 dp, rata kanan, padding 2 dp.
              if (t.kotak.left < t.sel.left + 2 - 0.01) lewatPadding++;
              if (t.kotak.left < t.sel.left - 0.01) keluarSel++;
            }
          }
        }
      }
      debugPrint(
        'Grid vs Excel: ${dibanding - bedaExcel.length - bedaSnap.length}'
        '/$dibanding cocok; beda karena Excel ${fx.dpiExcel} dpi membulatkan '
        'lebar kolom pecahan lain: ${bedaSnap.length}; teks Inter memakan '
        'padding kiri: $lewatPadding; keluar sel: $keluarSel\n'
        '${bedaSnap.join('\n')}',
      );
      expect(dibanding, fx.kasus.length * kolom.length);
      expect(bedaExcel, isEmpty, reason: bedaExcel.take(30).join('\n'));
      // Beda pembulatan dpi hanya diketahui untuk lebar 4.6 dan 7.6 (64 kasus
      // pada fixture 144 dpi). Lebih dari itu berarti regresi yang tersembunyi.
      expect(bedaSnap.length, lessThanOrEqualTo(64),
          reason: bedaSnap.take(30).join('\n'));
      expect(keluarSel, 0);
    });
  });

  group('kapan General ditiru (SelWorkbook.keGrid)', () {
    SelGrid grid(Map<String, Object?> j, {bool tiru = true}) =>
        SelWorkbook.fromJson({'b': 1, 'k': 1, ...j}).keGrid(tiruGeneral: tiru);

    test('xlsm: angka tanpa format (f null / "General") & hasil rumus '
        'berangka → general, nilai = n', () {
      final a = grid({'t': 'n', 'n': 0.1 + 0.2, 's': '0.3', 'f': null});
      expect(a.general, isTrue);
      expect(a.nilai, 0.1 + 0.2);
      expect(
        grid({'t': 'n', 'n': 1, 's': '1', 'f': 'General'}).general,
        isTrue,
      );
      expect(
        grid({'t': 'f', 'n': 2.5, 's': '2.5', 'r': '=A2/2'}).general,
        isTrue,
      );
    });

    test('format eksplisit, teks, logika, galat, CSV → BUKAN general '
        '(teks `s` server dipakai apa adanya)', () {
      expect(
        grid({'t': 'n', 'n': 0.127, 's': '0.127', 'f': '0.000'}).general,
        isFalse,
      );
      expect(grid({'t': 's', 's': 'Satuan'}).general, isFalse);
      expect(grid({'t': 'b', 's': 'TRUE'}).general, isFalse);
      expect(grid({'t': 'e', 's': '#DIV/0!'}).general, isFalse);
      // Sel CSV: `s` = teks hasil format Excel saat ekspor (mis. 0.0010).
      final csv = grid({'t': 'n', 'n': 0.001, 's': '0.0010'}, tiru: false);
      expect(csv.general, isFalse);
      expect(csv.teks, '0.0010');
    });

    test(
      'halaman: cache bentuk grid ikut berganti bila tiruGeneral berubah',
      () {
        final h = HalamanSelWorkbook.fromJson({
          'baris_dari': 1,
          'baris_sampai': 1,
          'jumlah_baris': 1,
          'sel': [
            {'b': 1, 'k': 1, 't': 'n', 'n': 1 / 3, 's': '0.33333333333333'},
          ],
        });
        expect(h.selGrid(1, 1, tiruGeneral: true).general, isTrue);
        expect(h.selGrid(1, 1).general, isFalse);
      },
    );
  });
}

// ─────────────────────────────────────────────────────────────── pembantu

/// `<col width>` yang Excel 96 dpi simpan untuk lebar [karakter] (ECMA-376
/// §18.3.1.13, MDW 7 px, padding 5 px).
double _lebarTersimpan96(double karakter) =>
    ((karakter * 7 + 5) / 7 * 256).truncate() / 256;

/// Teks tiap sel grid + kotak sel & kotak Text-nya (koordinat global),
/// dibaca dalam SATU penelusuran pohon.
Map<AlamatSel, ({String teks, Rect sel, Rect kotak})> _bacaGrid(
  WidgetTester tester,
) {
  Rect kotak(Element e) {
    final r = e.findRenderObject()! as RenderBox;
    return MatrixUtils.transformRect(
      r.getTransformTo(null),
      Offset.zero & r.size,
    );
  }

  final hasil = <AlamatSel, ({String teks, Rect sel, Rect kotak})>{};
  for (final e in find.byType(Text).evaluate()) {
    Element? sel;
    e.visitAncestorElements((a) {
      final k = a.widget.key;
      if (k is ValueKey<String> && k.value.startsWith('sel-')) {
        sel = a;
        return false;
      }
      return true;
    });
    final s = sel;
    if (s == null) continue;
    final alamat = AlamatSel.urai(
      (s.widget.key! as ValueKey<String>).value.substring(4),
    )!;
    hasil[alamat] = (
      teks: (e.widget as Text).data ?? '',
      sel: kotak(s),
      kotak: kotak(e),
    );
  }
  return hasil;
}

Future<void> _pompaGrid(
  WidgetTester tester,
  int baris,
  int kolom,
  Map<int, double> lebar,
  Map<AlamatSel, SelGrid> isi,
) async {
  final total = lebar.values.fold<double>(0, (a, b) => a + b);
  tester.view.physicalSize = Size(total + 120, baris * 20 + 160);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SelGrid? baca(WidgetRef _, int b, int k) =>
      isi[AlamatSel(b, k)] ?? SelGrid.kosong;

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: TemaStudio.terang,
        locale: const Locale('id'),
        localizationsDelegates: StudioL10n.localizationsDelegates,
        supportedLocales: StudioL10n.supportedLocales,
        home: Scaffold(
          body: GridSel(
            jumlahBaris: baris,
            jumlahKolom: kolom,
            tataLetak: TataLetakGrid(lebarKolom: lebar),
            kendali: KendaliGridSel(awal: AlamatSel(baris, kolom)),
            selTonton: baca,
            selBaca: baca,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Kolom {
  _Kolom(Map<String, dynamic> j)
    : kunci = j['kunci'] as String,
      diminta = (j['diminta'] as num).toDouble(),
      columnWidth = (j['column_width'] as num).toDouble(),
      ukuran = (j['ukuran'] as num?)?.toDouble(),
      tebal = j['tebal'] == true;

  final String kunci;
  final double diminta;

  /// `ColumnWidth` yang Excel laporkan setelah disetel (sudah dibulatkan ke
  /// piksel pada dpi Excel).
  final double columnWidth;
  final double? ukuran;
  final bool tebal;
}

class _Kasus {
  _Kasus(Map<String, dynamic> j)
    : ekspresi = j['ekspresi'] as String,
      n = (j['n'] as num).toDouble(),
      tersimpan = (j['tersimpan'] as num?)?.toDouble(),
      bilahRumus = j['bilah_rumus'] as String,
      teks = (j['teks'] as Map).cast<String, String>();

  final String ekspresi;
  final double n;
  final double? tersimpan;
  final String bilahRumus;
  final Map<String, String> teks;
}

class _Calibri {
  _Calibri(Map<String, dynamic> j)
    : pt = j['pt'] as int,
      tebal = j['tebal'] == true,
      metrik = MetrikGeneral(
        digit: (j['digit'] as num).toDouble(),
        minus: (j['minus'] as num).toDouble(),
        pagar: (j['pagar'] as num).toDouble(),
      );

  final int pt;
  final bool tebal;
  final MetrikGeneral metrik;
}

class _Fixture {
  _Fixture._(Map<String, dynamic> j)
    : dpiExcel = (j['meta']['dpi_excel'] as num).toDouble(),
      mdwExcel = (j['meta']['mdw_excel_px'] as num).toDouble(),
      kolom = [for (final k in j['kolom'] as List) _Kolom(k)],
      kasus = [for (final k in j['kasus'] as List) _Kasus(k)],
      kolomFont = [for (final k in j['kolom_font'] as List) _Kolom(k)],
      kasusFont = [for (final k in j['kasus_font'] as List) _Kasus(k)],
      calibri96 = [for (final k in j['calibri_gdi_96dpi'] as List) _Calibri(k)],
      calibriExcel = [
        for (final k in j['calibri_gdi_excel'] as List) _Calibri(k),
      ];

  factory _Fixture.muat() => _Fixture._(
    jsonDecode(File('test/fixtures/excel_general_text.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  final double dpiExcel;
  final double mdwExcel;
  final List<_Kolom> kolom;
  final List<_Kasus> kasus;
  final List<_Kolom> kolomFont;
  final List<_Kasus> kasusFont;
  final List<_Calibri> calibri96;
  final List<_Calibri> calibriExcel;

  /// Ruang teks sel (px pada dpi Excel): `ColumnWidth` × MDW font Normal.
  double ruangExcel(_Kolom k) => (k.columnWidth * mdwExcel).roundToDouble();

  MetrikGeneral metrikExcel(int pt, bool tebal) =>
      calibriExcel.firstWhere((c) => c.pt == pt && c.tebal == tebal).metrik;
}
