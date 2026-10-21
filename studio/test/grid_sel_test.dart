import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sidik_studio/l10n/studio_l10n.dart';
import 'package:sidik_studio/tema/tema_studio.dart';
import 'package:sidik_studio/tema/warna_studio.dart';
import 'package:sidik_studio/widget/grid/grid_sel.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

/// ST-T-015 — grid sel bersama (Workbook Alat S1b, nanti Kelola Data &
/// Lembar Hitung). Sumber sel di sini peta sintetis: yang diuji perilaku
/// grid, bukan isi workbook (isi workbook diuji di `workbook_layar_test.dart`
/// & `workbook_kontrak_test.dart`).
void main() {
  group('satuan & alamat Excel', () {
    test('lebar kolom Excel → dp (ECMA-376 §18.3.1.13, MDW 7)', () {
      // Lebar bawaan 8,43 karakter tersimpan 9.140625 → 64 px.
      expect(lebarKolomExcelKeDp(9.140625), 64);
      // floor(7·12,5 + 0,4921875) = floor(87,99…) = 87.
      expect(lebarKolomExcelKeDp(12.5), 87);
      expect(lebarKolomExcelKeDp(0), 0);
      expect(lebarKolomExcelKeDp(-1), 0);
    });

    test('tinggi baris poin → dp (96/72)', () {
      expect(tinggiBarisExcelKeDp(15), 20);
      expect(tinggiBarisExcelKeDp(30), 40);
      expect(tinggiBarisExcelKeDp(0), 0);
    });

    test('huruf kolom bolak-balik sampai XFD', () {
      for (final (n, h) in const [
        (1, 'A'),
        (26, 'Z'),
        (27, 'AA'),
        (52, 'AZ'),
        (703, 'AAA'),
        (16384, 'XFD'),
      ]) {
        expect(hurufKolom(n), h);
        expect(indeksKolom(h), n);
      }
      expect(indeksKolom('XFE'), isNull);
      expect(indeksKolom('A1'), isNull);
    });

    test('alamat & rentang A1', () {
      expect(AlamatSel.urai(r'$C$5'), const AlamatSel(5, 3));
      expect(AlamatSel.urai('c5')?.a1, 'C5');
      expect(AlamatSel.urai('C0'), isNull);
      expect(RentangSel.urai('C3:A1'), RentangSel(1, 1, 3, 3));
      expect(RentangSel.urai('A1:C1')?.a1, 'A1:C1');
      expect(RentangSel.urai('B2')?.tunggal, isTrue);
      expect(RentangSel.urai('A1:'), isNull);
    });
  });

  group('TSV', () {
    test('tab antar kolom, baris baru antar baris; teks bertab/berpetik '
        'dibungkus petik seperti salinan Excel', () {
      final isi = {
        (1, 1): 'Nominal',
        (1, 2): 'a\tb',
        (2, 1): '0.127',
        (2, 2): 'kata "kutip"',
        (3, 1): 'dua\nbaris',
      };
      final tsv = susunTsv(RentangSel(1, 1, 3, 2), (b, k) => isi[(b, k)] ?? '');
      expect(
        tsv,
        'Nominal\t"a\tb"\n'
        '0.127\t"kata ""kutip"""\n'
        '"dua\nbaris"\t',
      );
    });
  });

  group('warna aman', () {
    test('teks hitam workbook di tema gelap digeser sampai ≥ 4,5:1, teks '
        'merah tetap kemerahan', () {
      final latar = WarnaStudio.gelapBawaan.permukaan;
      final hitam = warnaTeksAman(const Color(0xFF000000), latar);
      expect(kontrasWarna(hitam, latar), greaterThanOrEqualTo(4.5));

      final merah = warnaTeksAman(const Color(0xFFFF0000), latar);
      expect(kontrasWarna(merah, latar), greaterThanOrEqualTo(4.5));
      expect(merah.r, greaterThan(merah.b));

      // Warna yang sudah aman tidak diubah.
      const navy = Color(0xFF0F1A2E);
      expect(warnaTeksAman(navy, const Color(0xFFFFFFFF)), navy);
    });
  });

  group('tata letak', () {
    testWidgets('kepala kolom & nomor baris terkunci; freeze menambah baris '
        'dan kolom terkunci', (tester) async {
      await _pompa(tester);

      Offset posisi(Key k) => tester.getTopLeft(find.byKey(k));
      final kepalaB = posisi(kunciKepalaKolom(2));
      final baris2 = posisi(kunciSelGrid(_a('B2')));
      final barisNomor = posisi(kunciKepalaBaris(1));
      final kolomA = posisi(kunciSelGrid(_a('A10')));
      final b10 = posisi(kunciSelGrid(_a('B10')));

      // Gulir ke bawah: kepala kolom & baris beku (1–2) tidak ikut bergerak.
      await tester.drag(find.byType(TableView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(posisi(kunciSelGrid(_a('B10'))).dy, lessThan(b10.dy - 200));
      expect(posisi(kunciKepalaKolom(2)), kepalaB);
      expect(posisi(kunciSelGrid(_a('B2'))), baris2);
      // Baris yang tergulir ke bawah area beku tertutup olehnya.
      expect(posisi(kunciSelGrid(_a('B10'))).dy, lessThan(baris2.dy));

      // Gulir ke kanan: nomor baris & kolom beku (A) tidak ikut bergerak.
      final e2 = posisi(kunciKepalaKolom(5));
      await tester.drag(find.byType(TableView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(posisi(kunciKepalaKolom(5)).dx, lessThan(e2.dx - 200));
      expect(posisi(kunciKepalaBaris(1)), barisNomor);
      expect(posisi(kunciSelGrid(_a('A25'))).dx, kolomA.dx);
    });

    testWidgets('sel gabungan selebar & setinggi rentangnya; sel yang '
        'tertutup tidak dibangun', (tester) async {
      await _pompa(tester);

      // B5:C6 → (100 + 64) × (20 + 20).
      expect(
        tester.getSize(find.byKey(kunciSelGrid(_a('B5')))),
        const Size(164, 40),
      );
      for (final a in ['C5', 'B6', 'C6']) {
        expect(find.byKey(kunciSelGrid(_a(a))), findsNothing, reason: a);
      }
      expect(find.text('Gabung B5'), findsOneWidget);
    });

    testWidgets('gabungan yang melintasi freeze dipecah; isinya tetap '
        'tergambar utuh melintasi batas', (tester) async {
      await _pompa(tester);

      // A1:C1 dengan kolom A beku → bagian A1 (80) + bagian B1:C1 (164).
      expect(tester.getSize(find.byKey(kunciSelGrid(_a('A1')))).width, 80);
      expect(
        tester.getSize(find.byKey(const ValueKey('sel-bagian-B1'))).width,
        164,
      );
      // Teks judul digambar di kedua bagian (digeser, dipotong).
      expect(find.text('Judul lembar'), findsNWidgets(2));
    });

    testWidgets('lebar/tinggi kustom; kolom & baris tersembunyi selebar 0', (
      tester,
    ) async {
      await _pompa(tester);

      expect(tester.getSize(find.byKey(kunciSelGrid(_a('A3')))).width, 80);
      expect(tester.getSize(find.byKey(kunciSelGrid(_a('B3')))).width, 100);
      expect(tester.getSize(find.byKey(kunciSelGrid(_a('A1')))).height, 30);
      // D tersembunyi: kepalanya tidak menggambar huruf.
      expect(find.text('D'), findsNothing);
      expect(find.byKey(kunciSelGrid(_a('D3'))), findsNothing);
      // Baris 8 tersembunyi.
      expect(find.byKey(kunciSelGrid(_a('B8'))), findsNothing);
    });

    testWidgets('angka rata kanan, teks rata kiri (aturan "General" Excel); '
        'satu font untuk keduanya', (tester) async {
      await _pompa(tester);

      // Kotak teks diletakkan persis: rata kanan berakhir 2 dp sebelum tepi
      // kanan sel (kotaknya +1 dp), rata kiri mulai 2 dp dari tepi kiri.
      final b3 = tester.getRect(find.byKey(kunciSelGrid(_a('B3'))));
      final angka = tester.getRect(find.text('1.500'));
      expect(b3.right - angka.right, closeTo(1, 0.01));
      final c3 = tester.getRect(find.byKey(kunciSelGrid(_a('C3'))));
      final teks = tester.getRect(find.text('teks biasa'));
      expect(teks.left - c3.left, closeTo(2, 0.01));

      // Excel memakai satu font untuk teks & angka.
      expect(
        tester.widget<Text>(find.text('1.500')).style?.fontFamily,
        contains('Inter'),
      );
      expect(
        tester.widget<Text>(find.text('teks biasa')).style?.fontFamily,
        contains('Inter'),
      );
    });
  });

  group('seleksi & keyboard', () {
    testWidgets('ketuk memilih; panah, Tab, Enter, Shift memindah/memperluas; '
        'melewati kolom/baris tersembunyi & gabungan', (tester) async {
      final kendali = KendaliGridSel();
      await _pompa(tester, kendali: kendali);

      await tester.tap(find.byKey(kunciSelGrid(_a('B3'))));
      await tester.pump();
      expect(kendali.aktif, _a('B3'));

      await _tekan(tester, LogicalKeyboardKey.arrowRight);
      expect(kendali.aktif, _a('C3'));
      // D tersembunyi → langsung E.
      await _tekan(tester, LogicalKeyboardKey.tab);
      expect(kendali.aktif, _a('E3'));
      await _tekan(tester, LogicalKeyboardKey.tab, shift: true);
      expect(kendali.aktif, _a('C3'));
      await _tekan(tester, LogicalKeyboardKey.enter);
      expect(kendali.aktif, _a('C4'));
      // Masuk ke gabungan B5:C6 → sel aktif = kiri-atasnya.
      await _tekan(tester, LogicalKeyboardKey.arrowDown);
      expect(kendali.aktif, _a('B5'));
      // Keluar dari gabungan ke bawah: baris 7, lalu 8 tersembunyi → 9.
      await _tekan(tester, LogicalKeyboardKey.arrowDown);
      expect(kendali.aktif, _a('B7'));
      await _tekan(tester, LogicalKeyboardKey.arrowDown);
      expect(kendali.aktif, _a('B9'));
      await _tekan(tester, LogicalKeyboardKey.enter, shift: true);
      expect(kendali.aktif, _a('B7'));

      // Shift+panah: sel aktif tetap, rentang melebar dan menutup gabungan.
      await _tekan(tester, LogicalKeyboardKey.arrowUp, shift: true);
      expect(kendali.aktif, _a('B7'));
      expect(kendali.rentang.a1, 'B5:C7');

      // Shift+ketuk memperluas dari sel aktif.
      await tester.tap(find.byKey(kunciSelGrid(_a('B3'))));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.byKey(kunciSelGrid(_a('C4'))));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(kendali.aktif, _a('B3'));
      expect(kendali.rentang.a1, 'B3:C4');
    });

    testWidgets('Home, Ctrl+Home, Ctrl+End, Ctrl+panah, PgDn/PgUp; sel aktif '
        'digulir ke dalam layar', (tester) async {
      final kendali = KendaliGridSel();
      await _pompa(tester, kendali: kendali);
      await tester.tap(find.byKey(kunciSelGrid(_a('C3'))));
      await tester.pump();

      await _tekan(tester, LogicalKeyboardKey.home);
      expect(kendali.aktif, _a('A3'));

      await _tekan(tester, LogicalKeyboardKey.end, ctrl: true);
      expect(kendali.aktif, AlamatSel(_baris, _kolom));
      // Digulir sampai terlihat.
      expect(
        find.byKey(kunciSelGrid(AlamatSel(_baris, _kolom))),
        findsOneWidget,
      );

      await _tekan(tester, LogicalKeyboardKey.home, ctrl: true);
      expect(kendali.aktif, _a('A1'));

      await _tekan(tester, LogicalKeyboardKey.arrowRight, ctrl: true);
      expect(kendali.aktif, AlamatSel(1, _kolom));
      await _tekan(tester, LogicalKeyboardKey.arrowLeft, ctrl: true);
      expect(kendali.aktif, _a('A1'));
      // Kembali ke awal: kolom B terlihat lagi.
      expect(find.byKey(kunciKepalaKolom(2)).hitTestable(), findsOneWidget);

      await tester.tap(find.byKey(kunciSelGrid(_a('B3'))));
      await tester.pump();
      await _tekan(tester, LogicalKeyboardKey.pageDown);
      // Satu layar: area gulir 400 − 22 (kepala) − 30 − 20 (baris beku)
      // = 328 dp ≈ 16 baris 20 dp (+ baris 8 yang tersembunyi).
      expect(kendali.aktif.baris, greaterThan(15));
      expect(find.byKey(kunciSelGrid(kendali.aktif)), findsOneWidget);
      await _tekan(tester, LogicalKeyboardKey.pageUp);
      expect(kendali.aktif.baris, lessThanOrEqualTo(3));
    });

    testWidgets('klik kepala kolom/baris memilih seluruh kolom/baris', (
      tester,
    ) async {
      final kendali = KendaliGridSel();
      await _pompa(tester, kendali: kendali);

      await tester.tap(find.byKey(kunciKepalaKolom(3)));
      await tester.pump();
      expect(kendali.rentang, RentangSel(1, 3, _baris, 3));

      await tester.tap(find.byKey(kunciKepalaBaris(4)));
      await tester.pump();
      expect(kendali.rentang, RentangSel(4, 1, 4, _kolom));
    });
  });

  group('salin & rumus', () {
    testWidgets('Ctrl+C menyalin rentang terpilih sebagai TSV; mode rumus '
        'menyalin rumus', (tester) async {
      final papan = _PapanKlip(tester);
      final kendali = KendaliGridSel();
      await _pompa(tester, kendali: kendali);

      await tester.tap(find.byKey(kunciSelGrid(_a('A3'))));
      await tester.pump();
      await _tekan(tester, LogicalKeyboardKey.arrowRight, shift: true);
      await _tekan(tester, LogicalKeyboardKey.arrowRight, shift: true);
      await _tekan(tester, LogicalKeyboardKey.arrowDown, shift: true);
      expect(kendali.rentang.a1, 'A3:C4');

      await _tekan(tester, LogicalKeyboardKey.keyC, ctrl: true);
      await tester.pump();
      expect(papan.isi, '1\t1.500\tteks biasa\n\t\t');
      expect(find.text('2 × 3 sel disalin'), findsOneWidget);

      await _tekan(tester, LogicalKeyboardKey.backquote, ctrl: true);
      await _tekan(tester, LogicalKeyboardKey.keyC, ctrl: true);
      await tester.pump();
      expect(papan.isi, '1\t=A3*1.5\tteks biasa\n\t\t');
    });

    testWidgets('Ctrl+` menampilkan rumus di sel; sekali lagi kembali ke '
        'nilai', (tester) async {
      final kendali = KendaliGridSel();
      await _pompa(tester, kendali: kendali);
      await tester.tap(find.byKey(kunciSelGrid(_a('B3'))));
      await tester.pump();

      expect(find.text('1.500'), findsOneWidget);
      await _tekan(tester, LogicalKeyboardKey.backquote, ctrl: true);
      expect(kendali.tampilkanRumus, isTrue);
      expect(find.text('=A3*1.5'), findsOneWidget);
      expect(find.text('1.500'), findsNothing);
      // Sel tanpa rumus tetap menampilkan nilainya.
      expect(find.text('teks biasa'), findsOneWidget);

      await _tekan(tester, LogicalKeyboardKey.backquote, ctrl: true);
      expect(find.text('1.500'), findsOneWidget);
    });

    testWidgets('sel yang belum termuat: salin DIBATALKAN dengan pesan, bukan '
        'menyalin sel kosong diam-diam', (tester) async {
      final papan = _PapanKlip(tester);
      final kendali = KendaliGridSel();
      await _pompa(
        tester,
        kendali: kendali,
        belumTermuat: {_a('C3')},
        siapkan: (_, _) async => throw Exception('jaringan'),
      );
      await tester.tap(find.byKey(kunciSelGrid(_a('B3'))));
      await tester.pump();
      await _tekan(tester, LogicalKeyboardKey.arrowRight, shift: true);

      await _tekan(tester, LogicalKeyboardKey.keyC, ctrl: true);
      await tester.pump();
      expect(papan.isi, isNull);
      expect(
        find.text('Sebagian sel belum termuat — salin dibatalkan. Coba lagi.'),
        findsOneWidget,
      );
    });

    testWidgets('pilihan melebihi batas salin ditolak dengan pesan', (
      tester,
    ) async {
      final papan = _PapanKlip(tester);
      final kendali = KendaliGridSel();
      await _pompa(tester, kendali: kendali, batasSalin: 10);
      await tester.tap(find.byKey(kunciKepalaKolom(2)));
      await tester.pump();

      await _tekan(tester, LogicalKeyboardKey.keyC, ctrl: true);
      await tester.pump();
      expect(papan.isi, isNull);
      expect(
        find.text('$_baris sel terlalu banyak untuk disalin (maks. 10).'),
        findsOneWidget,
      );
    });
  });
}

// ─────────────────────────────────────────────────────────────── pembantu

const _baris = 60;
const _kolom = 20;

AlamatSel _a(String a1) => AlamatSel.urai(a1)!;

/// Lembar uji 60 × 20: lebar A=80, B=100; tinggi baris 1 = 30; freeze B3
/// (baris 1–2 & kolom A beku); A1:C1 & B5:C6 bergabung; D & baris 8
/// tersembunyi.
const _tataLetak = TataLetakGrid(
  lebarKolom: {1: 80, 2: 100},
  tinggiBaris: {1: 30},
  barisBeku: 2,
  kolomBeku: 1,
  kolomTersembunyi: {4},
  barisTersembunyi: {8},
);

final _gabungan = [RentangSel(1, 1, 1, 3), RentangSel(5, 2, 6, 3)];

final Map<AlamatSel, SelGrid> _isi = {
  _a('A1'): const SelGrid(teks: 'Judul lembar', tebal: true),
  _a('A3'): const SelGrid(teks: '1', jenis: JenisSelGrid.angka),
  _a('B3'): const SelGrid(
    teks: '1.500',
    rumus: '=A3*1.5',
    jenis: JenisSelGrid.angka,
  ),
  _a('C3'): const SelGrid(teks: 'teks biasa'),
  _a('B5'): const SelGrid(
    teks: 'Gabung B5',
    isi: Color(0xFFFFF2CC),
    rata: TextAlign.center,
  ),
  for (var b = 1; b <= _baris; b++)
    if (b > 8) AlamatSel(b, 1): SelGrid(teks: '$b', jenis: JenisSelGrid.angka),
};

Future<void> _pompa(
  WidgetTester tester, {
  KendaliGridSel? kendali,
  Set<AlamatSel> belumTermuat = const {},
  PenyiapRentangGrid? siapkan,
  int batasSalin = 200000,
}) async {
  tester.view.physicalSize = const Size(800, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SelGrid? baca(WidgetRef _, int b, int k) {
    final a = AlamatSel(b, k);
    if (belumTermuat.contains(a)) return null;
    return _isi[a] ?? SelGrid.kosong;
  }

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: TemaStudio.terang,
        locale: const Locale('id'),
        localizationsDelegates: StudioL10n.localizationsDelegates,
        supportedLocales: StudioL10n.supportedLocales,
        home: Scaffold(
          body: GridSel(
            jumlahBaris: _baris,
            jumlahKolom: _kolom,
            tataLetak: TataLetakGrid(
              lebarKolom: _tataLetak.lebarKolom,
              tinggiBaris: _tataLetak.tinggiBaris,
              gabungan: _gabungan,
              barisBeku: _tataLetak.barisBeku,
              kolomBeku: _tataLetak.kolomBeku,
              kolomTersembunyi: _tataLetak.kolomTersembunyi,
              barisTersembunyi: _tataLetak.barisTersembunyi,
            ),
            kendali: kendali,
            selTonton: baca,
            selBaca: baca,
            siapkanRentang: siapkan,
            batasSalinSel: batasSalin,
            fokusOtomatis: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tekan(
  WidgetTester tester,
  LogicalKeyboardKey tombol, {
  bool shift = false,
  bool ctrl = false,
}) async {
  if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(tombol);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// Tiruan papan klip platform: `Clipboard.setData` ditangkap.
class _PapanKlip {
  _PapanKlip(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          isi = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  String? isi;
}
