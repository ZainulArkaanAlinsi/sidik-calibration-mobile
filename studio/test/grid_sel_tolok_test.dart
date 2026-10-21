import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_studio/l10n/studio_l10n.dart';
import 'package:sidik_studio/tema/tema_studio.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// Tolok ukur sederhana ST-T-015 (+ Tahap A): 2.000 baris digulir.
///
/// Yang DIBUKTIKAN di sini: virtualisasi — sel yang dibangun tetap sebanding
/// layar, bukan sebanding lembar — dan biaya per frame gulir DIBANDINGKAN
/// TableView polos (sel `Text` saja) pada urutan gulir yang sama. Angka
/// absolut test (JIT debug, binding test, tanpa raster GPU) tidak mewakili
/// fps; rasio terhadap TableView polos yang bermakna.
///
/// Dua lembar:
///  - PADAT 2.000 × 20, tiap sel berisi (biaya gaya, garis, warna);
///  - JARANG 2.000 × 60, sel berteks panjang hanya di kolom B tiap 7 baris —
///    sel kosong memindai tetangganya mencari teks yang meluber (Tahap A),
///    jadi inilah kasus terburuk pemindaian.
///
/// Sumber sel lewat provider seperti layar workbook (`ref.watch` untuk sel
/// yang digambar, `ref.read` untuk bacaan tetangga), bukan peta polos —
/// supaya biaya berlangganan ikut terukur.
///
/// Yang TIDAK bisa dibuktikan widget test: fps nyata (≥ 55 fps sasaran
/// rencana S1b). Cara ukur manual:
///   1. `flutter run --profile -d windows` (dan tablet: `-d <id>`),
///   2. buka Workbook Alat → lembar besar (atau sumber uji 2.000 × 20),
///   3. DevTools → Performance → rekam sambil menggulir cepat 10 detik,
///   4. catat "UI/Raster frame time" rata-rata & persentil 90 (< 16,7 ms =
///      ≥ 60 fps; < 18,2 ms = ≥ 55 fps) dan jumlah jank.
void main() {
  testWidgets('PADAT 2.000 × 20: sel terbangun sebanding layar; gulir 50 '
      'frame tanpa galat', (tester) async {
    const sel = [
      SelGrid(teks: '0.07332', jenis: JenisSelGrid.angka),
      SelGrid(teks: 'Resolusi'),
      SelGrid(teks: '1.7321', rumus: '=SQRT(3)', jenis: JenisSelGrid.angka),
      SelGrid(teks: 'µm', isi: Color(0xFFFFF2CC)),
    ];
    final perSel = await _tolok(
      tester,
      nama: 'PADAT 2000×20',
      kolom: 20,
      sel: (b, k) => sel[(b + k) % sel.length],
    );
    // Sel sendiri + tetangga kanan & bawah (garis/isi) + sumber luberan.
    expect(perSel, lessThan(6));
  });

  testWidgets('JARANG 2.000 × 60 (teks meluber, sel kosong memindai '
      'tetangga): gulir 50 frame tanpa galat', (tester) async {
    final perSel = await _tolok(
      tester,
      nama: 'JARANG 2000×60',
      kolom: 60,
      sel: (b, k) => b % 7 == 0 && k == 2
          ? const SelGrid(
              teks: 'Uc2 (hasil penjumlahan semua elemen pada kolom ui)',
            )
          : SelGrid.kosong,
    );
    // Memo baris: sel kosong TIDAK memindai puluhan tetangga satu per satu.
    expect(perSel, lessThan(8));
  });
}

/// Sumber sel yang "ditonton" lewat provider, seperti halaman sel workbook.
final _sumberProvider = Provider<SelGrid Function(int, int)>(
  (ref) => throw UnimplementedError(),
);

/// Kunci sel yang tampil di frame sebelumnya (hitung sel BARU per frame).
var _sebelum = <Key>{};

int _dibangunFrameIni(WidgetTester tester) {
  final kini = find
      .byWidgetPredicate((w) => '${w.runtimeType}' == '_SelWidget')
      .evaluate()
      .map((e) => e.widget.key!)
      .toSet();
  final baru = kini.difference(_sebelum).length;
  _sebelum = kini;
  return baru;
}

/// Bacaan sel per sel yang dibangun (deterministik; waktu tidak).
Future<double> _tolok(
  WidgetTester tester, {
  required String nama,
  required int kolom,
  required SelGrid Function(int baris, int kolom) sel,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  var bacaan = 0;
  SelGrid tonton(WidgetRef ref, int b, int k) {
    bacaan++;
    return ref.watch(_sumberProvider)(b, k);
  }

  SelGrid baca(WidgetRef ref, int b, int k) {
    bacaan++;
    return ref.read(_sumberProvider)(b, k);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [_sumberProvider.overrideWithValue(sel)],
      child: MaterialApp(
        theme: TemaStudio.terang,
        localizationsDelegates: StudioL10n.localizationsDelegates,
        supportedLocales: StudioL10n.supportedLocales,
        home: Scaffold(
          body: GridSel(
            jumlahBaris: 2000,
            jumlahKolom: kolom,
            tataLetak: const TataLetakGrid(barisBeku: 1, kolomBeku: 1),
            selTonton: tonton,
            selBaca: baca,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  int jumlahSel() => find
      .byWidgetPredicate((w) => '${w.runtimeType}' == '_SelWidget')
      .evaluate()
      .length;
  final awal = jumlahSel();
  // 800 dp / 20 dp ≈ 40 baris × ≤ 20 kolom + cache gulir — jauh dari isi
  // lembar.
  expect(awal, lessThan(2000));

  final gulir = tester.state<ScrollableState>(
    find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    ),
  );
  final waktu = <int>[];
  var maks = 0;
  var dibangun = 0;
  _dibangunFrameIni(tester);
  bacaan = 0;
  for (var i = 1; i <= 50; i++) {
    gulir.position.jumpTo(i * 397.0);
    final sw = Stopwatch()..start();
    await tester.pump();
    sw.stop();
    waktu.add(sw.elapsedMicroseconds);
    final n = jumlahSel();
    if (n > maks) maks = n;
    dibangun += _dibangunFrameIni(tester);
  }
  expect(tester.takeException(), isNull);
  expect(maks, lessThan(2000));
  expect(
    find.byKey(kunciKepalaBaris(gulir.position.pixels ~/ 20)),
    findsOneWidget,
  );

  // Pembanding: TableView polos dengan jumlah baris/kolom sama, urutan
  // gulir sama.
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TableView.builder(
          rowCount: 2001,
          columnCount: kolom + 1,
          pinnedRowCount: 2,
          pinnedColumnCount: 2,
          rowBuilder: (_) => const TableSpan(extent: FixedTableSpanExtent(20)),
          columnBuilder: (_) =>
              const TableSpan(extent: FixedTableSpanExtent(64)),
          cellBuilder: (_, v) =>
              TableViewCell(child: Text('${v.row}:${v.column}')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final gulirPolos = tester.state<ScrollableState>(
    find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    ),
  );
  final polos = <int>[];
  for (var i = 1; i <= 50; i++) {
    gulirPolos.position.jumpTo(i * 397.0);
    final sw = Stopwatch()..start();
    await tester.pump();
    sw.stop();
    polos.add(sw.elapsedMicroseconds);
  }

  double rata(List<int> x) => x.reduce((a, b) => a + b) / x.length / 1000;
  double p90(List<int> x) =>
      (x.toList()..sort())[(x.length * 0.9).floor()] / 1000;
  final rasio = rata(waktu) / rata(polos);
  final perSel = bacaan / (dibangun == 0 ? 1 : dibangun);
  debugPrint(
    'TOLOK $nama (gulir 397 dp/frame × 50): sel terbangun awal $awal, maks '
    '$maks. GridSel rata ${rata(waktu).toStringAsFixed(0)} ms p90 '
    '${p90(waktu).toStringAsFixed(0)} ms; TableView polos rata '
    '${rata(polos).toStringAsFixed(0)} ms p90 '
    '${p90(polos).toStringAsFixed(0)} ms; rasio '
    '${rasio.toStringAsFixed(2)}× (test JIT debug, bukan fps); bacaan sel '
    '$bacaan untuk $dibangun sel dibangun = ${perSel.toStringAsFixed(1)} per '
    'sel',
  );
  return perSel;
}
