import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_studio/l10n/studio_l10n.dart';
import 'package:sidik_studio/tema/tema_studio.dart';
import 'package:sidik_studio/tema/warna_studio.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';

import 'pembantu/studio_uji.dart';

/// Tahap A — grid "Asli Excel" HARUS tampil seperti Excel. Lembar sintetis
/// 14 × 10 (kolom bawaan 64 dp, baris 20 dp, padding teks 2 dp), satu
/// perilaku per baris:
///
/// | baris | perilaku |
/// |---|---|
/// | 1 | A1 teks panjang rata kiri → meluber ke B1, C1 |
/// | 2 | A2 teks panjang, B2 berisi → A2 dipotong, B2 tidak kena |
/// | 3 | E3 rata kanan → meluber ke KIRI (D3, C3) |
/// | 4 | E4 rata tengah → meluber ke dua arah |
/// | 5 | A5:B5 gabungan berteks panjang → tidak keluar gabungan |
/// | 6 | B6 angka tak muat → `########` |
/// | 7 | B7 "Wrap Text" → dibungkus, tidak meluber |
/// | 8 | C8 berisi warna → kisi di sekelilingnya hilang |
/// | 9 | B9 bergaris tepi → garis DI ATAS kisi |
/// | 10 | G10 teks panjang, H10 kosong BERGAYA → tetap dilintasi |
///
/// Pemeriksaan gambar memakai pencocok `paints` (urutan panggilan kanvas
/// satu sel) — bukan meniru implementasi: yang diperiksa adalah apa yang
/// SAMPAI ke kanvas (teks, garis kisi, garis tepi, isi).
void main() {
  setUpAll(muatFontStudio);

  group('teks meluber', () {
    testWidgets('rata kiri meluber ke kanan melintasi sel kosong; kisi di '
        'bawah teks hilang', (tester) async {
      await _pompa(tester);

      // Teks A1 diletakkan selebar ukurannya mulai padding 2 dp, melewati
      // tepi A1; A1 memotong miliknya sendiri.
      final rect = tester.getRect(_teksDi('A1', _panjangA1));
      final sel = tester.getRect(find.byKey(kunciSelGrid(_a('A1'))));
      expect(rect.left - sel.left, closeTo(2, 0.01));
      expect(rect.right, greaterThan(sel.right + 64));
      expect(_stack(tester, 'A1').clipBehavior, Clip.hardEdge);

      // B1 & C1 kosong → menggambar potongan teks A1 (paragraf).
      expect(_lukis(tester, 'B1'), paints..paragraph());
      expect(_lukis(tester, 'C1'), paints..paragraph());
      // D1 di luar jangkauan teks.
      expect(_lukis(tester, 'D1'), isNot(paints..paragraph()));

      // Kisi kanan A1 & B1 hilang (teks melintas); C1 tetap (teks berakhir
      // di dalam C1). Kisi bawah tetap ada.
      expect(_lukis(tester, 'A1'), isNot(_garis(p1: _kanan(0))));
      expect(_lukis(tester, 'B1'), isNot(_garis(p1: _kanan(0))));
      expect(_lukis(tester, 'C1'), _garis(warna: _kisi, p1: _kanan(0)));
      expect(_lukis(tester, 'B1'), _garis(warna: _kisi, p1: _bawah(0)));
    });

    testWidgets('berhenti di sel BERISI berikutnya: teks dipotong, tetangga '
        'cuma menggambar isinya sendiri', (tester) async {
      await _pompa(tester);
      expect(_stack(tester, 'A2').clipBehavior, Clip.hardEdge);
      // B2 berisi: satu paragraf saja (miliknya), bukan potongan A2.
      expect(_lukis(tester, 'B2'), paintsExactlyCountTimes(#drawParagraph, 1));
      expect(_lukis(tester, 'C2'), isNot(paints..paragraph()));
      // Kisi antara A2 & B2 tetap (teks tidak melintas).
      expect(_lukis(tester, 'A2'), _garis(warna: _kisi, p1: _kanan(0)));
    });

    testWidgets('rata kanan meluber ke KIRI; rata tengah ke DUA arah', (
      tester,
    ) async {
      await _pompa(tester);

      final e3 = tester.getRect(find.byKey(kunciSelGrid(_a('E3'))));
      final teksE3 = tester.getRect(_teksDi('E3', _panjangE3));
      expect(e3.right - teksE3.right, closeTo(2 - 1, 0.01)); // kotak + 1 dp
      expect(teksE3.left, lessThan(e3.left - 64));
      expect(_lukis(tester, 'D3'), paints..paragraph());
      expect(_lukis(tester, 'F3'), isNot(paints..paragraph()));

      final e4 = tester.getRect(find.byKey(kunciSelGrid(_a('E4'))));
      final teksE4 = tester.getRect(_teksDi('E4', _panjangE4));
      expect(
        (teksE4.left + teksE4.right - 1) / 2,
        closeTo((e4.left + e4.right) / 2, 0.6),
      );
      expect(_lukis(tester, 'D4'), paints..paragraph());
      expect(_lukis(tester, 'F4'), paints..paragraph());
    });

    testWidgets('teks di sel GABUNGAN tidak keluar gabungan; sel kosong '
        'bergaya tetap dilintasi', (tester) async {
      await _pompa(tester);
      // A5:B5 = 128 dp, dipotong di sana.
      expect(tester.getSize(find.byKey(kunciSelGrid(_a('A5')))).width, 128);
      expect(_stack(tester, 'A5').clipBehavior, Clip.hardEdge);
      expect(_lukis(tester, 'C5'), isNot(paints..paragraph()));

      // H10 kosong tapi bergaris: tetap kena luberan G10.
      expect(_lukis(tester, 'H10'), paints..paragraph());
    });
  });

  group('angka, bungkus, rumus', () {
    testWidgets('angka yang tak muat jadi #### (bukan meluber, bukan '
        'terpotong); yang muat tampil apa adanya', (tester) async {
      await _pompa(tester);
      expect(find.text('123456789.123'), findsNothing);
      expect(find.text('########'), findsOneWidget);
      expect(_lukis(tester, 'C6'), isNot(paints..paragraph()));
      expect(find.text('12345678'), findsOneWidget);
    });

    testWidgets('Wrap Text: dibungkus di dalam sel (lebih dari satu '
        'baris), tidak meluber', (tester) async {
      await _pompa(tester);
      final teks = tester.widget<Text>(find.text(_bungkus));
      expect(teks.softWrap, isTrue);
      expect(tester.getSize(find.text(_bungkus)).height, greaterThan(20));
      expect(tester.getSize(find.text(_bungkus)).width, lessThanOrEqualTo(60));
      expect(_lukis(tester, 'C7'), isNot(paints..paragraph()));
    });

    testWidgets('satu font untuk teks & angka (Inter, angka tabular); mono '
        'hanya di mode tampilkan rumus', (tester) async {
      final kendali = KendaliGridSel(awal: _a('J14'));
      await _pompa(tester, kendali: kendali);
      final angka = tester.widget<Text>(find.text('12345678'));
      final teks = tester.widget<Text>(find.text(_bungkus));
      expect(angka.style?.fontFamily, contains('Inter'));
      expect(teks.style?.fontFamily, contains('Inter'));
      expect(angka.style?.fontSize, ukuranFontExcelKeDp(ukuranFontBawaanPt));

      kendali.balikRumus();
      await tester.pumpAndSettle();
      final rumus = tester.widget<Text>(find.text('=B6*1'));
      expect(rumus.style?.fontFamily, contains('IBMPlexMono'));
    });
  });

  group('garis kisi, isi, garis tepi', () {
    testWidgets('isi warna menutup kisi sel itu DAN kisi tetangga yang '
        'berbatasan dengannya', (tester) async {
      await _pompa(tester);
      expect(
        _lukis(tester, 'C8'),
        paints..rect(color: const Color(0xFFFFF2CC)),
      );
      expect(_lukis(tester, 'C8'), isNot(_garis(warna: _kisi)));
      // B8 (kiri) kehilangan kisi kanannya; C7 (atas) kisi bawahnya.
      expect(_lukis(tester, 'B8'), isNot(_garis(p1: _kanan(0))));
      expect(_lukis(tester, 'B8'), _garis(warna: _kisi, p1: _bawah(0)));
      expect(_lukis(tester, 'C7'), isNot(_garis(p1: _bawah(0))));
    });

    testWidgets('garis tepi sel digambar DI ATAS kisi; garis kiri sel '
        'digambar tetangganya sebagai garis kanan', (tester) async {
      await _pompa(tester);
      expect(
        _lukis(tester, 'B9'),
        _garis(warna: _kisi, p1: _kanan(0), lalu: _hitam),
      );
      // A9 menggambar garis kiri B9 di tepi kanannya, juga di atas kisi.
      expect(
        _lukis(tester, 'A9'),
        _garis(warna: _kisi, p1: _kanan(0), lalu: _hitam),
      );
      // B9 TIDAK menggambar garis kirinya sendiri (dua garis berdempet).
      expect(
        _lukis(tester, 'B9'),
        isNot(_garis(warna: _hitam, p1: const Offset(0.5, 0))),
      );
    });

    testWidgets('garis_kisi = false: tanpa kisi sama sekali, garis tepi '
        'tetap', (tester) async {
      await _pompa(tester, garisKisi: false);
      expect(_lukis(tester, 'D8'), isNot(_garis()));
      expect(_lukis(tester, 'B9'), _garis(warna: _hitam));
      expect(_lukis(tester, 'B9'), isNot(_garis(warna: _kisi)));
    });

    testWidgets('di luar rentang terpakai: sel kosong berkisi sampai tepi '
        'layar, sumber TIDAK ditanya', (tester) async {
      final ditanya = <AlamatSel>{};
      await _pompa(tester, catat: ditanya);
      // Lembar 14 × 10 di layar 800 × 400 → kolom & baris tambahan.
      expect(find.byKey(kunciSelGrid(_a('L3'))), findsOneWidget);
      expect(find.byKey(kunciKepalaKolom(12)), findsOneWidget);
      expect(_lukis(tester, 'L3'), _garis(warna: _kisi));
      expect(
        ditanya.where((a) => a.baris > _baris || a.kolom > _kolom),
        isEmpty,
      );
    });
  });

  group('zoom', () {
    testWidgets('Ctrl+= / Ctrl+− / Ctrl+0 mengubah zoom; lebar kolom, '
        'tinggi baris, dan font ikut', (tester) async {
      final kendali = KendaliGridSel(awal: _a('J14'));
      await _pompa(tester, kendali: kendali);
      await tester.tap(find.byKey(kunciSelGrid(_a('J14'))));
      await tester.pump();

      await _ctrl(tester, LogicalKeyboardKey.equal);
      expect(kendali.zoom, 1.1);
      expect(
        tester.getSize(find.byKey(kunciSelGrid(_a('D1')))),
        const Size(70, 22),
      );
      expect(
        tester.widget<Text>(find.text('12345678')).style?.fontSize,
        closeTo(11 * 1.1, 0.001),
      );
      await _ctrl(tester, LogicalKeyboardKey.minus);
      await _ctrl(tester, LogicalKeyboardKey.minus);
      expect(kendali.zoom, 0.9);
      await _ctrl(tester, LogicalKeyboardKey.digit0);
      expect(kendali.zoom, 1.0);
      expect(
        tester.getSize(find.byKey(kunciSelGrid(_a('D1')))),
        const Size(64, 20),
      );
    });

    testWidgets('Ctrl+gulir mengubah zoom (lembar TIDAK ikut tergulir); '
        'gulir biasa menggulir', (tester) async {
      final kendali = KendaliGridSel(awal: _a('J14'));
      await _pompa(tester, kendali: kendali, baris: 80);
      final titik = tester.getCenter(find.byKey(kunciSelGrid(_a('D3'))));
      final penunjuk = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(penunjuk.hover(titik));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(penunjuk.scroll(const Offset(0, -40)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(kendali.zoom, 1.1);
      expect(find.byKey(kunciKepalaBaris(1)).hitTestable(), findsOneWidget);

      final y1 = tester.getTopLeft(find.byKey(kunciKepalaBaris(10))).dy;
      await tester.sendEventToBinding(penunjuk.scroll(const Offset(0, 60)));
      await tester.pumpAndSettle();
      expect(kendali.zoom, 1.1);
      expect(
        tester.getTopLeft(find.byKey(kunciKepalaBaris(10))).dy,
        lessThan(y1),
      );
    });

    testWidgets('pinch dua jari memperbesar (dijepit 200 %) & memperkecil', (
      tester,
    ) async {
      final kendali = KendaliGridSel(awal: _a('J14'));
      await _pompa(tester, kendali: kendali);
      final tengah = tester.getCenter(find.byType(GridSel));

      final j1 = await tester.startGesture(tengah - const Offset(20, 0));
      final j2 = await tester.startGesture(
        tengah + const Offset(20, 0),
        pointer: 7,
      );
      for (var i = 0; i < 6; i++) {
        await j1.moveBy(const Offset(-10, 0));
        await j2.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      // Jarak 40 → 160: ×4, dijepit 2,0.
      expect(kendali.zoom, 2.0);
      // Kembali sampai jarak 20 (lebih rapat dari awal 40) → ×0,5.
      for (var i = 0; i < 7; i++) {
        await j1.moveBy(const Offset(10, 0));
        await j2.moveBy(const Offset(-10, 0));
        await tester.pump();
      }
      await j1.up();
      await j2.up();
      await tester.pumpAndSettle();
      expect(kendali.zoom, lessThan(1.0));
    });

    testWidgets('pas lebar: semua kolom terpakai muat selebar grid', (
      tester,
    ) async {
      final kendali = KendaliGridSel(awal: _a('J14'));
      await _pompa(tester, kendali: kendali, kolom: 30);
      expect(kendali.bisaPasLebar, isTrue);
      kendali.pasLebar();
      await tester.pumpAndSettle();
      // 30 × 64 + kepala baris 32 = 1952 dp ke 800 dp → ±0,40 → dijepit 0,5.
      expect(kendali.zoom, 0.5);
      expect(find.byKey(kunciKepalaKolom(20)), findsOneWidget);
    });
  });

  group('golden', () {
    for (final (nama, tema, zoom) in [
      ('terang', TemaStudio.terang, 1.0),
      ('gelap', TemaStudio.gelap, 1.0),
      ('zoom150-terang', TemaStudio.terang, 1.5),
    ]) {
      testWidgets(
        'grid Excel — $nama',
        (tester) async {
          final kendali = KendaliGridSel(awal: _a('D9'))..aturZoom(zoom);
          await _pompa(tester, kendali: kendali, tema: tema);
          await expectLater(
            find.byType(GridSel),
            matchesGoldenFile('goldens/grid-excel-$nama.png'),
          );
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  });
}

// ─────────────────────────────────────────────────────────────── pembantu

const _baris = 14;
const _kolom = 10;

const _panjangA1 = 'Teks panjang yang meluber jauh';
const _panjangE3 = 'Rata kanan meluber ke kiri';
const _panjangE4 = 'Rata tengah ke dua arah ya';
const _bungkus = 'Teks dibungkus dua baris';

final _kisi = WarnaStudio.terangBawaan.garis;
const _hitam = Color(0xFF000000);

AlamatSel _a(String a1) => AlamatSel.urai(a1)!;

const _tipis = GarisSel(
  jenisAtas: JenisGaris.tipis,
  jenisKanan: JenisGaris.tipis,
  jenisBawah: JenisGaris.tipis,
  jenisKiri: JenisGaris.tipis,
);

final Map<AlamatSel, SelGrid> _isi = {
  _a('A1'): const SelGrid(teks: _panjangA1),
  _a('A2'): const SelGrid(teks: _panjangA1),
  _a('B2'): const SelGrid(teks: 'isi'),
  _a('E3'): const SelGrid(teks: _panjangE3, rata: TextAlign.right),
  _a('E4'): const SelGrid(teks: _panjangE4, rata: TextAlign.center),
  _a('A5'): const SelGrid(teks: '$_panjangA1 dalam gabungan'),
  _a('B6'): const SelGrid(
    teks: '123456789.123',
    rumus: '=B6*1',
    jenis: JenisSelGrid.angka,
  ),
  _a('D6'): const SelGrid(teks: '12345678', jenis: JenisSelGrid.angka),
  _a('B7'): const SelGrid(teks: _bungkus, bungkus: true),
  _a('C8'): const SelGrid(jenis: JenisSelGrid.kosong, isi: Color(0xFFFFF2CC)),
  _a('B9'): const SelGrid(teks: 'garis', garis: _tipis),
  _a('G10'): const SelGrid(teks: _panjangA1),
  _a('H10'): const SelGrid(jenis: JenisSelGrid.kosong, garis: _tipis),
};

/// Titik awal garis kanan / bawah sel 64 × 20 (garis 1 px di dalam tepi).
Offset _kanan(double y, [double tebal = 1]) => Offset(64 - tebal / 2, y);
Offset _bawah(double x, [double tebal = 1]) => Offset(x, 20 - tebal / 2);

Finder _teksDi(String a1, String teks) => find.descendant(
  of: find.byKey(kunciSelGrid(_a(a1))),
  matching: find.text(teks),
);

/// Ada `drawLine` (berwarna [warna], mulai [p1]) di antara panggilan kanvas
/// sel — dicari ke depan, urutan panggilan lain tidak menentukan. [lalu] =
/// sesudahnya ada lagi garis berwarna itu di titik yang sama (lapis atas).
PaintPattern _garis({Color? warna, Offset? p1, Color? lalu}) {
  bool cocok(Symbol m, List<dynamic> a, Color? w) =>
      m == #drawLine &&
      (p1 == null || a[0] == p1) &&
      // Paint menyimpan warna sebagai float32: bandingkan ARGB 8-bit.
      (w == null || (a[2] as Paint).color.toARGB32() == w.toARGB32());
  final pola = paints..something((m, a) => cocok(m, a, warna));
  if (lalu != null) pola.something((m, a) => cocok(m, a, lalu));
  return pola;
}

RenderObject _lukis(WidgetTester tester, String a1) => tester.renderObject(
  find
      .descendant(
        of: find.byKey(kunciSelGrid(_a(a1))),
        matching: find.byType(CustomPaint),
      )
      .first,
);

Stack _stack(WidgetTester tester, String a1) => tester.widget<Stack>(
  find.descendant(
    of: find.byKey(kunciSelGrid(_a(a1))),
    matching: find.byType(Stack),
  ),
);

Future<void> _pompa(
  WidgetTester tester, {
  KendaliGridSel? kendali,
  bool garisKisi = true,
  ThemeData? tema,
  int baris = _baris,
  int kolom = _kolom,
  Set<AlamatSel>? catat,
}) async {
  tester.view.physicalSize = const Size(800, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SelGrid? baca(WidgetRef _, int b, int k) {
    final a = AlamatSel(b, k);
    catat?.add(a);
    return _isi[a] ?? SelGrid.kosong;
  }

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: tema ?? TemaStudio.terang,
        locale: const Locale('id'),
        localizationsDelegates: StudioL10n.localizationsDelegates,
        supportedLocales: StudioL10n.supportedLocales,
        home: Scaffold(
          body: GridSel(
            jumlahBaris: baris,
            jumlahKolom: kolom,
            tataLetak: TataLetakGrid(
              tinggiBaris: const {7: 40},
              gabungan: [RentangSel(5, 1, 5, 2)],
              garisKisi: garisKisi,
            ),
            kendali: kendali ?? KendaliGridSel(awal: _a('J14')),
            selTonton: baca,
            selBaca: baca,
            fokusOtomatis: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey tombol) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(tombol);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}
